pipelien {
    agent any
    tools{
        ansible 'ansible'
        terraform 'terraform'
    }

    environment {
            AWS_DEFAULT_REGION = 'us-east-1'
            AWS_ACCOUNT_ID=sh(script:'export PATH="$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
            ECR_REPOSITORY_ID="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
            APP_REPO_NAME = ""
            APP_NAME = "unitodo"
    }

    stages{
        stage('Create Tf '){
            steps{
                echo 'Create Tf on AWS'
                sh 'terraform init'
                sh 'terraform apply --auto-approve'
                
            }
        }

        stage('ECR Repo') {
            steps{
                echo 'Creating ECR repository'
                sh '''
                aws ecr create-repository --region $(AWS_REGION) --repository-name $ECR_REPOSITORY_NAME || \
                aws ecr create-repository \
                   --repository-name $APP_REPO_NAME 
                   --image-scanning-configuration scanOnPush=false \
                   --region $(AWS_REGION)
                   --image-tag-mutability MUTABLE 
                ''',   

        }
        stage("Build Image"){
            steps{
                echo 'Building Docker image'
                script {
                    env.NODE_IP = sh(script: 'terraform output -raw node_public_ip', returnStdout:true).trim()
                    env.DB_HOST = sh(script: 'terraform output -raw postgre_private_ip', returnStdout:true).trim()
                    env.DB_NAME = sh(script: 'aws --region=us-east-1 ssm get-parameters --names "db_name" --query "Parameters[*].{Value:Value}" --output text', returnStdout:true).trim()
                    env.DB_PASSWORD = sh(script: 'aws --region=us-east-1 ssm get-parameters --names "db_password" --query "Parameters[*].{Value:Value}" --output text', returnStdout:true).trim()
                }
                sh 'echo ${DB_HOST}'
                sh 'echo ${NODE_IP}'
                sh 'echo ${DB_NAME}'
                sh 'echo ${DB_PASSWORD}'
                // Substitute environment variables into template files
                sh 'envsubst < node-env-template > ./nodejs/server/.env'
                sh 'cat ./nodejs/server/.env'
                sh 'envsubst < react-env-template > ./react/client/.env'
                sh 'cat ./react/client/.env'
                // Build Docker images for different components
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:postgre" -f ./postgresql/dockerfile-postgresql .'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:nodejs" -f ./nodejs/dockerfile-nodejs .'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:react" -f ./react/dockerfile-react .'
                sh 'docker image ls'
            }
        }
        stage('Push Image to ECR Repo') {
            steps {
                echo 'Pushing App Image to ECR Repo'
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:postgre"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:nodejs"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:react"'
            }
        }
        stage('wait the instance') {
            steps {
                script {
                    echo 'Waiting for the instance'
                    id = sh(script: 'aws ec2 describe-instances --filters Name=tag-value,Values=ansible_postgresql Name=instance-state-name,Values=running --query Reservations[*].Instances[*].[InstanceId] --output text',  returnStdout:true).trim()
                    sh 'aws ec2 wait instance-status-ok --instance-ids $id'
                }
            }
        }
        stage('Deploy the App') {
            steps {
                echo 'Deploy the App'
                sh 'ls -l'
                sh 'ansible --version'
                sh 'ansible-inventory --graph'
                ansiblePlaybook credentialsId: '', disableHostKeyChecking: true, installation: 'ansible', inventory: 'inventory_aws_ec2.yml', playbook: 'docker_project.yml'
            }
        }
        stage('Destroy the infrastructure') {
            steps{
                timeout(time:5, unit:'DAYS') {
                    input message: 'accept terminate'
                }
                echo "Terminate EC2 Instance..."
                sh '''
                docker image prune -af
                terraform destroy --auto-approve
                aws ecr delete-repository \
                   --repository-name ${APP_REPO_NAME} \
                   --region ${AWS_REGION} \
                   --force
                '''   
            }
        }
    }
    
}