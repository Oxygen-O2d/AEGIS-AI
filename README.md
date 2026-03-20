# Aegis-AI: Autonomous Dual-Tier Security Operations Center

Aegis-AI is an autonomous, AI-driven SOC and threat intelligence platform. It functions as a tireless Tier-1 and Tier-2 security analyst by ingesting raw telemetry, triaging threats, and generating enterprise-grade Root Cause Analysis (RCA) reports with actionable remediation playbooks.

## Table of Contents

- [Repository Structure](#repository-structure)
- [Backend Quick Start (FastAPI + AI Models)](#backend-quick-start-fastapi--ai-models)
- [AltoroJ Quick Start (Windows + WSL + Java 11 + Tomcat 9)](#altoroj-quick-start-windows--wsl--java-11--tomcat-9)
- [Common Issues and Fixes](#common-issues-and-fixes)
- [License](#license)

## Repository Structure

This repository is a monorepo with two primary components:

- **Blue Team Backend (`/backend`)**: A high-speed FastAPI engine using Groq (Llama-3) for millisecond threat triage and NVIDIA NIM for deep forensic reasoning.
- **Target Environment and Dashboard (`/AltoroJ`)**: A JSP/Tomcat application that acts as both the SOC command center UI and the deliberately vulnerable target infrastructure.

## Backend Quick Start (FastAPI + AI Models)

To run the Aegis-AI backend engine, open a terminal (PowerShell, Command Prompt, or WSL) and follow the steps below.

### 1) Navigate to the backend directory

```bash
cd backend
```

### 2) Create and activate a virtual environment

```bash
python -m venv venv

# On Windows:
venv\Scripts\activate

# On Mac/Linux/WSL:
source venv/bin/activate
```

### 3) Install dependencies

```bash
pip install -r requirements.txt
```

Ensure FastAPI, Uvicorn, HTTPX, and Python-dotenv are installed.

### 4) Configure API keys

Create a `.env` file in the root of the backend folder and add your AI API keys:

```bash
GROQ_API_KEY=your_groq_key_here
NVIDIA_API_KEY=your_nvidia_key_here
```

### 5) Start the Aegis-AI server

```bash
uvicorn app.main:app --reload
```

The backend API will be available at `http://127.0.0.1:8000`.

### 6) Simulate an attack (red team)

To populate the dashboard with realistic threat telemetry, open a second terminal, navigate to the backend folder, and trigger the simulator:

```bash
python red_team_simulator.py
```

## AltoroJ Quick Start (Windows + WSL + Java 11 + Tomcat 9)

This is a tested setup path to run AltoroJ reliably on modern Windows hardware using WSL2.

### 1) Install WSL (PowerShell as Administrator)

```bash
wsl --install -d Ubuntu
```

Reboot if prompted, then open Ubuntu from the Start menu.

### 2) Install Java 11 in Ubuntu (inside WSL)

```bash
sudo apt update
sudo apt install -y openjdk-11-jdk curl
java -version
```

### 3) Install Tomcat 9 (inside WSL)

Ubuntu 24.04 may not provide a `tomcat9` package directly, so install the official Apache Tomcat 9 binary:

```bash
cd /tmp
curl -fLO [https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz](https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz)
sudo rm -rf /opt/tomcat9
sudo mkdir -p /opt/tomcat9
sudo tar -xzf apache-tomcat-9.0.115.tar.gz -C /opt/tomcat9 --strip-components=1
sudo chmod +x /opt/tomcat9/bin/*.sh
```

### 4) Copy project into WSL

If this repository is on `D:\AltoroJ` in Windows:

```bash
rm -rf ~/AltoroJ
cp -a /mnt/d/AltoroJ ~/AltoroJ
```

### 5) Build WAR (optional if already present)

If `build/libs/altoromutual.war` is missing:

```bash
cd ~/AltoroJ
./gradlew war
```

### 6) Deploy WAR to Tomcat

```bash
sudo cp ~/AltoroJ/build/libs/altoromutual.war /opt/tomcat9/webapps/
```

### 7) Start Tomcat

```bash
sudo /opt/tomcat9/bin/startup.sh
```

If you want to run in the background with redirected logs:

```bash
sudo bash -lc 'nohup /opt/tomcat9/bin/catalina.sh run >/opt/tomcat9/logs/console.out 2>&1 &'
```

### 8) Verify

Inside WSL:

```bash
curl -I [http://127.0.0.1:8080/altoromutual/aegis/aegis_dashboard.jsp](http://127.0.0.1:8080/altoromutual/aegis/aegis_dashboard.jsp)
```

From a Windows browser:

```bash
http://localhost:8080/altoromutual/aegis/aegis_dashboard.jsp
```

Expected result: HTTP 200.

### 9) Stop Tomcat

```bash
sudo /opt/tomcat9/bin/shutdown.sh
```

## Common Issues and Fixes

### `wsl: command not found` inside Ubuntu

You are already in WSL. Run Linux commands directly without `wsl ...`.

### Permission denied when using `>/opt/tomcat9/logs/...`

Use:

```bash
sudo bash -lc '... > ... 2>&1 &'
```

This ensures redirection runs as root.

### Browser shows `ERR_CONNECTION_REFUSED`

Start Tomcat and confirm port binding:

```bash
ps -ef | grep -i '[o]rg.apache.catalina.startup.Bootstrap'
ss -ltnp | grep 8080
```

### App deployed but not loading

Check logs:

```bash
tail -n 150 /opt/tomcat9/logs/catalina.out
```

## License

All files in this project are licensed under the Apache License 2.0.
