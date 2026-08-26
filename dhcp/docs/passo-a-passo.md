# 🛠️ Servidor DHCP — Passo a Passo do Laboratório

> Guia prático de configuração de um servidor DHCP com `isc-dhcp-server` no Ubuntu Server, usando VirtualBox com rede interna.

---

## 📋 Índice

- [Ambiente do laboratório](#ambiente-do-laboratório)
- [Parte 1 — Configuração do Servidor](#parte-1--configuração-do-servidor)
  - [1. Instalando o isc-dhcp-server](#1-instalando-o-isc-dhcp-server)
  - [2. Verificando o status inicial](#2-verificando-o-status-inicial)
  - [3. Configurando o dhcpd.conf](#3-configurando-o-dhcpdconf)
  - [4. Especificando a interface de escuta](#4-especificando-a-interface-de-escuta)
  - [5. Atribuindo IP estático ao servidor](#5-atribuindo-ip-estático-ao-servidor)
  - [6. Reiniciando e verificando o serviço](#6-reiniciando-e-verificando-o-serviço)
- [Parte 2 — Configuração do Cliente](#parte-2--configuração-do-cliente)
  - [7. Verificando a interface antes do DHCP](#7-verificando-a-interface-antes-do-dhcp)
  - [8. Solicitando IP via DHCP](#8-solicitando-ip-via-dhcp)
  - [9. Confirmando o IP recebido](#9-confirmando-o-ip-recebido)
  - [10. Verificando o DNS recebido](#10-verificando-o-dns-recebido)
- [Parte 3 — Reserva Estática por MAC Address](#parte-3--reserva-estática-por-mac-address)
  - [11. Configurando a reserva no servidor](#11-configurando-a-reserva-no-servidor)
  - [12. Confirmando o IP fixo no cliente](#12-confirmando-o-ip-fixo-no-cliente)

---

## Ambiente do laboratório

| VM | Sistema | Função | Interface DHCP | IP |
|---|---|---|---|---|
| VM 1 | Ubuntu Server | Servidor DHCP | `enp0s8` | `192.168.1.5` (estático) |
| VM 2 | Linux Mint | Cliente DHCP | `enp0s8` | Dinâmico |

> **Rede interna:** ambas as VMs foram configuradas em **Internal Network** no VirtualBox para se comunicarem de forma isolada.

---

## Parte 1 — Configuração do Servidor

### 1. Instalando o isc-dhcp-server

Ligue a VM do servidor. Abra o terminal e instale o pacote:

```bash
sudo apt install isc-dhcp-server
```


---

### 2. Verificando o status inicial

Após a instalação, verifique o status do serviço:

```bash
sudo systemctl status isc-dhcp-server.service
```

> ⚠️ **Esperado:** o serviço vai aparecer como `failed`. Isso é normal, ele ainda não sabe em qual interface escutar.


Vamos resolver isso nas próximas etapas.

---

### 3. Configurando o dhcpd.conf

Edite o arquivo de configuração principal do DHCP:

```bash
sudo nano /etc/dhcp/dhcpd.conf
```

Substitua o conteúdo pela configuração abaixo:

```conf
# Tempo padrão de concessão: 600 segundos (10 minutos)
default-lease-time 600;

# Tempo máximo de concessão: 7200 segundos (2 horas)
max-lease-time 7200;

subnet 192.168.1.0 netmask 255.255.255.0 {
  range 192.168.1.150 192.168.1.200;          # Pool de IPs disponíveis
  option routers 192.168.1.254;               # Gateway padrão
  option domain-name-servers 192.168.1.1, 192.168.1.2;  # Servidores DNS
  option domain-name "erick-fanka.com";       # Domínio
}
```

**O que cada linha faz:**

| Diretiva | Função |
|---|---|
| `range` | Define o intervalo de IPs que serão distribuídos |
| `option routers` | Informa o gateway ao cliente |
| `option domain-name-servers` | Informa os servidores DNS ao cliente |
| `option domain-name` | Informa o nome de domínio ao cliente |
| `default-lease-time` | Tempo de concessão padrão em segundos |
| `max-lease-time` | Tempo máximo de concessão em segundos |

Salve o arquivo: `Ctrl + O` → `Enter` → `Ctrl + X`

---

### 4. Especificando a interface de escuta

O servidor precisa saber em qual interface de rede ele deve escutar as requisições DHCP. Edite o arquivo:

```bash
sudo nano /etc/default/isc-dhcp-server
```

Localize a linha `INTERFACESv4` e defina a interface da rede interna:

```conf
INTERFACESv4="enp0s8"
```

> 💡 **Por quê `enp0s8`?** Essa é a interface da **rede interna** no VirtualBox é por ela que o cliente irá se comunicar com o servidor. A `enp0s3` é usada para a internet e não deve ser usada aqui.

---

### 5. Atribuindo IP estático ao servidor

O servidor precisa de um IP fixo na interface `enp0s8` antes de iniciar o serviço DHCP. Instale o `net-tools` e configure o IP:

```bash
sudo apt install net-tools
sudo ifconfig enp0s8 192.168.1.5
```

Isso garante que o servidor está no endereço `192.168.1.5` dentro da rede `192.168.1.0/24`.

> ⚠️ **Importante:** sem um IP configurado na interface, o serviço DHCP não consegue iniciar — ele não tem como anunciar ofertas para os clientes.

---

### 6. Reiniciando e verificando o serviço

Reinicie o serviço para aplicar todas as configurações:

```bash
sudo systemctl restart isc-dhcp-server.service
```

Verifique o status:

```bash
sudo systemctl status isc-dhcp-server.service
```

Monitore os logs em tempo real (deixe esse terminal aberto):

```bash
sudo journalctl -fu isc-dhcp-server
```

> ✅ **O serviço deve aparecer como `active (running)`.**  
> Mantenha o terminal com o `journalctl` aberto — você verá os logs em tempo real quando o cliente começar a pedir IP.

---

## Parte 2 — Configuração do Cliente

### 7. Verificando a interface antes do DHCP

Ligue a VM do cliente. Abra o terminal e veja o estado atual das interfaces:

```bash
ip address show
```

Note que a interface `enp0s8` ainda **não tem IP** — é justamente o que o DHCP vai resolver.

---

### 8. Solicitando IP via DHCP

Force a interface a fazer uma requisição DHCP ao servidor:

```bash
sudo dhclient enp0s8 -v
```

No terminal do **servidor**, você verá o processo DORA acontecendo nos logs:

```
DHCPDISCOVER from 08:00:27:1a:47:c1 via enp0s8
DHCPOFFER    on  192.168.1.150 to 08:00:27:1a:47:c1 (Cliente) via enp0s8
DHCPREQUEST  for 192.168.1.150 (192.168.1.5) from 08:00:27:1a:47:c1 (Cliente) via enp0s8
DHCPACK      on  192.168.1.150 to 08:00:27:1a:47:c1 (Cliente) via enp0s8
```

---

### 9. Confirmando o IP recebido

De volta ao cliente, verifique as interfaces novamente:

```bash
ip address show enp0s8
```

✅ O cliente recebeu automaticamente:

| Configuração | Valor |
|---|---|
| Endereço IP | `192.168.1.150` |
| Máscara | `255.255.255.0 (/24)` |
| Broadcast | `192.168.1.255` |
| Lease restante | `567 segundos` |

---

### 10. Verificando o DNS recebido

Confirme que o servidor DNS foi aplicado corretamente no cliente:

```bash
resolvectl status
```

```
Link 3 (enp0s8)
    Current Scopes: DNS
Current DNS Server: 192.168.1.1
       DNS Servers: 192.168.1.1 192.168.1.2
        DNS Domain: erick-fanka.com
```

</details>

✅ Os servidores DNS e o domínio foram distribuídos corretamente pelo DHCP — sem qualquer configuração manual no cliente.

---

## Parte 3 — Reserva Estática por MAC Address

É possível fixar um IP específico para um cliente com base no seu **MAC Address**. Assim, sempre que aquela máquina se conectar, receberá o mesmo IP — sem sair do gerenciamento centralizado do DHCP.

### 11. Configurando a reserva no servidor

Descubra o MAC Address da interface `enp0s8` do cliente (já visto na etapa anterior):

```
08:00:27:1a:47:c1
```

No servidor, edite novamente o `dhcpd.conf`:

```bash
sudo nano /etc/dhcp/dhcpd.conf
```

Adicione o bloco de reserva **fora** do bloco `subnet`:

```conf
default-lease-time 600;
max-lease-time 7200;

subnet 192.168.1.0 netmask 255.255.255.0 {
  range 192.168.1.150 192.168.1.200;
  option routers 192.168.1.254;
  option domain-name-servers 192.168.1.1, 192.168.1.2;
  option domain-name "erick-fanka.com";
}

# Reserva estática para a VM cliente
host cliente-vm {
  hardware ethernet 08:00:27:1a:47:c1;
  fixed-address 192.168.1.41;
}
```

Reinicie o serviço:

```bash
sudo systemctl restart isc-dhcp-server.service
```

No cliente, renove a concessão para aplicar a reserva:

```bash
sudo dhclient -r enp0s8   # Libera o IP atual
sudo dhclient enp0s8      # Solicita novo IP
```

---

### 12. Confirmando o IP fixo no cliente

```bash
ip address show enp0s8
```

```
3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP
    link/ether 08:00:27:1a:47:c1 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.41/24 brd 192.168.1.255 scope global dynamic noprefixroute enp0s8
       valid_lft 526sec preferred_lft 526sec
```

✅ O cliente recebeu o IP `192.168.1.41` — exatamente o que foi reservado para o seu MAC Address.

---

## Resumo dos comandos

### Servidor

```bash
# Instalação
sudo apt install isc-dhcp-server
sudo apt install net-tools

# Configuração
sudo nano /etc/dhcp/dhcpd.conf
sudo nano /etc/default/isc-dhcp-server

# Interface
sudo ifconfig enp0s8 192.168.1.5

# Serviço
sudo systemctl restart isc-dhcp-server.service
sudo systemctl status isc-dhcp-server.service
sudo journalctl -fu isc-dhcp-server
```

### Cliente

```bash
# Verificar interfaces
ip address show

# Solicitar IP via DHCP
sudo dhclient enp0s8 -v

# Renovar IP (libera e pede novo)
sudo dhclient -r enp0s8
sudo dhclient enp0s8

# Verificar DNS recebido
resolvectl status
```

---

*Laboratório realizado com VirtualBox + Ubuntu Server 22.04 + Linux Mint 21*