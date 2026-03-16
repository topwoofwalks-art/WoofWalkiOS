#!/bin/bash

echo "========================================="
echo "Docker-OSX Setup for WoofWalk iOS Testing"
echo "========================================="
echo ""
echo "⚠️  DISCLAIMER: This setup runs macOS on non-Apple hardware,"
echo "which violates Apple's EULA. Use for personal testing only."
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}Step 1: Adding user to KVM group...${NC}"
sudo usermod -aG kvm $USER
echo -e "${GREEN}✓ Added to KVM group${NC}"
echo -e "${YELLOW}Note: You'll need to log out and log back in for this to take effect${NC}"

echo ""
echo -e "${YELLOW}Step 2: Installing Docker...${NC}"

# Remove old Docker versions
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install dependencies
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo -e "${GREEN}✓ Docker installed${NC}"

echo ""
echo -e "${YELLOW}Step 3: Adding user to Docker group...${NC}"
sudo usermod -aG docker $USER
echo -e "${GREEN}✓ Added to Docker group${NC}"

echo ""
echo -e "${YELLOW}Step 4: Starting Docker service...${NC}"
sudo service docker start
echo -e "${GREEN}✓ Docker started${NC}"

echo ""
echo -e "${YELLOW}Step 5: Testing Docker...${NC}"
sudo docker run hello-world
echo -e "${GREEN}✓ Docker works!${NC}"

echo ""
echo -e "${YELLOW}Step 6: Installing QEMU and dependencies...${NC}"
sudo apt-get install -y qemu-system-x86 qemu-utils
echo -e "${GREEN}✓ QEMU installed${NC}"

echo ""
echo "========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "========================================="
echo ""
echo "⚠️  IMPORTANT: You MUST log out and log back in for group changes to take effect!"
echo ""
echo "After logging back in, run:"
echo "  cd /mnt/c/app/WoofWalkiOS"
echo "  ./run-macos.sh"
echo ""
echo "This will download and start macOS (~20GB download)."
echo ""
