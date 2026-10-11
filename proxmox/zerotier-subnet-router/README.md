# 🔐 ZeroTier Subnet Router — Acesso remoto seguro ao Proxmox

Projeto de laboratório que permite acessar as **VMs e o painel do Proxmox de qualquer lugar**, sem abrir portas no roteador, usando um **container LXC dedicado** como roteador de sub-rede (*subnet router*) do ZeroTier.

> ⚠️ **Ambiente de laboratório para fins educacionais.** IDs de rede, tokens e IPs reais foram substituídos por placeholders. Revise as regras de firewall para o seu cenário antes de usar em produção.

---

## 🏗️ Topologia & Infraestrutura

```text
   Notebook (fora de casa)
   IP ZeroTier: 10.147.17.10
            │
            │  túnel criptografado (ZeroTier)
            ▼
   ZeroTier Central ── rota gerenciada:
   192.168.10.0/24 via 10.147.17.201
            │
            ▼
   ┌──────────────────────────────┐
   │  LXC CT101 (subnet router)   │
   │  zt0: 10.147.17.201          │
   │  eth0: 192.168.10.201        │
   │  ip_forward + NAT + FORWARD  │
   └──────────────┬───────────────┘
                  │  vmbr0
      ┌───────────┼────────────┐
      ▼           ▼            ▼
  Painel Proxmox   VM 1       VM 2
  :8006         192.168.10.x  192.168.10.x
```

### Endereçamento IP

| Máquina | IP | Função |
|---|---|---|
| `Notebook` | `10.147.17.10` (ZeroTier) | Cliente remoto |
| `CT101` (LXC) | `10.147.17.201` (ZeroTier) / `192.168.10.201` (LAN) | Subnet router |
| `Proxmox` | `192.168.10.x` | Hipervisor (painel na porta 8006) |
| `VMs` | `192.168.10.x` | Destinos acessados remotamente |

> Os IPs do ZeroTier (`10.147.17.x`) são exemplos. A sub-rede real é definida no ZeroTier Central.

### Ambiente

| Componente | Especificação |
|---|---|
| Hipervisor | Proxmox VE |
| Container | LXC *unprivileged*, 2 GB de RAM, 30 GB de disco | *Pode ser bem mais reduzido*
| Rede do container | Bridge `vmbr0`, IP fixo na LAN, gateway configurado |

---

## 🧰 Stack Utilizada

| Tecnologia | Versão | Função |
|---|---|---|
| Proxmox VE | - | Hipervisor e gerenciador de containers |
| Ubuntu Server | 26.04 LTS | Sistema operacional do container |
| ZeroTier One | 1.x | Rede virtual criptografada (VPN *mesh*) |
| iptables | 1.8.x | NAT (`MASQUERADE`) e regras de `FORWARD` |
| netfilter-persistent | - | Persistência das regras após reiniciar |

---

## ⚙️ Como Funciona

- **ZeroTier:** cria uma rede virtual entre os dispositivos autorizados. Cada membro recebe um IP privado dentro dela.
- **Subnet router:** é um *papel*, não um programa. Uma máquina vira roteador de sub-rede quando tem o ZeroTier instalado, o *IP forwarding* ligado e uma rota gerenciada apontando para ela.
- **Rota gerenciada:** configurada no ZeroTier Central (`192.168.10.0/24 via <IP ZeroTier do LXC>`). O ZeroTier a instala automaticamente nos dispositivos autorizados.
- **IP forwarding:** permite ao kernel do LXC repassar pacotes da interface `zt` para a `eth0`.
- **NAT (`MASQUERADE`):** troca a origem dos pacotes pelo IP do LXC, para que as VMs respondam sem conhecer a rede ZeroTier.
- **`FORWARD` restrito:** só a sub-rede ZeroTier e as portas necessárias passam. O tráfego de volta é limitado a conexões já estabelecidas.
- **TUN no LXC:** o ZeroTier precisa criar uma interface virtual. Por isso o container recebe o dispositivo `/dev/net/tun` do host.

### Por que em um LXC e não no host?

Se o ZeroTier rodasse no hipervisor e fosse comprometido, o atacante estaria no host. Em um container *unprivileged*, o impacto fica isolado.

---

## 📁 Estrutura do Repositório

```bash
zerotier-subnet-router/
├── README.md                      # Documentação do laboratório
├── configs/
│   ├── lxc-tun.conf               # Linhas do TUN para /etc/pve/lxc/<ID>.conf
│   ├── sysctl.conf                # Habilita o ip_forward
│   └── firewall.sh                # Regras de NAT e FORWARD
├── docs/
│   ├── passo-a-passo.md           # Guia completo de instalação com comandos
│   └── conceitos.md               # Explicação de TUN, NAT, forwarding e rotas

```

---

## 🚀 Instalação Resumida

**1. No host Proxmox**, adicione ao `/etc/pve/lxc/<ID>.conf` e reinicie o container:

```text
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

**2. No LXC**, instale o ZeroTier e entre na rede:

```bash
apt update && apt install -y curl iptables iptables-persistent
curl -s https://install.zerotier.com | bash
zerotier-cli join <ID_DA_REDE>
```

**3. No LXC**, ligue o *forwarding* e aplique as regras:

```bash
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i zt+ -o eth0 -s <SUBREDE_ZEROTIER> -p tcp -m multiport --dports 22,443,8006 -j ACCEPT
iptables -A FORWARD -i zt+ -o eth0 -p icmp -j ACCEPT
iptables -A FORWARD -i eth0 -o zt+ -m state --state RELATED,ESTABLISHED -j ACCEPT
netfilter-persistent save
```

**4. No ZeroTier Central**, autorize o membro e crie a rota em *Advanced → Managed Routes*:

| Campo | Valor |
|---|---|
| Destination | `192.168.10.0/24` |
| Via | IP ZeroTier do LXC |

---

## ✅ Teste de Funcionamento

Com o notebook **fora da rede local** (por exemplo, no *hotspot* do celular):

```bash
# 1. A rota foi instalada pelo ZeroTier?
ip route | grep 192.168.10

# 2. O LXC responde pelo ZeroTier?
ping -c 2 <IP_ZEROTIER_DO_LXC>

# 3. A LAN é alcançada passando pelo LXC?
ping -c 2 192.168.10.<IP_DE_UMA_VM>

# 4. O painel do Proxmox abre?
curl -k -I https://192.168.10.<IP_DO_PROXMOX>:8006
```

> 💡 **Como saber que o tráfego passou pelo roteador:** o `ping` para a LAN responde com `ttl=63`, e não 64. O TTL cai em 1 a cada roteador, e esse "1" é o LXC.

Para acompanhar o tráfego dentro do container:

```bash
iptables -L FORWARD -n -v      # os contadores devem subir durante o teste
tcpdump -ni eth0 icmp          # mostra os pacotes saindo com o IP do LXC (NAT)
```

---

## 🛠️ Problemas Comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| ZeroTier acusa erro de TUN/TAP | `/dev/net/tun` não está no container | Revisar as 2 linhas do `.conf` do LXC e reiniciar o CT |
| `Network is unreachable` no LXC | Container sem gateway padrão | `pct set <ID> -net0 ...,gw=<GATEWAY>` e reiniciar |
| `Não há rota para o host` no notebook | Rota gerenciada não chegou | Conferir *Allow Managed* (`zerotier-cli set <ID_REDE> allowManaged=1`) |
| `Host de destino inalcançável` vindo do IP do LXC | O pacote chegou ao LXC, mas o destino não existe na LAN | Conferir se o IP de destino está ligado |
| Ping dá timeout, rota existe | Sub-rede errada nas regras de `FORWARD` | Usar a sub-rede real do ZeroTier em `-s` |
| `'xterm-kitty': unknown terminal type` | Container sem o terminfo do Kitty | `apt install kitty-terminfo` ou `SetEnv TERM=xterm-256color` no `~/.ssh/config` |
| Rota conflita ao acessar de outra rede | A rede onde está usa o mesmo `192.168.10.0/24` | Trocar a sub-rede da LAN por uma menos comum |

---

## 🔐 Segurança

- **Redes ZeroTier privadas** exigem autorização manual de cada membro no Central.
- **Nenhuma porta exposta** na internet, ao contrário de *port forwarding* no roteador.
- **Firewall restrito:** só a origem ZeroTier e as portas necessárias.
- **Recomendado:** 2FA na conta do ZeroTier Central, 2FA no Proxmox e *Flow Rules* para limitar o que cada membro acessa.
- **Atenção:** um membro autorizado alcança tudo que o `FORWARD` permitir. Autorize apenas dispositivos seus.


---

## 👨‍💻 Autor

**Erick Fanka**  
Ex-Competidor WorldSkills | Cloud Computing | Linux | Redes | AWS

🔗 [LinkedIn](https://www.linkedin.com/in/erick-fanka/)  
🐙 [GitHub](https://github.com/Erick-Fanka)