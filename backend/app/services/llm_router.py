import os
import json
import httpx
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables (API Keys)
load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY")

# API Endpoints
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
NVIDIA_URL = "https://integrate.api.nvidia.com/v1/chat/completions"

# Models
FAST_MODEL = "llama-3.3-70b-versatile"
HEAVY_MODEL = "meta/llama3-70b-instruct"

async def get_fast_triage(prompt: str) -> str:
    """Tier 1: High-Speed Triage using Groq"""
    if not GROQ_API_KEY:
        print("⚠️ Warning: GROQ_API_KEY missing. Using fallback.")
        return '{"threat_type": "Unknown", "severity": "Low", "escalate": false}'

    headers = {
        "Authorization": f"Bearer {GROQ_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": FAST_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(GROQ_URL, headers=headers, json=payload)
            
            # Expose the exact error if Groq rejects it
            if response.status_code != 200:
                print(f"🛑 GROQ REJECTION DETAILS: {response.text}")
                
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]
    except Exception as e:
        print(f"❌ Groq Triage Error: {str(e)}")
        return '{"threat_type": "Parsing Failed", "severity": "Low", "escalate": false}'

async def get_attack_prediction(prompt: str) -> str:
    """Tier 2: Deep JSON Prediction using NVIDIA NIM"""
    if not NVIDIA_API_KEY:
        raise ValueError("NVIDIA_API_KEY is missing from .env")

    headers = {
        "Authorization": f"Bearer {NVIDIA_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": HEAVY_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
        "max_tokens": 512,
    }

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(NVIDIA_URL, headers=headers, json=payload)
            response.raise_for_status()
            
            content = response.json()["choices"][0]["message"]["content"]
            content = content.replace("```json", "").replace("```", "").strip()
            return content
    except Exception as e:
        print(f"❌ NVIDIA Prediction Error: {str(e)}")
        raise e

async def generate_rca_report(log_content: str, triage_data: dict) -> str:
    """Enterprise Format: Blue ### Headers restored, --- lines removed."""
    print("⏳ [DEBUG] Generating Enterprise RCA via strict formatting...")
    
    prompt = f"""
    You are a Senior Incident Response Analyst compiling a Root Cause Analysis (RCA) report intended for a Chief Information Security Officer (CISO).
    Analyze the provided security incident and output ONLY valid JSON.
    Format your analysis as a strict, factual report. Do not use emojis, introductory phrases, or conversation.

    Use this exact schema for your JSON output:
    {{
        "technique": "State the specific MITRE ATT&CK technique name or high-level vector (e.g. T1190 - Exploit Public-Facing Application).",
        "summary": "State a strict, 2-3 sentence overview detailing the specific threat, asset targeted, and business impact.",
        "root_cause": "Provide a detailed technical breakdown of the vulnerability exploited and the exact attack path used.",
        "containment_action": "Explain the immediate network containment or blocking strategy required.",
        "cli_command": "Provide ONLY the necessary raw CLI command string (e.g. aws wafv2 update-ip-set ...). Just the raw command string.",
        "eradication": "Explain the precise steps required to patch the vulnerability and remove threat artifacts.",
        "recovery": "Explain long-term monitoring and service validation procedures."
    }}

    INCIDENT DATA TO ANALYZE: {json.dumps(triage_data, indent=2)}
    RAW TELEMETRY LOGS: {log_content}
    """

    headers = {
        "Authorization": f"Bearer {NVIDIA_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": HEAVY_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,  
        "max_tokens": 1024,
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(NVIDIA_URL, headers=headers, json=payload)
            response.raise_for_status()
            
            content = response.json()["choices"][0]["message"]["content"]
            
            start_idx = content.find('{')
            end_idx = content.rfind('}') + 1
            
            if start_idx != -1 and end_idx != -1:
                clean_json = content[start_idx:end_idx]
                data = json.loads(clean_json)
                
                # 🛑 FIX: Restored the '###' for blue headings, but kept the '---' out!
                report = f"""**INCIDENT FORENSIC REPORT**
**Technique:** {data.get('technique', 'Unclassified Vector')} | **Status:** PENDING CONTAINMENT | **Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}


### EXECUTIVE SUMMARY
{data.get('summary', 'Summary data unavailable.')}


### ROOT CAUSE ANALYSIS
{data.get('root_cause', 'Root cause data unavailable.')}


### INCIDENT RESPONSE PROCEDURE
**Containment Strategy:**
{data.get('containment_action', 'Containment strategy unavailable.')}

`{data.get('cli_command', 'Manual intervention required.')}`

**Eradication:**
{data.get('eradication', 'Eradication steps unavailable.')}

**Recovery & Monitoring:**
{data.get('recovery', 'Recovery steps unavailable.')}"""
                
                print("✅ [DEBUG] Enterprise RCA generated successfully.")
                return report
                
            return "### ⚠️ FORMAT ERROR\nInference engine failed to produce structured JSON output."
            
    except Exception as e:
        print(f"❌ [DEBUG] NVIDIA API Error: {str(e)}")
        return f"### ⚠️ SYSTEM ERROR\nFailed to Compile Forensic Report: {str(e)}"