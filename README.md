# K8Networking  ---> app.mldevops.org hosted in Route53 and built on AWS EKS, this frontend client reactjs and backend api with Altas Mongo db for testing stateful session in Kubernetes Cluster.
Below are the steps for Building infrastructure for CI/CD setup.


1) Infra: EKS on existing VPC + public subnets

Confirm VPC + two public subnets (in different AZs).

Create/prepare Terraform variables for: region, cluster_name, existing_vpc_id, public_subnet_ids, admin_principal_arn.

Init/apply:

cd IAC
terraform init
terraform apply


(Optional) Create ECR repos via TF (frontend/backed) or in console.

2) kubectl access (Windows)
aws eks update-kubeconfig --name mern-app-cluster --region us-east-2
kubectl get nodes

3) Install ingress controller (one-time)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
  -n ingress-nginx --create-namespace
kubectl -n ingress-nginx get svc ingress-nginx-controller


Note the ELB hostname from that Service.

4) Jenkins 

Install Jenkins LTS.

Install plugins: Git, Pipeline, Amazon ECR, AWS Credentials, GitHub, Blue Ocean (optional).

Global tools: Git, JDK (if needed).

Credentials:

github-ssh (SSH key for repo).

aws-creds (Access key for the AWS account with ECR/EKS permissions).

Docker Desktop:

Enable “Expose daemon on tcp://localhost:2375 without TLS”.

GitHub → Webhooks: point to http://<jenkins-host>:8080/github-webhook/.

5) Jenkins job (Multibranch or Pipeline)

Source: your GitHub repo with the Jenkinsfile.

Build Trigger: GitHub hook trigger for GITScm polling.

Confirm a push starts the job (“Started by GitHub push …”).

6) CI stages (what happens)

Checkout → Tag (short SHA).

Login to ECR:

aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin <acct>.dkr.ecr.us-east-2.amazonaws.com


Build + push images:

# Backend
docker build -t <acct>.dkr.ecr.us-east-2.amazonaws.com/mern-backend:<TAG> -t <...>:latest ./API-jokes
docker push <...>/mern-backend:<TAG>
docker push <...>/mern-backend:latest

# Frontend (Dockerfile.prod → NGINX on :80)
docker build -f Dockerfile.prod -t <acct>.dkr.ecr.us-east-2.amazonaws.com/mern-frontend:<TAG> -t <...>:latest ./react-client
docker push <...>/mern-frontend:<TAG>
docker push <...>/mern-frontend:latest


kubectl context for the pipeline:

aws eks update-kubeconfig --name mern-app-cluster --region us-east-2
kubectl get nodes
kubectl create namespace mern-ns --dry-run=client -o yaml | kubectl apply -f -

7) K8s app deploys (via Helm)

Backend:

helm upgrade --install backend ./K8s-helm/backend -n mern-ns `
  --set container.image=<ECR_BACKEND>:<TAG> `
  --set container.port=5000 `
  --atomic --timeout 10m


Frontend:

helm upgrade --install frontend ./K8s-helm/frontend -n mern-ns `
  --set container.image=<ECR_FRONTEND>:<TAG> `
  --set container.port=80 `
  --atomic --timeout 10m


On a single node: switch backend strategy to Recreate (one-time patch if needed):

kubectl -n mern-ns patch deploy mern-backend -p '{"spec":{"strategy":{"type":"Recreate"}}}'

8) Ingress for app

Deploy your ingress chart (simple host + two paths):

helm upgrade --install mern-ingress ./K8s-helm/ingress -n mern-ns -f ./K8s-helm/ingress/values.yaml
kubectl -n mern-ns get ing -o wide


Route53 → A (alias) record: app.mldevops.org → the ELB hostname from ingress-nginx-controller.

9) TLS with cert-manager (Let’s Encrypt)

Install cert-manager:

helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager `
  -n cert-manager --create-namespace --set installCRDs=true
kubectl -n cert-manager get pods


Apply ClusterIssuers (staging + prod):

kubectl apply -f ./K8s-helm/clusterissuers.yaml
kubectl get clusterissuer


Annotate Ingress for prod issuer and enable TLS (done in values).

Redeploy ingress chart:

helm upgrade --install mern-ingress ./K8s-helm/ingress -n mern-ns -f ./K8s-helm/ingress/values.yaml


Watch issuance:

kubectl -n mern-ns get certificate
kubectl -n mern-ns describe certificate app-mern-tls
kubectl -n mern-ns get secret app-mern-tls

10) Sanity checks / day-2 ops
# App state
kubectl -n mern-ns get pods,svc,ing -o wide
kubectl -n mern-ns rollout status deploy/mern-backend --timeout=600s
kubectl -n mern-ns rollout status deploy/mern-frontend --timeout=600s

# Endpoints wired?
kubectl -n mern-ns get endpoints backend-service frontend-service

# Ingress controller logs
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=100

# TLS chain (optional)
curl -I https://app.mldevops.org/

11) Resource tuning (t3.medium, 1 node)

Backend (start): requests 250m/256Mi, limits 1/1Gi.

Frontend (start): requests 50m/128Mi, limits 300m/256Mi.

Verify:

kubectl describe node $(kubectl get nodes -o name)
# If metrics-server installed:
kubectl top pods -A

12) Common fixes

Pending new backend pod on single node → ensure Recreate strategy.

ELB URL works, domain doesn’t → Route53 alias target mismatch; re-check current ELB hostname.

HTTPS “Not secure” → confirm Certificate Ready=True, Ingress references the TLS secret, no mixed content.

13) Clean up (optional)
helm -n mern-ns uninstall frontend backend mern-ingress
helm -n ingress-nginx uninstall ingress-nginx
helm -n cert-manager uninstall cert-manager
kubectl delete ns mern-ns cert-manager ingress-nginx --wait=false
cd IAC
terraform destroy

