import re
from typing import Any

MAX_ENRICHMENT_NODES = 150


def build_topology_from_nmap(hosts: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    seen_nodes: set[str] = set()

    for host_data in hosts:
        host_id = host_data["host"]
        host_os = host_data.get("os", "Unknown")
        if host_id not in seen_nodes:
            nodes.append({"id": host_id, "type": "host", "os": host_os})
            seen_nodes.add(host_id)

        for service in host_data.get("services", []):
            service_id = f"{host_id}:{service['port']}"
            if service_id not in seen_nodes:
                nodes.append(
                    {
                        "id": service_id,
                        "type": "service",
                        "port": service["port"],
                        "service": service.get("service", "unknown"),
                        "product": service.get("product", ""),
                        "version": service.get("version", ""),
                    }
                )
                seen_nodes.add(service_id)
            edges.append({"from": host_id, "to": service_id})

    return {"nodes": nodes, "edges": edges}


def build_recon_enrichment(
    events: list[dict[str, Any]],
    root_target: str,
) -> dict[str, list[dict[str, Any]]]:
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    seen_nodes: set[str] = set()
    root_id = root_target.strip()

    if root_id:
        nodes.append({"id": root_id, "type": "host"})
        seen_nodes.add(root_id)

    domain_pattern = re.compile(r"\b(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\b")
    ipv4_pattern = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")

    def add_node(node_id: str, node_type: str) -> None:
        if not node_id or node_id in seen_nodes or len(nodes) >= MAX_ENRICHMENT_NODES:
            return
        nodes.append({"id": node_id, "type": node_type})
        seen_nodes.add(node_id)
        if root_id and node_id != root_id:
            edges.append({"from": root_id, "to": node_id})

    for event in events:
        event_type = event.get("event_type", "")
        data = event.get("data", "")
        combined = f"{event_type} {data}".lower()

        for domain in domain_pattern.findall(data):
            domain = domain.lower().strip(".")
            if "subdomain" in combined:
                add_node(domain, "subdomain")
            elif "dns" in combined:
                add_node(domain, "dns_record")
            else:
                add_node(domain, "associated_host")

        for ip in ipv4_pattern.findall(data):
            add_node(ip, "related_ip")

    return {"nodes": nodes, "edges": edges}


def merge_topologies(
    base_topology: dict[str, list[dict[str, Any]]],
    enrichment_topology: dict[str, list[dict[str, Any]]],
) -> dict[str, list[dict[str, Any]]]:
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    seen_nodes: set[str] = set()
    seen_edges: set[tuple[str, str]] = set()

    for node in (base_topology.get("nodes", []) + enrichment_topology.get("nodes", [])):
        node_id = node.get("id")
        if not node_id or node_id in seen_nodes:
            continue
        nodes.append(node)
        seen_nodes.add(node_id)

    for edge in (base_topology.get("edges", []) + enrichment_topology.get("edges", [])):
        edge_from = edge.get("from")
        edge_to = edge.get("to")
        if not edge_from or not edge_to:
            continue
        key = (edge_from, edge_to)
        if key in seen_edges:
            continue
        edges.append({"from": edge_from, "to": edge_to})
        seen_edges.add(key)

    return {"nodes": nodes, "edges": edges}

