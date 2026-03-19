from app.scanner.alert_processor import calculate_security_score


def test_security_score_uses_requested_weights_and_clamps() -> None:
    vulnerabilities = [
        {"risk": "High"},
        {"risk": "Medium"},
        {"risk": "Low"},
        {"risk": "Info"},
    ]

    assert calculate_security_score(vulnerabilities) == 65

    repeated_highs = [{"risk": "High"} for _ in range(8)]
    assert calculate_security_score(repeated_highs) == 0
