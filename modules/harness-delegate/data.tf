# EKS cluster details — used to configure the Helm and Kubernetes providers
# and to build the IRSA trust policy.
data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster_name
}

# Derive the OIDC provider ARN from the issuer URL embedded in the cluster.
# EKS stores the raw URL (without the https:// scheme) in the OIDC config.
data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
