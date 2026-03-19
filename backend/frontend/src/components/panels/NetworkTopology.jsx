import React, { useMemo, useState } from 'react';
import { Activity, Search, ZoomIn, ZoomOut, RotateCcw } from 'lucide-react';

const SCAN_ENDPOINT = 'http://localhost:8000/scan-full';
const HOST_MIN_WIDTH = 130;
const HOST_MAX_WIDTH = 280;
const HOST_TEXT_PADDING = 18;
const HOST_APPROX_CHAR_WIDTH = 7;
const HOST_BOX_HEIGHT = 44;
const SERVICE_MIN_WIDTH = 170;
const SERVICE_MAX_WIDTH = 320;
const SERVICE_TEXT_PADDING = 18;
const SERVICE_APPROX_CHAR_WIDTH = 6.8;
const SERVICE_BOX_HEIGHT = 44;

function clamp(value, min, max) {
  return Math.max(min, Math.min(value, max));
}

function fitLabel(text, maxChars) {
  if (!text) return '';
  if (text.length <= maxChars) return text;
  if (maxChars <= 3) return text.slice(0, maxChars);
  return `${text.slice(0, maxChars - 3)}...`;
}

function computeHostSizing(hostId, osLabel) {
  const longest = Math.max((hostId || '').length, (osLabel || '').length);
  const boxWidth = clamp(
    HOST_TEXT_PADDING + longest * HOST_APPROX_CHAR_WIDTH,
    HOST_MIN_WIDTH,
    HOST_MAX_WIDTH,
  );
  const maxChars = Math.max(10, Math.floor((boxWidth - HOST_TEXT_PADDING) / HOST_APPROX_CHAR_WIDTH));

  return {
    boxWidth,
    idLabel: fitLabel(hostId || '', maxChars),
    osLabel: fitLabel(osLabel || 'OS unknown', maxChars),
  };
}

function computeServiceSizing(serviceName, port, metaLabel) {
  const lineOne = `${serviceName || 'unknown'}:${port}`;
  const lineTwo = metaLabel || 'product/version unknown';
  const longest = Math.max(lineOne.length, lineTwo.length);

  const boxWidth = clamp(
    SERVICE_TEXT_PADDING + longest * SERVICE_APPROX_CHAR_WIDTH,
    SERVICE_MIN_WIDTH,
    SERVICE_MAX_WIDTH,
  );
  const maxChars = Math.max(12, Math.floor((boxWidth - SERVICE_TEXT_PADDING) / SERVICE_APPROX_CHAR_WIDTH));

  return {
    boxWidth,
    lineOneLabel: fitLabel(lineOne, maxChars),
    lineTwoLabel: fitLabel(lineTwo, maxChars),
  };
}

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function extractTopology(payload) {
  if (payload?.topology?.nodes && payload?.topology?.edges) {
    return payload.topology;
  }
  return {
    nodes: payload?.nodes || [],
    edges: payload?.edges || [],
  };
}

export default function NetworkTopology({ onScanData }) {
  const [target, setTarget] = useState('');
  const [topology, setTopology] = useState({ nodes: [], edges: [] });
  const [scanStatus, setScanStatus] = useState('Manual scan idle');
  const [isScanning, setIsScanning] = useState(false);
  const [detectedIp, setDetectedIp] = useState('');
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragOrigin, setDragOrigin] = useState({ x: 0, y: 0 });

  const graphLayout = useMemo(() => {
    const hosts = (topology.nodes || []).filter((node) => node.type === 'host');
    const serviceById = new Map(
      (topology.nodes || [])
        .filter((node) => node.type === 'service')
        .map((node) => [node.id, node]),
    );

    const positionedHosts = hosts.map((host, index) => {
      const sizing = computeHostSizing(host.id, host.os || 'OS unknown');
      return {
        ...host,
        ...sizing,
        x: 150,
        y: 90 + index * 160,
      };
    });

    const positionedServices = [];
    positionedHosts.forEach((host) => {
      const hostEdges = (topology.edges || []).filter((edge) => edge.from === host.id);
      hostEdges.forEach((edge, idx) => {
        const service = serviceById.get(edge.to);
        if (!service) return;
        const meta = service.product || service.version
          ? `${service.product || ''} ${service.version || ''}`.trim()
          : 'product/version unknown';
        const sizing = computeServiceSizing(service.service, service.port, meta);

        positionedServices.push({
          ...service,
          ...sizing,
          metaLabel: meta,
          x: host.x + host.boxWidth + 52,
          y: host.y - 25 + idx * 62,
          hostId: host.id,
        });
      });
    });

    return {
      hosts: positionedHosts,
      services: positionedServices,
    };
  }, [topology]);

  const runScan = async () => {
    const cleanedTarget = target.trim();
    const autoMode = cleanedTarget.length === 0;
    setIsScanning(true);
    setScanStatus(autoMode ? 'Scanning detected server IP...' : `Scanning ${cleanedTarget}...`);

    try {
      const url = autoMode
        ? SCAN_ENDPOINT
        : `${SCAN_ENDPOINT}?target=${encodeURIComponent(cleanedTarget)}`;
      const response = await fetch(url);
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.detail || 'Network scan failed');
      }

      setTopology(extractTopology(data));
      setDetectedIp(data.detected_ip || cleanedTarget || '');
      setZoom(1);
      setPan({ x: 0, y: 0 });
      if (onScanData) onScanData(data);

      if (data.status === 'running' && data.job_id) {
        setScanStatus(data.message || 'Reconnaissance scan running...');
        await pollFullScanJob(data.job_id);
      } else {
        setScanStatus(
          data.detected_ip
            ? `Scan complete for ${data.detected_ip}`
            : `Scan complete for ${cleanedTarget || 'auto target'}`,
        );
      }
    } catch (error) {
      setScanStatus(`Scan error: ${error.message}`);
    } finally {
      setIsScanning(false);
    }
  };

  const pollFullScanJob = async (jobId) => {
    for (let attempt = 0; attempt < 120; attempt += 1) {
      await sleep(2000);
      const response = await fetch(`${SCAN_ENDPOINT}?job_id=${encodeURIComponent(jobId)}`);
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.detail || 'Full scan polling failed');
      }

      if (onScanData) onScanData(data);
      if (data.status === 'completed') {
        setTopology(extractTopology(data));
        setDetectedIp((prev) => data.detected_ip || prev);
        setScanStatus(data.message || 'Reconnaissance scan completed.');
        return;
      }

      if (data.status === 'failed') {
        setScanStatus(data.message || 'Reconnaissance scan failed.');
        return;
      }

      setScanStatus(data.message || 'Reconnaissance scan running...');
    }

    setScanStatus('Reconnaissance scan still running. Poll timed out in UI.');
  };

  const clampZoom = (value) => clamp(value, 0.5, 3);

  const handleZoomIn = () => {
    setZoom((prev) => clampZoom(prev + 0.15));
  };

  const handleZoomOut = () => {
    setZoom((prev) => clampZoom(prev - 0.15));
  };

  const resetView = () => {
    setZoom(1);
    setPan({ x: 0, y: 0 });
  };

  const handleWheel = (e) => {
    e.preventDefault();
    const delta = e.deltaY > 0 ? -0.1 : 0.1;
    setZoom((prev) => clampZoom(prev + delta));
  };

  const handleMouseDown = (e) => {
    setIsDragging(true);
    setDragOrigin({
      x: e.clientX - pan.x,
      y: e.clientY - pan.y,
    });
  };

  const handleMouseMove = (e) => {
    if (!isDragging) return;
    setPan({
      x: e.clientX - dragOrigin.x,
      y: e.clientY - dragOrigin.y,
    });
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  return (
    <div className="h-full flex flex-col bg-[#0B1018]">
      <div className="p-3 border-b border-white/5 bg-black/40 flex items-center gap-2">
        <input
          value={target}
          onChange={(e) => setTarget(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') runScan();
          }}
          placeholder="Leave blank for auto-detect or enter IP/hostname"
          className="flex-1 bg-black/60 border border-[#2A3648] rounded px-3 py-2 text-[13px] font-mono outline-none focus:border-soc-accent"
        />
        <button
          onClick={runScan}
          disabled={isScanning}
          className="px-4 py-2.5 rounded-md bg-[#0EA5E9] hover:bg-[#38BDF8] text-[#001018] text-[12px] font-black uppercase tracking-wide border border-[#7DD3FC] shadow-[0_0_18px_rgba(14,165,233,0.28)] transition-all disabled:opacity-60 disabled:shadow-none"
        >
          {isScanning ? 'Scanning...' : 'Scan Network'}
        </button>
      </div>

      <div className="px-3 py-2 text-[11px] font-mono uppercase tracking-wide text-gray-300 flex items-center gap-2 border-b border-white/5">
        <div className="flex items-center gap-2">
          <Activity size={12} />
          {scanStatus}
          {detectedIp && <span className="text-soc-accent">({detectedIp})</span>}
        </div>
        <div className="ml-auto flex items-center gap-1">
          <button
            onClick={handleZoomOut}
            className="p-1 rounded border border-white/10 hover:bg-white/10 text-gray-300"
            title="Zoom Out"
          >
            <ZoomOut size={13} />
          </button>
          <button
            onClick={handleZoomIn}
            className="p-1 rounded border border-white/10 hover:bg-white/10 text-gray-300"
            title="Zoom In"
          >
            <ZoomIn size={13} />
          </button>
          <button
            onClick={resetView}
            className="p-1 rounded border border-white/10 hover:bg-white/10 text-gray-300"
            title="Reset View"
          >
            <RotateCcw size={13} />
          </button>
          <span className="ml-1 text-[11px] text-soc-accent">{Math.round(zoom * 100)}%</span>
        </div>
      </div>

      <div
        className={`flex-1 p-3 overflow-auto ${isDragging ? 'cursor-grabbing' : 'cursor-grab'}`}
        onWheel={handleWheel}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
      >
        {(topology.nodes || []).length === 0 ? (
          <div className="h-full flex items-center justify-center text-center opacity-35">
            <div>
              <Search size={34} className="mx-auto mb-3 text-soc-accent" />
              <p className="font-mono text-[13px] uppercase tracking-[2px]">Run Scan Network to map hosts/services</p>
            </div>
          </div>
        ) : (
          <svg width="100%" height="100%" viewBox="0 0 800 500" className="min-h-[280px]">
            <g transform={`translate(${pan.x} ${pan.y}) scale(${zoom})`}>
              {graphLayout.services.map((service) => {
                const host = graphLayout.hosts.find((h) => h.id === service.hostId);
                if (!host) return null;
                return (
                  <line
                    key={`${host.id}-${service.id}`}
                    x1={host.x + host.boxWidth}
                    y1={host.y + 22}
                    x2={service.x}
                    y2={service.y + 18}
                    stroke="#334155"
                    strokeWidth="2"
                  />
                );
              })}

              {graphLayout.hosts.map((host) => (
                <g key={host.id} transform={`translate(${host.x}, ${host.y})`}>
                  <title>{`Host: ${host.id}\nOS: ${host.os || 'OS unknown'}`}</title>
                  <rect width={host.boxWidth} height={HOST_BOX_HEIGHT} rx="10" fill="#0EA5E9" fillOpacity="0.22" stroke="#38BDF8" strokeWidth="2" />
                  <text x="12" y="18" fill="#E2E8F0" fontSize="12" fontWeight="700">{host.idLabel}</text>
                  <text x="12" y="33" fill="#94A3B8" fontSize="10">
                    {host.osLabel}
                  </text>
                </g>
              ))}

              {graphLayout.services.map((service) => (
                <g key={service.id} transform={`translate(${service.x}, ${service.y})`}>
                  <title>{`${service.service || 'unknown'}:${service.port}\n${service.metaLabel}`}</title>
                  <rect width={service.boxWidth} height={SERVICE_BOX_HEIGHT} rx="10" fill="#1E293B" stroke="#F97316" strokeWidth="1.5" />
                  <text x="12" y="16" fill="#E2E8F0" fontSize="11" fontWeight="700">
                    {service.lineOneLabel}
                  </text>
                  <text x="12" y="29" fill="#94A3B8" fontSize="10">
                    {service.lineTwoLabel}
                  </text>
                </g>
              ))}
            </g>
          </svg>
        )}
      </div>
    </div>
  );
}
