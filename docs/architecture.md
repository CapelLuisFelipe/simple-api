# Arquitetura

## Visão Geral

API Node.js containerizada, executada em ECS Fargate, com banco PostgreSQL no RDS,
exposta publicamente via Application Load Balancer, com CI/CD automatizado via
CodePipeline e infraestrutura gerenciada por Terraform.

## Diagrama

```
Internet
   │
   ▼
[ALB] ──── porta 80 (HTTP) ──── pública
   │
   │  (Security Group: ECS só aceita do ALB)
   ▼
[ECS Fargate Tasks] ─── subnet pública ─── assign_public_ip=true
   │   (auto-scaling: min 1, max 4 tasks)   │
   │                                         └── ECR (pull de imagem)
   │                                         └── Secrets Manager (senha DB)
   │  (Security Group: RDS só aceita do ECS)
   ▼
[RDS PostgreSQL 15] ─── subnet privada ─── sem acesso público
```

## Rede (VPC dedicada)

| Recurso              | CIDR            | Tipo    |
|----------------------|-----------------|---------|
| VPC                  | 10.0.0.0/16     | —       |
| Subnet pública AZ-a  | 10.0.1.0/24     | Pública |
| Subnet pública AZ-b  | 10.0.2.0/24     | Pública |
| Subnet privada AZ-a  | 10.0.11.0/24    | Privada |
| Subnet privada AZ-b  | 10.0.12.0/24    | Privada |

Não há NAT Gateway (decisão de custo para ambiente dev — ver ADR-001).

## Security Groups

```
ALB SG:  0.0.0.0/0 → porta 80
ECS SG:  ALB SG    → porta 3000
RDS SG:  ECS SG    → porta 5432
```

## Componentes AWS

| Serviço           | Uso                                               |
|-------------------|---------------------------------------------------|
| ECS Fargate       | Orquestração de containers (256 CPU / 512 MB)     |
| RDS PostgreSQL 15 | Banco de dados gerenciado (db.t3.micro, 20 GB)    |
| ALB               | Load balancer público, health check na rota `/`   |
| ECR               | Registry de imagens Docker                        |
| Secrets Manager   | Armazenamento da senha do banco                   |
| CodePipeline      | Orquestração de CI/CD (2 pipelines)               |
| CodeBuild         | Build da imagem Docker + execução do Terraform    |
| CloudWatch Logs   | Logs das tasks ECS (`/ecs/simple-api`, 7 dias)    |
| CloudWatch Alarms | Alertas de CPU ≥30% (alta) e ≤20% (baixa)        |
| SNS               | Entrega de alertas por e-mail                     |
| S3                | Artefatos das pipelines + Terraform state         |

## CI/CD

### Pipeline de aplicação
Disparada por mudanças em: `src/`, `Dockerfile`, `buildspec.yml`, `package*.json`

```
GitHub → CodePipeline → CodeBuild (docker build + push ECR) → ECS Deploy
```

### Pipeline de infraestrutura
Disparada por mudanças em: `terraform/`

```
GitHub → CodePipeline → CodeBuild (terraform fmt + validate + plan + apply)
```

Variáveis sensíveis do Terraform são lidas do SSM Parameter Store durante o build
(não ficam no repositório).

## Auto-scaling

| Métrica | Scale Out | Scale In | Cooldown Out | Cooldown In |
|---------|-----------|----------|--------------|-------------|
| CPU     | ≥ 30%     | ≤ 20%    | 30s          | 120s        |

Capacidade: mínimo 1 task, máximo 4 tasks.

## Endpoints da API

| Rota                   | Descrição                                                    |
|------------------------|--------------------------------------------------------------|
| `GET /`                | Mensagem estática + hostname da task + contador de requests  |
| `GET /connect`         | Testa conexão com o banco PostgreSQL                         |
| `GET /stress`          | Satura CPU por N segundos (`?seconds=30`, máx. 30s)          |
| `GET /dashboard`       | Painel de observabilidade visual                             |
| `GET /obs/status`      | Status do ECS Service (running/desired/pending)              |
| `GET /obs/scaling-events` | Últimos 10 eventos de auto scaling                        |
| `GET /obs/alarm-history`  | Histórico de estados dos alarmes CloudWatch               |
