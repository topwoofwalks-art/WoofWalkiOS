#!/bin/bash

echo "========================================="
echo "WoofWalk iOS - Firebase Setup"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Firebase project details (from Android)
PROJECT_ID="woofwalk-e0231"
BUNDLE_ID="com.woofwalk.ios"
APP_NAME="WoofWalk iOS"

echo -e "${YELLOW}Step 1: Checking Firebase CLI...${NC}"
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}Firebase CLI not installed!${NC}"
    echo "Install with: npm install -g firebase-tools"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI found${NC}"
echo ""

echo -e "${YELLOW}Step 2: Checking authentication...${NC}"
if ! firebase projects:list > /dev/null 2>&1; then
    echo -e "${YELLOW}Not logged in. Running firebase login...${NC}"
    firebase login
    if [ $? -ne 0 ]; then
        echo -e "${RED}Login failed!${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Authenticated${NC}"
echo ""

echo -e "${YELLOW}Step 3: Checking if iOS app already exists...${NC}"
EXISTING_APP=$(firebase apps:list --project $PROJECT_ID 2>&1 | grep -i "$BUNDLE_ID" || true)
if [ -n "$EXISTING_APP" ]; then
    echo -e "${GREEN}✓ iOS app already registered!${NC}"
    echo ""
    echo -e "${YELLOW}Step 4: Downloading GoogleService-Info.plist...${NC}"

    # Get the app ID from the list
    APP_ID=$(firebase apps:list --project $PROJECT_ID 2>&1 | grep -i "$BUNDLE_ID" | awk '{print $4}' | head -1)

    if [ -z "$APP_ID" ]; then
        echo -e "${RED}Could not find app ID. Download manually from:${NC}"
        echo "https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
    else
        echo "Attempting to download config for app: $APP_ID"
        firebase apps:sdkconfig ios "$APP_ID" --project $PROJECT_ID > WoofWalk/GoogleService-Info.plist 2>&1

        if [ -f "WoofWalk/GoogleService-Info.plist" ]; then
            echo -e "${GREEN}✓ GoogleService-Info.plist downloaded${NC}"
        else
            echo -e "${YELLOW}Download failed. Manual download required:${NC}"
            echo "https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
        fi
    fi
else
    echo -e "${YELLOW}No iOS app found. Creating iOS app...${NC}"

    # Create iOS app
    firebase apps:create --project $PROJECT_ID ios "$BUNDLE_ID" --display-name "$APP_NAME"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ iOS app created${NC}"
        echo ""
        echo -e "${YELLOW}Step 4: Downloading GoogleService-Info.plist...${NC}"

        # Wait a moment for app to be fully created
        sleep 2

        # Get the newly created app ID
        APP_ID=$(firebase apps:list --project $PROJECT_ID 2>&1 | grep -i "$BUNDLE_ID" | awk '{print $4}' | head -1)

        if [ -n "$APP_ID" ]; then
            firebase apps:sdkconfig ios "$APP_ID" --project $PROJECT_ID > WoofWalk/GoogleService-Info.plist 2>&1

            if [ -f "WoofWalk/GoogleService-Info.plist" ]; then
                echo -e "${GREEN}✓ GoogleService-Info.plist downloaded${NC}"
            else
                echo -e "${YELLOW}Download failed. Manual download from:${NC}"
                echo "https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
            fi
        else
            echo -e "${YELLOW}Download manually from:${NC}"
            echo "https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
        fi
    else
        echo -e "${RED}Failed to create iOS app${NC}"
        echo "Try manually at: https://console.firebase.google.com/project/$PROJECT_ID/overview"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}Step 5: Installing CocoaPods dependencies...${NC}"
if command -v pod &> /dev/null; then
    pod install
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ CocoaPods installed${NC}"
    else
        echo -e "${RED}Pod install failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}CocoaPods not installed!${NC}"
    echo "Install with: sudo gem install cocoapods"
    exit 1
fi

echo ""
echo "========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Open WoofWalk.xcworkspace (NOT .xcodeproj)"
echo "2. In Xcode: Select target → Signing & Capabilities"
echo "3. Select your development team"
echo "4. Build and run on simulator or device"
echo ""
echo "Files created:"
echo "  ✓ WoofWalk/secrets.plist (Google Maps key)"
if [ -f "WoofWalk/GoogleService-Info.plist" ]; then
    echo "  ✓ WoofWalk/GoogleService-Info.plist (Firebase config)"
else
    echo "  ⚠ WoofWalk/GoogleService-Info.plist (download manually)"
fi
echo "  ✓ Pods/ (CocoaPods dependencies)"
echo ""
