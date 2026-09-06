# Infraestrutura Kubernetes — fiap-mecanica-infra-k8s (Terraform)

Provisiona, na conta AWS Academy Lab, o cluster Kubernetes (EKS) e a rede que ele precisa — VPC,
subnets, node group — mais os add-ons de nível de cluster: metrics-server e a integração
Kubernetes da New Relic (Helm `nri-bundle`).

Um dos **4 repositórios** exigidos pela Fase 3 (Lambda, Infra Kubernetes — este —, Infra de
Banco, Aplicação). Nasceu em 2026-09-03 a partir de uma divisão do repositório `fiap-mecanica`,
que antes concentrava toda a infraestrutura num state só.

## Recursos criados

| Arquivo | Recurso | O que é |
|---|---|---|
| `vpc.tf` | `aws_vpc.vpc_fiap` | VPC dedicada (`10.0.0.0/16`) |
| `subnet.tf` | `aws_subnet.subnet_public` (x3) | 3 subnets públicas, uma por AZ — EKS exige subnets em pelo menos 2 AZs |
| `internet-g.tf`, `route-t.tf` | Internet Gateway + rota `0.0.0.0/0` | Saída para a internet |
| `iam-role.tf` | `data.aws_iam_role.lab_role` | `LabRole` já existente na conta — a Academy Lab não permite criar IAM roles próprias |
| `eks-cluster.tf` | `aws_eks_cluster.cluster` | Cluster EKS `eks-fiap-mecanica` |
| `eks-node.tf` | `aws_eks_node_group.node-group` | Node group gerenciado (`t3.medium`, 1–3 nodes) |
| `access-entry.tf` | Access entries | Admin do cluster pro usuário Lab (`voclabs`) + entry `EC2_LINUX` pra `LabRole` (nodes) |

`bucket.tf` **não cria recurso nenhum** — é só um comentário explicando por que o bucket do
backend (usado por **todos os 4 repositórios**, cada um com sua própria chave) não é gerenciado
pelo Terraform. Ver "Bootstrap" abaixo.

## Por que a chave de state não foi renomeada

`backend.tf` aponta para `tfstate/terraform.tfstate` — a mesma chave que já gerenciava estes
recursos no repositório `fiap-mecanica` original, antes da divisão. Renomear exigiria uma
operação de state só por estética; o nome é histórico, não reflete mais "todo o Terraform do
projeto", só a parte de K8s.

## Migração (2026-09-03) — como foi feita, sem destruir nada

VPC/EKS/node group não têm por que ser destruídos e recriados — não guardam nada que precise ser
descartado, e recriá-los custa ~20 minutos de controle plane à toa. A divisão foi só trocar de
repositório: os arquivos foram copiados para cá apontando para a **mesma chave de backend**, e
`terraform plan` confirmou "No changes" antes de qualquer coisa ser considerada pronta.

RDS, ECR e New Relic — que também viviam nesse mesmo state — foram migrados para os outros 3
repositórios (RDS/ECR via `import`, New Relic via `destroy`+`create`, este último ainda
pendente). Ver os READMEs de `fiap-mecanica-infra-db` e `fiap-mecanica/infra/terraform/app-infra`
para os detalhes de cada um.

### Efeito colateral: o repositório `fiap-mecanica` ainda tem cópias destes arquivos

Por segurança, os arquivos de VPC/EKS **não foram apagados** do diretório
`infra/terraform/aws/` do repositório `fiap-mecanica` durante a migração — apagá-los exigiria
também um `terraform state rm` desses recursos ali (já que aquele diretório aponta para a mesma
chave de state), e como o CD daquele repositório roda `terraform apply -auto-approve` **sem
revisão humana**, qualquer descompasso entre config e state teria destruído o cluster
automaticamente no primeiro push. Em vez disso, o `cd.yml` de lá foi ajustado para nunca mais
tocar nesses recursos (usa `-target` restrito só ao que ainda é legado de verdade — New Relic).
Esses arquivos ali são cópias congeladas, inofensivas, e podem ser apagados num cleanup futuro.

**A partir de agora, este repositório é o único que deve aplicar mudanças em VPC/EKS/node
group.**

## Bootstrap (bucket do backend) — sem passo manual

O bucket S3 usado como backend remoto (`fiap-mecanica`) **não é um recurso Terraform** — é criado
via `aws s3api create-bucket`, direto pelo `cd.yml`/`ci.yml`, de forma idempotente, antes do
`terraform init`. Numa conta nova, é só disparar o CD normalmente; não há passo manual.

### Por que não é gerenciado pelo Terraform

Já foi um `resource "aws_s3_bucket"` aqui. O provider AWS, para esse tipo de recurso, sempre
chama `GetBucketObjectLockConfiguration` como parte do ciclo normal de leitura (todo
`plan`/`refresh`, não só na criação). Numa conta AWS Academy Lab encontrada em 2026-09-06, uma
**Service Control Policy** nega essa chamada explicitamente — e SCP se propaga da Organização
para **todas** as contas-membro, então trocar de conta dentro do mesmo programa não resolve.
Nem a `LabRole` escapa de um "explicit deny" de SCP; não existe argumento do recurso que
desative essa leitura. O efeito: todo `terraform plan` deste módulo passaria a falhar, para
sempre, mesmo sem nenhuma mudança pendente.

A correção foi tirar o bucket do Terraform e criá-lo por fora, com uma chamada que não aciona
essa leitura. Rodando localmente (fora do CD), crie o bucket uma vez à mão antes do primeiro
`terraform init`:
```bash
aws s3api create-bucket --bucket fiap-mecanica --region us-east-1
```

## Variáveis (`vars.tf`)

| Variável | Default | Descrição |
|---|---|---|
| `project_name` | `fiap-mecanica` | Prefixo do nome da maioria dos recursos |
| `region_default` | `us-east-1` | Região AWS |
| `cidr_vpc` | `10.0.0.0/16` | CIDR da VPC |
| `tags` | `{Name = "fiap-mecanica-terraform"}` | Tags aplicadas aos recursos |
| `instance_type` | `t3.medium` | Tipo de instância dos nodes EKS |

## Outputs (`output.tf`)

| Output | Uso |
|---|---|
| `vpc_id`, `vpc_cidr`, `subnet_id`, `subnet_cidr` | Consumidos pelo repositório `fiap-mecanica-infra-db` (rede do RDS) |
| `eks_cluster_security_group_id` | Consumido pelo `fiap-mecanica-infra-db` — libera a porta 3306 só para o SG do cluster |
| `eks_cluster_name` | Consumido pelo `cd.yml` deste repositório (`update-kubeconfig`) e, via `terraform_remote_state`, pelo `app-infra` do repositório `fiap-mecanica` |
| `eks_cluster_endpoint`, `eks_cluster_certificate_authority_data` | Endpoint/CA do control plane |
| `eks_node_group_name` | Nome do node group |

## CI/CD

- `ci.yml` (Pull Request): garante o bucket do backend, depois `terraform plan`.
- `cd.yml` (push na `main`): garante o bucket do backend, `terraform apply` do cluster, depois
  `kubectl apply` do metrics-server e `helm upgrade --install` do `nri-bundle` da New Relic
  (agente de infraestrutura + `kube-state-metrics` + `newrelic-logging`/Fluent Bit).

Secrets necessários: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (sessão da
conta Academy Lab, renovar quando expirar) e `NEW_RELIC_LICENSE_KEY` (a mesma usada pelo Secret
da aplicação no repositório `fiap-mecanica` — o chart Helm não precisa de `NEW_RELIC_API_KEY`
nem `NEW_RELIC_ACCOUNT_ID`, só usados pelo provider Terraform de alertas, que não existe aqui).

## Ordem de deploy numa infra do zero

Este repositório é o **primeiro** de todo o projeto: `fiap-mecanica-infra-db` lê seu state, e o
`app-infra` do repositório `fiap-mecanica` também. Ordem completa:

```
1º fiap-mecanica-infra-k8s   (este)
2º fiap-mecanica-infra-db
3º fiap-mecanica-lambda      (independente, pode ser antes ou depois)
4º fiap-mecanica             (app-infra lê 1º e 2º; apigateway lê o nome da função Lambda, se existir)
```

Não existe gatilho automático entre os 4 CDs — cada um roda independente, disparado por push na
sua própria `main`. Numa conta zerada, é preciso rodar cada CD manualmente, nessa ordem, esperando
o anterior terminar antes do próximo.

## Destruir

Este repositório deve ser o **último** a ser destruído — `fiap-mecanica-infra-db` e o `app-infra`
do `fiap-mecanica` leem o state daqui; destruir antes deles quebraria essas leituras (e, no caso
do SG do banco, deixaria uma referência a um SG que não existe mais).

```
1º fiap-mecanica (app-infra + apigateway)
2º fiap-mecanica-infra-db
3º fiap-mecanica-infra-k8s (este)
```

**O bucket do backend nunca é destruído por nenhum `terraform destroy` dos 4 repositórios** —
não é mais estruturalmente possível, já que ele não é um recurso Terraform (ver "Bootstrap"
acima). "Derrubar tudo" quer dizer os recursos AWS de cada repositório; o bucket fica parado,
guardando os states, pronto pro próximo apply.
