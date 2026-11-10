
pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        AWS_REGION = 'ap-south-1'

        ECR_REPOSITORY = 'vm-docker-deployment-lab'
        ASG_NAME = 'vm-docker-lab-asg'
        TARGET_GROUP_NAME = 'vm-docker-lab-tg'

        IMAGE_NAME = 'vm-docker-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate EC2 Jenkins Environment') {
            steps {
                sh '''
                    set -e

                    echo "Jenkins execution host:"
                    hostname

                    echo "Jenkins user:"
                    whoami

                    echo "AWS identity:"
                    aws sts get-caller-identity

                    docker --version
                    aws --version
                    ssh -V

                    echo "Checking ECR repository..."
                    aws ecr describe-repositories \
                      --repository-names "$ECR_REPOSITORY" \
                      --region "$AWS_DEFAULT_REGION"

                    echo "Environment validation successful."
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    set -e
                    docker build -t "$IMAGE_NAME:$IMAGE_TAG" .
                    echo "Docker build successful."
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    set -e
                    set +x

                    ACCOUNT_ID=$(aws sts get-caller-identity \
                      --query Account --output text)

                    ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
                    ECR_URI="$ECR_REGISTRY/$ECR_REPOSITORY"

                    aws ecr get-login-password \
                      --region "$AWS_DEFAULT_REGION" |
                      docker login \
                        --username AWS \
                        --password-stdin "$ECR_REGISTRY"

                    docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ECR_URI:$IMAGE_TAG"
                    docker push "$ECR_URI:$IMAGE_TAG"

                    echo "Image pushed: $ECR_URI:$IMAGE_TAG"
                '''
            }
        }

        stage('Rolling Deployment') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'aws-ec2-ssh',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        set -e

                        ACCOUNT_ID=$(aws sts get-caller-identity \
                          --query Account --output text)

                        ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
                        ECR_IMAGE="$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"

                        TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
                          --names "$TARGET_GROUP_NAME" \
                          --region "$AWS_DEFAULT_REGION" \
                          --query 'TargetGroups[0].TargetGroupArn' \
                          --output text)

                        export AWS_DEFAULT_REGION
                        export ASG_NAME
                        export TARGET_GROUP_ARN
                        export ECR_REGISTRY
                        export ECR_IMAGE
                        export SSH_KEY
                        export SSH_USER

                        chmod +x scripts/deploy.sh scripts/rollback.sh

                        echo "Starting rolling deployment..."
                        bash ./scripts/deploy.sh
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Deployment successful. Image tag: ${BUILD_NUMBER}"
        }

        failure {
            echo "Deployment failed. Check console output."
        }

        always {
            echo "Pipeline execution completed."
        }
    }
}

