output "delegate_iam_role_arn" {
  description = "ARN of the IAM role assumed by the Harness Delegate pods via IRSA."
  value       = aws_iam_role.delegate.arn
}

output "ci_cache_bucket_name" {
  description = "Name of the S3 bucket used as the Harness CI build cache."
  value       = aws_s3_bucket.ci_cache.bucket
}

output "tf_state_bucket_name" {
  description = "Name of the S3 bucket used to store Terraform state from Harness CD pipelines."
  value       = aws_s3_bucket.tf_state.bucket
}

output "delegate_namespace" {
  description = "Kubernetes namespace the delegate is deployed into."
  value       = kubernetes_namespace.harness_delegate.metadata[0].name
}

output "delegate_service_account" {
  description = "Kubernetes service account name used by the delegate pods."
  value       = kubernetes_service_account.harness_delegate.metadata[0].name
}

output "aws_connector_identifier" {
  description = "Harness identifier of the AWS connector (use this in pipeline YAML for the awsConnectorRef field)."
  value       = harness_platform_connector_aws.delegate.identifier
}

output "k8s_connector_identifier" {
  description = "Harness identifier of the Kubernetes connector (use this in pipeline YAML for the connectorRef field)."
  value       = harness_platform_connector_kubernetes.delegate.identifier
}
