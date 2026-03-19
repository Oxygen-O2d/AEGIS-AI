import uuid

# In-memory database to store our incidents
# Structure: { "incident_id": { ...incident_data... } }
incident_db = {}

def create_incident(
    source: str,
    log_content: str,
    triage_alert: dict | str,
    timestamp: str | None = None,
) -> str:
    """Creates a new incident record and returns the ID."""
    incident_id = str(uuid.uuid4())
    incident_db[incident_id] = {
        "id": incident_id,
        "source": source,
        "log_content": log_content,
        "timestamp": timestamp,
        "triage_alert": triage_alert,
        "deep_analysis": "PENDING", # DeepSeek will update this
        "status": "Active"
    }
    return incident_id

def update_deep_analysis(incident_id: str, analysis: str):
    """Updates the incident with DeepSeek's heavy reasoning."""
    if incident_id in incident_db:
        incident_db[incident_id]["deep_analysis"] = analysis

def clear_db():
    """Wipes all incidents from the memory."""
    global incident_db
    incident_db.clear()
    return {"status": "Database Wiped"}
