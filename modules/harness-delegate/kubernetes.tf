# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "harness_delegate" {
  metadata {
    name = local.delegate_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# Service account — no IRSA annotation; the delegate assumes its IAM role
# explicitly via sts:AssumeRole using the node instance profile.
# ---------------------------------------------------------------------------
resource "kubernetes_service_account" "harness_delegate" {
  metadata {
    name      = local.delegate_sa_name
    namespace = kubernetes_namespace.harness_delegate.metadata[0].name

    labels = {
      "app.kubernetes.io/name"       = local.delegate_sa_name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# ClusterRoleBinding — gives the delegate cluster-admin so it can create
# namespaces and any resources directed by Harness CD pipelines.
# ---------------------------------------------------------------------------
resource "kubernetes_cluster_role_binding" "harness_delegate_admin" {
  metadata {
    name = "harness-delegate-cluster-admin"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.harness_delegate.metadata[0].name
    namespace = kubernetes_namespace.harness_delegate.metadata[0].name
  }
}
