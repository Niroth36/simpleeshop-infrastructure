#!/bin/bash
# setup-from-repos.sh - Deploy everything from the 3 repositories

set -e

echo "🚀 Setting up SimpleEshop from Multi-Repository Structure"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Step 1: Clone Infrastructure Repository
print_header "Cloning Infrastructure Repository"
if [ -d "simpleeshop-infrastructure" ]; then
    print_warning "Infrastructure repo already exists, pulling latest..."
    cd simpleeshop-infrastructure
    git pull origin main
    cd ..
else
    git clone https://github.com/Niroth36/simpleeshop-infrastructure.git
fi

# Step 2: Deploy Infrastructure
print_header "Deploying Kubernetes Infrastructure"
cd simpleeshop-infrastructure/kubernetes

# Update the ArgoCD applications to point to GitOps repo
print_status "Updating ArgoCD applications to point to GitOps repository..."

# Apply all infrastructure
print_status "Deploying namespaces..."
kubectl apply -f namespaces/

print_status "Deploying Jenkins..."
kubectl apply -f jenkins/

print_status "Deploying ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

print_status "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

print_status "Configuring ArgoCD NodePort service..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "targetPort": 8080, "nodePort": 30443, "name": "https"}]}}'

# Apply ArgoCD applications that will pull from GitOps repo
print_status "Deploying ArgoCD Applications (pointing to GitOps repo)..."
kubectl apply -f argocd/applications/

cd ../..

# Step 3: Wait for everything to be ready
print_header "Waiting for All Services to be Ready"

print_status "Waiting for Jenkins..."
kubectl wait --for=condition=available --timeout=300s deployment/jenkins -n jenkins

print_status "Waiting for ArgoCD to sync applications..."
sleep 30  # Give ArgoCD time to sync

# Step 4: Display access information
print_header "🎉 Setup Complete! Access Information"

# Get Jenkins password
JENKINS_POD=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
JENKINS_PASSWORD=$(kubectl exec -it $JENKINS_POD -n jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null | tr -d '\r\n')

# Get ArgoCD password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Not available")

# Get external IP
EXTERNAL_IP=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|.*://||' | sed 's|:.*||')

echo ""
echo "📱 Application URLs:"
echo "   SimpleEshop:  http://$EXTERNAL_IP:30000"
echo "   Jenkins:      http://$EXTERNAL_IP:30080"
echo "   ArgoCD:       https://$EXTERNAL_IP:30443"

echo ""
echo "🔐 Credentials:"
echo "   Jenkins:"
echo "     Username: admin"
echo "     Password: $JENKINS_PASSWORD"
echo ""
echo "   ArgoCD:"
echo "     Username: admin"
echo "     Password: $ARGOCD_PASSWORD"

echo ""
echo "📊 Status Check:"
kubectl get pods -A | grep -E "(simpleeshop|jenkins|argocd)" | head -20

echo ""
print_status "🎯 Next Steps:"
echo "1. Configure Jenkins credentials (Docker Hub + GitHub)"
echo "2. Create Jenkins pipeline job pointing to: https://github.com/Niroth36/simpleeshop-app.git"
echo "3. Enable Jenkins Docker BuildKit for multi-arch builds"
echo "4. Test the CI/CD pipeline by pushing to the app repository"

echo ""
print_status "Setup completed successfully! 🎉"