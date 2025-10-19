pipeline {
  agent any 
  environment {
    AWS_REGION   = 'us-east-2'
    EKS_CLUSTER  = 'mern-app-cluster'

    ECR_BACKEND  = '577999460012.dkr.ecr.us-east-2.amazonaws.com/mern-backend'
    ECR_FRONTEND = '577999460012.dkr.ecr.us-east-2.amazonaws.com/mern-frontend'
    DOCKER_HOST = 'tcp://localhost:2375'
  }
  options { timestamps() }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Tag Image') {
      steps {
        script {
          // Short git SHA; fallback if GIT_COMMIT missing
          def sha = powershell(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.IMAGE_TAG = sha ?: "local-${env.BUILD_NUMBER}"
          echo "IMAGE_TAG=${env.IMAGE_TAG}"
        }
      }
    }

stage('Login to ECR') {
  steps {
    withAWS(credentials: 'aws-creds', region: "${env.AWS_REGION}") {
      powershell '''
        $ErrorActionPreference = "Stop"
        $acct = (aws sts get-caller-identity --query Account --output text)
        $registry = "$acct.dkr.ecr.${Env:AWS_REGION}.amazonaws.com"

        $pass = aws ecr get-login-password --region $Env:AWS_REGION
        if (-not $pass) { throw "Empty ECR login password" }

        docker logout $registry 2>$null | Out-Null
        docker login $registry -u AWS -p $pass
      '''
    }
  }
}


    stage('Build Backend Image') {
      steps {
        dir('API-jokes') {
          powershell '''
            docker build -t ${Env:ECR_BACKEND}:${Env:IMAGE_TAG} -t ${Env:ECR_BACKEND}:latest .
          '''
        }
      }
    }

stage('Build Frontend Image') {
  steps {
    dir('react-client') {
      powershell '''
        docker build -f Dockerfile.prod -t ${Env:ECR_FRONTEND}:${Env:IMAGE_TAG} -t ${Env:ECR_FRONTEND}:latest .
      '''
    }
  }
}

    stage('Push Images') {
      steps {
        powershell '''
          docker push ${Env:ECR_BACKEND}:${Env:IMAGE_TAG}
          docker push ${Env:ECR_BACKEND}:latest
          docker push ${Env:ECR_FRONTEND}:${Env:IMAGE_TAG}
          docker push ${Env:ECR_FRONTEND}:latest
        '''
      }
    }

    stage('Configure kubectl') {
      steps {
        withAWS(credentials: 'aws-creds', region: "${env.AWS_REGION}") {
          powershell '''
            aws eks update-kubeconfig --name ${Env:EKS_CLUSTER} --region ${Env:AWS_REGION}
            kubectl get nodes
            kubectl create namespace mern-ns --dry-run=client -o yaml | kubectl apply -f -
          '''
        }
      }
    }

    stage('Deploy Backend (Helm)') {
      steps {
        dir('K8s-helm/backend') {
          powershell '''
            helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>$null
            helm repo update
            helm upgrade --install backend . -n mern-ns `
              --set container.image=${Env:ECR_BACKEND}:${Env:IMAGE_TAG} `
              --set container.port=5000 `
              --wait --timeout 300s
          '''
        }
      }
    }

    stage('Deploy Frontend (Helm)') {
      steps {
        dir('K8s-helm/frontend') {
          powershell '''
            helm upgrade --install frontend . -n mern-ns `
              --set container.image=${Env:ECR_FRONTEND}:${Env:IMAGE_TAG} `
              --set container.port=80 `
              --wait --timeout 300s
          '''
        }
      }
    }

    stage('Check') {
      steps {
        powershell 'kubectl -n mern-ns get pods,svc,ing'
      }
    }
  }

  post {
    always {
      powershell 'docker image prune -f'
    }
  }
}
