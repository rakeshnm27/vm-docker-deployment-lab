# VM Docker Deployment Lab – AWS DevOps Project

### Docker | Jenkins | AWS | Terraform | CI/CD | Infrastructure as Code

A hands-on DevOps project demonstrating VM-based application deployment, Docker containerization, Jenkins CI/CD automation, deployment and rollback scripting, and AWS infrastructure provisioning using Terraform.

The project starts with a Docker-based application deployment workflow and extends towards a scalable AWS architecture using EC2, Application Load Balancer, Auto Scaling Groups and Amazon ECR.

---

# 1. Project Overview

The objective of this project is to automate application deployment using DevOps tools and practices.

Key objectives:

- Deploy a Python application inside Docker containers.
- Manage application containers using Docker Compose.
- Automate CI/CD using Jenkins.
- Build and push Docker images to Amazon ECR.
- Provision AWS infrastructure using Terraform.
- Configure VPC networking, public and private subnets.
- Deploy applications to private EC2 instances using SSH.
- Implement application health checks.
- Automate application rollback.
- Design a scalable architecture using ALB and Auto Scaling Groups.
- Configure monitoring using Amazon CloudWatch.

# 2. Architecture

## Planned AWS Infrastructure Architecture

```text
                         INTERNET
                            |
                            v
                  APPLICATION LOAD BALANCER
                            |
                            v
                       TARGET GROUP
                            |
                +-----------+-----------+
                |                       |
                v                       v
           PRIVATE EC2             PRIVATE EC2
           APP INSTANCE            APP INSTANCE
                |                       |
                +-----------+-----------+
                            |
                     DOCKER CONTAINERS


                  JENKINS EC2 INSTANCE
                            |
                     JENKINS PIPELINE
                            |
                 +----------+----------+
                 |                     |
                 v                     v
           BUILD DOCKER IMAGE     DEPLOY OVER SSH
                 |
                 v
             AMAZON ECR
                 |
                 v
          APPLICATION INSTANCES


                    TERRAFORM
                        |
          +-------------+-------------+
          |             |             |
          v             v             v
         VPC           IAM       SECURITY GROUPS
          |
          +------ PUBLIC SUBNETS
          |
          +------ PRIVATE SUBNETS
          |
          +------ NAT GATEWAY
          |
          +------ APPLICATION LOAD BALANCER
          |
          +------ AUTO SCALING GROUP
          |
          +------ EC2 INSTANCES
```

## AWS Architecture Components

| Component | Purpose |
|---|---|
| Amazon VPC | Provides isolated networking |
| Public Subnets | Host ALB and NAT Gateway |
| Private Subnets | Host Jenkins and application EC2 instances |
| Application Load Balancer | Distributes incoming application traffic |
| Target Group | Registers application instances |
| Auto Scaling Group | Maintains EC2 instance capacity |
| Amazon EC2 | Runs Jenkins and Docker applications |
| Amazon ECR | Stores Docker images |
| IAM | Manages AWS permissions |
| NAT Gateway | Provides outbound internet connectivity |
| CloudWatch | Monitoring and alerting |
| Terraform | Infrastructure as Code |

The planned architecture uses two application instances across two Availability Zones and one NAT Gateway to reduce lab costs. The single NAT Gateway is a cost-saving trade-off and is not fully Availability Zone resilient.

# 3. Technology Stack

- Linux / Ubuntu on WSL2
- Python
- Docker
- Docker Compose
- Jenkins
- AWS EC2
- Amazon ECR
- Application Load Balancer
- Auto Scaling Groups
- IAM
- VPC
- Security Groups
- Terraform
- Bash scripting
- Git
- GitHub

# 4. Repository Structure

```text
vm-docker-deployment-lab/
|
|-- app.py
|-- Dockerfile
|-- compose.yaml
|-- Jenkinsfile
|-- jenkins-ecr-policy.json
|-- .gitignore
|-- README.md
|
|-- scripts/
|   |
|   |-- deploy.sh
|   |-- rollback.sh
|   |-- health-check.sh
|
|-- terraform/
    |
    |-- providers.tf
    |-- variables.tf
    |-- networking.tf
    |-- security.tf
    |-- iam.tf
    |-- ecr.tf
    |-- alb.tf
    |-- autoscaling.tf
    |-- jenkins.tf
    |-- monitoring.tf
    |-- outputs.tf
```

# 5. Application Details

The project contains a lightweight Python HTTP application.

Application container port: 5000

| Endpoint | Description |
|---|---|
| `/` | Application welcome response |
| `/health` | Application health check |

The health endpoint is used to verify application availability during deployment.

# 6. Docker Deployment

## Prerequisites

- Linux / Ubuntu
- Docker Engine
- Docker Compose

## Clone the Repository

```bash
git clone https://github.com/rakeshnm27/vm-docker-deployment-lab.git

cd vm-docker-deployment-lab
```

## Build and Start the Application

```bash
docker compose up -d --build
```

## Verify Running Containers

```bash
docker ps
```

## Test Application Health

```bash
curl -i http://localhost:5003/health
```

Expected response:

```text
HTTP 200 OK
Application is healthy
```

## Test Application

```bash
curl http://localhost:5003/
```

## Stop the Application

```bash
docker compose down
```

# 7. Jenkins CI/CD Pipeline

Jenkins automates the Docker build and deployment workflow.

## Pipeline Stages

1. Checkout application source code from GitHub.
2. Validate required tools and AWS access.
3. Build the Docker image.
4. Authenticate with Amazon ECR.
5. Tag the Docker image.
6. Push the image to Amazon ECR.
7. Discover application instances through the Auto Scaling Group.
8. Connect to private EC2 instances using SSH.
9. Deploy the new Docker image.
10. Perform application health checks.

## CI/CD Workflow

```text
Developer
    |
    v
GitHub Repository
    |
    v
Jenkins Pipeline
    |
    v
Source Code Checkout
    |
    v
Docker Image Build
    |
    v
Amazon ECR Authentication
    |
    v
Push Docker Image to ECR
    |
    v
Discover ASG Instances
    |
    v
Deregister Instance from ALB
    |
    v
SSH into Application EC2
    |
    v
Pull New Docker Image
    |
    v
Run Application Container
    |
    v
Health Check
    |
    +---- SUCCESS ----> Register Target with ALB
    |
    +---- FAILURE ----> Attempt Rollback
```

Jenkins SSH credentials are intended to be stored securely using the Jenkins Credentials store.

AWS credentials and private SSH keys must never be committed to GitHub.

# 8. Deployment Automation

The `scripts/` directory contains the following scripts.

## deploy.sh

Responsible for:

- Discovering healthy EC2 instances in the Auto Scaling Group.
- Deregistering an instance from the ALB target group.
- Connecting to the application instance through SSH.
- Pulling the new Docker image from ECR.
- Replacing the running Docker container.
- Performing application health checks.
- Attempting rollback when deployment fails.

## rollback.sh

Responsible for:

- Retrieving the previously deployed Docker image.
- Pulling the previous image.
- Restoring the previous application container.
- Checking application health after rollback.

## health-check.sh

Responsible for:

- Checking the application's health endpoint.
- Retrying failed health checks.
- Returning success or failure based on application availability.

# 9. AWS Infrastructure Using Terraform

Terraform is used to define and provision AWS infrastructure.

The Terraform configuration is separated by resource responsibility.

| File | Responsibility |
|---|---|
| providers.tf | Terraform and AWS provider configuration |
| variables.tf | Input variables |
| networking.tf | VPC networking, subnets and NAT Gateway |
| security.tf | Security groups and traffic rules |
| iam.tf | IAM roles, policies and instance profiles |
| ecr.tf | Existing ECR repository reference |
| alb.tf | Application Load Balancer, target group and listener |
| autoscaling.tf | EC2 Launch Template and Auto Scaling Group |
| jenkins.tf | Jenkins EC2 configuration |
| monitoring.tf | CloudWatch monitoring configuration |
| outputs.tf | Infrastructure outputs |

## Terraform Commands

Navigate to the Terraform directory:

```bash
cd terraform
```

Format Terraform files:

```bash
terraform fmt -recursive
```

Initialize Terraform:

```bash
terraform init
```

Validate configuration:

```bash
terraform validate
```

Generate an execution plan:

```bash
terraform plan
```

Review the planned resources and estimated AWS costs before applying changes.

Do not execute `terraform apply` without reviewing the plan and explicitly approving the AWS costs.

# 10. Security Considerations

- Use IAM instance profiles instead of embedding AWS access keys.
- Maintain separate IAM roles for Jenkins and application EC2 instances.
- Store SSH private keys securely in Jenkins Credentials.
- Keep application instances in private subnets.
- Allow application traffic only from the ALB security group.
- Restrict SSH access to the Jenkins security group.
- Require IMDSv2 for EC2 instances.
- Encrypt EBS volumes.
- Exclude Terraform state, plans, private keys and secret variable files from Git.

# 11. Project Testing and Validation

The following table distinguishes completed local testing from planned AWS implementation.

| Component | Current Status |
|---|---|
| Python application | Running locally |
| Docker image | Built and running locally |
| Docker Compose | Running locally |
| Application health endpoint | HTTP 200 verified |
| Jenkins container | Running locally |
| Jenkins pipeline | Previously exercised in the lab |
| Terraform formatting | Completed |
| Terraform validation | Passed |
| AWS Terraform plan | Generated and reviewed |
| AWS infrastructure deployment | Pending |
| ALB and ASG testing | Pending |
| End-to-end private EC2 deployment | Pending |
| AWS rollback testing | Pending |

**Implementation note:** The AWS architecture is currently represented through Terraform configuration and a reviewed execution plan. It has not yet been applied and end-to-end tested. The AWS deployment workflow must not be described as production-deployed or fully validated until implementation and testing are completed.

# 12. Future Improvements

- Complete AWS infrastructure deployment and testing.
- Validate rolling deployments and rollback under failure conditions.
- Configure HTTPS using AWS Certificate Manager.
- Improve deployment concurrency and minimum healthy capacity checks.
- Complete CloudWatch application log collection.
- Review IAM policies using least privilege.
- Evaluate multi-AZ NAT architecture for higher availability.

# 13. Author

GitHub Profile:

https://github.com/rakeshnm27/

Project Repository:

https://github.com/rakeshnm27/vm-docker-deployment-lab
