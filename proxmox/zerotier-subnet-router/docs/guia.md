# 🚀 Passo a Passo — ZeroTier Subnet Router em LXC

Guia completo para configurar um container LXC no Proxmox como **roteador de sub-rede ZeroTier**, permitindo acessar as VMs e o painel do Proxmox de qualquer lugar.

> ⚠️ Os valores abaixo são **exemplos**. Substitua pelos da sua rede e nunca publique IDs, tokens ou IPs reais.

---

## 📋 Pré-requisitos

| Item | Detalhe |
|---|---|
| Proxmox VE | Com acesso root ao host |
| Conta no ZeroTier | Com uma rede **privada** criada em [my.zerotier.com](https://my.zerotier.com) |
| Template Ubuntu | Baixado em *Local → CT Templates → Templates* |
| Notebook | Com o ZeroTier instalado, para o teste final |

### Valores usados neste guia

| Variável | Exemplo | Onde descobrir |
|---|---|---|
| `<ID_CT>` | `101` | Número do container no Proxmox |
| `<ID_DA_REDE>` | 16 caracteres hex | ZeroTier Central |
| LAN | `192.168.10.0/24` | Rede das suas VMs |
| `<GATEWAY>` | `192.168.10.254` | IP do seu roteador |
| IP do LXC (LAN) | `192.168.10.201` | Escolha um IP fixo livre |
| `<SUBREDE_ZT>` | `10.147.17.0/24` | ZeroTier Central → *Managed Routes* |
| `<IP_ZT_LXC>` | `10.147.17.201` | Aparece depois que o LXC entra na rede |

> 💡 Se o notebook for usado em redes de terceiros, evite uma LAN com sub-rede comum (`192.168.0.0/24`, `192.168.1.0/24`), pois pode haver conflito de rota.

---

## 1️⃣ Criar o container LXC

Na interface do Proxmox, clique em **Create CT** e use:

| Aba | Configuração |
|---|---|
| General | Hostname (ex.: `zt-router`), **Unprivileged container** marcado, senha do root |
| Template | Ubuntu Server |
| Disks | 4 GB |
| CPU | 1 core |
| Memory | 512 MB |
| Network | Bridge `vmbr0`, **IPv4 estático** `192.168.10.201/24`, **Gateway** preenchido |
| DNS | `1.1.1.1` (ou o do seu roteador) |

**Não inicie o container ainda.** Marque *Start after created* como desligado.

> ⚠️ O campo **Gateway** é obrigatório. Sem ele, o container enxerga a LAN mas não acessa a internet (`Network is unreachable`).

---

## 2️⃣ Liberar o dispositivo TUN (no host Proxmox)

O ZeroTier precisa do `/dev/net/tun` para criar a interface virtual. No **host**:

```bash
nano /etc/pve/lxc/<ID_CT>.conf
```

Adicione no final do arquivo, **uma diretiva por linha** e sem espaços sobrando:

```text
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

Inicie o container:

```bash
pct start <ID_CT>
```

**Como verificar** (dentro do container):

```bash
ls -l /dev/net/tun
```

Deve aparecer `crw-rw-rw-`. Se der *No such file or directory*, as linhas não foram aplicadas: confira o `.conf` e reinicie com `pct stop <ID_CT> && pct start <ID_CT>`.

---

## 3️⃣ Testar a rede do container

Entre no container (pelo console do Proxmox ou por SSH) e valide de dentro para fora:

```bash
ip a                    # eth0 com 192.168.10.201/24
ip r                    # deve existir "default via <GATEWAY>"
ping -c 2 <GATEWAY>     # chega no roteador?
ping -c 2 1.1.1.1       # chega na internet?
ping -c 2 google.com    # o DNS resolve?
```

| Falha em | Causa provável | Correção (no host) |
|---|---|---|
| `default via` ausente / `Network is unreachable` | Sem gateway | `pct set <ID_CT> -net0 name=eth0,bridge=vmbr0,ip=192.168.10.201/24,gw=<GATEWAY>` |
| `1.1.1.1` ok, `google.com` falha | DNS | `pct set <ID_CT> --nameserver 1.1.1.1` |

Depois de ajustar, reinicie: `pct stop <ID_CT> && pct start <ID_CT>`.

> ℹ️ O `pct set -net0` **substitui a linha inteira**. Veja a atual antes com `pct config <ID_CT> | grep net0` e inclua VLAN (`,tag=10`) ou firewall (`,firewall=1`) se existirem.

### (Opcional) Terminal Kitty

Se aparecer `'xterm-kitty': unknown terminal type` ao usar o SSH, adicione no **notebook**, em `~/.ssh/config`:

```bash
cat >> ~/.ssh/config <<EOF

Host 192.168.10.*
    SetEnv TERM=xterm-256color
EOF
chmod 600 ~/.ssh/config
```

Ou instale no container: `apt install -y kitty-terminfo`.

---

## 4️⃣ Instalar o ZeroTier (dentro do LXC)

```bash
apt update
apt install -y curl iptables iptables-persistent
curl -s https://install.zerotier.com | bash
```

Durante a instalação do `iptables-persistent`, aceite salvar as regras atuais (pode responder *Yes*).

Entre na rede:

```bash
zerotier-cli join <ID_DA_REDE>
zerotier-cli info
```

O `info` deve mostrar `ONLINE`.

---

## 5️⃣ Autorizar o membro no ZeroTier Central

1. Acesse [my.zerotier.com](https://my.zerotier.com) e abra a sua rede.
2. Em **Members**, localize o container (o ID aparece em `zerotier-cli info`).
3. Marque **Auth?** para autorizá-lo.
4. Anote o **IP gerenciado** atribuído (`<IP_ZT_LXC>`). Ele será usado na rota.

**Como verificar** (no LXC):

```bash
zerotier-cli listnetworks
```

O status deve ser `OK`, com o IP do ZeroTier. Se estiver `ACCESS_DENIED`, o membro ainda não foi autorizado.

---

## 6️⃣ Ligar o IP forwarding (no LXC)

```bash
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
```

**Como verificar:** o `sysctl -p` deve imprimir `net.ipv4.ip_forward = 1`.

---

## 7️⃣ Configurar NAT e firewall (no LXC)

Substitua `<SUBREDE_ZT>` pela sub-rede do seu ZeroTier e ajuste as portas conforme os serviços que quer acessar.

```bash
# NAT: troca a origem pelo IP do LXC para as VMs conseguirem responder
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Ida: só a sub-rede ZeroTier e só as portas necessárias
iptables -A FORWARD -i zt+ -o eth0 -s <SUBREDE_ZT> -p tcp -m multiport --dports 22,443,8006 -j ACCEPT

# Ping (só para teste; pode remover depois)
iptables -A FORWARD -i zt+ -o eth0 -p icmp -j ACCEPT

# Volta: só respostas de conexões já iniciadas
iptables -A FORWARD -i eth0 -o zt+ -m state --state RELATED,ESTABLISHED -j ACCEPT

# Persistir após reiniciar
netfilter-persistent save
```

| Porta | Serviço |
|---|---|
| 22 | SSH |
| 443 | HTTPS |
| 8006 | Painel web do Proxmox |

Para liberar outros serviços (RDP `3389`, HTTP `80`, etc.), inclua a porta no `--dports`.

**Como verificar:**

```bash
iptables -t nat -L POSTROUTING -n -v
iptables -L FORWARD -n -v --line-numbers
```

Se a sub-rede ficou errada, limpe a chain e refaça as regras de `FORWARD`:

```bash
iptables -F FORWARD
```

---

## 8️⃣ Criar a rota no ZeroTier Central

Em *Advanced → Managed Routes*:

| Campo | Valor |
|---|---|
| **Destination** | `192.168.10.0/24` |
| **Via** | `<IP_ZT_LXC>` (o IP **ZeroTier** do LXC, e não o da LAN) |

Clique em **Submit** e confirme que a rota aparece na lista.

> 💡 A rota é aplicada nos **dispositivos ZeroTier** (o notebook), e não na LAN. Em casa, o notebook usa o caminho local direto. Fora de casa, usa o ZeroTier.

---

## 9️⃣ Testar (fora da rede local)

No **notebook**, conecte-se a outra rede (por exemplo, o *hotspot* do celular) e verifique:

```bash
# 1. O ZeroTier instalou a rota?
ip route | grep 192.168.10
# esperado: 192.168.10.0/24 via <IP_ZT_LXC> dev zt...

# 2. O LXC responde pelo ZeroTier?
ping -c 2 <IP_ZT_LXC>

# 3. A LAN é alcançada passando pelo LXC?
ping -c 2 192.168.10.<IP_DE_UMA_VM>

# 4. O painel do Proxmox abre?
curl -k -I https://192.168.10.<IP_DO_PROXMOX>:8006

# 5. SSH em uma VM
ssh usuario@192.168.10.<IP_DA_VM>
```

> ✅ O `ping` para a LAN deve responder com **`ttl=63`**. O TTL cai em 1 a cada roteador, e esse "1" é o LXC.

Para acompanhar o tráfego dentro do container:

```bash
iptables -L FORWARD -n -v      # os contadores sobem durante o teste
tcpdump -ni eth0 icmp          # pacotes saindo com o IP do LXC (NAT)
```

### Se a rota não aparecer no notebook

```bash
zerotier-cli listnetworks                              # status OK?
zerotier-cli set <ID_DA_REDE> allowManaged=1           # aceitar rotas gerenciadas
```

---

## 🔟 Limpar o ZeroTier do host Proxmox (se existia)

Faça isso **somente depois** de confirmar o acesso remoto pelo LXC, para não perder a conexão.

No **host**:

```bash
zerotier-cli leave <ID_DA_REDE>
apt remove --purge zerotier-one
```

Se você tinha aplicado regras de roteamento no host, remova-as também (um comando por linha):

```bash
iptables -t nat -D POSTROUTING -o vmbr0 -j MASQUERADE
iptables -D FORWARD -i zt+ -o vmbr0 -j ACCEPT
iptables -D FORWARD -i vmbr0 -o zt+ -j ACCEPT
```

Remova o `net.ipv4.ip_forward = 1` do `/etc/sysctl.conf` do host, **só se nada mais depender dele**.

No **ZeroTier Central**, apague o membro do host da lista para que nenhuma rota antiga aponte para ele.

---

## ✅ Checklist final

- [ ] LXC criado, **unprivileged**, com IP fixo e gateway
- [ ] `/dev/net/tun` presente dentro do container
- [ ] Container com internet e DNS funcionando
- [ ] ZeroTier instalado, membro **autorizado** e status `OK`
- [ ] `net.ipv4.ip_forward = 1` ativo
- [ ] `MASQUERADE` e regras de `FORWARD` aplicadas e **salvas**
- [ ] Rota gerenciada com **Via = IP ZeroTier do LXC**
- [ ] Teste feito de **fora de casa**, com `ttl=63`
- [ ] ZeroTier do host removido e membro antigo apagado do Central
- [ ] Nenhum ID de rede, token ou IP real no repositório

---

## 🔗 Veja também

- [`conceitos.md`](./conceitos.md): explicação de cada conceito e diagnóstico por camadas
- [`README.md`](../README.md): visão geral e topologia do projeto