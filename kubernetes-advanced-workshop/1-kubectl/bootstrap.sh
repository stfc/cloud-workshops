#!/bin/bash

set -euo pipefail


# Simple K8s Setup for Ubuntu
# Installs Docker, kubectl, and Minikube

echo "Kubernetes Setup Starting..."

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Please do not run this script as root. It will use sudo when needed."
    exit 1
fi

# Install Docker
echo ""
echo "Installing Docker..."
if command -v docker >/dev/null 2>&1; then
    echo "Docker already installed"
else
    # Add Docker's official GPG key:
    sudo apt -y update
    sudo apt -y install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt -y update
    sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker "$USER"

    echo "Docker installed"
fi

# Install kubectl
echo ""
echo "Installing kubectl..."
if command -v kubectl >/dev/null 2>&1; then
    echo "kubectl already installed"
else
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo "kubectl installed"
fi

# Install Minikube
echo ""
echo "Installing Minikube..."
if command -v minikube >/dev/null 2>&1; then
    echo -e "Minikube already installed"
else
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
    echo "Minikube installed"
fi

# Verify installations
echo ""
echo "Installed versions:"
docker --version
kubectl version --client --short 2>/dev/null || kubectl version --client
minikube version --short

echo ""
echo -e "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Log out and back in for Docker group changes to take effect"
echo "  2. Start Minikube with: minikube start"
echo "  3. Verify with: kubectl cluster-info"
echo "Once ready, continue with the workshop"