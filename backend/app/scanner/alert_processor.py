from typing import Any

MAX_SECURITY_SCORE = 100
MIN_SECURITY_SCORE = 0
SEVERITY_ORDER = {"High": 0, "Medium": 1, "Low": 2}
SEVERITY_WEIGHTS = {"High": 20, "Medium": 10, "Low": 5, "Info": 0}


def count_vulnerabilities_by_severity(
    vulnerabilities: list[dict[str, Any]],
) -> dict[str, int]:
    counts = {"high": 0, "medium": 0, "low": 0}
    for vulnerability in vulnerabilities:
        risk = str(vulnerability.get("risk") or "").strip().lower()
        if risk in counts:
            counts[risk] += 1
    return counts


def calculate_security_score(vulnerabilities: list[dict[str, Any]]) -> int:
    score = MAX_SECURITY_SCORE
    for vulnerability in vulnerabilities:
        risk = str(vulnerability.get("risk") or "").strip().title()
        score -= SEVERITY_WEIGHTS.get(risk, 0)
    return max(MIN_SECURITY_SCORE, min(score, MAX_SECURITY_SCORE))


def build_live_alerts(vulnerabilities: list[dict[str, Any]]) -> list[dict[str, str]]:
    alerts: list[dict[str, str]] = []
    for vulnerability in vulnerabilities:
        if str(vulnerability.get("risk") or "").strip().title() != "High":
            continue
        alerts.append(
            {
                "name": str(vulnerability.get("name") or "Unknown"),
                "risk": "High",
                "url": str(vulnerability.get("url") or ""),
                "description": str(
                    vulnerability.get("description") or "No description provided."
                ),
            }
        )
    return alerts


def build_intelligence_stream(
    vulnerabilities: list[dict[str, Any]],
) -> list[dict[str, str]]:
    stream: list[dict[str, str]] = []
    for vulnerability in vulnerabilities:
        risk = str(vulnerability.get("risk") or "").strip().title()
        if risk not in {"Medium", "Low"}:
            continue
        stream.append(
            {
                "name": str(vulnerability.get("name") or "Unknown"),
                "risk": risk,
                "url": str(vulnerability.get("url") or ""),
                "description": str(
                    vulnerability.get("description") or "No description provided."
                ),
            }
        )
    stream.sort(
        key=lambda item: (
            SEVERITY_ORDER.get(item["risk"], 3),
            item["name"].lower(),
            item["url"].lower(),
        )
    )
    return stream


def build_web_scan_dashboard(
    vulnerabilities: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "alerts": build_live_alerts(vulnerabilities),
        "intelligence_stream": build_intelligence_stream(vulnerabilities),
        "severity_counts": count_vulnerabilities_by_severity(vulnerabilities),
        "security_score": calculate_security_score(vulnerabilities),
    }
