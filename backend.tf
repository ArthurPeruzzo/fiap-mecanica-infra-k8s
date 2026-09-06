terraform {
  backend "s3" {
    # Chave mantida como "tfstate/terraform.tfstate" de propósito — é a MESMA chave que já
    # gerenciava estes recursos no repositório fiap-mecanica original, antes da divisão em 4
    # repositórios. Renomear exigiria uma operação de state só por estética; o nome é histórico.
    bucket = "fiap-mecanica"
    key    = "tfstate/terraform.tfstate"
    region = "us-east-1"
  }
}
