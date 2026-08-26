# 🖥️ HA Cluster — Pacemaker + Corosync + QDevice

Projeto de laboratório implementando um cluster de **Alta Disponibilidade (HA)** com failover automático usando hardware físico real, dois servidores Dell PowerEdge T420.

> ⚠️ Ambiente de laboratório para fins educacionais. Algumas configurações como STONITH desabilitado não são recomendadas para produção.

---

## 📋 Sobre o Projeto

O objetivo foi construir do zero um cluster de HA funcional em hardware físico, entendendo na prática como funciona o failover automático de serviços em infraestrutura Linux.

Quando o servidor ativo cai, o cluster detecta a falha e migra automaticamente o IP virtual e os serviços para o servidor secundário — sem intervenção manual.

---

## 🏗️ Infraestrutura

```
                        Roteador (192.168.10.0/24)
                       /          |          \
                      /           |           \
               Server-1      QDevice VM      Server-2
           192.168.10.1    192.168.10.3    192.168.10.2
           (nó primário)    (árbitro)     (nó secundário)
                      \                      /
                       \←── heartbeat ──→   /
                              VIP
                        192.168.10.100
                    (migra entre os servidores)
```

### Hardware

| Componente | Especificação |
|-----------|--------------|
| Servidores | 2x Dell PowerEdge T420 |
| Controladora RAID | PERC H310 |
| Discos SO | 2x 500GB em RAID 1 (por servidor) |
| QDevice | VM Ubuntu 22.04 no VirtualBox |

### Endereçamento

| Máquina | IP | Função |
|---------|-----|--------|
| server-1 | 192.168.10.1 | Nó primário do cluster |
| server-2 | 192.168.10.2 | Nó secundário do cluster |
| Quorum | 192.168.10.3 | Árbitro (QDevice) |
| VIP | 192.168.10.100 | IP virtual flutuante |

---

## 🧰 Stack Utilizada

| Tecnologia | Versão | Função |
|-----------|--------|--------|
| Ubuntu Server | 22.04 LTS | Sistema operacional |
| Corosync | 3.x | Comunicação entre nós (heartbeat) |
| Pacemaker | 2.x | Gerenciamento de recursos e failover |
| PCS | 0.10.x | Interface de configuração do cluster |
| corosync-qnetd | - | QDevice — árbitro na VM |
| corosync-qdevice | - | Cliente do QDevice nos servidores |
| Apache2 | 2.4.x | Serviço de teste para failover |

---

## ⚙️ Como Funciona

### Corosync
Camada de comunicação do cluster. Envia mensagens de heartbeat entre os nós constantemente. Se um nó para de responder, avisa o Pacemaker.

### Pacemaker
Gerente do cluster. Decide onde cada recurso roda, em que ordem sobe, monitora a saúde dos serviços e executa o failover quando necessário.

### QDevice
Árbitro que resolve o problema de split-brain em clusters de 2 nós. Com 2 servidores + 1 QDevice = 3 votos, sempre há maioria para tomar uma decisão. Roda em uma VM leve e não precisa de hardware dedicado.

### VIP (IP Virtual)
IP flutuante que sempre está ativo em um dos servidores. Todo tráfego aponta para esse IP. No failover, ele migra automaticamente para o servidor ativo.

### Grupo de Recursos (WebCluster)
VIP e Apache estão agrupados — migram juntos para o mesmo servidor durante o failover.

---

## 📁 Estrutura do Projeto
 
```
cluster-ha/
├── README.md                      # Documentação principal
├── configs/
│   ├── corosync.conf              # Configuração do Corosync
│   └── netplan.yaml               # Configuração de rede (IP estático)
├── docs/
│   ├── passo-a-passo.md           # Guia completo de instalação com comandos
│   └── conceitos.md               # Explicação de cada componente
├── media/
│   ├── servers-fisicos.jpeg       # Foto do lab físico
│   └── cluster-video.mp4          # Vídeo do failover funcionando
└── web/
    └── index.html                 # Página de teste do failover
```

---

## 🚀 Resultado

Com o cluster configurado:

- **Failover automático** em 10 a 30 segundos após queda de um nó
- **3 votos de quorum** — sem risco de split-brain
- **IP virtual** migra transparentemente entre os servidores
- **Apache** sobe automaticamente no servidor que assumir

### Teste de Failover

```bash
# Simular queda do server-1
sudo pcs node standby server-1

# Verificar migração no server-2
sudo pcs status

# Restaurar server-1
sudo pcs node unstandby server-1
```

---

## 📌 Próximos Passos

- [ ] Configurar DRBD para espelhar os discos de 2TB entre os servidores
- [ ] Configurar STONITH via iDRAC para ambiente de produção
- [ ] Adicionar monitoramento com Prometheus + Grafana

---

## 👨‍💻 Autor

**Erick Fanka**  
Estudante de Redes de Computadores | Estudante de Cloud Computing | Competidor World Skills Shanghai 2026

🔗 [LinkedIn](https://www.linkedin.com/in/erick-fanka/)  
🐙 [GitHub](https://github.com/Erick-Fanka)
📽️ [Youtube](https://youtu.be/2cmaPCZvlyc) *Video com o cluster funcionando.*
---

> 💡 Este repositório é voltado para fins educacionais e práticas de laboratório.