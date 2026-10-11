# Configurações (Configs)

Esta pasta contém arquivos de configuração de exemplo e templates utilizados para a implementação do ZeroTier Subnet Router.

## Arquivos

* `netplan-example.yaml`: Exemplo de configuração de rede estática e roteamento utilizando o Netplan.

## Como utilizar

Estes arquivos servem como base. Para utilizá-los no seu ambiente:

1. Copie o arquivo de exemplo para o diretório de destino correspondente no seu sistema (por exemplo, `/etc/netplan/`).
2. Remova o sufixo `-example` do nome do arquivo.
3. Edite o arquivo inserindo os endereços IP e as interfaces de rede correspondentes ao seu ambiente.
4. Aplique as configurações (ex: `sudo netplan apply`).

> **Nota:** Não faça o commit de arquivos com dados sensíveis de produção (como tokens ou IPs reais expostos) sem antes anonimizá-los.
