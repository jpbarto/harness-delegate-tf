# ---------------------------------------------------------------------------
# IAM role — assumed by the Harness Delegate pod via IRSA
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "delegate_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.delegate_namespace}:${local.delegate_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "delegate" {
  name               = local.delegate_iam_role_name
  assume_role_policy = data.aws_iam_policy_document.delegate_assume.json
  tags               = local.tags
}

# ---------------------------------------------------------------------------
# Policy — S3 access (CI cache + Terraform state buckets)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "delegate_s3" {
  statement {
    sid    = "CICacheBucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.ci_cache.arn,
      "${aws_s3_bucket.ci_cache.arn}/*",
    ]
  }

  statement {
    sid    = "TFStateBucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketVersioning",
    ]
    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "delegate_s3" {
  name        = "${local.delegate_iam_role_name}-s3"
  description = "Grants the Harness Delegate access to its CI cache and TF state S3 buckets"
  policy      = data.aws_iam_policy_document.delegate_s3.json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "delegate_s3" {
  role       = aws_iam_role.delegate.name
  policy_arn = aws_iam_policy.delegate_s3.arn
}

# ---------------------------------------------------------------------------
# Policy — EKS access so the delegate can describe the cluster and refresh
# its kubeconfig when running Terraform/kubectl steps in pipelines
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "delegate_eks" {
  statement {
    sid    = "EKSDescribe"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:AccessKubernetesApi",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "delegate_eks" {
  name        = "${local.delegate_iam_role_name}-eks"
  description = "Grants the Harness Delegate read access to EKS cluster metadata"
  policy      = data.aws_iam_policy_document.delegate_eks.json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "delegate_eks" {
  role       = aws_iam_role.delegate.name
  policy_arn = aws_iam_policy.delegate_eks.arn
}
