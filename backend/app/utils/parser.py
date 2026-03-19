import json
import re

def parse_nmap(raw_data: str) -> str:
    """Extract only open ports and services from Nmap JSON/Text."""
    if "open" not in raw_data:
        return "No open ports found."
    lines = [line for line in raw_data.split("\n") if "open" in line]
    return " | ".join(lines[:10])

def parse_zap(raw_data: str) -> str:
    """Extract high-signal OWASP ZAP alerts from JSON."""
    try:
        data = json.loads(raw_data)
    except json.JSONDecodeError:
        return raw_data[:500]

    alerts = []
    for site in data.get("site", []):
        site_alerts = site.get("alerts", []) if isinstance(site, dict) else []
        for alert in site_alerts:
            if not isinstance(alert, dict): continue
            risk = str(alert.get("risk") or alert.get("riskdesc") or "").title()
            if risk and risk.split()[0] not in {"High", "Medium"}:
                continue
            name = alert.get("alert") or alert.get("name") or "Unknown"
            alerts.append(f"{name} ({risk.split()[0]})")

    return " | ".join(alerts) if alerts else "No high-risk web vulnerabilities."

def parse_modsec_waf(raw_data: str) -> str:
    """
    Parses ModSecurity Audit logs and generic WAF JSON.
    Extracts: Source IP, Targeted URI, and the Security Rule triggered.
    """
    # 1. Try JSON Parsing first (Typical for Cloud WAFs like AWS/Cloudflare)
    try:
        data = json.loads(raw_data)
        client_ip = data.get("clientIp", "UNKNOWN_IP")
        action = data.get("action", "DETECTED")
        rule = data.get("ruleId", "Generic_WAF_Rule")
        uri = data.get("uri", "N/A")
        return f"WAF {action}: {rule} from {client_ip} on {uri}"
    except:
        pass

    # 2. ModSecurity Text Parsing (Regex)
    # Extracting the [client IP], [message "Rule Description"], and [uri "/path"]
    ip_match = re.search(r'\[client (.*?)\]', raw_data)
    msg_match = re.search(r'\[msg "(.*?)"\]', raw_data)
    uri_match = re.search(r'\[uri "(.*?)"\]', raw_data)

    if ip_match or msg_match:
        ip = ip_match.group(1) if ip_match else "Unknown"
        msg = msg_match.group(1) if msg_match else "Malicious Activity"
        uri = uri_match.group(1) if uri_match else "N/A"
        return f"MODSEC BLOCK: {msg} | Src: {ip} | URI: {uri}"

    return f"RAW TELEMETRY: {raw_data[:200]}..."

def master_parse(raw_data: str) -> str:
    """The central entry point. Identifies log type and routes to the right parser."""
    if not raw_data: return "Empty log received."
    
    # Simple routing logic
    if "Nmap scan report" in raw_data or '"nmaprun"' in raw_data:
        return parse_nmap(raw_data)
    elif '"@zapVersion"' in raw_data or '"site"' in raw_data:
        return parse_zap(raw_data)
    elif "ModSecurity" in raw_data or "[client" in raw_data or '"clientIp"' in raw_data:
        return parse_modsec_waf(raw_data)
    
    return raw_data[:300] # Fallback for unknown formats