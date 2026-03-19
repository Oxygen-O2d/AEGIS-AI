from fastapi import BackgroundTasks

from app.routers import network_scan


def test_scan_web_returns_structured_zap_results(monkeypatch) -> None:
    fake_result = {
        "target": "http://localhost:8080/AltoroMutual",
        "vulnerabilities": [
            {
                "name": "SQL Injection",
                "risk": "High",
                "url": "http://localhost:8080/AltoroMutual/login.jsp",
                "description": "Unsanitized input reaches a SQL sink.",
            },
            {
                "name": "Missing Anti-clickjacking Header",
                "risk": "Low",
                "url": "http://localhost:8080/AltoroMutual/",
                "description": "X-Frame-Options header is missing.",
            },
        ],
    }

    monkeypatch.setattr(
        network_scan,
        "resolve_web_target",
        lambda target: target or fake_result["target"],
    )
    monkeypatch.setattr(network_scan, "run_zap_scan", lambda target: fake_result)

    payload = network_scan.scan_web(target=None)

    assert payload["target"] == "http://localhost:8080/AltoroMutual"
    assert payload["vulnerabilities"] == fake_result["vulnerabilities"]
    assert payload["alerts"] == [fake_result["vulnerabilities"][0]]
    assert payload["intelligence_stream"] == [fake_result["vulnerabilities"][1]]
    assert payload["severity_counts"] == {"high": 1, "medium": 0, "low": 1}
    assert payload["security_score"] == 75


def test_scan_full_keeps_nmap_and_adds_zap_results(monkeypatch) -> None:
    fake_nmap = {
        "hosts": [
            {
                "host": "127.0.0.1",
                "os": "Linux",
                "services": [
                    {"port": 8080, "service": "http", "product": "Tomcat", "version": "9.0"}
                ],
            }
        ],
        "warnings": [],
    }
    fake_zap = {
        "target": "http://localhost:8080/AltoroMutual",
        "vulnerabilities": [
            {
                "name": "SQL Injection",
                "risk": "High",
                "url": "http://localhost:8080/AltoroMutual/login.jsp",
                "description": "Unsanitized input reaches a SQL sink.",
            }
        ],
    }

    monkeypatch.setattr(network_scan, "resolve_target", lambda target: target or "127.0.0.1")
    monkeypatch.setattr(
        network_scan,
        "resolve_web_target",
        lambda target: target or "http://localhost:8080/AltoroMutual",
    )
    monkeypatch.setattr(network_scan, "run_nmap_discovery", lambda target: fake_nmap)
    monkeypatch.setattr(network_scan, "run_zap_scan", lambda target: fake_zap)

    background_tasks = BackgroundTasks()
    initial_payload = network_scan.scan_full(
        background_tasks,
        target=None,
        web_target=None,
        job_id=None,
    )

    assert initial_payload["status"] == "running"
    assert initial_payload["detected_ip"] == "127.0.0.1"
    assert initial_payload["web_target"] == "http://localhost:8080/AltoroMutual"

    network_scan._run_full_job(  # noqa: SLF001
        initial_payload["job_id"],
        initial_payload["web_target"],
        initial_payload["topology"],
        initial_payload["warnings"],
    )
    final_payload = network_scan.scan_full(
        BackgroundTasks(),
        target=None,
        web_target=None,
        job_id=initial_payload["job_id"],
    )

    assert final_payload["status"] == "completed"
    assert final_payload["web_scan_status"] == "completed"
    assert final_payload["vulnerabilities"] == fake_zap["vulnerabilities"]
    assert final_payload["alerts"] == fake_zap["vulnerabilities"]
    assert final_payload["intelligence_stream"] == []
    assert final_payload["severity_counts"] == {"high": 1, "medium": 0, "low": 0}
    assert final_payload["security_score"] == 80
    assert final_payload["topology"]["nodes"] == [
        {"id": "127.0.0.1", "type": "host", "os": "Linux"},
        {
            "id": "127.0.0.1:8080",
            "type": "service",
            "port": 8080,
            "service": "http",
            "product": "Tomcat",
            "version": "9.0",
        },
    ]
