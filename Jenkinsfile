
pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        ECR_URI = '743702012398.dkr.ecr.ap-south-1.amazonaws.com/vm-docker-deployment-lab'
        LOCAL_IMAGE = 'vm-docker-app:1.2'
        ECR_IMAGE = '743702012398.dkr.ecr.ap-south-1.amazonaws.com/vm-docker-deployment-lab:1.2'
        CONTAINER_NAME = 'vm-docker-jenkins'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $LOCAL_IMAGE .'
            }
        }

        stage('Verify Docker Image') {
            steps {
                sh 'docker images vm-docker-app'
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
                    docker tag "$LOCAL_IMAGE" "$ECR_IMAGE"

                    docker push "$ECR_IMAGE"

                    echo "Docker image pushed to Amazon ECR"
                '''
            }
        }

        stage('Deploy Application from ECR') {
            steps {
                sh '''
                    docker pull "$ECR_IMAGE"

                    docker rm -f "$CONTAINER_NAME" || true

                    docker run -d \
                      --name "$CONTAINER_NAME" \
                      --restart unless-stopped \
                      -p 5004:5000 \
                      "$ECR_IMAGE"

                    echo "Application deployed from Amazon ECR"
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
            echo 'Deployment completed successfully!'
        }

        failure {
            echo 'Pipeline failed. Check Console Output.'
        }
    }
}

