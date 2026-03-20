Aegis-AI: The Autonomous, Dual-Tier Security Operations Center

Aegis-AI is an autonomous, AI-driven SOC and threat intelligence platform. It acts as a tireless Tier-1 and Tier-2 security analyst, instantly ingesting raw telemetry, triaging threats, and generating enterprise-grade Root Cause Analysis (RCA) reports with actionable remediation playbooks.

This repository is a monorepo containing two distinct components:

The Blue Team Backend (/backend): A high-speed FastAPI engine utilizing Groq (Llama-3) for millisecond threat triage and NVIDIA NIM for deep forensic reasoning.

The Target Environment & Dashboard (/AltoroJ): A JSP/Tomcat application that serves as both the SOC command center UI and the deliberately vulnerable target infrastructure.

Backend Quick Start (FastAPI + AI Models)

To run the Aegis-AI backend engine, open a terminal (PowerShell, Command Prompt, or WSL) and follow these steps:

1) Navigate to the backend directory
cd backend
2) Create and activate a virtual environment
python -m venv venv

# On Windows:
venv\Scripts\activate

# On Mac/Linux/WSL:
source venv/bin/activate
3) Install dependencies
pip install -r requirements.txt
(Ensure FastAPI, Uvicorn, HTTPX, and Python-dotenv are installed)

4) Configure API Keys
Create a .env file in the root of the backend folder and add your AI API keys:
GROQ_API_KEY=your_groq_key_here
NVIDIA_API_KEY=your_nvidia_key_here
5) Start the Aegis-AI Server
uvicorn app.main:app --reload
The backend API will now be running securely at http://127.0.0.1:8000.

6) Simulate an Attack (Red Team)
To populate the dashboard with realistic threat telemetry, open a second terminal window, navigate to the backend folder, and trigger the simulator:
python red_team_simulator.py
Description
WARNING: This application contains security vulnerabilities. Run it only in a backed-up and sheltered environment (such as a VM with a recent snapshot and host-only networking) and at your own risk, escpecially if you enable some of the advanced options described below!

AltoroJ is a sample banking J2EE web application. It shows what happens when web applications are written with consideration of app functionality but not app security. It's a simple and uncluttered platform for demonstrating and learning more about real-life application security issues.

AltoroJ uses standard Java & JSP functionality without relying on any additional frameworks. While vast majority of real-life applications do use frameworks, the exact same principles of Application Security apply in both cases. Frameworks can also be hard to understand for someone not familiar with a particular framework and introduce complexities that detract from the overall learning experience. Not to mention, a large number of large and complex "legacy" Java web applications that look very similar to AltoroJ (but are infinitely more complex of course).

AltoroJ uses Apache Derby as its SQL database that is automatically initialized the first time you log into AltoroJ via its web interface. All of the transactions and operations will then be stored in this database from that point on until you delete your repository folder called "altoro" that is located in your OS home folder (e.g. C:\Users[your_username] or /Users/[your_username]) or enable advanced option to re-initialize your database every time your web application server is restarted (see below).

AltoroJ was created in 2008 and has gone through a number of iterations since then. It currently, being used around the world to demonstrate application security vulnerabilities, educate folks on how easy some of these issues are to exploit and how severe the impact may be, and is even a part of academic curricula. Even though AltoroJ is pretty stable, if you do find a bug or create a cool exploit for one of its vulnerabilities - please let us know!!!

Binaries and hosted versions
If you'd like to try AltoroJ but want to skip all of the cool software development stuff, use publicly hosted version, available at http://altoromutual.com:8080/ . You will not be able to enable any of the advanced options and this site may not always be available, but it's the easiest way to get started

Quick start (Windows + WSL + Java 11 + Tomcat 9)
This is a tested setup path to run AltoroJ reliably on modern Windows hardware using WSL2.

1) Install WSL (Windows PowerShell as Administrator)
wsl --install -d Ubuntu
Reboot if prompted, then open Ubuntu from Start menu.

2) Install Java 11 in Ubuntu (inside WSL)
sudo apt update
sudo apt install -y openjdk-11-jdk curl
java -version
3) Install Tomcat 9 (inside WSL)
Ubuntu 24.04 may not provide tomcat9 package directly, so install official Apache Tomcat 9 binary:
cd /tmp
curl -fLO [https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz](https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz)
sudo rm -rf /opt/tomcat9
sudo mkdir -p /opt/tomcat9
sudo tar -xzf apache-tomcat-9.0.115.tar.gz -C /opt/tomcat9 --strip-components=1
sudo chmod +x /opt/tomcat9/bin/*.sh
4) Copy project into WSL
If this repo is on D:\AltoroJ in Windows:
rm -rf ~/AltoroJ
cp -a /mnt/d/AltoroJ ~/AltoroJ
5) Build WAR (optional if already present)
If build/libs/altoromutual.war is missing:
cd ~/AltoroJ
./gradlew war
6) Deploy WAR to Tomcat
sudo cp ~/AltoroJ/build/libs/altoromutual.war /opt/tomcat9/webapps/
7) Start Tomcat
sudo /opt/tomcat9/bin/startup.sh
If you want to run in background with redirected logs, use:
sudo bash -lc 'nohup /opt/tomcat9/bin/catalina.sh run >/opt/tomcat9/logs/console.out 2>&1 &'
8) Verify
Inside WSL:
curl -I [http://127.0.0.1:8080/altoromutual/aegis/aegis_dashboard.jsp](http://127.0.0.1:8080/altoromutual/aegis/aegis_dashboard.jsp)
From Windows browser:
http://localhost:8080/altoromutual/aegis/aegis_dashboard.jsp
Expected result: HTTP 200.

9) Stop Tomcat
sudo /opt/tomcat9/bin/shutdown.sh
Common issues and fixes
wsl: command not found inside Ubuntu:
You are already in WSL. Run Linux commands directly without wsl ....

Permission denied when using >/opt/tomcat9/logs/...:Use sudo bash -lc '... > ... 2>&1 &' so redirection runs as root.

Browser shows ERR_CONNECTION_REFUSED:
Start Tomcat and confirm port:
ps -ef | grep -i '[o]rg.apache.catalina.startup.Bootstrap'
ss -ltnp | grep 8080
App deployed but not loading:
Check logs:
tail -n 150 /opt/tomcat9/logs/catalina.out
Prereqiusites
AltoroJ has been developed using Eclipse and designed to run on Tomcat 7, but since it's a relatively simple J2EE app, it should be pretty easy to port it to a different J2EE IDE or another J2EE web application server. Here are out-of-the-box requirements:
Eclipse 4.6 or newer recommended (requires Java 8)
Tomcat 7.x
Gradle 3.0 to build from command line
Gradle's Buildship Eclipse plug-in to automatically download required 3rd party libraries and run AltoroJ inside Eclipse
-- Easiest way to install Buildship is from Eclipse Marketplace (inside Eclipse, go to Help -> Eclipse Marketplace)
Read more about importing AltoroJ into Eclipse from GitHub here

AltoroJ credentials
Main usernames and passwords for AltoroJ are as follows:
jsmith/demo1234
admin/admin
Advanced options
AltoroJ’s original design goals were to create an application that is easy to deploy, very stable and less dangerous (as far as vulnerable web apps go). However, these goals meant that certain attacks couldn’t be a part of it. Because of this, there are advanced user-configurable properties that can enable AltoroJ behaviors which are disabled by default.
These enable extra functionality, new cool attacks and demos as well as optional behaviors.
Please see WEB-INF/app.properties file for more information on each property

REST API
AltoroJ has a fairly extensive REST API, which is documented using Swagger. You can find out more about and interact with the provided REST services by clicking on the REST API link in the footer of almost every AltoroJ page.

Troubleshooting
Problem: AltoroJ runs, but an error “Failed to create database 'altoro‘” comes up when you try to log in
Cause: AltoroJ database does not get created. This is usually caused by folder permission issues on a locked-down system
Solution: 	To make sure this isn’t a fluke, try to log in again using jsmith/demo1234.
AltoroJ uses Java’s user.home property as a base directory for its database so this shouldn’t happen. However, if it does.
Take a look at your Eclipse Console, or if running directly on Tomcat, open "catalina.out" file from Tomcat’s logs folder in a text editor and look for “user.home=“. This is the folder that AltoroJ is trying to create another folder in and needs write access. You can then:
Give the user Tomcat runs under read/write/create access to this folder (recommended)
OR modify Tomcat’s startup to include –Duser.home=“<new_path>” in Java arguments to change DB location

Problem: AltoroJ does not run on Tomcat due to compilation errors
Cause: If you have compilation errors in Eclipse, Java build path is likely to blame
Solution: Run AltoroJ's Gradle build in order to download required third party libraries and build AltoroJ

License
All files found in this project are licensed under the Apache License 2.0.




