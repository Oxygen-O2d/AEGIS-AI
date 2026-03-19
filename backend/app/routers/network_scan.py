from datetime import datetime, timezone
from threading import Lock
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, HTTPException, Query

from app.scanner.alert_processor import build_web_scan_dashboard
from app.scanner.nmap_scan import NmapScanError, resolve_target, run_nmap_discovery
from app.scanner.topology_builder import build_topology_from_nmap
from app.scanner.zap_scan import (
    DEFAULT_ZAP_TARGET,
    ZapScanError,
    resolve_web_target,
    run_zap_scan,
)

router = APIRouter()

_JOB_LOCK = Lock()
_FULL_JOBS: dict[str, dict[str, Any]] = {}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _raise_nmap_http(error: NmapScanError) -> None:
    detail = str(error)
    if detail.startswith("Invalid target"):
        raise HTTPException(status_code=400, detail=detail)
    if "timed out" in detail.lower():
        raise HTTPException(status_code=504, detail=detail)
    raise HTTPException(status_code=500, detail=detail)


def _raise_zap_http(error: ZapScanError) -> None:
    detail = str(error)
    if detail.startswith("Invalid web target"):
        raise HTTPException(status_code=400, detail=detail)
    if "timed out" in detail.lower():
        raise HTTPException(status_code=504, detail=detail)
    raise HTTPException(status_code=500, detail=detail)


def _default_web_scan_payload(web_target: str) -> dict[str, Any]:
    return {
        "web_target": web_target,
        "vulnerabilities": [],
        "alerts": [],
        "intelligence_stream": [],
        "severity_counts": {"high": 0, "medium": 0, "low": 0},
        "security_score": 100,
        "web_scan_status": "idle",
    }


def _get_job(store: dict[str, dict[str, Any]], job_id: str) -> dict[str, Any]:
    with _JOB_LOCK:
        job = store.get(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found.")
        return dict(job)


def _set_job(store: dict[str, dict[str, Any]], job_id: str, payload: dict[str, Any]) -> None:
    with _JOB_LOCK:
        store[job_id] = payload


def _update_job(
    store: dict[str, dict[str, Any]],
    job_id: str,
    updates: dict[str, Any],
) -> None:
    with _JOB_LOCK:
        if job_id not in store:
            return
        store[job_id].update(updates)
        store[job_id]["updated_at"] = _utc_now()


def _run_full_job(
    job_id: str,
    web_target: str,
    base_topology: dict[str, list[dict[str, Any]]],
    warnings: list[str],
) -> None:
    try:
        zap_result = run_zap_scan(web_target)
        dashboard_payload = build_web_scan_dashboard(zap_result["vulnerabilities"])

        _update_job(
            _FULL_JOBS,
            job_id,
            {
                "status": "completed",
                "message": "Full scan completed.",
                "topology": base_topology,
                "warnings": warnings,
                "web_scan_status": "completed",
                "web_target": zap_result["target"],
                "vulnerabilities": zap_result["vulnerabilities"],
                **dashboard_payload,
            },
        )
    except ZapScanError as error:
        _update_job(
            _FULL_JOBS,
            job_id,
            {
                "status": "failed",
                "message": str(error),
                "error": str(error),
                "topology": base_topology,
                "warnings": warnings,
                **_default_web_scan_payload(web_target),
                "web_scan_status": "failed",
            },
        )
    except Exception as error:  # noqa: BLE001
        _update_job(
            _FULL_JOBS,
            job_id,
            {
                "status": "failed",
                "message": "Unexpected full scan processing error.",
                "error": str(error),
                "topology": base_topology,
                "warnings": warnings,
                **_default_web_scan_payload(web_target),
                "web_scan_status": "failed",
            },
        )


@router.get("/scan-network")
def scan_network(
    target: str | None = Query(
        default=None,
        description="Optional override target. If omitted, server IPv4 is auto-detected.",
    ),
) -> dict[str, Any]:
    try:
        resolved_target = resolve_target(target)
        nmap_result = run_nmap_discovery(resolved_target)
    except NmapScanError as error:
        _raise_nmap_http(error)

    topology = build_topology_from_nmap(nmap_result["hosts"])
    return {
        "detected_ip": resolved_target,
        "nodes": topology["nodes"],
        "edges": topology["edges"],
        "warnings": nmap_result["warnings"],
    }


@router.get("/scan-web")
def scan_web(
    target: str | None = Query(
        default=None,
        description="Optional web URL target. Defaults to AltoroMutual.",
    ),
) -> dict[str, Any]:
    try:
        resolved_target = resolve_web_target(target)
        zap_result = run_zap_scan(resolved_target)
    except ZapScanError as error:
        _raise_zap_http(error)

    dashboard_payload = build_web_scan_dashboard(zap_result["vulnerabilities"])
    return {
        "target": zap_result["target"],
        "vulnerabilities": zap_result["vulnerabilities"],
        **dashboard_payload,
    }


@router.get("/scan-full")
def scan_full(
    background_tasks: BackgroundTasks,
    target: str | None = Query(default=None, description="Optional network target."),
    web_target: str | None = Query(
        default=None,
        description=(
            "Optional web URL target for OWASP ZAP. Defaults to "
            f"{DEFAULT_ZAP_TARGET}."
        ),
    ),
    job_id: str | None = Query(default=None, description="Poll existing full-scan job."),
) -> dict[str, Any]:
    if job_id:
        return _get_job(_FULL_JOBS, job_id)

    try:
        resolved_target = resolve_target(target)
        resolved_web_target = resolve_web_target(web_target)
        nmap_result = run_nmap_discovery(resolved_target)
    except NmapScanError as error:
        _raise_nmap_http(error)
    except ZapScanError as error:
        _raise_zap_http(error)

    base_topology = build_topology_from_nmap(nmap_result["hosts"])
    new_job_id = uuid4().hex

    payload = {
        "job_id": new_job_id,
        "status": "running",
        "message": "Network discovery complete. OWASP ZAP web scan running...",
        "detected_ip": resolved_target,
        "topology": base_topology,
        "warnings": nmap_result["warnings"],
        "created_at": _utc_now(),
        "updated_at": _utc_now(),
        **_default_web_scan_payload(resolved_web_target),
    }
    payload["web_scan_status"] = "running"
    _set_job(_FULL_JOBS, new_job_id, payload)
    background_tasks.add_task(
        _run_full_job,
        new_job_id,
        resolved_web_target,
        base_topology,
        nmap_result["warnings"],
    )
    return payload
