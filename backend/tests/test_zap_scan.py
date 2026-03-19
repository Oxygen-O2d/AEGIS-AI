from pathlib import Path

from app.scanner.zap_scan import run_zap_scan
from app.services.zap_service import ZapScanner


class _FakeProgress:
    def __init__(self, scan_id: str, statuses: list[int]) -> None:
        self.scan_id = scan_id
        self.statuses = statuses
        self.index = 0

    def scan(self, target_url: str) -> str:
        self.target_url = target_url
        return self.scan_id

    def status(self, scan_id: str) -> str:
        assert scan_id == self.scan_id
        status = self.statuses[min(self.index, len(self.statuses) - 1)]
        self.index += 1
        return str(status)


class _FakeCore:
    def __init__(self, alerts: list[dict[str, str]]) -> None:
        self._alerts = alerts

    def alerts(self) -> list[dict[str, str]]:
        return self._alerts


class _FakeZapClient:
    def __init__(self, alerts: list[dict[str, str]]) -> None:
        self.opened_url: str | None = None
        self.spider = _FakeProgress("spider-1", [15, 100])
        self.ascan = _FakeProgress("ascan-1", [20, 100])
        self.core = _FakeCore(alerts)

    def urlopen(self, target_url: str) -> None:
        self.opened_url = target_url


def test_zap_scanner_runs_full_workflow_and_saves_report(tmp_path, monkeypatch) -> None:
    alerts = [
        {
            "alert": "SQL Injection",
            "risk": "High",
            "url": "http://localhost:8000/login",
            "description": "Unsanitized input reaches a SQL sink.",
        }
    ]
    fake_client = _FakeZapClient(alerts)
    monkeypatch.setattr("app.services.zap_service.time.sleep", lambda _: None)

    scanner = ZapScanner(
        reports_dir=tmp_path,
        poll_interval_seconds=0,
        zap_client=fake_client,
    )
    result = scanner.scan_target("http://localhost:8000")

    assert fake_client.opened_url == "http://localhost:8000"
    assert result == {
        "target": "http://localhost:8000",
        "total_alerts": 1,
        "alerts": alerts,
    }

    report_path = tmp_path / "localhost_8000_root.json"
    assert report_path.exists()
    assert '"total_alerts": 1' in report_path.read_text(encoding="utf-8")


def test_run_zap_scan_normalizes_alerts(monkeypatch) -> None:
    fake_result = {
        "target": "http://localhost:8080/AltoroMutual",
        "total_alerts": 2,
        "alerts": [
            {
                "alert": "SQL Injection",
                "risk": "High",
                "url": "http://localhost:8080/AltoroMutual/login.jsp",
                "description": "Unsanitized query parameter detected.",
            },
            {
                "alert": "Missing X-Frame-Options Header",
                "riskdesc": "Low",
                "url": "http://localhost:8080/AltoroMutual/",
                "desc": "Clickjacking protection header is missing.",
            },
        ],
    }

    monkeypatch.setattr(
        ZapScanner,
        "scan_target",
        lambda self, target_url: fake_result,
    )

    result = run_zap_scan("http://localhost:8080/AltoroMutual")

    assert result["target"] == "http://localhost:8080/AltoroMutual"
    assert result["total_alerts"] == 2
    assert result["alerts"] == fake_result["alerts"]
    assert result["vulnerabilities"] == [
        {
            "name": "SQL Injection",
            "risk": "High",
            "url": "http://localhost:8080/AltoroMutual/login.jsp",
            "description": "Unsanitized query parameter detected.",
        },
        {
            "name": "Missing X-Frame-Options Header",
            "risk": "Low",
            "url": "http://localhost:8080/AltoroMutual/",
            "description": "Clickjacking protection header is missing.",
        },
    ]
