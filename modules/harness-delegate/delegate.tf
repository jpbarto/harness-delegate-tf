# ---------------------------------------------------------------------------
# Harness delegate token — created via the Harness provider and injected
# into the Helm chart so the pod can authenticate to Harness SaaS.
# ---------------------------------------------------------------------------
resource "harness_platform_delegatetoken" "delegate" {
  name       = var.delegate_name
  account_id = var.harness_account_id
}

# ---------------------------------------------------------------------------
# Helm release — Harness Delegate NG
# ---------------------------------------------------------------------------
locals {
  # The INIT_SCRIPT env var runs when the delegate pod starts and installs
  # OpenTofu into /usr/local/bin so it is available on the default PATH.
  delegate_init_script = <<-EOT
    echo "==> Installing OpenTofu ${var.terraform_version}"
    curl -fsSL \
      "https://github.com/opentofu/opentofu/releases/download/v${var.terraform_version}/tofu_${var.terraform_version}_linux_${var.terraform_arch}.zip" \
      -o /tmp/tofu.zip
    unzip -q /tmp/tofu.zip -d /tmp/tofu-install
    mv /tmp/tofu-install/tofu /usr/local/bin/tofu
    chmod +x /usr/local/bin/tofu
    # Also expose as 'terraform' so Harness Terraform steps find it
    ln -sf /usr/local/bin/tofu /usr/local/bin/terraform
    echo "==> $(terraform version)"
    rm -rf /tmp/tofu.zip /tmp/tofu-install
  EOT
}

resource "helm_release" "harness_delegate" {
  name             = "harness-delegate"
  repository       = "https://app.harness.io/storage/harness-download/delegate-helm-chart/"
  chart            = "harness-delegate-ng"
  namespace        = kubernetes_namespace.harness_delegate.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300
  cleanup_on_fail  = true

  # Ensure the service account and RBAC exist before the pods start.
  depends_on = [
    kubernetes_cluster_role_binding.harness_delegate_admin,
    kubernetes_service_account.harness_delegate,
  ]

  values = [
    yamlencode({
      replicas = var.delegate_replicas

      accountId       = var.harness_account_id
      delegateToken   = harness_platform_delegatetoken.delegate.value
      delegateName    = var.delegate_name
      deployMode      = "KUBERNETES"
      nextGen         = true
      managerEndpoint = var.harness_manager_endpoint

      # Run init script before delegate starts — used to install OpenTofu.
      initScript = local.delegate_init_script

      # Use the pre-created service account (annotated for IRSA).
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.harness_delegate.metadata[0].name
      }

      # Extra environment variables injected into the delegate container.
      # harness-delegate-ng chart uses custom_envs: list of {name, value}.
      custom_envs = [
        { name = "HARNESS_CI_CACHE_BUCKET", value = aws_s3_bucket.ci_cache.bucket },
        { name = "HARNESS_CI_CACHE_REGION", value = var.region },
        { name = "HARNESS_TF_STATE_BUCKET", value = aws_s3_bucket.tf_state.bucket },
        { name = "HARNESS_TF_STATE_REGION", value = var.region },
      ]

      # Optionally pin the delegate image tag.
      image = var.delegate_image_tag != "" ? { tag = var.delegate_image_tag } : {}

      upgrader = {
        enabled = true
      }
    })
  ]
}
