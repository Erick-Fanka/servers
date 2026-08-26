Aqui está o README reestruturado para a pasta `cluster-ha/`, mantendo toda a riqueza técnica do seu texto original, mas alinhado ao padrão limpo e direto de documentação de laboratório:

```markdown
# 🖥️ HA Cluster — Pacemaker + Corosync + QDevice

Projeto de laboratório implementando um cluster de **Alta Disponibilidade (HA)** com failover automático utilizando hardware físico real (dois servidores Dell PowerEdge T420).

> ⚠️ **Ambiente de laboratório para fins educacionais.** Algumas configurações (como o STONITH desabilitado) não são recomendadas para ambientes de produção.

---

## 🏗️ Topologia & Infraestrutura

```text
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

### Endereçamento IP

| Máquina | IP | Função |
|---|---|---|
| `server-1` | 192.168.10.1 | Nó primário do cluster |
| `server-2` | 192.168.10.2 | Nó secundário do cluster |
| `QDevice` | 192.168.10.3 | Árbitro (VM Ubuntu no VirtualBox) |
| `VIP` | 192.168.10.100 | IP virtual flutuante (Cluster) |

### Hardware Físico

| Componente | Especificação |
|---|---|
| Servidores | 2x Dell PowerEdge T420 |
| Controladora RAID | PERC H310 |
| Discos SO | 2x 500GB em RAID 1 (por servidor) |

---

## 🧰 Stack Utilizada

| Tecnologia | Versão | Função |
|---|---|---|
| Ubuntu Server | 22.04 LTS | Sistema operacional |
| Corosync | 3.x | Comunicação entre nós (heartbeat) |
| Pacemaker | 2.x | Gerenciamento de recursos e failover |
| PCS | 0.10.x | Interface de configuração do cluster |
| QDevice | - | Árbitro de quorum (anti *split-brain*) |
| Apache2 | 2.4.x | Serviço web para teste de failover |

---

## ⚙️ Como Funciona

- **Corosync:** Camada de comunicação que envia mensagens de *heartbeat* entre os nós. Se um nó para de responder, avisa o Pacemaker.
- **Pacemaker:** Gerente do cluster que decide onde cada recurso roda, monitora a saúde dos serviços e executa o failover.
- **QDevice:** Árbitro externo que resolve o problema de *split-brain* em clusters de 2 nós (2 servidores + 1 QDevice = 3 votos, garantindo maioria).
- **VIP (IP Virtual):** IP flutuante que aponta para o servidor ativo. No failover, migra automaticamente.
- **Grupo de Recursos (WebCluster):** Agrupa o VIP e o Apache para que migrem juntos durante o failover.

---

## 📁 Estrutura do Repositório
 
```bash
cluster-ha/
├── README.md                      # Documentação do laboratório
├── configs/
│   ├── corosync.conf              # Configuração do Corosync
│   └── netplan.yaml               # Configuração de rede (IP estático)
├── docs/
│   ├── passo-a-passo.md           # Guia completo de instalação com comandos
│   └── conceitos.md               # Explicação detalhada de cada componente
├── media/
│   ├── servers-fisicos.jpeg       # Foto do ambiente físico
│   └── cluster-video.mp4          # Vídeo demonstrando o failover
└── web/
    └── index.html                 # Página web de teste do failover
```

---

## 🚀 Teste de Failover

Com o cluster configurado e em execução:

```bash
# 1. Simular queda do server-1
sudo pcs node standby server-1

# 2. Verificar a migração automática dos serviços no server-2
sudo pcs status

# 3. Restaurar o server-1 ao cluster
sudo pcs node unstandby server-1
```

---

## 📌 Próximos Passos

- [ ] Configurar DRBD para espelhamento de discos entre os servidores
- [ ] Configurar STONITH via iDRAC para cenários de produção
- [ ] Implementar monitoramento centralizado com Prometheus + Grafana

---

## 👨‍💻 Autor

**Erick Fanka**  
Competidor WorldSkills | Estudante de Cloud Computing e Redes  

🔗 [LinkedIn](https://www.linkedin.com/in/erick-fanka/)  
🐙 [GitHub](https://github.com/Erick-Fanka)  
📽️ [YouTube](https://youtu.be/2cmaPCZvlyc) — *Demonstração do cluster em funcionamento*
```
