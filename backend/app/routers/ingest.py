import json
from fastapi import APIRouter, BackgroundTasks
from pydantic import BaseModel

# Imports for your specific architecture
from app.services.llm_router import get_fast_triage, get_attack_prediction, generate_rca_report
from app.database import create_incident, update_deep_analysis, incident_db, clear_db
from app.utils.parser import master_parse  # <--- Using the correct utils path

router = APIRouter()

class LogEntry(BaseModel):
    source: str
    log_content: str
    timestamp: str

async def process_deep_scan(incident_id: str, log_content: str, parsed_summary: str):
    """
    Tier-2: Deep Forensic Analysis using Llama-3.3-70B on NVIDIA NIM.
    Now utilizes the parsed summary to anchor the AI's reasoning.
    """
    try:
        api_prompt = f"""
        Analyze this security event. Respond ONLY in valid JSON.
        Keep analysis brief, but output the FULL remediation command.

        SURGICAL RULEBOOK - Match the log to the exact command:
        - If log contains "ModifyDBInstance" or "RDS" -> 'aws rds modify-db-instance --db-instance-identifier [DB_NAME] --no-publicly-accessible'
        - If log contains "GetCallerIdentity" or "IAM User" -> 'aws iam deactivate-access-key --user-name [USER] --access-key-id [KEY]'
        - If log contains "EC2" or "Mining" -> 'aws ec2 modify-instance-attribute --instance-id [ID] --groups [ISOLATION_SG]'
        - If log contains "Secret" -> 'aws secretsmanager put-resource-policy --secret-id [SECRET] --resource-policy [DENY]'
        - If log contains "ModSec" or "WAF" or "POST" -> 'aws wafv2 update-ip-set --name Blocklist --scope REGIONAL --addresses [IP]/32'
        - Default Fallback -> 'aws ec2 create-network-acl-entry --cidr-block [IP]/32 --rule-action deny'

        Schema Requirements:
        {{
            "mitre_t_code": "Txxxx",
            "technique": "Name",
            "next_move": "Prediction",
            "remediation": "The exact AWS CLI command from the rulebook"
        }}
        
        PARSED INTELLIGENCE: {parsed_summary}
        RAW LOG: {log_content}
        """
        
        prediction_str = await get_attack_prediction(api_prompt)
        
        prediction_dict = json.loads(prediction_str) 
        update_deep_analysis(incident_id, prediction_dict)
        print(f"✅ Tier-2 Forensics complete: {incident_id}")
        
    except Exception as e:
        print(f"❌ Tier-2 Analysis Error: {str(e)}")
        update_deep_analysis(incident_id, {
            "error": "Analysis latency or format error",
            "mitre_t_code": "T1000",
            "technique": "Investigation Required",
            "next_move": "Unknown - Manual review triggered.",
            "remediation": "Verify raw log output."
        })

@router.post("/logs")
async def ingest_log(entry: LogEntry, background_tasks: BackgroundTasks):
    """
    Tier-1: High-speed Triage via Groq.
    Passes data through our custom parser first to extract high-signal artifacts.
    """
    # 1. Run the raw log through our parser
    parsed_summary = master_parse(entry.log_content)

    # 2. Feed BOTH the raw log and the clean summary to the Triage AI
    api_prompt = f"Triage this log. Output strictly in JSON format: {{'threat_type': '...', 'severity': '...', 'escalate': bool}}. \nPARSED SUMMARY: {parsed_summary} \nRAW LOG: {entry.log_content}"
    
    fast_alert_str = await get_fast_triage(api_prompt)
    
    # 3. Bulletproof JSON Extraction (Strips out AI conversational text/markdown)
    try:
        start_idx = fast_alert_str.find('{')
        end_idx = fast_alert_str.rfind('}') + 1
        
        if start_idx != -1 and end_idx != -1:
            clean_json_str = fast_alert_str[start_idx:end_idx]
            fast_alert_dict = json.loads(clean_json_str)
        else:
            raise ValueError("No valid JSON brackets found in AI response.")
            
    except Exception as e:
        print(f"❌ JSON Cleanup Failed. Raw AI Output was:\n{fast_alert_str}")
        fast_alert_dict = {"threat_type": "Parsing Error / Unknown", "severity": "Low", "escalate": False}
        
    # Store initial record
    incident_id = create_incident(
        entry.source,
        entry.log_content,
        fast_alert_dict,
        timestamp=entry.timestamp,
    )
    
    # DECISION GATE: Only escalate Medium/High/Critical to NVIDIA NIM
    severity = fast_alert_dict.get("severity", "low").lower()
    if severity in ["medium", "high", "critical"] or fast_alert_dict.get("escalate"):
        # Pass the parsed_summary to the deep scan as well
        background_tasks.add_task(process_deep_scan, incident_id, entry.log_content, parsed_summary)
    else:
        update_deep_analysis(incident_id, {
            "mitre_t_code": "N/A",
            "technique": "Routine Baseline Traffic",
            "next_move": "Standard monitoring.",
            "remediation": "No action required."
        })
    
    return {
        "status": "RECEIVED",
        "incident_id": incident_id,
        "triage_alert": fast_alert_dict
    }

@router.get("/alerts")
async def get_all_alerts():
    return {"incidents": list(incident_db.values())}

@router.post("/clear")
async def reset_incidents():
    """Wipes data for clean demo starts."""
    return clear_db()

@router.get("/rca/{incident_id}")
async def fetch_rca_report(incident_id: str):
    """
    Endpoint for the frontend to request a full RCA/IR report.
    Fixed output format to match React's expected `data.report` payload.
    """
    incident = incident_db.get(incident_id)
    if not incident:
        return {"error": "Incident not found."}
        
    # Check Cache
    if "rca_report" in incident:
        return {"report": incident["rca_report"]}
        
    # Generate on-the-fly
    report_markdown = await generate_rca_report(
        log_content=incident["log_content"],
        triage_data=incident.get("deep_analysis", {})
    )
    
    # Save to database cache
    incident["rca_report"] = report_markdown
    
    # Returning {"report": ...} matches the React App.jsx data.report expectation
    return {"report": report_markdown}