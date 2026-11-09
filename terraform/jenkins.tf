
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = false

  monitoring = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -Eeuo pipefail

    exec > >(tee -a /var/log/jenkins-bootstrap.log) 2>&1

    echo "Starting Jenkins EC2 bootstrap..."

    # Install required packages
    dnf update -y

    dnf install -y \
      java-17-amazon-corretto \
      docker \
      git \
      wget \
      curl \
      awscli-2 \
      openssh-clients \
      amazon-ssm-agent

    # Verify Java and AWS CLI
    java -version
    aws --version

    # Configure Jenkins stable repository
    wget -O /etc/yum.repos.d/jenkins.repo \
      https://pkg.jenkins.io/redhat-stable/jenkins.repo

    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

    # Install Jenkins
    dnf install -y jenkins

    # Start and enable Docker
    systemctl enable docker
    systemctl start docker

    # Allow Jenkins to execute Docker commands
    usermod -aG docker jenkins

    # Start and enable Jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Start and enable SSM Agent
    systemctl enable amazon-ssm-agent
    systemctl restart amazon-ssm-agent

    # Verify services
    systemctl is-active --quiet docker
    systemctl is-active --quiet jenkins
    systemctl is-active --quiet amazon-ssm-agent

    echo "Jenkins bootstrap completed successfully."
  EOF

  tags = {
    Name        = "${var.project_name}-jenkins-server"
    Project     = var.project_name
    Environment = "lab"
    Role        = "jenkins"
  }

  volume_tags = {
    Name    = "${var.project_name}-jenkins-volume"
    Project = var.project_name
  }
}
