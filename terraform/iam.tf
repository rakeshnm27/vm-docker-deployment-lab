
# ============================================================
# EC2 TRUST POLICY
# Allows EC2 instances to assume their attached IAM roles
# ============================================================

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


# ============================================================
# APPLICATION EC2 IAM ROLE
# ============================================================

resource "aws_iam_role" "app_ec2" {
  name               = "${var.project_name}-app-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-app-ec2-role"
  }
}


# ============================================================
# APPLICATION EC2 - ECR PULL PERMISSIONS
# ============================================================

data "aws_iam_policy_document" "ecr_pull" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]

    resources = [data.aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_policy" "ecr_pull" {
  name   = "${var.project_name}-ecr-pull-policy"
  policy = data.aws_iam_policy_document.ecr_pull.json
}

resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.app_ec2.name
  policy_arn = aws_iam_policy.ecr_pull.arn
}


# ============================================================
# APPLICATION CLOUDWATCH LOG GROUP
# ============================================================

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ec2/${var.project_name}/app"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-app-logs"
  }
}


# ============================================================
# APPLICATION EC2 - CLOUDWATCH LOG PERMISSIONS
# ============================================================

data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]

    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }
}

resource "aws_iam_policy" "cloudwatch_logs" {
  name   = "${var.project_name}-cloudwatch-logs-policy"
  policy = data.aws_iam_policy_document.cloudwatch_logs.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.app_ec2.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}


# ============================================================
# APPLICATION EC2 INSTANCE PROFILE
# Attaches the application IAM role to EC2 instances
# ============================================================

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-app-instance-profile"
  role = aws_iam_role.app_ec2.name
}


# ============================================================
# JENKINS EC2 IAM ROLE
# ============================================================

resource "aws_iam_role" "jenkins_ec2" {
  name               = "${var.project_name}-jenkins-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-jenkins-ec2-role"
  }
}


# ============================================================
# JENKINS - ECR PUSH PERMISSIONS
# ============================================================

data "aws_iam_policy_document" "jenkins_ecr_push" {

  # ECR authentication requires Resource = "*"
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Repository discovery requires Resource = "*"
  statement {
    effect    = "Allow"
    actions   = ["ecr:DescribeRepositories"]
    resources = ["*"]
  }

  # Image upload permissions are restricted to our repository
  statement {
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [data.aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_policy" "jenkins_ecr_push" {
  name   = "${var.project_name}-jenkins-ecr-push-policy"
  policy = data.aws_iam_policy_document.jenkins_ecr_push.json
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr_push" {
  role       = aws_iam_role.jenkins_ec2.name
  policy_arn = aws_iam_policy.jenkins_ecr_push.arn
}


# ============================================================
# JENKINS - ASG AND ALB DEPLOYMENT PERMISSIONS
# ============================================================

data "aws_iam_policy_document" "jenkins_deploy" {

  # Discover ASG instances and their private IP addresses
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "ec2:DescribeInstances",
      "elasticloadbalancing:DescribeTargetGroups"
    ]

    resources = ["*"]
  }

  # Register and deregister targets during rolling deployment
  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]

    resources = [aws_lb_target_group.app.arn]
  }
}

resource "aws_iam_policy" "jenkins_deploy" {
  name   = "${var.project_name}-jenkins-deploy-policy"
  policy = data.aws_iam_policy_document.jenkins_deploy.json
}

resource "aws_iam_role_policy_attachment" "jenkins_deploy" {
  role       = aws_iam_role.jenkins_ec2.name
  policy_arn = aws_iam_policy.jenkins_deploy.arn
}


# ============================================================
# JENKINS - AWS SYSTEMS MANAGER PERMISSIONS
# Enables secure administration through SSM
# ============================================================

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# ============================================================
# JENKINS EC2 INSTANCE PROFILE
# ============================================================

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-instance-profile"
  role = aws_iam_role.jenkins_ec2.name
}
