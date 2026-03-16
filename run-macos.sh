#!/bin/bash

echo "========================================="
echo "Docker-OSX - macOS Ventura with Xcode"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if user is in docker group
if ! groups | grep -q docker; then
    echo -e "${RED}ERROR: You're not in the docker group!${NC}"
    echo "Run: sudo usermod -aG docker \$USER"
    echo "Then log out and log back in."
    exit 1
fi

# Check if user is in kvm group
if ! groups | grep -q kvm; then
    echo -e "${RED}ERROR: You're not in the kvm group!${NC}"
    echo "Run: sudo usermod -aG kvm \$USER"
    echo "Then log out and log back in."
    exit 1
fi

# Check if /dev/kvm exists and is accessible
if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
    echo -e "${RED}ERROR: Cannot access /dev/kvm${NC}"
    echo "Make sure you've logged out and back in after adding to kvm group."
    exit 1
fi

echo -e "${YELLOW}Pulling Docker-OSX image (this will take a while - ~20GB)...${NC}"
echo "You can grab a coffee ☕ - this might take 30-60 minutes depending on your connection."
echo ""

docker pull sickcodes/docker-osx:latest

echo ""
echo -e "${GREEN}✓ Image downloaded!${NC}"
echo ""
echo -e "${YELLOW}Starting macOS Ventura...${NC}"
echo ""
echo "Once macOS boots:"
echo "  1. Complete the setup wizard (select language, region)"
echo "  2. Skip Apple ID sign-in (not needed for testing)"
echo "  3. Open Safari and download Xcode from developer.apple.com"
echo "  4. Or install Xcode Command Line Tools: xcode-select --install"
echo ""
echo "The macOS window will open shortly..."
echo ""

# Create a data directory for persistence
mkdir -p ~/docker-osx-data

# Run Docker-OSX with optimized settings
docker run -it \
    --device /dev/kvm \
    -p 50922:10022 \
    -v "${PWD}":/mnt/woofwalk \
    -v ~/docker-osx-data:/home/arch/OSX-KVM/data \
    -e "DISPLAY=${DISPLAY:-:0.0}" \
    -e CORES=4 \
    -e RAM=8192 \
    -e USERNAME=woofwalk \
    -e PASSWORD=woofwalk \
    -e GENERATE_UNIQUE=true \
    -e MASTER_PLIST_URL=https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-nopicker-custom.plist \
    sickcodes/docker-osx:latest

echo ""
echo -e "${YELLOW}macOS has stopped.${NC}"
echo ""
echo "To start it again, run: ./run-macos.sh"
echo ""
