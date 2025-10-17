pipeline {
  agent any
  environment {
    AWS_REGION   = 'us-east-2'
    EKS_CLUSTER  = 'mern-app-cluster'
    // Fill with terraform output (Account ID will be yours)
    ECR_BACKEND  = '577999460012.dkr.ecr.us-east-2.amazonaws.com/mern-backend'
    ECR_FRONTEND = '577999460012.dkr.ecr.us-east-2.amazonaws.com/mern-frontend'
    COMMIT_SHA = "${env.GIT_COMMIT}".take(7)
    IMAGE_TAG  = "${COMMIT_SHA}"
  }

  stages {
    stage('Checkout') { steps { checkout scm } }

    stage('Login to ECR') {
      steps {
        sh '''
          aws ecr get-login-password --region $AWS_REGION \
          | docker login --username AWS --password-stdin ${ECR_BACKEND%/mern-backend}
        '''
      }
    }

    stage('Build Backend') {
      steps {
        dir('API-jokes') {
          sh 'docker build -t $ECR_BACKEND:$IMAGE_TAG -t $ECR_BACKEND:latest .'
        }
      }
    }

    stage('Build Frontend') {
      steps {
        dir('react-client') {
          // If you don’t have a Dockerfile here, create a 2-stage (node build -> nginx serve)
          sh 'docker build -t $ECR_FRONTEND:$IMAGE_TAG -t $ECR_FRONTEND:latest .'
        }
      }
    }

    stage('Push Images') {
      steps {
        sh '''
          docker push $ECR_BACKEND:$IMAGE_TAG
          docker push $ECR_BACKEND:latest
          docker push $ECR_FRONTEND:$IMAGE_TAG
          docker push $ECR_FRONTEND:latest
        '''
      }
    }

    stage('Kubeconfig') {
      steps {
        sh '''
          aws eks update-kubeconfig --name $EKS_CLUSTER --region $AWS_REGION
          kubectl get nodes
          kubectl create namespace mern-ns || true
        '''
      }
    }

    stage('Deploy Backend (Helm)') {
      steps {
        dir('K8s-helm/backend') {
          sh '''
            helm upgrade --install backend . -n mern-ns \
              --set name=mern-backend \
              --set namespace=mern-ns \
              --set container.image=$ECR_BACKEND:$IMAGE_TAG \
              --set container.port=5000 \
              --wait --timeout 300s
          '''
        }
      }
    }

    stage('Deploy Frontend (Helm)') {
      steps {
        dir('K8s-helm/frontend') {
          sh '''
            helm upgrade --install frontend . -n mern-ns \
              --set name=mern-frontend \
              --set namespace=mern-ns \
              --set container.image=$ECR_FRONTEND:$IMAGE_TAG \
              --set container.port=80 \
              --wait --timeout 300s
          '''
        }
      }
    }

    stage('Check') {
      steps {
        sh '''
          kubectl get pods,svc,ing -n mern-ns
        '''
      }
    }
  }

  post {
    always { sh 'docker image prune -f || true' }
  }
}