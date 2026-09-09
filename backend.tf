terraform {
  # use_lockfile (lock de state nativo do S3, sem DynamoDB) exige Terraform >= 1.10.
  required_version = ">= 1.10.0"
  backend "s3" {
    # Chave mantida como "tfstate/terraform.tfstate" de propósito — é a MESMA chave que já
    # gerenciava estes recursos no repositório fiap-mecanica original, antes da divisão em 4
    # repositórios. Renomear exigiria uma operação de state só por estética; o nome é histórico.
    bucket = "fiap-mecanica"
    key    = "tfstate/terraform.tfstate"
    region = "us-east-1"
    # Lock de state nativo do S3: dois `apply` na mesma chave nao se sobrescrevem
    # (ex.: apply local sobrepondo o CD). Objeto <chave>.tflock no mesmo bucket.
    use_lockfile = true
  }
}
