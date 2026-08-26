# Guia Completo — Cluster HA com Pacemaker e Corosync

> Guia baseado em laboratório real com dois servidores Dell PowerEdge T420.
> Alguns ajustes podem ser necessários dependendo do seu hardware.

---

## Pré-requisitos

- 2 servidores com Ubuntu Server 22.04 LTS instalado
- 1 VM ou máquina extra para o QDevice
- Todos na mesma rede local
- Acesso root ou sudo nos três

---

## Etapa 1 — Instalação do Ubuntu Server

### Problema conhecido em servidores Dell com controladora PERC

Durante o boot do pendrive de instalação, pressione `e` no menu do GRUB e adicione ao final da linha `linux`:

```
intel_iommu=off pci=nomsi
```

Pressione `Ctrl+X` para continuar. Isso resolve o erro DMAR comum em servidores Dell.

### Após instalar, tornar o parâmetro permanente

```bash
sudo nano /etc/default/grub
```

Edite a linha:

```
GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=off pci=nomsi"
```

Salve e aplique:

```bash
sudo update-grub
```

---

## Etapa 2 — Configuração de Rede

### IP estático via Netplan (nos dois servidores e na VM)

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Conteúdo para o server-1:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:
      dhcp4: false
      addresses:
        - 192.168.10.1/24
      routes:
        - to: default
          via: 192.168.10.254
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

> No server-2 use `192.168.10.2/24` e na VM use `192.168.10.3/24`.

Aplique:

```bash
sudo netplan apply
```

### DNS permanente

```bash
sudo nano /etc/systemd/resolved.conf
```

Edite:

```
DNS=8.8.8.8
FallbackDNS=8.8.4.4
```

Aplique:

```bash
sudo systemctl restart systemd-resolved
```

### Arquivo /etc/hosts (nos dois servidores e na VM)

```bash
sudo nano /etc/hosts
```

Adicione ao final:

```
192.168.10.1 server-1
192.168.10.2 server-2
192.168.10.3 quorum
```

### Firewall UFW

```bash
sudo ufw enable
sudo ufw allow from 192.168.10.0/24
```

---

## Etapa 3 — SSH para gerenciamento remoto

### Instalar e habilitar SSH (nos dois servidores e na VM)

```bash
sudo apt install openssh-server -y
sudo systemctl enable ssh
sudo systemctl start ssh
```

### Liberar SSH no UFW

```bash
sudo ufw allow from 192.168.10.0/24 to any port 22
```

### Conectar remotamente do notebook

```bash
ssh usuario@192.168.10.1   # server-1
ssh usuario@192.168.10.2   # server-2
ssh usuario@192.168.10.3   # quorum VM
```

> Com SSH configurado você gerencia tudo sem precisar de monitor conectado nos servidores.

---

## Etapa 4 — Instalar Corosync e Pacemaker

Nos **dois servidores**:

```bash
sudo apt install pacemaker corosync pcs resource-agents -y
```

---

## Etapa 5 — Configurar o Corosync

Nos **dois servidores**, edite o arquivo de configuração:

```bash
sudo nano /etc/corosync/corosync.conf
```

Substitua todo o conteúdo por:

```
totem {
    version: 2
    secauth: off
    cluster_name: lab_cluster
    transport: udpu
}

nodelist {
    node {
        ring0_addr: 192.168.10.1
        name: server-1
        nodeid: 1
    }
    node {
        ring0_addr: 192.168.10.2
        name: server-2
        nodeid: 2
    }
}

quorum {
    provider: corosync_votequorum
}
```

Inicie e habilite nos dois servidores:

```bash
sudo systemctl start corosync
sudo systemctl enable corosync
sudo systemctl start pacemaker
sudo systemctl enable pacemaker
```

Libere a porta do Corosync no UFW:

```bash
sudo ufw allow from 192.168.10.0/24
```

Verifique se os nós se enxergam:

```bash
sudo corosync-cmapctl | grep members
```

Deve aparecer `nodeid: 1` e `nodeid: 2` nos dois servidores.

---

## Etapa 6 — Configurar PCS e autenticação

### Definir senha do hacluster (nos dois servidores)

```bash
sudo passwd hacluster
```

> Use a mesma senha nos dois servidores.

### Habilitar PCSD e liberar porta (nos dois servidores)

```bash
sudo systemctl enable --now pcsd
sudo ufw allow from 192.168.10.0/24 to any port 2224
```

### Autenticar os nós (somente no server-1)

```bash
sudo pcs host auth server-1 server-2 -u hacluster
```

Deve aparecer:
```
server-1: Authorized
server-2: Authorized
```

---

## Etapa 7 — Configurar o QDevice (VM árbitro)

### Na VM — instalar somente o qnetd

```bash
sudo apt install -y corosync-qnetd pcs
sudo systemctl enable --now corosync-qnetd
sudo systemctl enable --now pcsd
sudo ufw allow from 192.168.10.0/24 to any port 2224
sudo passwd hacluster
```

### Nos dois servidores — instalar somente o qdevice

```bash
sudo apt install -y corosync-qdevice
```

### Autenticar a VM (no server-1)

```bash
sudo pcs host auth 192.168.10.3 -u hacluster
```

### Adicionar o QDevice ao cluster (somente no server-1)

```bash
sudo pcs quorum device add model net \
  host=192.168.10.3 \
  algorithm=ffsplit
```

### Verificar o quorum

```bash
sudo pcs quorum status
```

Resultado esperado:
```
Expected votes: 3
Total votes:    3
Quorate:        Yes
```

---

## Etapa 8 — Desabilitar STONITH (somente em lab)

```bash
sudo pcs property set stonith-enabled=false
```

> ⚠️ Em produção configure o STONITH via iDRAC antes de desabilitar.

---

## Etapa 9 — Criar o IP Virtual (VIP)

Somente no **server-1**:

```bash
sudo pcs resource create VIP ocf:heartbeat:IPaddr2 \
  ip=192.168.10.100 \
  cidr_netmask=24 \
  op monitor interval=30s
```

---

## Etapa 10 — Instalar e configurar o Apache

### Instalar nos dois servidores

```bash
sudo apt install apache2 -y
sudo systemctl stop apache2
sudo systemctl disable apache2
```

> O Apache deve ser parado e desabilitado no systemd — quem vai gerenciar ele é o Pacemaker.

### Instalar os resource agents nos dois servidores

```bash
sudo apt install resource-agents -y
```

### Criar o recurso Apache no Pacemaker (somente no server-1)

```bash
sudo pcs resource create Apache ocf:heartbeat:apache \
  configfile=/etc/apache2/apache2.conf \
  op monitor interval=30s
```

### Agrupar VIP e Apache (somente no server-1)

```bash
sudo pcs resource group add WebCluster VIP Apache
```

Isso garante que o VIP e o Apache sempre migrem juntos para o mesmo servidor.

---

## Etapa 11 — Testar o failover

### Verificar status do cluster

```bash
sudo pcs status
```

Resultado esperado:
```
Node List:
  * Online: [ server-1 server-2 ]

Full List of Resources:
  * Resource Group: WebCluster:
    * VIP    (ocf:heartbeat:IPaddr2): Started server-1
    * Apache (ocf:heartbeat:apache):  Started server-1
```

### Testar acesso pelo VIP

```bash
curl http://192.168.10.100
```

### Simular queda do server-1

```bash
sudo pcs node standby server-1
```

Verifique no server-2:

```bash
sudo pcs status
```

O VIP e o Apache devem aparecer como `Started server-2`.

### Restaurar o server-1

```bash
sudo pcs node unstandby server-1
```

---

## Comandos úteis do dia a dia

```bash
# Status geral do cluster
sudo pcs status

# Status do quorum
sudo pcs quorum status

# Ver recursos configurados
sudo pcs resource show

# Mover recurso manualmente
sudo pcs resource move VIP server-2

# Limpar erros de recursos
sudo pcs resource cleanup

# Ver logs do Corosync
sudo journalctl -u corosync -f

# Ver logs do Pacemaker
sudo journalctl -u pacemaker -f
```

---

## Próximos Passos

- [ ] Configurar DRBD para espelhar os discos de 2TB entre os servidores
- [ ] Configurar STONITH via iDRAC para ambiente de produção
- [ ] Adicionar monitoramento com Prometheus + Grafana