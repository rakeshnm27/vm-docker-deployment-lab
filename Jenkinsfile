pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
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
                sh 'curl -f http://localhost:5004/health'
            }
        }
    }
}
