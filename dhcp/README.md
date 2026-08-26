# 🌐 DHCP Server — Laboratório de Redes

Implementação e configuração de um **Servidor DHCP (Dynamic Host Configuration Protocol)** utilizando o pacote `isc-dhcp-server` em ambiente virtualizado.

> ⚠️ Ambiente de laboratório para fins educacionais e prática de administração de serviços de infraestrutura.

---

## 📋 Sobre o Projeto

Laboratório focado em entender e aplicar a distribuição automática de endereços IP, máscara de sub-rede, gateway padrão e servidores DNS para máquinas clientes em uma rede local, utilizando uma rede interna isolada no VirtualBox.

---

## 🏗️ Ambiente de Laboratório

```text
[ Servidor DHCP ] (Ubuntu Server) ──(Rede Interna)──► [ Clientes ] (Linux Mint)
   - IP Estático: 192.168.10.10                         - DHCP Client ativado
   - Pool: 192.168.10.50 - 192.168.10.150               - Recebem IP, Gateway e DNS
```

---

## 🧰 Stack Utilizada

| Tecnologia | Versão | Função |
|---|---|---|
| Ubuntu Server | 22.04 LTS | Sistema operacional do Servidor DHCP |
| Linux Mint | 21.x | Máquina cliente para teste de concessão |
| `isc-dhcp-server` | Standard | Daemon oficial para entrega dinâmica de IPs |
| VirtualBox | 7.x | Hipervisor utilizado para isolamento em Rede Interna |

---

## 📁 Estrutura do Repositório

```bash
dhcp/
├── README.md                 # Documentação do laboratório
├── configs/
│   └── dhcpd.conf            # Arquivo principal de configuração do DHCP
└── docs/
    ├── dhcp-conceitos.md     # Explicação teórica do protocolo (DORA)
    └── dhcp-passo-a-passo.md # Guia prático de instalação e testes
```

---

## 🚀 Comandos Úteis

Para gerenciar e testar o serviço durante o laboratório:

```bash
# Verificar o status do servidor DHCP
sudo systemctl status isc-dhcp-server

# Visualizar as concessões ativas (leases) no servidor
cat /var/lib/dhcp/dhcpd.leases

# Forçar a liberação e renovação do IP no cliente (Linux)
sudo dhclient -r && sudo dhclient
```

---

## 👨‍💻 Autor

**Erick Fanka**  
Competidor WorldSkills | Estudante de Cloud Computing e Redes  

🔗 [LinkedIn](https://www.linkedin.com/in/erick-fanka/)  
🐙 [GitHub](https://github.com/Erick-Fanka)
```

Pode mandar o próximo quando estiver pronto!
