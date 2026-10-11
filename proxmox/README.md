# 🧱 Proxmox

Documentação, configurações e laboratórios do meu ambiente **Proxmox VE**: virtualização, containers LXC, acesso remoto seguro e alta disponibilidade.

> ⚠️ **Ambiente de laboratório para fins educacionais.** Os arquivos usam placeholders (`<ID_DA_REDE>`, `192.168.x.x`) no lugar de IDs, tokens e IPs reais. Revise as configurações de segurança antes de usar em produção.

---

## 🔎 Sobre

Esta pasta reúne tudo que é específico do **Proxmox**: ajustes no host, containers LXC, redes virtuais e serviços que rodam em cima dele. Projetos genéricos de Linux (sem dependência do Proxmox) ficam nas outras pastas do repositório.

---

## 📁 Projetos

| Projeto | Descrição | Tecnologias |
|---|---|---|
| [`zerotier-subnet-router`](./zerotier-subnet-router) | Acesso remoto seguro às VMs e ao painel do Proxmox por meio de um LXC dedicado como roteador de sub-rede ZeroTier | Proxmox, LXC, Ubuntu Server, ZeroTier, iptables ||

---

## 🗂️ Estrutura

```bash
proxmox/
├── zerotier-subnet-router/    # Acesso remoto via ZeroTier + LXC
│   ├── configs/
│   ├── docs/
│   ├── media/
│   └── README.md
└── README.md                  # Este índice
```

Cada projeto segue o mesmo padrão:

| Pasta | Conteúdo |
|---|---|
| `configs/` | Arquivos de configuração e scripts prontos para uso |
| `docs/` | Passo a passo e explicações dos conceitos |
| `media/` | Diagramas, fotos e vídeos |
| `README.md` | Resumo do projeto, topologia e como validar |

---

## 🔐 Boas práticas adotadas

- **Nada de segredos no repositório:** tokens, senhas, chaves SSH, IDs de rede e IPs públicos nunca são commitados. Os exemplos usam placeholders.
- **Menor privilégio:** regras de firewall limitadas à origem e às portas necessárias, em vez de liberar tudo.
- **Isolamento:** serviços de acesso remoto rodam em um LXC dedicado, e não diretamente no hipervisor.
- **Persistência:** regras de firewall e ajustes de kernel são salvos para sobreviver a reinicializações.

---

## 🗺️ Roadmap

- [x] Acesso remoto seguro com ZeroTier em LXC dedicado
- [ ] Monitoramento do host e das VMs com Prometheus + Grafana

---

## 👨‍💻 Autor

**Erick Fanka**  
Ex-Competidor WorldSkills | Cloud Computing | Linux | Redes | AWS

🔗 [LinkedIn](https://www.linkedin.com/in/erick-fanka/)  
🐙 [GitHub](https://github.com/Erick-Fanka)