#!/bin/bash
# Deploy complete infrastructure

echo "🚀 Deploying SimpleEshop Infrastructure..."

# Deploy Terraform infrastructure
echo "📦 Deploying Azure infrastructure..."
cd terraform/
terraform init
terraform plan
terraform apply -auto-approve
cd ..

# Deploy Kubernetes base components
echo "☸️ Deploying Kubernetes infrastructure..."
cd kubernetes/
./scripts/deploy-all.sh
cd ..

echo "✅ Infrastructure deployment complete!"
