
# --------------------------------------------------
# Latest Amazon Linux 2023 AMI
# --------------------------------------------------

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --------------------------------------------------
# Launch Template
# --------------------------------------------------

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = var.key_name != "" ? var.key_name : null

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = data.aws_ami.amazon_linux.root_device_name

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # ------------------------------------------------
  # EC2 User Data - Application Bootstrap
  # ------------------------------------------------

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -Eeuo pipefail

    exec > >(tee -a /var/log/app-bootstrap.log) 2>&1

    echo "Starting application bootstrap..."

    # Install Docker and SSM Agent
    dnf install -y docker amazon-ssm-agent

    # Start Docker
    systemctl enable docker
    systemctl start docker

    # Start SSM Agent
    systemctl enable amazon-ssm-agent
    systemctl restart amazon-ssm-agent

    systemctl is-active amazon-ssm-agent

    # Verify AWS CLI
    command -v aws
    aws --version

    # Known-good baseline image pinned by digest
    BASELINE_IMAGE="${data.aws_ecr_repository.app.repository_url}@sha256:66ac565e6f407a73b1d12d855f4d76c11230d7cc8781868372cb53cd5efbd222"

    # Authenticate with Amazon ECR using EC2 IAM role
    aws ecr get-login-password \
      --region ${var.aws_region} |
      docker login \
        --username AWS \
        --password-stdin \
        "${data.aws_ecr_repository.app.registry_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

    # Pull known-good application image
    docker pull "$BASELINE_IMAGE"

    # Start application container
    docker run -d \
      --name vm-docker-app \
      --restart unless-stopped \
      -p 5000:5000 \
      "$BASELINE_IMAGE"

    # Verify application health
    for attempt in $(seq 1 30); do
      if curl -fsS http://127.0.0.1:5000/health; then
        echo
        echo "Application bootstrap successful."
        exit 0
      fi

      echo "Waiting for application health: attempt $attempt/30"
      sleep 5
    done

    echo "ERROR: Application bootstrap health check failed."
    exit 1
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-app-instance"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.project_name}-app-volume"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------------
# Auto Scaling Group
# --------------------------------------------------

resource "aws_autoscaling_group" "app" {
  name = "${var.project_name}-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = [
    for subnet in aws_subnet.private : subnet.id
  ]

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}
