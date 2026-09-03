output "vpc_cidr" {
  value = aws_vpc.vpc_fiap.cidr_block
}

output "vpc_id" {
  value = aws_vpc.vpc_fiap.id
}

output "subnet_cidr" {
  value = aws_subnet.subnet_public[*].cidr_block
}

output "subnet_id" {
  value = aws_subnet.subnet_public[*].id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = aws_eks_cluster.cluster.certificate_authority[0].data
}

output "eks_cluster_security_group_id" {
  description = "SG do control plane do EKS. Consumido pelo repositório fiap-mecanica-infra-db via terraform_remote_state, para liberar a porta 3306 do RDS só para o cluster."
  value       = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
}

output "eks_node_group_name" {
  value = aws_eks_node_group.node-group.node_group_name
}
