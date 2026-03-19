import ipaddress
import re
import socket
import subprocess
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from typing import Any

FALLBACK_TARGET = "127.0.0.1"
AWS_IMDS_TOKEN_URL = "http://169.254.169.254/latest/api/token"
AWS_IMDS_PUBLIC_IPV4_URL = "http://169.254.169.254/latest/meta-data/public-ipv4"
AWS_IMDS_LOCAL_IPV4_URL = "http://169.254.169.254/latest/meta-data/local-ipv4"
HOSTNAME_PATTERN = re.compile(
    r"^(?=.{1,253}$)(localhost|[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)$"
)


class NmapScanError(RuntimeError):
    """Raised when Nmap execution fails."""


def is_valid_ipv4(value: str) -> bool:
    try:
        return isinstance(ipaddress.ip_address(value), ipaddress.IPv4Address)
    except ValueError:
        return False


def is_public_ipv4(value: str) -> bool:
    try:
        ip = ipaddress.ip_address(value)
        return (
            isinstance(ip, ipaddress.IPv4Address)
            and not ip.is_private
            and not ip.is_loopback
            and not ip.is_link_local
            and not ip.is_multicast
            and not ip.is_reserved
        )
    except ValueError:
        return False


def discover_local_ipv4() -> str | None:
    # UDP connect reveals the active interface without sending payload.
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            ip = sock.getsockname()[0]
            if is_valid_ipv4(ip):
                return ip
    except OSError:
        pass

    # Hostname fallback for restricted environments.
    try:
        ip = socket.gethostbyname(socket.gethostname())
        if is_valid_ipv4(ip) and not ipaddress.ip_address(ip).is_loopback:
            return ip
    except OSError:
        pass

    return None


def fetch_aws_imdsv2_token() -> str | None:
    request = urllib.request.Request(
        AWS_IMDS_TOKEN_URL,
        method="PUT",
        headers={"X-aws-ec2-metadata-token-ttl-seconds": "60"},
    )
    try:
        with urllib.request.urlopen(request, timeout=0.25) as response:
            return response.read().decode("utf-8").strip() or None
    except (urllib.error.URLError, TimeoutError, ValueError, OSError):
        return None


def fetch_aws_metadata(url: str, token: str) -> str | None:
    request = urllib.request.Request(url, headers={"X-aws-ec2-metadata-token": token})
    try:
        with urllib.request.urlopen(request, timeout=0.25) as response:
            value = response.read().decode("utf-8").strip()
            return value or None
    except (urllib.error.URLError, TimeoutError, ValueError, OSError):
        return None


def auto_detect_target_ipv4() -> str:
    local_ip = discover_local_ipv4()
    if local_ip and is_public_ipv4(local_ip):
        return local_ip

    token = fetch_aws_imdsv2_token()
    if token:
        public_ip = fetch_aws_metadata(AWS_IMDS_PUBLIC_IPV4_URL, token)
        if public_ip and is_valid_ipv4(public_ip):
            return public_ip

        local_meta_ip = fetch_aws_metadata(AWS_IMDS_LOCAL_IPV4_URL, token)
        if local_meta_ip and is_valid_ipv4(local_meta_ip):
            return local_meta_ip

    if local_ip and is_valid_ipv4(local_ip):
        return local_ip

    return FALLBACK_TARGET


def validate_target(target: str) -> str:
    cleaned = (target or "").strip()
    if not cleaned:
        return FALLBACK_TARGET

    if is_valid_ipv4(cleaned):
        return cleaned

    if HOSTNAME_PATTERN.match(cleaned):
        return cleaned

    raise NmapScanError("Invalid target. Provide a valid IPv4 address or hostname.")


def resolve_target(target: str | None) -> str:
    if target and target.strip():
        return validate_target(target)
    return auto_detect_target_ipv4()


def _execute_nmap(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        capture_output=True,
        text=True,
        check=False,
        timeout=240,
    )


def run_nmap_scan(target: str) -> tuple[str, list[str]]:
    primary_cmd = ["nmap", "-sV", "-O", "-oX", "-", target]
    fallback_cmd = ["nmap", "-sV", "-oX", "-", target]

    try:
        result = _execute_nmap(primary_cmd)
    except FileNotFoundError as exc:
        raise NmapScanError(
            "Nmap is not installed. On Ubuntu run: "
            "'sudo apt update && sudo apt install nmap -y'."
        ) from exc
    except subprocess.TimeoutExpired as exc:
        raise NmapScanError(
            "Nmap scan timed out. Try scanning a smaller target scope."
        ) from exc

    warnings: list[str] = []
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        privilege_issue = "requires root privileges" in stderr.lower()
        if privilege_issue:
            warnings.append("OS detection requires elevated privileges. Retried without -O.")
            try:
                result = _execute_nmap(fallback_cmd)
            except subprocess.TimeoutExpired as exc:
                raise NmapScanError(
                    "Nmap scan timed out. Try scanning a smaller target scope."
                ) from exc

        if result.returncode != 0:
            fallback_stderr = (result.stderr or "").strip()
            raise NmapScanError(
                f"Nmap scan failed: {fallback_stderr or stderr or 'unknown error'}"
            )

    if not result.stdout.strip():
        raise NmapScanError("Nmap returned empty XML output.")

    return result.stdout, warnings


def _extract_service_fields(service: ET.Element | None) -> tuple[str, str, str]:
    if service is None:
        return "unknown", "", ""

    service_name = (service.attrib.get("name") or "unknown").strip() or "unknown"
    product = (service.attrib.get("product") or "").strip()
    version_parts: list[str] = []
    version_value = (service.attrib.get("version") or "").strip()
    extrainfo_value = (service.attrib.get("extrainfo") or "").strip()
    if version_value:
        version_parts.append(version_value)
    if extrainfo_value:
        version_parts.append(extrainfo_value)
    return service_name, product, " ".join(version_parts)


def _extract_host_os(host: ET.Element) -> str:
    osmatch = host.find("os/osmatch")
    if osmatch is not None:
        return (osmatch.attrib.get("name") or "").strip() or "Unknown"
    return "Unknown"


def parse_nmap_xml(xml_output: str) -> list[dict[str, Any]]:
    try:
        root = ET.fromstring(xml_output)
    except ET.ParseError as exc:
        raise NmapScanError("Unable to parse Nmap XML output.") from exc

    hosts: list[dict[str, Any]] = []
    for host in root.findall("host"):
        status = host.find("status")
        if status is not None and status.attrib.get("state") not in {None, "up"}:
            continue

        host_ip = ""
        for address in host.findall("address"):
            addr = (address.attrib.get("addr") or "").strip()
            addr_type = (address.attrib.get("addrtype") or "").strip()
            if addr and addr_type == "ipv4":
                host_ip = addr
                break
            if not host_ip and addr:
                host_ip = addr

        if not host_ip:
            hostname_elem = host.find("hostnames/hostname")
            if hostname_elem is not None:
                host_ip = (hostname_elem.attrib.get("name") or "").strip()

        if not host_ip:
            continue

        services: list[dict[str, Any]] = []
        for port in host.findall("ports/port"):
            state = port.find("state")
            if state is None or state.attrib.get("state") != "open":
                continue

            port_id_raw = (port.attrib.get("portid") or "").strip()
            if not port_id_raw.isdigit():
                continue

            service_name, product, version = _extract_service_fields(port.find("service"))
            services.append(
                {
                    "port": int(port_id_raw),
                    "service": service_name,
                    "product": product,
                    "version": version,
                }
            )

        hosts.append({"host": host_ip, "os": _extract_host_os(host), "services": services})

    return hosts


def run_nmap_discovery(target: str) -> dict[str, Any]:
    xml_output, warnings = run_nmap_scan(target)
    hosts = parse_nmap_xml(xml_output)
    return {"target": target, "hosts": hosts, "warnings": warnings}

