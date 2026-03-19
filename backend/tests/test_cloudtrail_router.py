from app.routers import cloudtrail


class _FakeMonitor:
    def get_dashboard_payload(self):
        return {
            "events": [{"event_name": "ConsoleLogin"}],
            "alerts": [{"alert_type": "Brute Force Attempt"}],
        }


def test_cloudtrail_endpoint_returns_dashboard_payload(monkeypatch) -> None:
    monkeypatch.setattr(cloudtrail, "get_monitor", lambda: _FakeMonitor())

    payload = cloudtrail.get_cloudtrail_events()

    assert payload == {
        "events": [{"event_name": "ConsoleLogin"}],
        "alerts": [{"alert_type": "Brute Force Attempt"}],
    }
