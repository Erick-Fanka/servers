# 🌐 Servidor DHCP — Conceitos e Laboratório Prático

> Documentação do laboratório de redes com servidor DHCP usando Ubuntu Server e Linux Mint em ambiente virtualizado.

---

## 📋 Índice

- [Infraestrutura do laboratório](#infraestrutura-do-laboratório)
- [Como o DHCP funciona](#como-o-dhcp-funciona)
- [O processo DORA na prática](#o-processo-dora-na-prática)
- [ISC DHCP Server](#isc-dhcp-server)
- [Pools de endereços](#pools-de-endereços)
- [Lease Time — Tempo de concessão](#lease-time--tempo-de-concessão)
- [Gateway e DNS](#gateway-e-dns)
- [Rede Interna no VirtualBox](#rede-interna-no-virtualbox)
- [Reserva por MAC Address](#reserva-por-mac-address)

---

## Infraestrutura do laboratório

O ambiente foi montado com duas VMs conectadas via rede interna no VirtualBox:

| Máquina | Sistema | Função | Endereço IP |
|---|---|---|---|
| VM 1 | Ubuntu Server | Servidor DHCP | `192.168.1.5` (estático) |
| VM 2 | Linux Mint | Cliente DHCP | Dinâmico (recebe automaticamente) |

```
             VirtualBox — Rede Interna

       ┌──────────────────────────────────┐
       │        Rede 192.168.1.0/24       │
       └──────────────────────────────────┘
                  │               │
           DHCP Server        Cliente DHCP
           Ubuntu Server       Linux Mint
           192.168.1.5          Dinâmico
```

---

## Como o DHCP funciona

Quando um dispositivo entra na rede sem IP configurado, ele não sabe com quem falar. Então ele **grita para todo mundo** (broadcast) perguntando: *"Tem algum servidor DHCP aqui?"*

O servidor ouve esse pedido e responde com um endereço IP disponível. Todo esse processo acontece em **4 etapas**.

---

## O processo DORA na prática

O acrônimo **DORA** resume as 4 etapas da negociação DHCP:

```
  Cliente                          Servidor
    │                                 │
    │──── 1. DHCPDISCOVER ──────────▶│  "Tem servidor DHCP aqui?"
    │                                 │
    │◀─── 2. DHCPOFFER ──────────────│  "Sim! Pode usar o IP 192.168.1.150"
    │                                 │
    │──── 3. DHCPREQUEST ───────────▶│  "Ok, quero esse IP!"
    │                                 │
    │◀─── 4. DHCPACK ────────────────│  "Confirmado, é seu por enquanto."
    │                                 │
```

| Etapa | Nome | O que acontece |
|---|---|---|
| 1 | **DISCOVER** | O cliente busca um servidor DHCP via broadcast |
| 2 | **OFFER** | O servidor oferece um IP disponível |
| 3 | **REQUEST** | O cliente aceita formalmente a oferta |
| 4 | **ACK** | O servidor confirma e registra a concessão |

### Log real do servidor durante o processo

```
DHCPDISCOVER from 08:00:27:1a:47:c1
DHCPOFFER    on  192.168.1.150
DHCPREQUEST  for 192.168.1.150
DHCPACK      on  192.168.1.150
```

Após as 4 etapas, o cliente recebeu automaticamente:

- ✅ Endereço IP
- ✅ Máscara de sub-rede
- ✅ Gateway padrão
- ✅ Servidores DNS
- ✅ Nome de domínio

**Tudo isso sem digitar uma linha no cliente.**

---

## ISC DHCP Server

No Ubuntu Server foi utilizado o `isc-dhcp-server`, um dos servidores DHCP mais tradicionais e robustos do Linux.

### O que ele faz

- Escuta as solicitações DHCP na interface de rede configurada
- Distribui IPs do pool para os clientes
- Controla o tempo de concessão (lease)
- Registra logs de cada transação
- Aplica reservas fixas por MAC Address
- Entrega gateway e DNS automaticamente

O serviço roda em background gerenciado pelo `systemd`:

```bash
systemctl status isc-dhcp-server
```

---

## Pools de endereços

O servidor trabalha com um **range** (intervalo) de IPs disponíveis para distribuição.

No laboratório foi configurado:

```
Range: 192.168.1.150 → 192.168.1.200
```

Sempre que um novo cliente solicita um endereço, o servidor entrega o **próximo IP livre** dentro desse intervalo.

### Por que isso é útil?

- IPs são reutilizados automaticamente quando clientes saem da rede
- Controle centralizado — nenhuma configuração manual por máquina
- Elimina conflitos de IP duplicado

---

## Lease Time — Tempo de concessão

O IP entregue pelo DHCP **não é permanente**. Ele funciona como um aluguel com prazo definido.

### Configuração usada no laboratório

```bash
default-lease-time 600;    # 10 minutos
max-lease-time     7200;   # 2 horas
```

### Como funciona na prática

```
   Concessão                  Renovação             Expiração
      │                           │                     │
   ───●───────────────────────────●─────────────────────○───▶ tempo
      │                           │                     │
   IP entregue             Cliente renova         IP volta ao pool
   ao cliente              automaticamente        se não renovar
```

- O cliente tenta **renovar antes do prazo expirar**
- Se sair da rede sem renovar, o IP **volta para o pool** e fica disponível para outro cliente
- Isso evita desperdício de endereços, especialmente em redes com muitos dispositivos

---

## Gateway e DNS

Além do IP, o servidor DHCP entrega outras informações essenciais para o cliente funcionar na rede.

### Gateway — A saída da rede

O **gateway** é o "portão" da rede — o equipamento que encaminha o tráfego para outras redes e para a internet. O DHCP informa o endereço do gateway automaticamente para cada cliente.

### DNS — Tradução de nomes

O **DNS** é responsável por traduzir nomes amigáveis como `google.com` em endereços IP reais. Sem DNS, você precisaria memorizar IPs para acessar qualquer site.

No laboratório foram distribuídos dois servidores DNS:

```
DNS 1: 192.168.1.1
DNS 2: 192.168.1.2
```

Verificação no cliente:

```bash
resolvectl status
```

---

## Rede Interna no VirtualBox

As VMs foram configuradas em modo **Internal Network** no VirtualBox, criando uma rede virtual **completamente isolada** da rede física da máquina host.

### Vantagens desse modelo

| Vantagem | Descrição |
|---|---|
| Isolamento | Sem interferência com a rede real |
| Controle | Apenas as VMs configuradas conseguem se comunicar |
| Segurança | Tráfego não vaza para a rede externa |
| Reprodutibilidade | Ambiente idêntico em qualquer máquina |

### Interfaces de rede das VMs

Cada VM utilizou **duas interfaces de rede**:

```
VM ├── Interface 1 (bridge/NAT)  → Internet / rede real
   └── Interface 2 (rede interna) → Comunicação DHCP entre as VMs
                                    Interface: enp0s8
```

O servidor DHCP escuta exclusivamente na interface `enp0s8` (rede interna).

---

## Reserva por MAC Address

Além da distribuição dinâmica, o DHCP permite **fixar um IP específico para um dispositivo**, usando o MAC Address como identificador.

### Como funciona

O servidor reconhece o MAC Address do cliente e **sempre entrega o mesmo IP** para aquele dispositivo — mesmo que ele saia e volte à rede.

### Reserva configurada no laboratório

```
MAC Address:  08:00:27:1a:47:c1
IP Reservado: 192.168.1.41
```

### Quando usar reservas?

Esse recurso é ideal para dispositivos que precisam de IP previsível, mas sem abrir mão do gerenciamento centralizado do DHCP:

- 🖨️ Impressoras de rede
- 📡 Access Points
- 🖥️ Servidores internos
- 📷 Câmeras IP

---

## Resumo

```
┌─────────────────────────────────────────────────────┐
│                   DHCP em resumo                    │
├─────────────────┬───────────────────────────────────┤
│ Protocolo       │ UDP — Portas 67 (server) / 68 (client) │
│ Processo        │ DORA: Discover → Offer → Request → ACK │
│ Servidor usado  │ isc-dhcp-server                   │
│ Range do lab    │ 192.168.1.150 – 192.168.1.200     │
│ Lease padrão    │ 600 segundos (10 min)              │
│ Lease máximo    │ 7200 segundos (2 horas)            │
│ Rede            │ Internal Network – VirtualBox      │
│ Interface       │ enp0s8                             │
└─────────────────┴───────────────────────────────────┘
```

---

*Laboratório realizado com VirtualBox + Ubuntu Server 22.04 + Linux Mint 22*