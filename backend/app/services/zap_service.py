import json
import logging
import re
import time
from pathlib import Path
from typing import Any, Callable
from urllib.parse import urlparse

from zapv2 import ZAPv2

ZAP_PROXY = "http://127.0.0.1:8080"
DEFAULT_ZAP_TIMEOUT_SECONDS = 900
DEFAULT_POLL_INTERVAL_SECONDS = 2.0
DEFAULT_REPORTS_DIR = Path(__file__).resolve().parents[2] / "zap_reports"

logger = logging.getLogger(__name__)


class ZapServiceError(RuntimeError):
    """Raised when a ZAP API workflow fails."""


class ZapScanner:
    def __init__(
        self,
        proxy: str = ZAP_PROXY,
        timeout_seconds: int = DEFAULT_ZAP_TIMEOUT_SECONDS,
        poll_interval_seconds: float = DEFAULT_POLL_INTERVAL_SECONDS,
        reports_dir: str | Path = DEFAULT_REPORTS_DIR,
        zap_client: ZAPv2 | None = None,
    ) -> None:
        self.proxy = proxy
        self.timeout_seconds = timeout_seconds
        self.poll_interval_seconds = poll_interval_seconds
        self.reports_dir = Path(reports_dir)
        self.zap = zap_client or ZAPv2(
            apikey="",
            proxies={"http": self.proxy, "https": self.proxy},
        )

    def scan_target(self, target_url: str) -> dict[str, Any]:
        normalized_target = self._validate_target_url(target_url)
        deadline = time.monotonic() + self.timeout_seconds

        logger.info("Starting ZAP scan for %s via %s", normalized_target, self.proxy)

        try:
            self.zap.urlopen(normalized_target)
            logger.info("Target %s opened successfully in ZAP", normalized_target)

            spider_scan_id = self.zap.spider.scan(normalized_target)
            logger.info(
                "Spider scan started for %s with scan id %s",
                normalized_target,
                spider_scan_id,
            )
            self._wait_for_completion(
                status_getter=lambda: self.zap.spider.status(spider_scan_id),
                scan_name="spider",
                target_url=normalized_target,
                deadline=deadline,
            )

            active_scan_id = self.zap.ascan.scan(normalized_target)
            logger.info(
                "Active scan started for %s with scan id %s",
                normalized_target,
                active_scan_id,
            )
            self._wait_for_completion(
                status_getter=lambda: self.zap.ascan.status(active_scan_id),
                scan_name="active",
                target_url=normalized_target,
                deadline=deadline,
            )

            raw_alerts = self.zap.core.alerts()
            filtered_alerts = self._filter_alerts_for_target(normalized_target, raw_alerts)
            result = {
                "target": normalized_target,
                "total_alerts": len(filtered_alerts),
                "alerts": filtered_alerts,
            }
            report_path = self._save_report(normalized_target, result)
            logger.info(
                "ZAP scan completed for %s with %s alerts saved to %s",
                normalized_target,
                result["total_alerts"],
                report_path,
            )
            return result
        except ZapServiceError:
            raise
        except Exception as exc:  # noqa: BLE001
            logger.exception("Unexpected ZAP scan failure for %s", normalized_target)
            raise ZapServiceError(f"ZAP scan failed: {exc}") from exc

    @staticmethod
    def _validate_target_url(target_url: str) -> str:
        candidate = (target_url or "").strip()
        parsed = urlparse(candidate)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ZapServiceError(
                "Invalid target URL. Provide a full http:// or https:// URL."
            )
        return candidate

    def _wait_for_completion(
        self,
        status_getter: Callable[[], Any],
        scan_name: str,
        target_url: str,
        deadline: float,
    ) -> None:
        last_status: int | None = None
        while True:
            if time.monotonic() > deadline:
                raise ZapServiceError(
                    f"ZAP {scan_name} scan timed out after {self.timeout_seconds} seconds for {target_url}."
                )

            try:
                status = int(status_getter())
            except Exception as exc:  # noqa: BLE001
                raise ZapServiceError(
                    f"Unable to read ZAP {scan_name} status for {target_url}: {exc}"
                ) from exc

            if status != last_status:
                logger.info("%s scan progress for %s: %s%%", scan_name.title(), target_url, status)
                last_status = status

            if status >= 100:
                return

            time.sleep(self.poll_interval_seconds)

    def _save_report(self, target_url: str, result: dict[str, Any]) -> Path:
        self.reports_dir.mkdir(parents=True, exist_ok=True)
        report_path = self.reports_dir / f"{self._build_report_name(target_url)}.json"
        report_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
        return report_path

    @staticmethod
    def _build_report_name(target_url: str) -> str:
        parsed = urlparse(target_url)
        host = re.sub(r"[^A-Za-z0-9]+", "_", parsed.netloc).strip("_")
        path = re.sub(r"[^A-Za-z0-9]+", "_", parsed.path.strip("/")).strip("_")
        if not path:
            path = "root"
        return f"{host}_{path}".lower()

    @staticmethod
    def _filter_alerts_for_target(
        target_url: str,
        alerts: list[dict[str, Any]] | Any,
    ) -> list[dict[str, Any]]:
        if not isinstance(alerts, list):
            return []

        parsed_target = urlparse(target_url)
        target_netloc = parsed_target.netloc.lower()
        filtered: list[dict[str, Any]] = []

        for alert in alerts:
            if not isinstance(alert, dict):
                continue

            alert_url = str(
                alert.get("url")
                or alert.get("uri")
                or alert.get("instanceurl")
                or ""
            ).strip()
            if not alert_url:
                filtered.append(alert)
                continue

            parsed_alert = urlparse(alert_url)
            if parsed_alert.netloc.lower() == target_netloc:
                filtered.append(alert)

        return filtered


def scan_target(target_url: str) -> dict[str, Any]:
    return ZapScanner().scan_target(target_url)
