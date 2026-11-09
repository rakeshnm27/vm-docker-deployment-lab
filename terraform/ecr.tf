# Reference existing ECR repository

data "aws_ecr_repository" "app" {
  name = "vm-docker-deployment-lab"
}
