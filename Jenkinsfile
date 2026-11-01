
pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        ECR_URI = '743702012398.dkr.ecr.ap-south-1.amazonaws.com/vm-docker-deployment-lab'
        IMAGE_NAME = 'vm-docker-app'
        CONTAINER_NAME = 'vm-docker-jenkins'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t "$IMAGE_NAME:$IMAGE_TAG" .
                    echo "Built image: $IMAGE_NAME:$IMAGE_TAG"
                '''
            }
        }

        stage('Verify Docker Image') {
            steps {
                sh '''
                    docker images "$IMAGE_NAME"
                '''
            }
        }

        stage('Authenticate with Amazon ECR') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-ecr-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    )
                ]) {
                    sh '''#!/bin/bash
                        set +x
                        set -eo pipefail

                        export AWS_DEFAULT_REGION=ap-south-1

                        echo "Verifying AWS identity..."
                        aws sts get-caller-identity

                        echo "Authenticating with Amazon ECR..."

                        aws ecr get-login-password \
                          --region ap-south-1 |
                        docker login \
                          --username AWS \
                          --password-stdin \
                          743702012398.dkr.ecr.ap-south-1.amazonaws.com

                        echo "ECR authentication successful"
                    '''
                }
            }
        }

        stage('Push Docker Image to ECR') {
            steps {
                sh '''
                    ECR_IMAGE="$ECR_URI:$IMAGE_TAG"

                    docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ECR_IMAGE"
                    docker push "$ECR_IMAGE"

                    echo "Pushed image: $ECR_IMAGE"
                '''
            }
        }

        stage('Deploy Application from ECR') {
            steps {
                sh '''
                    ECR_IMAGE="$ECR_URI:$IMAGE_TAG"

                    docker pull "$ECR_IMAGE"

                    docker rm -f "$CONTAINER_NAME" || true

                    docker run -d \
                      --name "$CONTAINER_NAME" \
                      --restart unless-stopped \
                      -p 5004:5000 \
                      "$ECR_IMAGE"

                    echo "Deployed image: $ECR_IMAGE"
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    for i in $(seq 1 10); do
                        if curl -fsS http://127.0.0.1:5004/health; then
                            echo "Application health check passed"
                            exit 0
                        fi

                        echo "Waiting for application..."
                        sleep 2
                    done

                    echo "Application health check failed"
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            echo "Deployment successful. Image tag: ${BUILD_NUMBER}"
        }

        failure {
            echo 'Pipeline failed. Check Console Output.'
        }
    }
}

