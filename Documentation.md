# 🔒 DigitalForensic-G31 Setup Guide

**What is this?** A step-by-step guide to install Wazuh (security monitoring system) on Ubuntu server and Windows agents.

## 📋 Quick Start

- **[Server Setup](#-server-setup-ubuntu)** (Ubuntu/Linux)
- **[Windows Agent Setup](#-windows-agent-setup)** (Windows)
- **[Test If It Works](#-verify-installation)** (Checklist)
- **[Fix Problems](#-troubleshooting)** (Common Issues)

---

## ✅ What You Need

### For Ubuntu Server:
- [ ] Ubuntu 18.04 or newer
- [ ] 4GB RAM minimum
- [ ] 20GB free disk space
- [ ] Internet connection
- [ ] Admin access (sudo)

### For Windows Computers:
- [ ] Windows 7 SP1 or newer
- [ ] PowerShell 5.0+
- [ ] Admin access
- [ ] Network connection to Wazuh server

**Versions:** Wazuh 4.12.0 | Docker (latest)

---

## 🖥️ Server Setup (Ubuntu)

### Part 1: Install Docker (5 minutes)

**What's Docker?** A container system that packages Wazuh with all its dependencies.

Copy & paste this into your Ubuntu terminal:

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Then add Docker repository:

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

**Test it works:**
```bash
sudo docker run hello-world
```
✅ You should see "Hello from Docker!"

---

### Part 2: Download Wazuh (2 minutes)

```bash
git clone https://github.com/wazuh/wazuh-docker.git -b v4.12.0
cd wazuh-docker/single-node
```

---

### Part 3: Create Security Certificates (3 minutes)

These are like digital locks to secure connections:

```bash
docker-compose -f generate-indexer-certs.yml run --rm generator
```

---

### Part 4: Start Wazuh (2 minutes)

```bash
sudo docker compose up -d
```

**What's `-d`?** Runs it in background. Don't close terminal!

---

### 🎯 Done! Access Wazuh Dashboard

Once containers are running:
- **URL:** `https://localhost`
- **Username:** `admin`
- **Password:** Find in setup output or `.env` file

---

## 🪟 Windows Agent Setup

**What's an Agent?** Software that monitors your Windows computer and sends data to Wazuh server.

### Step 1: Open PowerShell as Admin

1. Right-click Windows Start menu
2. Select "Windows PowerShell (Admin)"
3. Click "Yes" when asked

### Step 2: Download Wazuh Agent (1 minute)

Copy & paste this:

```powershell
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.12.0-1.msi?raw=1" -OutFile "$env:TEMP\wazuh-agent.msi"
```

### Step 3: Install Agent (2 minutes)

**⚠️ IMPORTANT:** Replace `YOUR_SERVER_IP` with your Wazuh server address!

Examples: `192.168.1.100` or `wazuh-server.local`

```powershell
msiexec.exe /i "$env:TEMP\wazuh-agent.msi" WAZUH_MANAGER="YOUR_SERVER_IP" WAZUH_AGENT_NAME="SANDEVISTAN-HOST"
```

### Step 4: Start the Agent (30 seconds)

```powershell
Start-Service -Name OssecSvc
```

✅ **Agent is running!**

---

## ✅ Verify Installation

### Is the Server Running?

```bash
sudo docker ps
```

You should see 3 containers:
- ✅ `wazuh.manager`
- ✅ `wazuh.indexer`
- ✅ `wazuh.dashboard`

### Is the Windows Agent Connected?

Open PowerShell and run:

```powershell
Get-Service OssecSvc
```

Look for: `Status : Running`

### Check Agent Logs

```powershell
Get-Content "C:\Program Files (x86)\ossec-agent\logs\active-response.log" -Tail 20
```

This shows last 20 lines of activity.

---

## 🔧 Troubleshooting

### Server Won't Start

**Problem:** Docker containers not running

**Solution:**
```bash
sudo docker compose logs
```
Read the error message and search online, or check firewall settings.

---

### Can't Access Wazuh Dashboard

**Problem:** `https://localhost` not working

**Solution:**
- Wait 2-3 minutes for containers to fully start
- Check if containers are running: `sudo docker ps`
- Check if port 443 is blocked by another app
- Try a different browser

---

### Windows Agent Won't Install

**Problem:** Installation fails or hangs

**Solution:**
1. Make sure you're running PowerShell as **Admin**
2. Check if Wazuh is already installed (uninstall first)
3. Check your server IP address is correct
4. Check network can reach server: `ping YOUR_SERVER_IP`

---

### Agent Shows as "Offline"

**Problem:** Agent installed but not connecting to server

**Solution:**
1. Check server IP in agent config:
   ```powershell
   Get-Content "C:\Program Files (x86)\ossec-agent\ossec.conf"
   ```

2. Restart agent:
   ```powershell
   Restart-Service OssecSvc
   ```

3. Check Windows Firewall allows port 1514:
   - Settings → Firewall → Allow app through firewall
   - Add `ossec.exe` if needed

4. Restart computer if still not connecting

---

### Still Having Issues?

Check these files for error messages:
- **Server:** `sudo docker compose logs`
- **Agent:** `C:\Program Files (x86)\ossec-agent\logs\`





