pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                echo 'Source code checkout completed'
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
                sh 'docker compose up -d --build'
            }
        }

        stage('Health Check') {
            steps {
                sh 'curl -f http://localhost:5003/health'
            }
        }
    }
}
