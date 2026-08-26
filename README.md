<div align="center">

# 🖥️ Servers

**Configurações, scripts e laboratórios de administração de servidores Linux.**

[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://www.linux.org/)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Debian](https://img.shields.io/badge/Debian-A81D33?style=for-the-badge&logo=debian&logoColor=white)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-brightgreen?style=for-the-badge)](#)

<p align="center">
  <a href="#-sobre">Sobre</a> •
  <a href="#-estrutura-do-repositório">Estrutura</a> •
  <a href="#-projetos">Projetos</a> •
  <a href="#-roadmap">Roadmap</a> •
  <a href="#-como-contribuir">Contribuição</a> •
  <a href="#-autor">Autor</a>
</p>

</div>

---

## 🔎 Sobre

Este repositório centraliza configurações, scripts e documentações de **servidores Linux**. O foco é a administração de serviços de rede e infraestrutura, desde a instalação e configuração de pacotes até a criação de ambientes de alta disponibilidade.

> 💡 **Nota:** Este repositório é voltado para fins educacionais e preparação para competições técnicas (como WorldSkills). Os ambientes são simulados e não devem ser usados em produção sem as devidas revisões de segurança.

---

## 📁 Estrutura do Repositório

```bash
servers/
├── cluster-ha/        # Laboratório de Cluster de Alta Disponibilidade
│   ├── configs/       # Arquivos de configuração 
│   ├── docs/          # Documentação e anotações do laboratório
│   ├── media/         # Diagramas e imagens da topologia
│   ├── web/           # Configurações do servidor web 
│   └── README.md
│
├── dhcp/              # Laboratório de Servidor DHCP
│   ├── configs/       # Arquivos de configuração 
│   ├── docs/          # Documentação e anotações
│   └── README.md
│
└── README.md          # Documentação principal do repositório
```

---

## 🚀 Projetos

### ️ Cluster de Alta Disponibilidade (`cluster-ha`)
Implementação de um cluster ativo-passivo utilizando **Keepalived** e **HAProxy** para garantir a disponibilidade de um serviço web.
- **Tecnologias:** Linux, Keepalived, HAProxy, Apache/Nginx.
- **Objetivo:** Simular um ambiente corporativo com failover automático de IP virtual (VIP).

### 🌐 Servidor DHCP (`dhcp`)
Configuração de um servidor DHCP para distribuição dinâmica de endereços IP em redes locais.
- **Tecnologias:** Linux, `isc-dhcp-server`.
- **Objetivo:** Gerenciar escopos, reservas de MAC address e opções de rede (gateway, DNS).

---

## 🗺️ Roadmap

- [ ] **DNS Server:** Configuração de Bind9 (cache, forwarder e zonas diretas/reversas).
- [ ] **Web Server:** Hardening e configuração avançada de Apache/Nginx com SSL.
- [ ] **File Server:** Implementação de Samba (SMB/CIFS) e NFS.
- [ ] **Monitoring:** Configuração de monitoramento com Zabbix ou Prometheus.
- [ ] **Mail Server:** Laboratório básico de Postfix e Dovecot.

---

## 🤝 Como Contribuir

Contribuições para corrigir configurações, adicionar novos serviços ou melhorar a documentação são muito bem-vindas!

1. Faça um **Fork** do repositório.
2. Crie uma branch para a sua funcionalidade:
   ```bash
   git checkout -b feature/novo-servidor-dns
   ```
3. Commit suas alterações:
   ```bash
   git commit -m "feat: adiciona laboratório de servidor DNS Bind9"
   ```
4. Submeta a branch:
   ```bash
   git push origin feature/novo-servidor-dns
   ```
5. Abra um **Pull Request**.

---

## 📄 Licença

Este projeto está sob a licença **MIT**. Consulte o arquivo [LICENSE](LICENSE) para obter detalhes.

---

## 👨‍💻 Autor

<table align="center">
  <tr>
    <td align="center">
      <a href="https://github.com/Erick-Fanka">
        <img src="https://avatars.githubusercontent.com/Erick-Fanka" width="120px;" alt="Foto de Erick Fanka" style="border-radius: 50%;" />
      </a>
      <br />
      <strong>Erick Fanka</strong>
    </td>
    <td>
      <strong>Competidor WorldSkills | Cloud Computing | AWS | Python | Redes </strong><br />
      <a href="https://www.linkedin.com/in/erick-fanka">
        <img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn" />
      </a>
      <a href="https://github.com/Erick-Fanka">
        <img src="https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white" alt="GitHub" />
      </a>
    </td>
  </tr>
</table>
