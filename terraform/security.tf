
# ==================================================
# APPLICATION LOAD BALANCER SECURITY GROUP
# ==================================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.existing.id

  ingress = []
  egress  = []

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Public HTTP traffic to ALB

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  description = "Allow HTTP traffic from internet"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}

# ALB to application EC2

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id = aws_security_group.alb.id

  description                  = "Allow traffic to application instances"
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
  referenced_security_group_id = aws_security_group.app.id
}

# ==================================================
# JENKINS EC2 SECURITY GROUP
# ==================================================

resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Security group for Jenkins EC2"
  vpc_id      = data.aws_vpc.existing.id

  ingress = []
  egress  = []

  tags = {
    Name = "${var.project_name}-jenkins-sg"
  }
}

# Jenkins to application EC2 over private SSH

resource "aws_vpc_security_group_egress_rule" "jenkins_to_app_ssh" {
  security_group_id = aws_security_group.jenkins.id

  description                  = "Allow Jenkins SSH access to application instances"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.app.id
}

# Jenkins outbound HTTPS for GitHub, ECR and AWS APIs

resource "aws_vpc_security_group_egress_rule" "jenkins_https" {
  security_group_id = aws_security_group.jenkins.id

  description = "Allow outbound HTTPS through NAT Gateway"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

# ==================================================
# APPLICATION EC2 SECURITY GROUP
# ==================================================

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for application EC2 instances"
  vpc_id      = data.aws_vpc.existing.id

  ingress = []
  egress  = []

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# Application traffic only from ALB

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.app.id

  description                  = "Allow application traffic from ALB"
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
  referenced_security_group_id = aws_security_group.alb.id
}

# SSH only from Jenkins EC2

resource "aws_vpc_security_group_ingress_rule" "app_from_jenkins_ssh" {
  security_group_id = aws_security_group.app.id

  description                  = "Allow SSH only from Jenkins instances"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.jenkins.id
}

# Temporary outbound access for application instances.
# Review and restrict before deployment.

resource "aws_vpc_security_group_egress_rule" "app_outbound" {
  security_group_id = aws_security_group.app.id

  description = "Temporary outbound access for application instances"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
