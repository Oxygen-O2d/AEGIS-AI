from __future__ import annotations

import json
import logging
import os
import time
import urllib.error
import urllib.request
from collections import defaultdict, deque
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from threading import Lock
from typing import Any, Callable

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from app.database import incident_db

logger = logging.getLogger(__name__)

AWS_IMDS_TOKEN_URL = "http://169.254.169.254/latest/api/token"
AWS_IMDS_IDENTITY_DOCUMENT_URL = (
    "http://169.254.169.254/latest/dynamic/instance-identity/document"
)
DEFAULT_REGION = "us-east-1"
DEFAULT_POLL_INTERVAL_SECONDS = 5
DEFAULT_LOOKBACK_SECONDS = 10 * 60
BRUTE_FORCE_WINDOW_SECONDS = 60
BRUTE_FORCE_THRESHOLD = 5
MAX_EVENT_CACHE_SIZE = 200
MAX_LOOKUP_EVENTS = 50
MAX_LOOKUP_PAGES = 3
MOCK_SOURCE = "AWS_CLOUDTRAIL"

MONITORED_EVENT_NAMES = {
    "ConsoleLogin",
    "CreateAccessKey",
    "AuthorizeSecurityGroupIngress",
    "RunInstances",
    "StopInstances",
    "AttachRolePolicy",
    "FailedConsoleLogin",
}


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _parse_datetime(value: str | datetime | None) -> datetime | None:
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc)
    if not value:
        return None
    text = value.strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = f"{text[:-1]}+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _safe_json_loads(payload: str | dict[str, Any] | None) -> dict[str, Any]:
    if isinstance(payload, dict):
        return payload
    if not payload:
        return {}
    try:
        parsed = json.loads(payload)
    except (TypeError, json.JSONDecodeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _isoformat(value: datetime | None) -> str:
    return (value or _utc_now()).astimezone(timezone.utc).isoformat()


def _normalize_status(
    event_name: str,
    response_elements: dict[str, Any],
    error_code: str,
    error_message: str,
) -> str:
    if event_name == "FailedConsoleLogin":
        return "Failure"
    console_status = (
        response_elements.get("ConsoleLogin")
        or response_elements.get("consoleLogin")
        or ""
    )
    if isinstance(console_status, str) and console_status:
        return "Success" if console_status.lower() == "success" else "Failure"
    if error_code or error_message:
        return "Failure"
    return "Success"


def _username_from_identity(
    event_username: str | None,
    user_identity: dict[str, Any],
    fallback_payload: dict[str, Any],
) -> str:
    if event_username:
        return event_username

    for key in ("userName", "username"):
        value = user_identity.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()

    session_context = user_identity.get("sessionContext", {})
    if isinstance(session_context, dict):
        session_issuer = session_context.get("sessionIssuer", {})
        if isinstance(session_issuer, dict):
            value = session_issuer.get("userName")
            if isinstance(value, str) and value.strip():
                return value.strip()

    arn = user_identity.get("arn")
    if isinstance(arn, str) and arn.strip():
        return arn.rsplit("/", 1)[-1]

    for key in ("user", "username", "role"):
        value = fallback_payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()

    return "unknown"


class CloudTrailMonitor:
    def __init__(
        self,
        *,
        poll_interval_seconds: int = DEFAULT_POLL_INTERVAL_SECONDS,
        lookback_seconds: int = DEFAULT_LOOKBACK_SECONDS,
        brute_force_threshold: int = BRUTE_FORCE_THRESHOLD,
        brute_force_window_seconds: int = BRUTE_FORCE_WINDOW_SECONDS,
        cloudtrail_client: Any | None = None,
        incident_store: dict[str, dict[str, Any]] | None = None,
        region: str | None = None,
        metadata_timeout_seconds: float = 0.5,
        time_provider: Callable[[], datetime] | None = None,
        enable_cloudtrail: bool = True,
    ) -> None:
        self.poll_interval_seconds = max(1, poll_interval_seconds)
        self.lookback_seconds = max(self.poll_interval_seconds, lookback_seconds)
        self.brute_force_threshold = max(1, brute_force_threshold)
        self.brute_force_window_seconds = max(1, brute_force_window_seconds)
        self._cloudtrail_client = cloudtrail_client
        self._incident_store = incident_store if incident_store is not None else incident_db
        self._region = region
        self._metadata_timeout_seconds = metadata_timeout_seconds
        self._time_provider = time_provider or _utc_now
        self._enable_cloudtrail = enable_cloudtrail
        self._lock = Lock()
        self._last_poll_monotonic = 0.0
        self._last_lookup_time: datetime | None = None
        self._event_cache: list[dict[str, Any]] = []
        self._alert_cache: list[dict[str, Any]] = []
        self._seen_event_ids: dict[str, datetime] = {}
        self._metadata_available: bool | None = None

    @property
    def region(self) -> str:
        if self._region:
            return self._region
        self._region = self._detect_region()
        return self._region

    def _detect_region(self) -> str:
        token_request = urllib.request.Request(
            AWS_IMDS_TOKEN_URL,
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
        )
        try:
            with urllib.request.urlopen(
                token_request,
                timeout=self._metadata_timeout_seconds,
            ) as response:
                token = response.read().decode("utf-8").strip()
            self._metadata_available = True
        except (urllib.error.URLError, TimeoutError, ValueError, OSError) as exc:
            self._metadata_available = False
            fallback = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or DEFAULT_REGION
            logger.info(
                "EC2 metadata unavailable for region detection. Using fallback region %s. (%s)",
                fallback,
                exc,
            )
            return fallback

        document_request = urllib.request.Request(
            AWS_IMDS_IDENTITY_DOCUMENT_URL,
            headers={"X-aws-ec2-metadata-token": token},
        )
        try:
            with urllib.request.urlopen(
                document_request,
                timeout=self._metadata_timeout_seconds,
            ) as response:
                document = json.loads(response.read().decode("utf-8"))
        except (
            urllib.error.URLError,
            TimeoutError,
            ValueError,
            OSError,
            json.JSONDecodeError,
        ) as exc:
            fallback = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or DEFAULT_REGION
            logger.warning(
                "Unable to parse EC2 instance identity document. Using fallback region %s. (%s)",
                fallback,
                exc,
            )
            return fallback

        region = str(document.get("region") or "").strip()
        if region:
            return region

        fallback = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or DEFAULT_REGION
        logger.warning("EC2 identity document did not contain a region. Using %s.", fallback)
        return fallback

    def _get_client(self) -> Any | None:
        if not self._enable_cloudtrail:
            return None
        if self._cloudtrail_client is not None:
            return self._cloudtrail_client
        if not self._should_use_aws_client():
            return None
        try:
            self._cloudtrail_client = boto3.client("cloudtrail", region_name=self.region)
        except (BotoCoreError, ClientError, RuntimeError, ValueError) as exc:
            logger.warning("Unable to create CloudTrail client: %s", exc)
            self._cloudtrail_client = None
        return self._cloudtrail_client

    def _should_use_aws_client(self) -> bool:
        credential_env_vars = (
            os.getenv("AWS_ACCESS_KEY_ID"),
            os.getenv("AWS_PROFILE"),
            os.getenv("AWS_WEB_IDENTITY_TOKEN_FILE"),
            os.getenv("AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"),
            os.getenv("AWS_CONTAINER_CREDENTIALS_FULL_URI"),
        )
        if any(credential_env_vars):
            return True
        if self._metadata_available is True:
            return True
        if self._metadata_available is None:
            _ = self.region
        return self._metadata_available is True

    def get_live_events(self) -> list[dict[str, Any]]:
        return self.get_dashboard_payload()["events"]

    def get_dashboard_payload(self) -> dict[str, list[dict[str, Any]]]:
        with self._lock:
            now_monotonic = time.monotonic()
            if now_monotonic - self._last_poll_monotonic < self.poll_interval_seconds:
                return {
                    "events": deepcopy(self._event_cache),
                    "alerts": deepcopy(self._alert_cache),
                }

            events: list[dict[str, Any]] = []
            events.extend(self._fetch_cloudtrail_events())
            events.extend(self._fetch_mock_events())

            if events:
                self._merge_events(events)
            self._prune_event_cache()

            self._alert_cache = self._build_brute_force_alerts()
            self._last_poll_monotonic = now_monotonic
            return {
                "events": deepcopy(self._event_cache),
                "alerts": deepcopy(self._alert_cache),
            }

    def _fetch_cloudtrail_events(self) -> list[dict[str, Any]]:
        client = self._get_client()
        if client is None:
            return []

        now = self._time_provider()
        overlap = timedelta(seconds=self.brute_force_window_seconds)
        start_time = max(
            now - timedelta(seconds=self.lookback_seconds),
            (self._last_lookup_time or now) - overlap,
        )
        fetched: list[dict[str, Any]] = []
        next_token: str | None = None
        pages_read = 0

        while pages_read < MAX_LOOKUP_PAGES:
            params: dict[str, Any] = {
                "StartTime": start_time,
                "EndTime": now,
                "MaxResults": MAX_LOOKUP_EVENTS,
            }
            if next_token:
                params["NextToken"] = next_token

            try:
                response = client.lookup_events(**params)
            except (BotoCoreError, ClientError) as exc:
                logger.exception("CloudTrail lookup_events failed: %s", exc)
                return []

            for event in response.get("Events", []):
                normalized = self._normalize_cloudtrail_event(event)
                if normalized:
                    fetched.append(normalized)

            next_token = response.get("NextToken")
            pages_read += 1
            if not next_token:
                break

        self._last_lookup_time = now
        return fetched

    def _fetch_mock_events(self) -> list[dict[str, Any]]:
        recent_cutoff = self._time_provider() - timedelta(seconds=self.lookback_seconds)
        mock_events: list[dict[str, Any]] = []

        for incident_id, incident in list(self._incident_store.items()):
            if incident.get("source") != MOCK_SOURCE:
                continue

            timestamp = _parse_datetime(incident.get("timestamp"))
            if timestamp and timestamp < recent_cutoff:
                continue

            normalized = self._normalize_mock_incident(incident_id, incident, timestamp)
            if normalized:
                mock_events.append(normalized)

        return mock_events

    def _normalize_cloudtrail_event(self, event: dict[str, Any]) -> dict[str, Any] | None:
        payload = _safe_json_loads(event.get("CloudTrailEvent"))
        event_name = str(event.get("EventName") or payload.get("eventName") or "").strip()
        response_elements = payload.get("responseElements", {})
        if not isinstance(response_elements, dict):
            response_elements = {}

        status = _normalize_status(
            event_name=event_name,
            response_elements=response_elements,
            error_code=str(payload.get("errorCode") or ""),
            error_message=str(payload.get("errorMessage") or ""),
        )
        if event_name == "ConsoleLogin" and status == "Failure":
            event_name = "FailedConsoleLogin"

        if event_name not in MONITORED_EVENT_NAMES:
            return None

        username = _username_from_identity(
            event.get("Username"),
            payload.get("userIdentity", {}) if isinstance(payload.get("userIdentity"), dict) else {},
            payload,
        )
        source_ip = (
            payload.get("sourceIPAddress")
            or payload.get("sourceIpAddress")
            or event.get("CloudTrailEventSourceIp")
            or "unknown"
        )
        normalized_time = _parse_datetime(event.get("EventTime")) or self._time_provider()
        event_id = str(event.get("EventId") or payload.get("eventID") or "").strip()
        if not event_id:
            event_id = f"{event_name}:{username}:{source_ip}:{int(normalized_time.timestamp())}"

        return {
            "event_id": event_id,
            "timestamp": _isoformat(normalized_time),
            "event_name": event_name,
            "source_ip": str(source_ip),
            "username": username,
            "aws_region": str(payload.get("awsRegion") or event.get("AwsRegion") or self.region),
            "event_source": str(
                event.get("EventSource") or payload.get("eventSource") or "unknown"
            ),
            "status": status,
        }

    def _normalize_mock_incident(
        self,
        incident_id: str,
        incident: dict[str, Any],
        timestamp: datetime | None,
    ) -> dict[str, Any] | None:
        payload = _safe_json_loads(incident.get("log_content"))
        log_content = str(incident.get("log_content") or "")
        event_description = str(payload.get("event") or log_content)
        lowered = event_description.lower()

        event_name = self._infer_mock_event_name(event_description)
        if event_name is None:
            logger.debug("Skipping unsupported mock CloudTrail event: %s", event_description)
            return None

        status = "Failure" if "failed" in lowered or "failure" in lowered else "Success"
        if event_name == "FailedConsoleLogin":
            status = "Failure"

        username = _username_from_identity("", {}, payload)
        source_ip = str(payload.get("ip") or payload.get("source_ip") or "unknown")
        event_source = str(payload.get("event_source") or "signin.amazonaws.com")
        if event_name not in {"ConsoleLogin", "FailedConsoleLogin"}:
            event_source = str(payload.get("event_source") or "mock.cloudtrail.amazonaws.com")

        return {
            "event_id": f"mock:{incident_id}",
            "timestamp": _isoformat(timestamp),
            "event_name": event_name,
            "source_ip": source_ip,
            "username": username,
            "aws_region": str(payload.get("aws_region") or self.region),
            "event_source": event_source,
            "status": status,
        }

    def _infer_mock_event_name(self, event_description: str) -> str | None:
        lowered = event_description.lower()
        direct_matches = {
            "failedconsolelogin": "FailedConsoleLogin",
            "createaccesskey": "CreateAccessKey",
            "authorizesecuritygroupingress": "AuthorizeSecurityGroupIngress",
            "runinstances": "RunInstances",
            "stopinstances": "StopInstances",
            "attachrolepolicy": "AttachRolePolicy",
            "consolelogin": "ConsoleLogin",
        }
        compact = lowered.replace(" ", "")
        for keyword, event_name in direct_matches.items():
            if keyword in compact:
                return event_name
        if "console login" in lowered or "login" in lowered:
            return "FailedConsoleLogin" if "failed" in lowered or "failure" in lowered else "ConsoleLogin"
        return None

    def _merge_events(self, events: list[dict[str, Any]]) -> None:
        cutoff = self._time_provider() - timedelta(seconds=max(self.lookback_seconds, 3600))
        for event_id, seen_at in list(self._seen_event_ids.items()):
            if seen_at < cutoff:
                self._seen_event_ids.pop(event_id, None)

        combined = list(self._event_cache)
        for event in events:
            event_id = str(event.get("event_id") or "").strip()
            event_time = _parse_datetime(event.get("timestamp")) or self._time_provider()
            if event_id and event_id in self._seen_event_ids:
                continue
            if event_id:
                self._seen_event_ids[event_id] = event_time
            combined.append(event)

        combined.sort(
            key=lambda item: _parse_datetime(item.get("timestamp")) or _utc_now(),
            reverse=True,
        )
        self._event_cache = combined[:MAX_EVENT_CACHE_SIZE]

    def _prune_event_cache(self) -> None:
        now = self._time_provider()
        cutoff = now - timedelta(seconds=max(self.lookback_seconds, 3600))
        self._event_cache = [
            event
            for event in self._event_cache
            if (_parse_datetime(event.get("timestamp")) or now) >= cutoff
        ][:MAX_EVENT_CACHE_SIZE]

    def _build_brute_force_alerts(self) -> list[dict[str, Any]]:
        attempts_by_ip: dict[str, deque[datetime]] = defaultdict(deque)
        alerts_by_ip: dict[str, dict[str, Any]] = {}

        ordered_events = sorted(
            self._event_cache,
            key=lambda item: _parse_datetime(item.get("timestamp")) or _utc_now(),
        )
        window = timedelta(seconds=self.brute_force_window_seconds)

        for event in ordered_events:
            if event.get("event_name") != "FailedConsoleLogin":
                continue

            source_ip = str(event.get("source_ip") or "unknown")
            event_time = _parse_datetime(event.get("timestamp")) or self._time_provider()
            attempts = attempts_by_ip[source_ip]

            while attempts and event_time - attempts[0] > window:
                attempts.popleft()

            attempts.append(event_time)
            if len(attempts) > self.brute_force_threshold:
                alerts_by_ip[source_ip] = {
                    "alert_type": "Brute Force Attempt",
                    "source_ip": source_ip,
                    "attempt_count": len(attempts),
                }
        return list(alerts_by_ip.values())


_DEFAULT_MONITOR: CloudTrailMonitor | None = None


def get_monitor() -> CloudTrailMonitor:
    global _DEFAULT_MONITOR
    if _DEFAULT_MONITOR is None:
        _DEFAULT_MONITOR = CloudTrailMonitor()
    return _DEFAULT_MONITOR


def get_live_events() -> list[dict[str, Any]]:
    return get_monitor().get_live_events()
