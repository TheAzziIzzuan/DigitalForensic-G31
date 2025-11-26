# 🔐 DigitalForensic-G31 Setup Guide

Quick links: [Server Setup](#-server-setup) | [Windows Agent](#-windows-agent) | [Verify](#-verify-it-works) | [Fix Issues](#-having-problems)

---

## ✅ What You Need First

### Ubuntu/Linux Server

- [ ] Ubuntu 18.04+ (or similar Linux)
- [ ] 4GB RAM
- [ ] 20GB free space
- [ ] Internet connection
- [ ] Admin access (sudo)

### Windows Computers

- [ ] Windows 7 SP1+
- [ ] PowerShell 5.0+
- [ ] Admin access
- [ ] Network to Wazuh server

**Using:** Wazuh v4.12.0 | Docker latest

---

## 🖥️ Server Setup

### Install Docker

Open terminal and run each command:

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Add Docker repository:

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

Test it:

```bash
sudo docker run hello-world
```

✅ Should see: `Hello from Docker!`

---

### Download Wazuh

```bash
git clone https://github.com/wazuh/wazuh-docker.git -b v4.12.0
cd wazuh-docker/single-node
```

---

### Create Security Keys

```bash
docker-compose -f generate-indexer-certs.yml run --rm generator
```

---

### Start Wazuh

```bash
sudo docker compose up -d
```

✅ **Done!** Now go to: `https://localhost`

- Username: `admin`
- Password: SuperPassword

---

## 🪟 Windows Agent

### 1️⃣ Open PowerShell as Admin

- Right-click Windows Start
- Select "Windows PowerShell (Admin)"
- Click "Yes"

### 2️⃣ Download Agent

```powershell
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.12.0-1.msi?raw=1" -OutFile "$env:TEMP\wazuh-agent.msi"
```

### 3️⃣ Install Agent

**⚠️ Replace `SERVER_IP` with your server address!**

Examples: `192.168.1.100` or `wazuh-server.local`

```powershell
msiexec.exe /i "$env:TEMP\wazuh-agent.msi" WAZUH_MANAGER="SERVER_IP" WAZUH_AGENT_NAME="SANDEVISTAN-HOST"
```

### 4️⃣ Start Agent

```powershell
Start-Service -Name OssecSvc
```

✅ **Agent is running!**

---

## ✅ Verify It Works

### Server Running?

```bash
sudo docker ps
```

You should see:

- ✅ `wazuh.manager`
- ✅ `wazuh.indexer`
- ✅ `wazuh.dashboard`

### Agent Running?

```powershell
Get-Service OssecSvc
```

Look for: `Status : Running`

### See Agent Activity

```powershell
Get-Content "C:\Program Files (x86)\ossec-agent\logs\active-response.log" -Tail 20
```

---

## 🔧 Having Problems?

### Server Won't Start

```bash
sudo docker compose logs
```

Read the error. It usually tells you what's wrong.

---

### Can't Access Dashboard

- Wait 2-3 minutes for startup
- Try different browser
- Check: `sudo docker ps` (are containers running?)
- Check firewall isn't blocking port 443

---

### Windows Agent Won't Install

**Check these:**

- Running PowerShell as Admin? ✓
- Server IP correct? ✓
- Can reach server? `ping SERVER_IP`
- Already installed? (uninstall first)

---

### Agent Shows Offline

```powershell
# Check config
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.conf"

# Restart it
Restart-Service OssecSvc

# Check firewall allows port 1514
```

**Windows Firewall:**
Settings → Firewall → Allow app → Add `ossec.exe`

---

### Still Stuck?

Check logs:

- **Server:** `sudo docker compose logs`
- **Agent:** `C:\Program Files (x86)\ossec-agent\logs\`


Setting up sysmon monitoring on Windows:
- 
