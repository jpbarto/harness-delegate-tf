# EKS cluster details — used to configure the Helm and Kubernetes providers.
data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster_name
}

# Discover the managed node groups for the cluster so we can retrieve the
# node IAM role ARN to use as the principal in the delegate's trust policy.
data "aws_eks_node_groups" "cluster" {
  cluster_name = var.eks_cluster_name
}

data "aws_eks_node_group" "default" {
  cluster_name    = var.eks_cluster_name
  node_group_name = tolist(data.aws_eks_node_groups.cluster.names)[0]
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
