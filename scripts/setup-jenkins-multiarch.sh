# setup-jenkins-multiarch.sh - Run this on your Jenkins pod

echo "🐳 Setting up Jenkins for Multi-Architecture Docker Builds"

# Get Jenkins pod name
JENKINS_POD=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')

echo "📦 Jenkins Pod: $JENKINS_POD"

# Install Docker Buildx in Jenkins container
kubectl exec -it $JENKINS_POD -n jenkins -- bash -c "
    echo '🔧 Installing Docker Buildx support...'
    
    # Enable experimental Docker features
    mkdir -p ~/.docker
    cat > ~/.docker/config.json << 'EOF'
{
    \"experimental\": \"enabled\"
}
EOF
    
    # Install QEMU for cross-platform builds
    docker run --privileged --rm tonistiigi/binfmt --install all
    
    # Create buildx builder
    docker buildx create --name multiarch-builder --use
    docker buildx inspect --bootstrap
    
    # Verify multi-arch support
    docker buildx ls
    
    echo '✅ Multi-architecture Docker build support enabled!'
"

echo "🔧 Configuring Jenkins for Docker..."

# Update Jenkins deployment to mount Docker socket and enable privileged mode
kubectl patch deployment jenkins -n jenkins -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "jenkins",
            "securityContext": {
              "privileged": true
            },
            "volumeMounts": [
              {
                "name": "jenkins-home",
                "mountPath": "/var/jenkins_home"
              },
              {
                "name": "docker-sock",
                "mountPath": "/var/run/docker.sock"
              }
            ]
          }
        ],
        "volumes": [
          {
            "name": "jenkins-home",
            "persistentVolumeClaim": {
              "claimName": "jenkins-pvc"
            }
          },
          {
            "name": "docker-sock",
            "hostPath": {
              "path": "/var/run/docker.sock"
            }
          }
        ]
      }
    }
  }
}'

echo "⏳ Waiting for Jenkins to restart..."
kubectl rollout status deployment/jenkins -n jenkins

echo "✅ Jenkins multi-architecture Docker support configured!"