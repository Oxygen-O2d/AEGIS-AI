import requests
import json
from datetime import datetime, timezone

# 🛑 THE FIX 1: Added /api/v1 to match your FastAPI router prefix!
API_URL = "http://127.0.0.1:8000/api/v1/logs"

def send_waf_attack():
    modsec_log = (
        '[Wed Mar 18 12:05:33 2026] [error] [client 198.51.100.42] '
        'ModSecurity: Access denied with code 403 (phase 2). '
        'Pattern match "(?i)(?:\\b(?:(?:s(?:elect\\b(?:.{1,100}?\\b(?:(?:length|count|top)\\b.{1,100}?\\bfrom|from\\b.{1,100}?\\bwhere)|.*\\b(?:from\\b.{1,100}?\\bwhere|where\\b.{1,100}?\\bin))|update\\b.{1,100}?\\bset|insert\\b.{1,100}?\\binto|delete\\b.{1,100}?\\bfrom))\\b)" '
        'at ARGS:username. [file "/etc/modsecurity/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf"] '
        '[line "100"] [id "942100"] [msg "SQL Injection Attack Detected via libinjection"] '
        '[data "Matched Data: 1\' OR \'1\'=\'1 found within ARGS:username: admin\' OR \'1\'=\'1"] '
        '[severity "CRITICAL"] [ver "OWASP_CRS/3.3.2"] [tag "application-multi"] '
        '[tag "language-multi"] [tag "platform-multi"] [tag "attack-sqli"] '
        '[tag "OWASP_CRS"] [tag "capec/1000/152/248/66"] [tag "PCI/6.5.2"] '
        '[tag "paranoia-level/1"] [hostname "api.subsume.os"] [uri "/auth/login"] '
        '[unique_id "Z_abcdef1234567890"]'
    )

    payload = {
        "source": "ModSecurity-WAF",
        "log_content": modsec_log,
        # 🛑 THE FIX 2: Using the modern Python 3.12 timezone-aware format
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

    try:
        print("🚀 Firing Simulated WAF SQLi Attack...")
        response = requests.post(API_URL, json=payload)
        
        if response.status_code == 200:
            print("✅ Payload Delivered! Check your React Dashboard.")
            print("Response:", json.dumps(response.json(), indent=2))
        else:
            print(f"❌ Failed. Status Code: {response.status_code}")
            print(response.text)
            
    except requests.exceptions.ConnectionError:
        print("⚠️ ERROR: Cannot connect to Backend. Is FastAPI running on port 8000?")

if __name__ == "__main__":
    send_waf_attack()