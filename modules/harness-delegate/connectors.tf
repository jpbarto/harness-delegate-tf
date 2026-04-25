# ---------------------------------------------------------------------------
# AWS connector — account-scoped, authenticates via IRSA on the delegate pod.
# Used by:
#   - Harness CI cache steps (S3 bucket)
#   - Harness CD Terraform steps (S3 state backend)
# ---------------------------------------------------------------------------
resource "harness_platform_connector_aws" "delegate" {
  identifier  = replace("aws_${local.name_suffix}", "-", "_")
  name        = "AWS ${var.region} - ${var.environment}"
  description = "AWS connector for ${var.region} — credentials via IRSA on the Harness Delegate pod"

  # IRSA: Harness tells the delegate to use its pod's IRSA-bound IAM role.
  # No static credentials needed.
  irsa {
    delegate_selectors = [var.delegate_name]
    region             = var.region
  }

  depends_on = [helm_release.harness_delegate]
}

# ---------------------------------------------------------------------------
# Kubernetes connector — account-scoped, connects via the delegate running
# inside the cluster. No explicit credentials required.
# Used by:
#   - Harness CD pipelines deploying Kubernetes workloads
#   - Harness CD Helm deployment steps
# ---------------------------------------------------------------------------
resource "harness_platform_connector_kubernetes" "delegate" {
  identifier  = replace("k8s_${local.name_suffix}", "-", "_")
  name        = "K8s ${var.eks_cluster_name} - ${var.region}"
  description = "Kubernetes connector for EKS cluster ${var.eks_cluster_name} in ${var.region} — credentials inherited from the Harness Delegate"

  inherit_from_delegate {
    delegate_selectors = [var.delegate_name]
  }

  depends_on = [helm_release.harness_delegate]
}
