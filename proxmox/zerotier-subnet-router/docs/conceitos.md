# 📚 Conceitos — ZeroTier Subnet Router

Explicação dos conceitos por trás do projeto, na ordem em que um pacote percorre o caminho entre o notebook e a VM.

---

## 1. Visão geral do caminho

```text
Notebook ──► zt0 ──► [túnel ZeroTier] ──► LXC (zt0 → eth0) ──► LAN ──► VM
              │                              │
        rota gerenciada                forwarding + NAT + firewall
```

Cada etapa depende de um conceito:

| Etapa | Conceito |
|---|---|
| Notebook decide mandar o pacote para o ZeroTier | Rota gerenciada |
| Pacote viaja até o LXC | ZeroTier (rede virtual criptografada) |
| LXC aceita repassar o pacote | IP forwarding + regras de `FORWARD` |
| LXC troca a origem do pacote | NAT / `MASQUERADE` |
| ZeroTier funciona dentro do container | Dispositivo TUN |

---

## 2. ZeroTier

O **ZeroTier** cria uma **rede virtual** entre dispositivos espalhados pela internet, como se estivessem no mesmo switch. É uma VPN do tipo *mesh*: os dispositivos conversam diretamente, e o tráfego é criptografado de ponta a ponta.

| Termo | Significado |
|---|---|
| **Network ID** | Identificador de 16 caracteres hexadecimais da sua rede. Quem tem o ID pode *pedir* para entrar, mas não entra sem autorização |
| **Membro (node)** | Qualquer dispositivo que entrou na rede. Recebe um IP privado dentro dela |
| **Autorização** | Em redes privadas, cada membro precisa ser aprovado manualmente no ZeroTier Central |
| **ZeroTier Central** | Painel web onde se gerenciam membros, IPs e rotas |
| **Interface `zt...`** | Interface de rede virtual criada no sistema pelo ZeroTier |

> 🔒 O ID da rede não é uma senha, mas **não deve ser publicado**: qualquer pessoa poderia ficar enviando pedidos de entrada.

---

## 3. Subnet Router

**Subnet router não é um programa.** É um *papel* que uma máquina assume quando reúne três condições:

1. Tem o **ZeroTier** instalado e autorizado.
2. Tem o **IP forwarding** ligado.
3. Existe uma **rota gerenciada** no Central apontando para ela.

Com isso, a máquina vira uma "porta de entrada" para uma rede inteira (a LAN), e os dispositivos ZeroTier alcançam máquinas que **não têm ZeroTier instalado** (VMs, impressoras, o próprio painel do Proxmox).

### Por que não instalar o ZeroTier em cada VM?
- Menos coisas para instalar e manter.
- Dispositivos que não aceitam ZeroTier também ficam acessíveis.
- Um único ponto para aplicar regras de firewall.

---

## 4. Rota gerenciada (Managed Route)

Configurada no ZeroTier Central, em *Advanced → Managed Routes*:

| Campo | Valor | Significado |
|---|---|---|
| **Destination** | `192.168.10.0/24` | A rede que você quer **alcançar** |
| **Via** | IP ZeroTier do LXC | O "porteiro" por onde o tráfego deve passar |

Leitura: *"para chegar em `192.168.10.0/24`, mande os pacotes pelo LXC"*.

Pontos importantes:

- **Quem usa a rota é o notebook** (e outros membros), não a LAN. O ZeroTier a instala automaticamente em cada dispositivo (precisa estar com `allowManaged` ligado).
- **Em casa**, o notebook já tem uma rota local direta para a LAN, que tem prioridade. O tráfego não passa pelo ZeroTier.
- **Fora de casa**, não existe rota local, então vale a do ZeroTier. É assim que o acesso remoto entra em ação sozinho.
- O **Via** é o IP **ZeroTier** do LXC, e não o IP dele na LAN.

### Conflito de sub-redes
Se a rede onde você estiver usar o mesmo `192.168.10.0/24`, o notebook acha que o destino é local e ignora o ZeroTier. Por isso redes menos comuns (como `10.20.30.0/24`) evitam problemas em Wi-Fi de terceiros.

---

## 5. IP Forwarding

Por padrão, o kernel Linux **descarta pacotes que não são destinados a ele**. Para atuar como roteador (receber por uma interface e repassar por outra), é preciso ligar:

```bash
net.ipv4.ip_forward = 1
```

Sem isso, o pacote chega ao LXC e morre ali. O valor fica em `/etc/sysctl.conf` para sobreviver a reinicializações, e `sysctl -p` aplica na hora.

---

## 6. NAT e MASQUERADE

Quando o notebook (IP ZeroTier) fala com uma VM, a VM precisa saber **como responder**. Mas ela só conhece a LAN e não sabe como chegar na rede ZeroTier.

O **NAT** resolve isso: o LXC troca o IP de origem do pacote pelo **próprio IP dele na LAN**. Para a VM, quem pediu foi o LXC, e ela responde para o LXC, que devolve ao notebook.

```text
Notebook (10.147.17.10) ──► LXC ──► VM
                  origem trocada para 192.168.10.201
VM responde ──► LXC ──► Notebook
```

`MASQUERADE` é o tipo de NAT que usa automaticamente o IP da interface de saída (`eth0`), sem precisar fixar o endereço.

> ⚠️ Efeito colateral: nos logs das VMs, todo acesso remoto aparece com o IP do LXC.

---

## 7. iptables

O **iptables** é o firewall do kernel. Ele organiza as regras em **tabelas** e **chains** (etapas do caminho do pacote).

| Tabela / Chain | Quando atua | Uso no projeto |
|---|---|---|
| `nat` / `POSTROUTING` | Pacote prestes a **sair** | `MASQUERADE` (troca a origem) |
| `filter` / `FORWARD` | Pacote **em trânsito** pela máquina | Decide quem pode atravessar o LXC |

### Opções usadas

| Opção | Significado |
|---|---|
| `-A` | **A**ppend: adiciona a regra ao final da chain |
| `-D` | **D**elete: remove uma regra idêntica |
| `-t nat` | Usa a tabela de NAT |
| `-i zt+` | Interface de **entrada**; o `+` é curinga (`zt` seguido de qualquer coisa) |
| `-o eth0` | Interface de **saída** |
| `-s <rede>` | IP ou sub-rede de **origem** |
| `-p tcp` | Protocolo |
| `-m multiport --dports 22,443,8006` | Várias portas de destino em uma só regra |
| `-m state --state RELATED,ESTABLISHED` | Só pacotes de conexões **já iniciadas** |
| `-j ACCEPT` / `-j MASQUERADE` | Ação a tomar |

### Regras estateful (`RELATED,ESTABLISHED`)

```bash
iptables -A FORWARD -i eth0 -o zt+ -m state --state RELATED,ESTABLISHED -j ACCEPT
```

Permite o tráfego de **volta** apenas quando ele é resposta a algo que partiu do ZeroTier. Assim, uma máquina da LAN **não consegue iniciar** conexão para o notebook. Isso é mais seguro do que liberar `eth0 → zt+` por completo.

### Ordem importa
O iptables lê as regras de cima para baixo e para na primeira que casa. Por isso o `ACCEPT` específico vem antes de qualquer regra mais ampla.

---

## 8. Persistência das regras

Regras do iptables ficam **na memória** e somem ao reiniciar. Para manter:

```bash
apt install iptables-persistent
netfilter-persistent save
```

As regras são gravadas em `/etc/iptables/rules.v4` e recarregadas no boot.

> 💡 Em versões recentes do Ubuntu, o `iptables` usa o `nftables` por baixo (modo de compatibilidade). Os comandos continuam os mesmos.

---

## 9. Dispositivo TUN no LXC

O ZeroTier cria a interface `zt...` usando o dispositivo **TUN** (`/dev/net/tun`), que permite a programas comuns criarem interfaces de rede virtuais.

Um LXC é isolado e, por padrão, **não enxerga** esse dispositivo do host. São necessárias duas linhas no `/etc/pve/lxc/<ID>.conf`:

```text
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

| Linha | Função |
|---|---|
| `devices.allow: c 10:200 rwm` | **Permissão**: libera ler, escrever e criar o dispositivo de caractere `10:200` (TUN) |
| `mount.entry: ... bind,create=file` | **Presença**: monta o `/dev/net/tun` do host dentro do container |

Em uma **VM** isso não é necessário, porque ela tem o próprio kernel.

---

## 10. Por que um LXC dedicado

| Opção | Vantagem | Desvantagem |
|---|---|---|
| **No host Proxmox** | Mais simples | Se o ZeroTier for comprometido, o atacante está no hipervisor. Mistura funções |
| **LXC dedicado** *(escolhido)* | Leve, isolado do host, fácil de recriar | Precisa liberar o TUN |
| **VM dedicada** | Isolamento máximo, sem ajuste de TUN | Gasta mais RAM e disco |

Um container **unprivileged** reduz ainda mais o impacto: o `root` dentro dele não é `root` no host.

---

## 11. Como saber que o tráfego passou pelo roteador (TTL)

Todo pacote tem um campo **TTL** que **diminui 1 a cada roteador** por onde passa.

- Ping direto na mesma rede: `ttl=64`
- Ping passando pelo LXC: `ttl=63`

O "1" a menos é a prova de que o pacote atravessou o subnet router.

---

## 12. Diagnóstico por camadas

Quando algo não funciona, teste de dentro para fora e veja **onde para**:

| # | Teste | Se falhar |
|---|---|---|
| 1 | `ping` do LXC para o gateway | Problema de IP/bridge do container |
| 2 | `ping 1.1.1.1` no LXC | Falta o gateway padrão (`Network is unreachable`) |
| 3 | `ping google.com` no LXC | Problema de DNS |
| 4 | `zerotier-cli listnetworks` mostra `OK` | Membro não autorizado ou sem TUN |
| 5 | `ip route \| grep 192.168.10` no notebook | Rota gerenciada não chegou (`allowManaged`) |
| 6 | `ping` do notebook para o IP ZeroTier do LXC | Problema na conexão ZeroTier |
| 7 | `ping` do notebook para uma máquina da LAN | `ip_forward`, `FORWARD` ou `MASQUERADE` |

Ferramentas úteis dentro do LXC:

```bash
iptables -L FORWARD -n -v      # os contadores devem subir durante o teste
tcpdump -ni eth0 icmp          # mostra os pacotes saindo com o IP do LXC
```

Mensagens que ajudam a localizar o problema:

| Mensagem | Quem a gerou | Significado |
|---|---|---|
| `Network is unreachable` | O próprio sistema | Não há rota padrão |
| `Não há rota para o host` | O notebook | A rota gerenciada não existe |
| `Host de destino inalcançável` vindo do IP do LXC | O LXC | O pacote chegou, mas o destino não existe na LAN |
| Timeout sem resposta | Ninguém | Pacote descartado: firewall, forwarding ou destino desligado |

---

## 13. Segurança: o que importa

- **Autorize apenas os seus dispositivos** no ZeroTier Central e use 2FA na conta.
- **Restrinja o `FORWARD`** à sub-rede de origem e às portas necessárias. Liberar tudo expõe a LAN inteira a qualquer membro.
- **Não exponha portas na internet.** O acesso remoto acontece só pelo túnel.
- **Proteja o host:** o painel (8006) e o SSH continuam exigindo senha forte ou chave, e 2FA no Proxmox.
- **Não publique segredos** no repositório: tokens, senhas, chaves, ID da rede e IPs reais.
- **Revogar é diferente de apagar:** se um segredo for commitado, ele continua no histórico do Git. A correção é trocar o segredo, e não só apagar o arquivo.

---

## 14. Glossário rápido

| Termo | Significado |
|---|---|
| **LAN** | Rede local (aqui, `192.168.10.0/24`) |
| **Gateway** | Roteador por onde se sai da rede local |
| **Bridge (`vmbr0`)** | Switch virtual do Proxmox que conecta VMs, containers e a rede física |
| **LXC** | Container Linux leve, compartilha o kernel do host |
| **cgroup** | Mecanismo do kernel que limita e controla acesso a recursos e dispositivos |
| **TUN/TAP** | Interfaces de rede virtuais criadas por programas |
| **CIDR** | Notação de sub-rede (`/24` = máscara `255.255.255.0`) |
| **TTL** | Contador que diminui a cada roteador atravessado |
| **Estateful** | Firewall que acompanha o estado das conexões |
| **Mesh** | Rede em que os dispositivos conversam diretamente entre si |