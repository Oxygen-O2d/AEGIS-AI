from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.services.cloudtrail_monitor import CloudTrailMonitor


class _FakeCloudTrailClient:
    def __init__(self, events):
        self.events = events
        self.calls = 0

    def lookup_events(self, **kwargs):
        self.calls += 1
        return {"Events": self.events}


def test_cloudtrail_monitor_normalizes_events_and_detects_bruteforce() -> None:
    base_time = datetime(2026, 3, 16, 12, 0, tzinfo=timezone.utc)
    events = []
    for index in range(6):
        event_time = base_time + timedelta(seconds=index * 8)
        events.append(
            {
                "EventId": f"failed-{index}",
                "EventName": "ConsoleLogin",
                "EventTime": event_time,
                "EventSource": "signin.amazonaws.com",
                "CloudTrailEvent": (
                    '{"eventName":"ConsoleLogin","sourceIPAddress":"1.2.3.4",'
                    '"awsRegion":"us-east-1","responseElements":{"ConsoleLogin":"Failure"},'
                    '"userIdentity":{"userName":"alice"}}'
                ),
            }
        )

    events.append(
        {
            "EventId": "create-key",
            "EventName": "CreateAccessKey",
            "EventTime": base_time + timedelta(seconds=55),
            "EventSource": "iam.amazonaws.com",
            "CloudTrailEvent": (
                '{"eventName":"CreateAccessKey","sourceIPAddress":"5.6.7.8",'
                '"awsRegion":"us-east-1","userIdentity":{"userName":"admin"}}'
            ),
        }
    )

    client = _FakeCloudTrailClient(events)
    monitor = CloudTrailMonitor(
        cloudtrail_client=client,
        enable_cloudtrail=True,
        incident_store={},
        region="us-east-1",
        poll_interval_seconds=5,
        time_provider=lambda: base_time + timedelta(seconds=56),
    )

    payload = monitor.get_dashboard_payload()

    assert len(payload["events"]) == 7
    assert payload["events"][0]["event_name"] == "CreateAccessKey"
    failed_logins = [event for event in payload["events"] if event["event_name"] == "FailedConsoleLogin"]
    assert len(failed_logins) == 6
    assert payload["alerts"] == [
        {
            "alert_type": "Brute Force Attempt",
            "source_ip": "1.2.3.4",
            "attempt_count": 6,
        }
    ]


def test_cloudtrail_monitor_uses_mock_incidents_when_cloudtrail_is_disabled() -> None:
    base_time = datetime(2026, 3, 16, 12, 0, tzinfo=timezone.utc)
    incident_store = {
        "incident-1": {
            "id": "incident-1",
            "source": "AWS_CLOUDTRAIL",
            "log_content": '{"event":"Failed Console Login from attacker host","user":"demo","ip":"9.9.9.9"}',
            "timestamp": "2026-03-16T12:00:00+00:00",
        }
    }
    monitor = CloudTrailMonitor(
        enable_cloudtrail=False,
        incident_store=incident_store,
        region="us-east-1",
        poll_interval_seconds=5,
        time_provider=lambda: base_time + timedelta(seconds=5),
    )

    payload = monitor.get_dashboard_payload()

    assert payload["events"] == [
        {
            "event_id": "mock:incident-1",
            "timestamp": "2026-03-16T12:00:00+00:00",
            "event_name": "FailedConsoleLogin",
            "source_ip": "9.9.9.9",
            "username": "demo",
            "aws_region": "us-east-1",
            "event_source": "signin.amazonaws.com",
            "status": "Failure",
        }
    ]
    assert payload["alerts"] == []
