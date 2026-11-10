
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

        stage('Validate Tools and AWS Access') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-ecr-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        set -e
                        command -v docker
                        command -v aws
                        command -v ssh

                        echo "Checking AWS identity..."
                        aws sts get-caller-identity

                        echo "Checking ECR repository..."
                        aws ecr describe-repositories \
                            --repository-names "$ECR_REPOSITORY" \
                            --region "$AWS_DEFAULT_REGION"

                        echo "AWS validation successful."
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    set -e
                    docker build -t "$IMAGE_NAME:$IMAGE_TAG" .
                    echo "Image built: $IMAGE_NAME:$IMAGE_TAG"
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-ecr-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''
                        set -e
                        set +x

                        ACCOUNT_ID=$(aws sts get-caller-identity \
                            --query Account --output text)

                        ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
                        ECR_URI="$ECR_REGISTRY/$ECR_REPOSITORY"

                        aws ecr get-login-password \
                            --region "$AWS_DEFAULT_REGION" |
                            docker login --username AWS --password-stdin "$ECR_REGISTRY"

                        docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ECR_URI:$IMAGE_TAG"
                        docker push "$ECR_URI:$IMAGE_TAG"

                        echo "Successfully pushed $ECR_URI:$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('Rolling Deployment to ASG') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-ecr-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
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
                            ECR_URI="$ECR_REGISTRY/$ECR_REPOSITORY"

                            TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
                                --names "$TARGET_GROUP_NAME" \
                                --region "$AWS_DEFAULT_REGION" \
                                --query 'TargetGroups[0].TargetGroupArn' \
                                --output text)

                            if [ -z "$TARGET_GROUP_ARN" ] || \
                               [ "$TARGET_GROUP_ARN" = "None" ]; then
                                echo "ERROR: Target group not found."
                                exit 1
                            fi

                            export AWS_DEFAULT_REGION
                            export ASG_NAME
                            export TARGET_GROUP_ARN
                            export ECR_REGISTRY
                            export ECR_IMAGE="$ECR_URI:$IMAGE_TAG"
                            export SSH_USER
                            export SSH_KEY

                            chmod +x scripts/deploy.sh
                            chmod +x scripts/rollback.sh

                            echo "Starting rolling deployment..."

                            # Explicitly execute the deployment script with Bash.
                            bash ./scripts/deploy.sh
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Rolling deployment completed. Image tag: ${BUILD_NUMBER}"
        }

        failure {
            echo 'Pipeline failed. Check Jenkins Console Output and deployment logs.'
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}

