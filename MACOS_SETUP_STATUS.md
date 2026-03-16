# macOS Docker Setup - Status Report

## ✅ Installation Complete!

All required software has been successfully installed on your WSL2 environment.

### What's Installed

**1. ✅ KVM Support**
- User `bret` added to `kvm` group
- /dev/kvm device available and accessible

**2. ✅ Docker Engine**
- Version: Docker CE 28.5.1
- Containerd: 1.7.28
- Docker Compose: 2.40.2
- Docker Buildx: 0.29.1

**3. ✅ User Permissions**
- Added to `kvm` group (hardware virtualization)
- Added to `docker` group (run containers without sudo)

**4. ✅ Docker Service**
- Service started and running
- Ready to pull and run containers

**5. ⏳ Docker-OSX Image**
- Currently downloading in background
- Image: `sickcodes/docker-osx:latest`
- Size: ~20GB (this will take 30-60 minutes)

---

## 📁 Scripts Created

### 1. `setup-macos-docker.sh`
Complete automated installation script (already executed).

### 2. `run-macos.sh`
Script to start macOS in Docker with proper settings:
- 4 CPU cores
- 8GB RAM
- KVM hardware acceleration
- Shared folder with WoofWalkiOS project

---

## ⚠️ Important: Group Changes

The user has been added to `kvm` and `docker` groups, but **you need to log out and log back in** for these changes to take effect.

### How to Refresh Groups

**Option 1: Restart WSL** (Recommended)
```cmd
# In Windows Command Prompt or PowerShell:
wsl --shutdown
# Then reopen WSL
```

**Option 2: Logout/Login**
```bash
# In WSL:
exit
# Then reopen WSL terminal
```

**Option 3: Use newgrp** (Temporary)
```bash
newgrp docker
newgrp kvm
```

---

## 🚀 Next Steps

### Step 1: Wait for Docker-OSX Download

Check download progress:
```bash
sudo docker images
```

Look for `sickcodes/docker-osx` in the list.

### Step 2: Make Scripts Executable

```bash
cd /mnt/c/app/WoofWalkiOS
chmod +x run-macos.sh setup-macos-docker.sh
```

### Step 3: Start macOS

```bash
cd /mnt/c/app/WoofWalkiOS
./run-macos.sh
```

This will:
- Launch macOS in a window (if X11 is configured)
- Or run headless (you can VNC to it)
- Share the WoofWalkiOS folder as `/mnt/woofwalk` inside macOS

### Step 4: Inside macOS

Once macOS boots (first boot takes 10-15 minutes):

1. **Complete Setup Wizard**
   - Select language and region
   - Skip Apple ID (not needed)
   - Create user account

2. **Install Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

3. **Install Homebrew** (optional but recommended)
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

4. **Install CocoaPods**
   ```bash
   sudo gem install cocoapods
   ```

5. **Navigate to Project**
   ```bash
   cd /mnt/woofwalk
   pod install
   ```

6. **Download Xcode** (if you want full Xcode IDE)
   - Open Safari
   - Go to developer.apple.com
   - Download Xcode (~13GB)
   - Install and open

7. **Build WoofWalk iOS**
   ```bash
   # With Xcode:
   open WoofWalk.xcworkspace

   # Or command line:
   xcodebuild -workspace WoofWalk.xcworkspace \
              -scheme WoofWalk \
              -sdk iphonesimulator \
              -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0'
   ```

---

## 🔧 Troubleshooting

### Docker Permission Denied

If you get permission errors:
```bash
# Verify you're in docker group:
groups | grep docker

# If not showing, log out and back in
exit
# Reopen WSL
```

### KVM Permission Denied

```bash
# Verify KVM access:
ls -la /dev/kvm

# Should show: crw-rw---- 1 root kvm
# Your user should be in kvm group
groups | grep kvm
```

### macOS Won't Boot

- Ensure VT-x is enabled in BIOS
- Check WSL2 has nested virtualization: `lscpu | grep Virtualization`
- Try with more RAM: Edit `run-macos.sh` and change `RAM=8192` to `RAM=16384`

### Slow Performance

- Increase CPU cores in `run-macos.sh`: `CORES=6` or `CORES=8`
- Close other applications
- This is emulation, expect ~30-50% native speed

### X11 Display Issues

If macOS window doesn't appear:

1. **Install VNC Viewer** on Windows
2. **Connect to**: `localhost:5900` or check Docker port mapping
3. **Or use headless mode** and connect via VNC

---

## 📊 System Requirements Check

Your system meets all requirements:

- ✅ **Virtualization**: VT-x enabled
- ✅ **KVM**: Available at /dev/kvm
- ✅ **Docker**: Version 28.5.1 installed
- ✅ **WSL2**: Running Ubuntu 24.04

**Recommended Specs for Good Performance:**
- RAM: 16GB+ (8GB allocated to macOS)
- CPU: 4+ cores (4 allocated to macOS)
- Disk: 50GB+ free (macOS image ~30GB after full setup)
- Internet: Fast connection for downloads

---

## 🎯 Current Status

- [x] KVM configured
- [x] Docker installed
- [x] User permissions set
- [x] Docker service running
- [ ] Docker-OSX image downloaded (in progress - check with `sudo docker images`)
- [ ] macOS booted
- [ ] Xcode installed
- [ ] WoofWalk iOS built

---

## 💡 Tips

1. **Save macOS State**: Docker-OSX supports snapshots, so you don't have to reinstall everything each time

2. **Performance**: If macOS is too slow, try the "naked" version which doesn't include a desktop environment

3. **Alternative**: If Docker-OSX doesn't work well, consider using GitHub Actions with macOS runners for CI/CD builds

4. **Legal Note**: Remember this is for personal testing only and violates Apple's EULA

---

**Setup Time**: Automated installation completed in ~5 minutes
**Download Time**: Docker-OSX image will take 30-60 minutes
**First Boot**: macOS takes 10-15 minutes to boot initially
**Xcode Download**: Add another 30-60 minutes for Xcode

**Total Time to Build iOS App**: ~2-3 hours from start to finish

---

For help or issues, check:
- Docker-OSX GitHub: https://github.com/sickcodes/Docker-OSX
- Discord: https://discord.gg/docker-osx
