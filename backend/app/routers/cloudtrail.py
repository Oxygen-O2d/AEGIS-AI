from __future__ import annotations

from fastapi import APIRouter

from app.services.cloudtrail_monitor import get_monitor

router = APIRouter()


@router.get("/security/cloudtrail")
def get_cloudtrail_events() -> dict[str, list[dict[str, Any]]]:
    payload = get_monitor().get_dashboard_payload()
    return {
        "events": payload["events"],
        "alerts": payload["alerts"],
    }
