# Decisões Arquiteturais

## ADR-001: ECS Fargate em subnets públicas (sem NAT Gateway)

**Contexto:** ECS Fargate em subnets privadas exige NAT Gateway para comunicação com ECR,
Secrets Manager e demais serviços AWS. Cada NAT Gateway custa ~$32/mês por AZ.

**Decisão:** Em ambiente dev, as tasks ECS ficam nas subnets **públicas** com
`assign_public_ip = true`. O acesso às APIs AWS é feito diretamente pelo Internet Gateway.

**Consequências:**
- Economia de ~$64/mês (2 AZs × NAT Gateway)
- As tasks ficam com IP público, mas o Security Group só aceita tráfego vindo do ALB (porta 3000)
- Em produção, o ideal é reverter: ECS em subnets privadas + NAT Gateway por AZ

---

## ADR-002: RDS em subnets privadas

**Contexto:** O banco de dados não deve ser acessível diretamente pela internet.

**Decisão:** O RDS fica nas subnets **privadas**, sem acesso público (`publicly_accessible = false`).
O Security Group do RDS só aceita conexões do Security Group do ECS na porta 5432.

**Consequências:**
- O banco está inacessível pela internet, mesmo sem NAT Gateway
- Acesso de desenvolvimento local exige bastion host ou AWS SSM Session Manager (não provisionado neste ambiente)

---

## ADR-003: Duas pipelines separadas com path filters

**Contexto:** Uma única pipeline que dispara em qualquer mudança força rebuild da imagem Docker
mesmo quando só o Terraform mudou, e vice-versa.

**Decisão:** Duas pipelines CodePipeline V2 com `file_paths` distintos:
- **App pipeline:** `src/**`, `Dockerfile`, `buildspec.yml`, `package*.json`
- **Terraform pipeline:** `terraform/**`

**Consequências:**
- Builds menores e mais rápidos
- Menor consumo de CodeBuild minutes
- Cada pipeline tem responsabilidade única

---

## ADR-004: Senha do banco via AWS Secrets Manager

**Contexto:** Passar secrets como variáveis de ambiente em plaintext expõe credenciais nos
logs do ECS, no console da AWS e no histórico do Terraform.

**Decisão:** A senha do RDS é armazenada no Secrets Manager. O container definition usa
`secrets:` (não `environment:`), fazendo o ECS injetar o valor diretamente na variável de
ambiente sem expô-lo nos logs.

**Consequências:**
- A senha nunca aparece em plaintext no CloudWatch Logs
- A task execution role precisa de `secretsmanager:GetSecretValue` (concedido no módulo IAM)

---

## ADR-005: Terraform state no S3

**Contexto:** State local bloqueia colaboração em time e não é resiliente a perda de máquina.

**Decisão:** Backend S3 com versioning e criptografia AES256. O bucket é nomeado com o
Account ID para garantir unicidade global.

**Consequências:**
- State compartilhado entre qualquer executor (desenvolvedor, CodeBuild)
- Sem lock (DynamoDB não configurado) — risco baixo em ambiente dev com um único executor

---

## ADR-006: Dockerfile multi-stage

**Contexto:** Instalar dependências de build e copiar o código em uma única stage gera
imagens maiores e com superfície de ataque desnecessária.

**Decisão:** Stage `builder` instala dependências com `npm ci --only=production`.
Stage final copia apenas `node_modules` e o código-fonte, sem ferramentas de build.

**Consequências:**
- Imagem final menor
- Nenhuma dependência de desenvolvimento (devDependencies) incluída

---

## ADR-007: FARGATE_SPOT como capacity provider secundário

**Contexto:** Fargate Spot oferece desconto de até 70% em relação ao Fargate on-demand.

**Decisão:** O cluster tem `FARGATE` como provider primário (base=1) e `FARGATE_SPOT`
configurado como alternativa. Em produção, seria possível usar peso 70/30 (Spot/On-demand)
para reduzir custos com tolerância a interrupções.

**Consequências:**
- Em dev, o serviço roda em Fargate on-demand (mais estável)
- A configuração está pronta para usar Spot em produção ajustando `weight`

---

## ADR-008: Container Insights desabilitado

**Contexto:** Container Insights no ECS gera métricas detalhadas de CPU/memória por task,
mas custa ~$0.35/GB de logs + ~$0.01 por métrica.

**Decisão:** Desabilitado em dev. Os alarmes de CPU e memória usam as métricas nativas
do ECS (sem custo adicional). Em produção, habilitar para visibilidade completa por task.
