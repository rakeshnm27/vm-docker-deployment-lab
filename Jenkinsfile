
pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo 'GitHub checkout completed'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t vm-docker-app:1.2 .'
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
                    sh '''
                        set +x
                        set -o pipefail

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

        stage('Deploy Application') {
            steps {
                sh '''
                    docker rm -f vm-docker-jenkins || true

                    docker run -d \
                      --name vm-docker-jenkins \
                      --restart unless-stopped \
                      -p 5004:5000 \
                      vm-docker-app:1.2
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    for attempt in $(seq 1 10); do

                        if curl -fsS http://127.0.0.1:5004/health; then
                            echo "Health check passed"
                            exit 0
                        fi

                        echo "Attempt $attempt failed. Retrying in 2 seconds..."
                        sleep 2
                    done

                    echo "Application failed health check"
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

