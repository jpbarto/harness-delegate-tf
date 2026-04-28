variable "region" {
  description = "AWS region where the EKS cluster lives."
  type        = string
}

variable "project_name" {
  description = "Name of the project — used to namespace resource names."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

# ---------------------------------------------------------------------------
# EKS cluster — must already exist (output from the platform module)
# ---------------------------------------------------------------------------
variable "eks_cluster_name" {
  description = "Name of the EKS cluster to deploy the delegate into."
  type        = string
}

# ---------------------------------------------------------------------------
# Harness platform
# ---------------------------------------------------------------------------
variable "harness_account_id" {
  description = "Harness account ID (found in Account Settings → Overview)."
  type        = string
}

variable "harness_platform_api_key" {
  description = "Harness API key used by the Terraform provider (SAT or PAT)."
  type        = string
  sensitive   = true
}

variable "harness_manager_endpoint" {
  description = "Harness SaaS manager endpoint."
  type        = string
  default     = "https://app.harness.io"
}

# ---------------------------------------------------------------------------
# Delegate sizing
# ---------------------------------------------------------------------------
variable "delegate_name" {
  description = "Name given to the delegate inside Harness."
  type        = string
  default     = "k8s-delegate"
}

variable "delegate_replicas" {
  description = "Number of delegate pod replicas."
  type        = number
  default     = 1
}

variable "delegate_image_tag" {
  description = "Harness delegate image tag. Leave empty to use chart default."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Terraform version to install inside the delegate
# ---------------------------------------------------------------------------
variable "terraform_version" {
  description = "Version of OpenTofu/Terraform to install inside the delegate pod."
  type        = string
  default     = "1.9.1"
}

variable "terraform_arch" {
  description = "CPU architecture of the delegate nodes (amd64 or arm64)."
  type        = string
  default     = "amd64"
}

variable "delegate_iam_role_name" {
  description = "Override for the IAM role name assigned to the Harness Delegate via IRSA. Defaults to '<project_name>-<environment>-harness-delegate' when null."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# GitOps Agent
# ---------------------------------------------------------------------------
variable "gitops_agent_name" {
  description = "Display name for the Harness GitOps agent registered at the account level."
  type        = string
  default     = "k8s-gitops-agent"
}
