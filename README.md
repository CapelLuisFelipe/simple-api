# KXC Simple API — Desafio Técnico

## Descrição

API em Node.js com Express que conecta a um banco PostgreSQL, implantada na AWS com infraestrutura completa como código (Terraform), pipeline CI/CD automatizado e painel de observabilidade em tempo real.

---

## O que foi construído

### Infraestrutura AWS (Terraform)

Toda a infraestrutura foi provisionada via Terraform, organizada em módulos reutilizáveis (`network`, `database`, `ecs`, `iam`, `cicd`, `monitoring`):

| Recurso | Configuração |
|---|---|
| **ECS Fargate** | Cluster + Service, 1–4 tasks, 0.25 vCPU / 0.5 GB |
| **Application Load Balancer** | Internet-facing, health check em `/health` |
| **RDS PostgreSQL 15** | `db.t3.micro`, Multi-AZ desativado, privado em subnet isolada |
| **VPC** | 2 AZs, subnets públicas (ECS/ALB) e privadas (RDS) |
| **ECR** | Registry privado para imagem Docker da API |
| **CodePipeline + CodeBuild** | 2 pipelines: infra (Terraform) e app (Docker → ECS deploy) |
| **CloudWatch Alarms** | CPU Alta ≥ 30% e CPU Baixa ≤ 20% com notificação SNS/e-mail |
| **Application Auto Scaling** | Scale out em 30s, scale in em 120s, máx. 4 tasks |
| **Secrets Manager** | Credenciais do banco injetadas no container via `secrets` do ECS |
| **IAM** | Roles separadas para task execution e task runtime (observability policy) |
| **SNS** | Tópico de alertas com assinatura por e-mail |
| **S3** | Artefatos do CodePipeline |

### Por que ECS Fargate + ALB e não instância EC2?

- **Sem gerenciamento de servidor**: Fargate elimina patching e provisionamento manual
- **Auto Scaling nativo**: ECS escala tasks automaticamente com base em métricas CloudWatch
- **Isolamento por container**: cada task tem CPU/memória garantidos
- **ALB**: distribui tráfego entre tasks, executa health checks e remove tasks falhas automaticamente

### Por que RDS em subnet privada?

Banco não tem acesso público. Somente o Security Group do ECS pode conectar na porta 5432 — eliminando exposição direta à internet.

### Por que Secrets Manager e não variáveis de ambiente?

Senha do banco não aparece em plaintext no task definition. ECS injeta o secret em tempo de execução via `secrets` block — auditável e rotacionável sem redeploy.

---

## Pipeline CI/CD

Dois pipelines independentes, ambos disparados automaticamente por push no GitHub:

```
Git Push → CodeStar Connection (GitHub App WebhookV2)
              ├── Pipeline Infra → CodeBuild → terraform init + plan + apply
              └── Pipeline App  → CodeBuild → docker build → ECR push → ECS rolling deploy
```

Ambos os pipelines completam com status **Succeeded** em condições normais.

---

## Auto Scaling — Como funciona

| Evento | Threshold | Ação | Cooldown |
|---|---|---|---|
| CPU média ≥ 30% | Alarme `cpu-high` ALARM | +1 task (até 4) | 30s |
| CPU média ≤ 20% | Alarme `cpu-low` ALARM | −1 task (até 1) | 120s |

Notificação por e-mail via SNS em cada transição de estado.

---

## Observabilidade — Dashboard

Acesse `/dashboard` para o painel visual com:

- **ECS Tasks**: quantidade de tasks running/desired/pending em tempo real (quadrados visuais)
- **Scaling Events**: histórico dos últimos eventos de scale out/in com timestamp
- **CloudWatch Alarms**: histórico de estados (`ALARM` / `OK`) com CPU no momento do disparo
- **Stress contínuo**: botão que satura CPU do container em loops de 30s para demonstrar auto scaling ao vivo

O painel atualiza automaticamente a cada 10s enquanto o stress loop está ativo.

---

## Rotas da API

| Rota | Método | Descrição |
|---|---|---|
| `/health` | GET | Health check do ALB (não incrementa contador) |
| `/` | GET | Mensagem estática + hostname da task + contador de requests |
| `/connect` | GET | Conecta ao RDS e retorna versão do PostgreSQL |
| `/stress` | GET | Satura CPU por N segundos (`?seconds=30`, máx. 30s) |
| `/dashboard` | GET | Painel de observabilidade visual |
| `/obs/status` | GET | Status do ECS Service (running/desired/pending) |
| `/obs/scaling-events` | GET | Últimos 10 eventos de auto scaling |
| `/obs/alarm-history` | GET | Histórico de estados dos alarmes CloudWatch |

---

## Estimativa de Custo AWS (us-east-1)

Ambiente de demonstração com 1 task Fargate rodando continuamente:

| Serviço | Custo mensal |
|---|---|
| Application Load Balancer | $22,27 |
| Amazon RDS for PostgreSQL (`db.t3.micro`) | $15,44 |
| AWS Fargate (1 task, 0.25 vCPU, 0.5 GB, 730h) | $8,89 |
| Amazon CloudWatch | $1,20 |
| AWS CodePipeline | $1,00 |
| AWS Secrets Manager | $0,40 |
| AWS CodeBuild | $0,50 |
| Amazon S3 | $0,23 |
| Amazon ECR | $0,02 |
| Amazon SNS | $0,00 |
| **Total estimado** | **~$49,95/mês** |

> O ALB representa o maior custo fixo (~$16,20/mês de base). Em produção com tráfego real o custo por task Fargate aumenta proporcionalmente ao número de tasks no pico de scaling.

---

## Variáveis de Ambiente

| Nome | Descrição | Padrão |
|---|---|---|
| `API_PORT` | Porta da API | `3000` |
| `DB_DATABASE` | Nome do banco | — |
| `DB_HOST` | Endereço do banco | — |
| `DB_PORT` | Porta do banco | `5432` |
| `DB_USER` | Usuário do banco | — |
| `DB_PASSWORD` | Senha do banco | — |
| `AWS_REGION` | Região AWS | `us-east-1` |
| `ECS_CLUSTER_NAME` | Nome do cluster ECS | `simple-api-cluster` |
| `ECS_SERVICE_NAME` | Nome do serviço ECS | `simple-api-service` |

---

## Estrutura do projeto

```
simple-api/
├── src/
│   └── index.js              # API Express + rotas observabilidade
├── public/
│   ├── index.html            # Dashboard visual
│   ├── app.js                # Frontend JS do dashboard
│   └── style.css             # Estilos
├── terraform/
│   ├── environments/dev/     # Configuração do ambiente dev
│   └── modules/              # Módulos: network, security, alb, rds, iam, cicd
├── Dockerfile
└── buildspec.yml             # CodeBuild: docker build → ECR → ECS deploy
```
