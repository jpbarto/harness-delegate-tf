# ---------------------------------------------------------------------------
# IAM role — assumed by the Harness Delegate pod via sts:AssumeRole.
# The EKS worker node IAM role is the trusted principal; the delegate calls
# sts:AssumeRole from the node's instance profile at runtime.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "delegate_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_eks_node_group.default.node_role_arn]
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

  # Harness AWS connector validation calls ec2:DescribeRegions to verify
  # that the IRSA role is reachable and has AWS access.
  statement {
    sid    = "EC2DescribeRegions"
    effect = "Allow"
    actions = [
      "ec2:DescribeRegions",
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

# ---------------------------------------------------------------------------
# Policy — application resource management, scoped to tag squad=jpbarto
# Covers: Lambda, SQS, DynamoDB, SSM Parameter Store
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "delegate_app" {
  statement {
    sid    = "LambdaManage"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:ListFunctions",
      "lambda:PublishVersion",
      "lambda:CreateAlias",
      "lambda:UpdateAlias",
      "lambda:DeleteAlias",
      "lambda:GetAlias",
      "lambda:ListAliases",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/squad"
      values   = ["jpbarto"]
    }
  }

  # Enforce that newly created Lambda functions must carry the squad tag.
  statement {
    sid    = "LambdaCreate"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/squad"
      values   = ["jpbarto"]
    }
  }

  statement {
    sid    = "SQSManage"
    effect = "Allow"
    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:GetQueueAttributes",
      "sqs:SetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:PurgeQueue",
      "sqs:TagQueue",
      "sqs:UntagQueue",
      "sqs:ListQueueTags",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/squad"
      values   = ["jpbarto"]
    }
  }

  # Enforce that newly created SQS queues must carry the squad tag.
  statement {
    sid    = "SQSCreate"
    effect = "Allow"
    actions = [
      "sqs:CreateQueue",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/squad"
      values   = ["jpbarto"]
    }
  }

  statement {
    sid    = "DynamoDBManage"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:UpdateTable",
      "dynamodb:ListTables",
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:ListTagsOfResource",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/squad"
      values   = ["jpbarto"]
    }
  }

  # Enforce that newly created DynamoDB tables must carry the squad tag.
  statement {
    sid    = "DynamoDBCreate"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/squad"
      values   = ["jpbarto"]
    }
  }

  statement {
    sid    = "SSMParameterManage"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:DescribeParameters",
      "ssm:LabelParameterVersion",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource",
      "ssm:ListTagsForResource",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/squad"
      values   = ["jpbarto"]
    }
  }

  # Enforce that newly created SSM parameters must carry the squad tag.
  statement {
    sid    = "SSMParameterCreate"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/squad"
      values   = ["jpbarto"]
    }
  }
}

resource "aws_iam_policy" "delegate_app" {
  name        = "${local.delegate_iam_role_name}-app"
  description = "Grants the Harness Delegate create/modify/delete on Lambda, SQS, DynamoDB and SSM Parameter Store resources tagged squad=jpbarto"
  policy      = data.aws_iam_policy_document.delegate_app.json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "delegate_app" {
  role       = aws_iam_role.delegate.name
  policy_arn = aws_iam_policy.delegate_app.arn
}
