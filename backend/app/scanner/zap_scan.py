from typing import Any
from urllib.parse import urlparse

from app.services.zap_service import ZapServiceError, ZapScanner

DEFAULT_ZAP_TARGET = "http://localhost:8080/AltoroMutual"
_RISK_CODE_MAP = {
    "3": "High",
    "2": "Medium",
    "1": "Low",
    "0": "Low",
    "-1": "Low",
}


class ZapScanError(RuntimeError):
    """Raised when an OWASP ZAP scan fails."""


def resolve_web_target(target: str | None) -> str:
    candidate = (target or DEFAULT_ZAP_TARGET).strip()
    parsed = urlparse(candidate)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ZapScanError(
            "Invalid web target. Provide a full http:// or https:// URL."
        )
    return candidate


def _normalize_risk_level(alert: dict[str, Any]) -> str:
    raw_risk = (
        str(alert.get("risk") or alert.get("riskdesc") or alert.get("riskcode") or "")
        .strip()
    )
    if not raw_risk:
        return "Low"

    normalized = raw_risk.split()[0].split("(")[0].strip().title()
    if normalized in {"High", "Medium", "Low", "Info"}:
        return normalized

    return _RISK_CODE_MAP.get(raw_risk, "Low")


def _normalize_alerts(alerts: list[dict[str, Any]]) -> list[dict[str, str]]:
    vulnerabilities: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()

    for alert in alerts:
        if not isinstance(alert, dict):
            continue

        name = str(alert.get("alert") or alert.get("name") or "Unknown").strip()
        risk = _normalize_risk_level(alert)
        url = str(
            alert.get("url") or alert.get("uri") or alert.get("instanceurl") or ""
        ).strip()
        description = str(
            alert.get("description") or alert.get("desc") or "No description provided."
        ).strip()

        vulnerability = {
            "name": name or "Unknown",
            "risk": risk,
            "url": url,
            "description": description or "No description provided.",
        }
        dedupe_key = (
            vulnerability["name"],
            vulnerability["risk"],
            vulnerability["url"],
        )
        if dedupe_key in seen:
            continue
        seen.add(dedupe_key)
        vulnerabilities.append(vulnerability)

    severity_order = {"High": 0, "Medium": 1, "Low": 2, "Info": 3}
    vulnerabilities.sort(
        key=lambda item: (
            severity_order.get(item["risk"], 4),
            item["name"].lower(),
            item["url"].lower(),
        )
    )
    return vulnerabilities


def run_zap_scan(target: str | None = None) -> dict[str, Any]:
    resolved_target = resolve_web_target(target)

    try:
        result = ZapScanner().scan_target(resolved_target)
    except ZapServiceError as exc:
        raise ZapScanError(str(exc)) from exc

    return {
        "target": result["target"],
        "total_alerts": result["total_alerts"],
        "alerts": result["alerts"],
        "vulnerabilities": _normalize_alerts(result["alerts"]),
    }
