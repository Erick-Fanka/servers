# Conceitos — Cluster de Alta Disponibilidade

> Este documento explica como cada componente do cluster funciona, sem foco em comandos. Para o passo a passo completo com comandos, veja `passo-a-passo.md`.

---

## O que é Alta Disponibilidade (HA)?

Alta Disponibilidade significa que um sistema foi projetado para continuar funcionando mesmo quando parte dele falha. No mundo de servidores, isso normalmente é resolvido com mais de um servidor trabalhando em conjunto — se um cair, o outro assume automaticamente.

O objetivo não é evitar falhas, porque falhas sempre acontecem. O objetivo é **reduzir ao máximo o tempo que o sistema fica fora do ar** quando uma falha acontece.

---

## Infraestrutura desse projeto

Dois servidores físicos Dell PowerEdge T420 formam o cluster. Uma VM rodando no notebook faz o papel de árbitro. Um IP virtual flutua entre os servidores e é o endereço que os usuários acessam.

```
                     Roteador
                    /    |    \
                   /     |     \
            Server-1   Quorum  Server-2
           (nó ativo) (árbitro) (standby)
                  \              /
                   ←─ heartbeat ─→
                        VIP
                  (sempre disponível)
```

Quando o servidor ativo cai, o cluster detecta a falha e o servidor em standby assume o VIP e todos os serviços em questão de segundos.

---

## Os componentes explicados

### Corosync — A camada de comunicação

O Corosync é responsável por manter os servidores se comunicando entre si. Ele funciona como um sistema de batimentos cardíacos (heartbeat) — os servidores ficam trocando mensagens o tempo todo dizendo "estou vivo".

Quando um servidor para de responder, o Corosync detecta a falha e comunica ao Pacemaker que algo aconteceu. Ele também é responsável por garantir que todos os nós do cluster tenham a mesma visão do estado do cluster.

O arquivo de configuração do Corosync define quais são os nós do cluster, como eles se comunicam e qual sistema de quorum vai ser usado.

---

### Pacemaker — O gerente do cluster

Se o Corosync é a camada de comunicação, o Pacemaker é o cérebro. Ele recebe as informações do Corosync e toma as decisões sobre o que fazer.

É o Pacemaker que decide:
- Em qual servidor cada serviço vai rodar
- Em que ordem os serviços sobem (por exemplo, o IP virtual sempre antes do Apache)
- Quando migrar um serviço de um servidor para outro
- Como monitorar se um serviço está funcionando corretamente
- O que fazer quando um serviço falha

O Pacemaker trabalha com o conceito de **recursos** — tudo que ele gerencia é um recurso. Um IP virtual é um recurso. O Apache é um recurso. O DRBD é um recurso.

---

### PCS — O painel de controle

O PCS (Pacemaker/Corosync Configuration System) é a ferramenta de linha de comando usada para configurar e gerenciar o cluster. Sem ele, seria necessário editar arquivos XML complexos do Pacemaker diretamente.

Com o PCS você consegue ver o status do cluster, criar recursos, simular falhas, mover serviços entre servidores e muito mais — tudo com comandos simples.

O PCS se comunica com um serviço chamado **PCSD** que roda em background em cada servidor. O PCSD escuta na porta 2224 e é o responsável por replicar as configurações entre os nós quando você faz uma mudança.

---

### hacluster — O usuário do cluster

Quando o Pacemaker é instalado, ele cria automaticamente um usuário do sistema chamado `hacluster`. O PCS usa esse usuário para autenticar e se comunicar com segurança entre os nós do cluster.

Antes de configurar o cluster é necessário definir uma senha para esse usuário nos dois servidores e autenticá-los entre si.

---

### QDevice — O árbitro

Um cluster com apenas dois nós tem um problema sério chamado **split-brain**. Imagine que a comunicação entre os dois servidores cai — cada servidor pensa que o outro morreu e os dois tentam assumir ao mesmo tempo. Se ambos tentarem escrever nos mesmos dados, eles serão corrompidos.

A solução é o **quorum** — uma regra que diz que o cluster só pode tomar decisões se tiver maioria de votos. Com dois servidores, em caso de falha de comunicação os dois ficam empatados em 1 a 1 e nenhum pode agir.

O QDevice resolve isso sendo um terceiro votante. Com 2 servidores + 1 QDevice = 3 votos disponíveis. Para agir, um lado precisa de pelo menos 2 votos. Mesmo que os dois servidores percam comunicação entre si, cada um pergunta ao QDevice quem está certo — e o QDevice decide.

O grande diferencial do QDevice é que ele não precisa ser um servidor dedicado. No nosso caso, roda em uma VM simples dentro do notebook. Ele não executa nenhum serviço do cluster, só existe para votar.

Na VM roda o `corosync-qnetd` (o servidor do QDevice) e nos servidores roda o `corosync-qdevice` (o cliente que se conecta à VM).

---

### STONITH — O mecanismo de segurança

STONITH significa **Shoot The Other Node In The Head**. É um mecanismo chamado de fencing, e existe por uma razão muito importante.

Imagine que o server-1 está com problemas de rede — ele não consegue mais se comunicar com o cluster, mas ainda está ligado e tentando escrever em disco. Se o server-2 assumir os serviços sem garantir que o server-1 parou completamente, os dois podem tentar escrever nos mesmos dados ao mesmo tempo — corrompendo tudo.

O STONITH garante que antes de o server-2 assumir, ele **mata o server-1 fisicamente** — normalmente desligando ele via iDRAC (o sistema de gerenciamento remoto da Dell). Só depois que o server-1 está comprovadamente morto o server-2 assume.

Em ambiente de laboratório o STONITH é desabilitado pois não há dados críticos em risco. Em produção, ele é essencial.

---

### VIP — O IP Virtual

O VIP (Virtual IP) é um endereço IP que não pertence a nenhum servidor fixo — ele flutua entre os servidores do cluster. É sempre nesse IP que os usuários e sistemas externos se conectam.

Quando o servidor ativo cai, o Pacemaker move o VIP para o servidor que vai assumir. Do ponto de vista de quem acessa, parece que nada aconteceu — o endereço continua sendo o mesmo.

---

### Resource Agents — Os tradutores

O Pacemaker não sabe nativamente como iniciar, parar ou monitorar o Apache, o MySQL ou qualquer outro serviço. Para isso existem os Resource Agents — scripts padronizados que ensinam o Pacemaker a gerenciar cada tipo de serviço.

Quando você cria um recurso Apache no Pacemaker, você está dizendo a ele para usar o resource agent do Apache, que já sabe como verificar se o Apache está rodando, como iniciá-lo e como pará-lo de forma limpa.

---

### Grupo de Recursos — Migrando junto

No nosso cluster, o VIP e o Apache estão no mesmo grupo chamado **WebCluster**. Isso garante que os dois sempre rodem no mesmo servidor e migrem juntos durante o failover.

Faz sentido porque não adiantaria o VIP migrar para o server-2 se o Apache continuasse no server-1 — o usuário chegaria no endereço certo mas o serviço não estaria lá.

---

## O failover na prática

Quando o servidor ativo cai, a sequência é:

1. **Corosync** para de receber heartbeat do servidor com problema
2. **Corosync** consulta o **QDevice** para confirmar que o servidor realmente caiu
3. **QDevice** confirma — o servidor perdedor perde o quorum
4. **Pacemaker** recebe o sinal e inicia o failover
5. O VIP é movido para o servidor em standby
6. O Apache sobe no servidor que assumiu
7. O tráfego começa a chegar no novo servidor

Tudo isso acontece em 10 a 30 segundos, sem nenhuma intervenção manual.

---

## Próximos passos planejados

**DRBD** — O próximo passo é configurar o DRBD para espelhar os discos de 2TB entre os servidores pela rede. Funciona como um RAID 1, mas ao invés de dois discos no mesmo servidor, são dois discos em servidores diferentes sincronizados em tempo real. Isso garante que os dados estejam no servidor que assumir o failover.

**STONITH via iDRAC** — Configurar o fencing real usando o iDRAC dos servidores Dell para um ambiente mais próximo de produção.

**Monitoramento** — Adicionar Prometheus e Grafana para visualizar o estado do cluster em tempo real.