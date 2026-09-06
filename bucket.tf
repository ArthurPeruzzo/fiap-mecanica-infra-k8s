# O bucket do backend NÃO é gerenciado pelo Terraform de propósito — ver "Bootstrap" no README.
#
# Já foi um resource "aws_s3_bucket" aqui, mas o recurso `aws_s3_bucket` do provider AWS sempre
# faz uma chamada `GetBucketObjectLockConfiguration` como parte do seu ciclo normal de leitura
# (todo `plan`/`refresh`, não só na criação). Em contas onde uma Service Control Policy nega essa
# chamada explicitamente (visto numa conta AWS Academy Lab em 2026-09-06 — nem a LabRole escapa
# de um "explicit deny" de SCP, que se propaga de toda a Organização pra todas as contas-membro),
# TODO `terraform plan` deste módulo passa a falhar, para sempre, mesmo sem nenhuma mudança
# pendente. Não há argumento do recurso que desative essa leitura.
#
# Criar o bucket via `aws s3api create-bucket` evita essa chamada inteiramente, e o job
# `terraform-apply` do cd.yml faz isso sozinho, de forma idempotente, antes do `terraform init` —
# sem passo manual, mesmo numa conta totalmente nova.
