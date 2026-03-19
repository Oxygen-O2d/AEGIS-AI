import React, { useState, useEffect, useCallback, useRef } from 'react'
import { marked } from 'marked'
import { 
  Loader2, 
  Zap, 
  Activity, 
  Terminal, 
  ShieldAlert, 
  AlertTriangle 
} from 'lucide-react'

// --- Component Imports (Ensuring paths are direct from src) ---
import Topbar from './components/layout/Topbar'
import ThreatFeed from './components/panels/ThreatFeed'
import NetworkTopology from './components/panels/NetworkTopology'
import SecurityStatus from './components/panels/SecurityStatus'
import RemediationPlan from './components/panels/RemediationPlan'
import ResizeHandle from './components/layout/ResizeHandle'
import { calculateSecurityScore } from './utils/securityScore'

const API_URL = "http://127.0.0.1:8000/api/v1/alerts";

// 🟢 FIX 1: Removed emoji-killing regex so 🚨, 🔍, and 🛡️ can appear
function sanitizeForensicReport(rawReport) {
  const fallback = '# No Forensic Data Available';
  const report = rawReport || fallback;

  return report
    .replace(/\uFE0F/g, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// 🟢 FIX 2: Removed emoji-killing regex here too
function sanitizeText(value) {
  return String(value || '')
    .replace(/\uFE0F/g, '')
    .trim();
}

function renderStructuredRcaHtml(reportJson) {
  const executiveSummary = sanitizeText(reportJson?.executive_summary || 'No executive summary provided.');
  const keyDetails = reportJson?.key_details || {};
  const rootCause = reportJson?.root_cause || {};
  const responseSteps = Array.isArray(reportJson?.response_steps) ? reportJson.response_steps : [];
  const checklist = Array.isArray(reportJson?.post_incident_checklist) ? reportJson.post_incident_checklist : [];

  const detailsRows = [
    ['Source IP', sanitizeText(keyDetails.source_ip || 'Unknown')],
    ['Affected Resource', sanitizeText(keyDetails.affected_resource || 'Unknown')],
    ['MITRE Technique', sanitizeText(keyDetails.mitre_technique || 'Investigation Required')],
    ['Severity', sanitizeText(keyDetails.severity || 'Unknown')],
  ]
    .map(([field, value]) => `
      <tr>
        <th class="forensic-key-cell" scope="row">${escapeHtml(field)}</th>
        <td class="forensic-value-cell">${escapeHtml(value)}</td>
      </tr>`)
    .join('');

  const stepRows = (responseSteps.length ? responseSteps : [
    { title: 'Contain', action: 'Isolate the affected resource immediately.' },
    { title: 'Eradicate', action: 'Remove malicious access paths and rotate credentials.' },
    { title: 'Recover', action: 'Restore normal operations with elevated monitoring.' },
  ])
    .map((step, idx) => `
      <li>
        <p><strong>${idx + 1}. ${escapeHtml(sanitizeText(step.title || `Step ${idx + 1}`))}</strong></p>
        <p>${escapeHtml(sanitizeText(step.action || 'No action provided.'))}</p>
      </li>`)
    .join('');

  const checklistRows = checklist
    .map((item) => `<li>${escapeHtml(sanitizeText(item))}</li>`)
    .join('');

  return `
    <section>
      <h3>Executive Summary</h3>
      <p>${escapeHtml(executiveSummary)}</p>
    </section>

    <section>
      <h3>Key Details</h3>
      <table class="forensic-key-table">
        <colgroup>
          <col class="forensic-key-col" />
          <col />
        </colgroup>
        <thead>
          <tr><th>Field</th><th>Value</th></tr>
        </thead>
        <tbody>${detailsRows}</tbody>
      </table>
    </section>

    <section>
      <h3>Root Cause</h3>
      <p><strong>What happened:</strong> ${escapeHtml(sanitizeText(rootCause.what_happened || 'No details provided.'))}</p>
      <p><strong>How it happened:</strong> ${escapeHtml(sanitizeText(rootCause.how_it_happened || 'No details provided.'))}</p>
      <p><strong>Why it matters:</strong> ${escapeHtml(sanitizeText(rootCause.why_it_matters || 'No details provided.'))}</p>
    </section>

    <section>
      <h3>Response Steps</h3>
      <ol>${stepRows}</ol>
    </section>

    <section>
      <h3>Post-Incident Checklist</h3>
      <ul>${checklistRows || '<li>No checklist available.</li>'}</ul>
    </section>
  `;
}

export default function App() {
  // 1. STATE MANAGEMENT
  const [incidents, setIncidents] = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [reconAlerts, setReconAlerts] = useState([]);
  const [reconIntel, setReconIntel] = useState(null);
  const [reconRiskDelta, setReconRiskDelta] = useState(0);
  const [reconStatus, setReconStatus] = useState('idle');
  const [reconTarget, setReconTarget] = useState('');
  const [isRcaLoading, setIsRcaLoading] = useState(false);
  const [rcaModal, setRcaModal] = useState({ open: false, content: '' });
  const rcaRequestSeq = useRef(0);

  // --- Resizable panel heights (pixels) ---
  const [centerTopH, setCenterTopH] = useState(null);
  const [rightTopH, setRightTopH] = useState(null);
  const centerColRef = useRef(null);
  const rightColRef = useRef(null);

  // Initialize heights once refs are measured
  useEffect(() => {
    const initHeights = () => {
      if (centerColRef.current && centerTopH === null) {
        const h = centerColRef.current.clientHeight;
        setCenterTopH(Math.round(h * 0.6));
      }
      if (rightColRef.current && rightTopH === null) {
        const h = rightColRef.current.clientHeight;
        setRightTopH(Math.round(h * 0.4));
      }
    };
    // Delay slightly so layout has settled
    const timer = setTimeout(initHeights, 100);
    return () => clearTimeout(timer);
  }, [centerTopH, rightTopH]);

  const MIN_PANEL = 80; // minimum panel height in px

  const handleCenterResize = useCallback((delta) => {
    setCenterTopH(prev => {
      if (prev === null || !centerColRef.current) return prev;
      const total = centerColRef.current.clientHeight - 8; // subtract handle height
      const next = prev + delta;
      return Math.max(MIN_PANEL, Math.min(next, total - MIN_PANEL));
    });
  }, []);

  const handleRightResize = useCallback((delta) => {
    setRightTopH(prev => {
      if (prev === null || !rightColRef.current) return prev;
      const total = rightColRef.current.clientHeight - 8;
      const next = prev + delta;
      return Math.max(MIN_PANEL, Math.min(next, total - MIN_PANEL));
    });
  }, []);

  // 2. DATA POLLING (FastAPI Sync)
  useEffect(() => {
    const syncData = async () => {
      try {
        const res = await fetch(API_URL);
        const data = await res.json();
        const incoming = data.incidents || [];
        setIncidents(incoming);
        
        // Auto-select first incident if none selected
        if (!activeId && incoming.length > 0) {
          setActiveId(incoming[incoming.length - 1].id);
        }
      } catch (err) {
        console.error("SOC Connectivity Error:", err);
      }
    };

    const interval = setInterval(syncData, 3000);
    return () => clearInterval(interval);
  }, [activeId]);

  // Derived Data
  const activeInc = incidents.find(i => i.id === activeId) || null;
  const hasReconIntel = reconIntel && Object.values(reconIntel).some((value) => Number(value) > 0);
  const averageSecurityScore = (() => {
    if (!incidents.length) return 100;

    const incidentScores = incidents.map((incident) => {
      const incidentRiskDelta = incident?.intel_summary?.risk_delta ?? incident?.risk_delta ?? 0;
      return {
        severity: (incident?.triage_alert?.severity || 'INFO').toLowerCase(),
        score: calculateSecurityScore(incident?.triage_alert?.severity || 'INFO', incident?.id, incidentRiskDelta),
      };
    });

    const rawAverage = incidentScores.reduce((sum, item) => sum + item.score, 0) / incidentScores.length;
    const hasCritical = incidentScores.some((item) => item.severity === 'critical');
    const highCount = incidentScores.filter((item) => item.severity === 'high').length;
    const hasHigh = highCount > 0;

    if (highCount > 2) return Math.min(rawAverage, 29);

    if (hasCritical) return Math.min(rawAverage, 25);
    if (hasHigh) return Math.min(rawAverage, 48);
    return rawAverage;
  })();

  const handleScanData = (scanPayload) => {
    if (!scanPayload) return;
    if (scanPayload.status) setReconStatus(scanPayload.status);
    if (scanPayload.detected_ip) setReconTarget(scanPayload.detected_ip);

    if (Array.isArray(scanPayload.alerts)) {
      setReconAlerts(scanPayload.alerts);
    }

    if (scanPayload.intel_summary) {
      setReconIntel(scanPayload.intel_summary);
      setReconRiskDelta(scanPayload.intel_summary.risk_delta || 0);
    }
  };

  // 3. ACTION HANDLERS
  const handleGenerateRCA = async () => {
    if (!activeId) return;
    const selectedIncidentId = activeId;
    const requestSeq = rcaRequestSeq.current + 1;
    rcaRequestSeq.current = requestSeq;
    
    // Open modal immediately to show processing state
    setRcaModal({ open: true, content: '' });
    setIsRcaLoading(true);

    try {
      const res = await fetch(`http://127.0.0.1:8000/api/v1/rca/${selectedIncidentId}`);
      const data = await res.json();
      
      // Artificial pause for "Decryption" aesthetic
      setTimeout(() => {
        if (requestSeq !== rcaRequestSeq.current) return;
        marked.setOptions({ gfm: true, breaks: true });
        let renderedContent = '# No Forensic Data Available';

        if (data.report_json && typeof data.report_json === 'object') {
          renderedContent = renderStructuredRcaHtml(data.report_json);
        } else {
          const cleanReport = sanitizeForensicReport(data.report);
          renderedContent = marked.parse(cleanReport);
        }

        setRcaModal({ 
          open: true, 
          content: renderedContent,
        });
        setIsRcaLoading(false);
      }, 1200);

    } catch (err) {
      if (requestSeq !== rcaRequestSeq.current) return;
      console.error("RCA Fetch Failed:", err);
      setRcaModal({ 
        open: true, 
        content: '<p class="text-red-500 font-bold uppercase tracking-widest">Alert: Connection to NVIDIA Inference Engine timed out.</p>' 
      });
      setIsRcaLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-screen w-screen bg-[#060B12] text-[#E2E8F0] font-sans overflow-hidden relative">

      {/* --- OVERLAY: RCA FORENSICS MODAL --- */}
      {rcaModal.open && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/90 backdrop-blur-lg p-6 animate-in fade-in duration-500">
          <div className="bg-[#0f172a] border border-[#0EA5E9]/40 w-full max-w-5xl h-[85vh] rounded-2xl overflow-hidden shadow-[0_0_80px_rgba(14,165,233,0.2)] flex flex-col">
            
            {/* Modal Header */}
            <div className="flex justify-between items-center border-b border-white/10 p-6 flex-none bg-black/40">
              <div className="flex items-center gap-4">
                <div className="h-3 w-3 rounded-full bg-red-600 animate-pulse shadow-[0_0_10px_#ef4444]"></div>
                <h2 className="text-2xl font-black italic text-white uppercase tracking-tighter">AI Forensic Inquest</h2>
              </div>
              <button 
                onClick={() => setRcaModal({ open: false, content: '' })} 
                className="text-gray-500 hover:text-red-500 transition-all hover:rotate-90 text-3xl p-2"
              >✕</button>
            </div>

            {/* Modal Body */}
            <div className="flex-1 overflow-y-auto p-12 custom-scrollbar relative bg-[#0b1120]">
              {isRcaLoading ? (
                <div className="absolute inset-0 flex flex-col items-center justify-center bg-[#0f172a] z-50">
                  <div className="relative flex items-center justify-center mb-10">
                    <Loader2 className="text-[#0EA5E9] animate-spin-slow" size={80} strokeWidth={1} />
                    <Activity size={32} className="absolute text-[#0EA5E9] animate-pulse" />
                  </div>
                  <div className="flex flex-col items-center gap-3">
                    <p className="text-xs font-black uppercase tracking-[8px] text-[#0EA5E9] animate-pulse">Reconstructing Vector</p>
                    <div className="w-48 h-[1px] bg-white/10 relative overflow-hidden">
                      <div className="absolute inset-0 bg-[#0EA5E9] animate-shimmer"></div>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="relative animate-in fade-in slide-in-from-bottom-12 duration-1000">
                  {/* 🟢 FIX 3: Styled the Markdown classes for the Blue/Green terminal look */}
                  <div className="prose prose-invert max-w-none text-[18px] leading-relaxed
                               prose-headings:text-[#3b82f6] prose-headings:uppercase prose-headings:tracking-widest prose-headings:not-italic prose-headings:mb-4 prose-headings:mt-8
                               prose-hr:border-[#3b82f6]/30 prose-hr:my-8
                               prose-p:text-gray-200 prose-p:leading-relaxed prose-p:mb-4
                               prose-strong:text-white prose-strong:font-black
                               prose-code:text-[#22c55e] prose-code:bg-black/80 prose-code:p-4 prose-code:block prose-code:rounded-lg prose-code:border prose-code:border-[#22c55e]/20 prose-code:font-mono prose-code:text-sm prose-code:my-4
                               prose-ul:my-4 prose-ul:pl-5 prose-ol:my-4 prose-ol:pl-5
                               prose-li:text-gray-300 prose-li:my-1
                               prose-table:w-full prose-table:my-6 prose-table:border-collapse
                               prose-th:text-left prose-th:text-soc-accent prose-th:text-sm prose-th:uppercase prose-th:tracking-wide prose-th:border-b prose-th:border-[#2A3648] prose-th:pb-2 prose-th:pr-6
                               prose-td:text-gray-200 prose-td:py-2 prose-td:pr-6 prose-td:border-b prose-td:border-[#1F2937]
                               [&_section]:mb-10" 
                    dangerouslySetInnerHTML={{ __html: rcaModal.content }} 
                  />
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div className="p-6 border-t border-white/5 bg-black/40 flex justify-end">
              <button onClick={() => setRcaModal({ open: false, content: '' })}
                      className="px-10 py-3 bg-white/5 hover:bg-soc-accent hover:text-black border border-white/10 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all duration-300">
                Acknowledge Findings
              </button>
            </div>
          </div>
        </div>
      )}

      {/* --- HEADER --- */}
      <div className="h-[60px] flex-none">
        <Topbar threatSeverity={activeInc?.triage_alert?.severity || 'INFO'} />
      </div>

      {/* --- MAIN DASHBOARD GRID --- */}
      <main className="flex-1 p-4 grid grid-cols-[335px_1fr_340px] gap-4 min-h-0">
        
        {/* Left Column: Alerts Feed */}
        <section className="soc-panel">
          <div className="panel-header">Live Alerts</div>
          <div className="flex-1 overflow-y-auto custom-scrollbar">
            <ThreatFeed
              incidents={incidents}
              activeId={activeId}
              onSelect={setActiveId}
              externalAlerts={reconAlerts}
            />
          </div>
        </section>

        {/* Center Column: Visuals */}
        <section ref={centerColRef} className="flex flex-col min-h-0">
          <div className="soc-panel min-h-0 relative" style={centerTopH !== null ? { height: centerTopH, flex: 'none' } : { flex: '2.5 1 0%' }}>
            <div className="panel-header">Infrastructure Topology</div>
            <div className="flex-1">
              <NetworkTopology
                severity={activeInc?.triage_alert?.severity}
                onScanData={handleScanData}
              />
            </div>
          </div>

          <ResizeHandle onResize={handleCenterResize} />
          
          <div className="soc-panel p-5 min-h-0 flex flex-col" style={centerTopH !== null ? { flex: '1 1 0%' } : { flex: '1 1 0%' }}>
            <div className="panel-header -m-5 mb-5">NVIDIA Intelligence Stream</div>
            <div className="flex-1 overflow-y-auto custom-scrollbar space-y-4">
              {(activeInc || hasReconIntel || reconStatus === 'running' || reconStatus === 'completed') ? (
                <>
                  <div className="bg-[#111827] border border-[#2A3648] rounded-lg p-3">
                    <p className="text-[12px] font-black uppercase tracking-wide text-soc-accent mb-2">
                      Recon Intelligence {reconTarget ? `(${reconTarget})` : ''}
                    </p>
                    <p className="text-[12px] text-gray-300 uppercase tracking-wide mb-3">
                      Status: {reconStatus}
                    </p>
                    {reconIntel && (
                      <div className="grid grid-cols-2 gap-2 text-[12px]">
                        <div className="bg-black/40 rounded px-2 py-1">Subdomains: {reconIntel.subdomains || 0}</div>
                        <div className="bg-black/40 rounded px-2 py-1">Emails: {reconIntel.emails || 0}</div>
                        <div className="bg-black/40 rounded px-2 py-1">DNS Records: {reconIntel.dns_records || 0}</div>
                        <div className="bg-black/40 rounded px-2 py-1">Breaches: {reconIntel.breaches || 0}</div>
                        <div className="bg-black/40 rounded px-2 py-1">Related IPs: {reconIntel.related_ips || 0}</div>
                        <div className="bg-black/40 rounded px-2 py-1">Risk Delta: {reconIntel.risk_delta || 0}</div>
                      </div>
                    )}
                  </div>

                  <div className="bg-black/50 p-4 rounded-lg border border-white/5 font-mono text-[13px] text-soc-accent break-all leading-relaxed shadow-inner">
                    <span className="text-gray-500 text-[11px] block mb-2 font-bold tracking-wide">RAW TELEMETRY:</span>
                    {activeInc ? activeInc.log_content : 'No active incident telemetry selected.'}
                  </div>
                  {activeInc && (
                    <button
                      onClick={handleGenerateRCA}
                      className="w-full bg-[#1e3a8a] hover:bg-blue-600 text-white py-3 rounded-lg text-[12px] font-black uppercase tracking-wide border border-blue-400 transition-all flex items-center justify-center gap-2 shadow-lg active:scale-95 group"
                    >
                      <Activity size={16} className="group-hover:animate-pulse" />
                      Analyze Incident Forensics
                    </button>
                  )}
                </>
              ) : (
                <div className="h-full flex items-center justify-center opacity-20 text-[10px] font-mono tracking-widest uppercase text-center italic">
                  Systems Nominal. Awaiting Alert Trigger...
                </div>
              )}
            </div>
          </div>
        </section>

        {/* Right Column: Status & Remediation */}
        <section ref={rightColRef} className="flex flex-col min-h-0 overflow-hidden">
          {/* Security Score */}
          <div className="soc-panel overflow-hidden" style={rightTopH !== null ? { height: rightTopH, flex: 'none' } : { flex: 'none', height: 280 }}>
            <div className="panel-header">Security Score</div>
            <div className="flex-1 flex items-center justify-center overflow-hidden">
              <SecurityStatus 
                severity={activeInc?.triage_alert?.severity || 'INFO'} 
                incidentId={activeInc?.id}
                riskDelta={reconRiskDelta}
                averageScore={averageSecurityScore}
              />
            </div>
          </div>

          <ResizeHandle onResize={handleRightResize} />

          {/* Remediation Plan */}
          <div className="soc-panel flex-1 min-h-0 overflow-hidden">
            <div className="panel-header">Remediation Playbook</div>
            <div className="flex-1 overflow-y-auto custom-scrollbar p-5">
              <RemediationPlan 
                key={activeInc?.id || 'no-incident'}
                remediation={activeInc?.deep_analysis?.remediation} 
              />
            </div>
          </div>
        </section>

      </main>
    </div>
  )
}