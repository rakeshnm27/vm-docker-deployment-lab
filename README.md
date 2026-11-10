# AWS DevOps Project: VM Docker Deployment with Terraform, Jenkins & ECR

**Technologies:** AWS | Terraform | Jenkins | Docker | Amazon ECR | EC2 | ALB | Auto Scaling | Linux | Bash

## 1. Project Overview

This project demonstrates an end-to-end AWS deployment workflow using Infrastructure as Code and Jenkins CI/CD.

Terraform provisions the AWS infrastructure. Jenkins builds the Docker image, pushes it to Amazon ECR, and deploys the application to private EC2 instances using SSH-based rolling deployment.

The deployment integrates an Application Load Balancer (ALB) for traffic distribution and health monitoring.

## 2. Architecture

### Deployment architecture

```text
                 Developer
                     |
                     v
                  GitHub
                     |
                     v
              Jenkins EC2
              (Private Subnet)
                     |
              +------+------+
              |             |
         Docker Build    AWS IAM Role
              |             |
              v             v
          Amazon ECR    AWS APIs
              |
         Docker Image
              |
              v
        SSH Deployment
              |
       +------+------+
       |             |
       v             v
    App EC2-1      App EC2-2
       |             |
       +------+------+
              |
              v
       Application Load
          Balancer
              |
              v
          End Users
```

### AWS infrastructure components

| Component | Purpose |
|---|---|
| VPC | Network isolation |
| Subnets | Host AWS resources |
| EC2 | Jenkins and application hosts |
| Application Load Balancer | Distribute incoming traffic |
| Auto Scaling Group | Maintain application instances |
| Launch Template | Define application EC2 configuration |
| Amazon ECR | Store Docker images |
| IAM Roles | Secure AWS access |
| Security Groups | Control network traffic |
| AWS Systems Manager | Secure instance management |

## 3. Repository Structure

```text
vm-docker-lab/
├── app.py
├── Dockerfile
├── compose.yaml
├── Jenkinsfile
├── README.md
├── scripts/
│   ├── deploy.sh
│   ├── rollback.sh
│   └── health-check.sh
└── terraform/
    ├── providers.tf
    ├── variables.tf
    ├── networking.tf
    ├── security.tf
    ├── iam.tf
    ├── ecr.tf
    ├── autoscaling.tf
    ├── alb.tf
    ├── jenkins.tf
    ├── monitoring.tf
    └── outputs.tf
```

Terraform state and plan files are excluded from Git.

## 4. Infrastructure Provisioning with Terraform

Terraform manages the AWS infrastructure.

Main responsibilities:

- Configure the AWS provider and region.
- Provision and configure networking.
- Create security groups.
- Configure IAM roles and instance profiles.
- Create the ECR repository.
- Provision Jenkins EC2.
- Configure application EC2 through a Launch Template.
- Create an Auto Scaling Group.
- Configure an Application Load Balancer and target group.
- Configure monitoring resources.

### Terraform commands

```bash
cd terraform

terraform init

terraform fmt -recursive

terraform validate

terraform plan

terraform apply
```

Useful outputs:

- ALB DNS name
- Application URL
- Application health-check URL

## 5. Docker Application

The application is containerized using Docker.

Build the image:

```bash
docker build -t vm-docker-app:local .
```

Run locally:

```bash
docker run -d \
  --name vm-docker-app \
  -p 5000:5000 \
  vm-docker-app:local
```

Health check:

```bash
curl http://localhost:5000/health
```

## 6. Jenkins CI/CD Pipeline

Jenkins runs on a dedicated EC2 instance.

The Jenkins EC2 instance uses an IAM instance role for AWS API access instead of storing static AWS access keys in the pipeline.

### Pipeline stages

1. Checkout source code from GitHub.
2. Validate the Jenkins execution environment.
3. Verify AWS identity and ECR access.
4. Build the Docker image.
5. Authenticate with Amazon ECR.
6. Push the image to ECR.
7. Discover healthy application instances in the Auto Scaling Group.
8. Verify SSH connectivity before deployment.
9. Deregister an application instance from the ALB.
10. Deploy the new Docker image over SSH.
11. Perform application health checks.
12. Register the instance back with the ALB.
13. Wait for ALB target health before proceeding.

## 7. Rolling Deployment Strategy

The deployment automation uses the following process:

```text
Discover ASG instances
        |
        v
Verify SSH connectivity
        |
        v
Deregister instance from ALB
        |
        v
Wait for target deregistration
        |
        v
Pull new image from ECR
        |
        v
Replace running container
        |
        v
Application health check
        |
        v
Register instance with ALB
        |
        v
Wait until target is healthy
        |
        v
Deploy next instance
```

This approach allows the other healthy application instance to continue serving traffic while one instance is being updated.

### Deployment automation scripts

- `deploy.sh`: Performs instance discovery, deregistration, deployment and re-registration.
- `rollback.sh`: Provides the previous-image rollback workflow.
- `health-check.sh`: Performs application health verification.

**Note:** Rollback implementation is included in the repository. Its end-to-end failure-recovery behavior should be validated separately before claiming it has been tested successfully.

## 8. Security Implementation

- IAM instance roles for AWS access.
- Jenkins hosted on a private EC2 instance.
- Application EC2 instances hosted in private subnets.
- Security Groups restrict access to required ports.
- SSH key authentication for deployment.
- AWS Systems Manager Agent and instance permissions for secure administration.
- Terraform state, plans and private keys excluded from Git.

## 9. Deployment Verification

### Application health endpoint

```bash
curl -i http://<ALB-DNS>/health
```

Expected response:

```text
HTTP/1.1 200 OK

Application is healthy
```

### ALB target health

```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET-GROUP-ARN> \
  --region ap-south-1
```

### Verified deployment result — 10 November 2026

| Validation | Result |
|---|---|
| Terraform configuration validation | Passed |
| Jenkins pipeline | Success |
| Docker image build | Success |
| ECR image push | Success |
| SSH authentication | Success |
| Rolling deployment | Success |
| Application health endpoint | HTTP 200 |
| First ALB target | Healthy |
| Second ALB target | Healthy |

Successfully deployed image:

```text
743702012398.dkr.ecr.ap-south-1.amazonaws.com/vm-docker-deployment-lab:5
```

## 10. Troubleshooting Experience

The following real issues were encountered and resolved during implementation:

| Issue | Resolution |
|---|---|
| Jenkins node offline due to disk threshold | Adjusted disk-space monitoring threshold |
| Jenkins job waiting for executor | Configured built-in node executor |
| Jenkins bootstrap package conflict | Corrected package installation |
| SSH connectivity from local Jenkins | Moved pipeline execution to Jenkins EC2 inside the VPC |
| ALB targets unhealthy | Corrected Security Group rules |
| SSH authentication issues | Configured Jenkins SSH private-key credential |
| ALB waiter AccessDenied | Corrected Jenkins EC2 IAM permissions |
| SSM access requirements | Added Systems Manager role permissions and agent configuration |

These troubleshooting scenarios provided practical experience in Jenkins administration, AWS IAM, Linux, networking and production deployment workflows.

## 11. Future Improvements

- Validate automated rollback under deployment failure conditions.
- Add CloudWatch dashboards and actionable alarms.
- Improve deployment notifications.
- Add automated integration testing.
- Implement deployment approval controls.
- Review infrastructure cost optimization.

## 12. Author

**DevOps / Cloud Engineering Portfolio Project**

GitHub: https://github.com/rakeshnm27/

Repository: https://github.com/rakeshnm27/vm-docker-deployment-lab

**Project focus:** AWS Infrastructure as Code, CI/CD automation, container deployment, high availability and operational troubleshooting.
