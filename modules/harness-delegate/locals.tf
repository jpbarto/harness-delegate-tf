locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Includes region so account-scoped Harness resources are unique per deployment.
  name_suffix = "${var.project_name}-${var.environment}-${var.region}"

  delegate_namespace     = "harness-delegate"
  delegate_sa_name       = "harness-delegate"
  delegate_iam_role_name = "${local.name_prefix}-harness-delegate"

  ci_cache_bucket_name = "${local.name_prefix}-harness-ci-cache"
  tf_state_bucket_name = "${local.name_prefix}-harness-tf-state"

  tags = {
    project     = var.project_name
    environment = var.environment
    terraform   = "true"
    component   = "harness-delegate"
  }
}
