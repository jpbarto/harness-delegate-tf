# ---------------------------------------------------------------------------
# Harness GitOps Agent — registration
#
# Registers the GitOps agent at the *account* level (no org_id / project_id)
# so it is available across all organisations and projects in the account.
# The resource returns an agent_token that the Helm chart needs at start-up.
# ---------------------------------------------------------------------------
resource "harness_platform_gitops_agent" "gitops" {
  identifier = replace("gitops_${local.name_suffix}", "-", "_")
  name       = var.gitops_agent_name
  account_id = var.harness_account_id

  # CONNECTED_ARGO_PROVIDER = Harness manages ArgoCD internally (no existing
  # ArgoCD installation required).
  type = "CONNECTED_ARGO_PROVIDER"

  metadata {
    namespace         = kubernetes_namespace.harness_gitops.metadata[0].name
    high_availability = false
  }
}

# ---------------------------------------------------------------------------
# Harness GitOps Agent — Helm deployment
#
# Chart: harness/gitops  (https://harness.github.io/helm-gitops)
# The agent token produced by the registration resource above is injected
# into the chart so the pod can authenticate to harness.io on start-up.
# ---------------------------------------------------------------------------
resource "helm_release" "harness_gitops_agent" {
  name             = "harness-gitops-agent"
  repository       = "https://harness.github.io/helm-gitops"
  chart            = "gitops"
  namespace        = kubernetes_namespace.harness_gitops.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300
  cleanup_on_fail  = true

  # The RBAC, service account and Harness-side registration must all exist
  # before the pod starts.
  depends_on = [
    kubernetes_cluster_role_binding.harness_gitops_agent_admin,
    kubernetes_service_account.harness_gitops_agent,
    harness_platform_gitops_agent.gitops,
  ]

  values = [
    yamlencode({
      replicaCount = 1

      # Reuse the pre-created service account bound to cluster-admin.
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.harness_gitops_agent.metadata[0].name
      }

      # -----------------------------------------------------------------------
      # SaaS / cloud mode — disable the bundled data-stores that are only
      # needed for a self-hosted (on-prem) Harness installation.  When these
      # are disabled the wait-for-mongo and wait-for-timescale init containers
      # are removed and the agent connects directly to the Harness SaaS backend.
      # -----------------------------------------------------------------------
      mongo = {
        enabled  = false
        protocol = "mongodb"
        hosts    = []
      }

      timescaledb = {
        enabled = false
      }

      redis = {
        enabled = false
      }

      argocd = {
        # The chart deploys its own ArgoCD instance when using
        # CONNECTED_ARGO_PROVIDER — keep it enabled.
        enabled = true
      }

      gitopsAgent = {
        config = {
          # Core agent identity — values come from the registration resource.
          ACCOUNT_ID       = var.harness_account_id
          AGENT_IDENTIFIER = harness_platform_gitops_agent.gitops.identifier
          AGENT_TOKEN      = harness_platform_gitops_agent.gitops.agent_token

          # Tell the agent it is connecting to Harness SaaS (not self-hosted).
          GITOPS_SERVICE_HTTP_URL = var.harness_manager_endpoint
          MANAGER_HOST_AND_PORT   = var.harness_manager_endpoint

          # With SaaS the remote service is not the manager endpoint directly.
          REMOTE_SERVICE_IS_MANAGER = "false"

          # Disable automatic webhook creation on first sync.
          SKIP_PRECREATE_WEBHOOK = "true"
        }
      }
    })
  ]
}
