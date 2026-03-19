<%@ include file="header.jspf" %>
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
    <meta charset="UTF-8">
    <title>AegisAI | Security Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/cytoscape/3.27.0/cytoscape.min.js"></script>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        :root {
            --bg: #060B12; --surface: #121924; --surface2: #1A2333;
            --border: #2A3648; --text: #E2E8F0; --muted: #94A3B8;
            --accent: #0EA5E9; --green: #10B981; --red: #EF4444; --critical: #DC2626; --orange: #F97316; --yellow: #EAB308;
        }
        body {
            background-color: var(--bg);
            color: var(--text);
            font-family: Inter, Roboto, "Segoe UI", system-ui, sans-serif;
            line-height: 1.5;
            letter-spacing: 0.01em;
            height: 100vh;
            overflow: hidden;
            margin: 0;
        }
        button, input, textarea, select { font: inherit; }
        .dashboard-layout { display: grid; grid-template-rows: 52px 1fr; height: 100vh; }
        .topbar { background: var(--surface2); border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; padding: 0 16px; }
        .main-content { padding: 18px; display: grid; grid-template-columns: 280px minmax(0, 1fr) 360px; gap: 18px; height: calc(100vh - 52px); }
        .panel {
            background: linear-gradient(180deg, rgba(18, 25, 36, 0.98) 0%, rgba(13, 20, 31, 0.98) 100%);
            border: 1px solid rgba(74, 93, 122, 0.42);
            border-radius: 14px;
            display: flex;
            flex-direction: column;
            overflow: hidden;
            box-shadow: 0 16px 40px -24px rgba(0, 0, 0, 0.85);
        }
        .panel-header {
            font-size: 11px;
            font-weight: 700;
            line-height: 1.2;
            letter-spacing: 2.2px;
            text-transform: uppercase;
            color: var(--muted);
            padding: 13px 16px;
            border-bottom: 1px solid rgba(74, 93, 122, 0.35);
            background: rgba(255,255,255,0.02);
        }
        .panel-body { padding: 18px; overflow-y: auto; flex: 1; font-size: 13px; line-height: 1.55; }
        .empty-state { text-align: center; padding: 2.75rem 1rem; opacity: 0.38; }
        .empty-state p { margin: 0; font-size: 11px; font-weight: 600; letter-spacing: 0.18em; text-transform: uppercase; }
        .score-circle { width: 94px; height: 94px; border-radius: 50%; border: 7px solid var(--green); display: flex; flex-direction: column; align-items: center; justify-content: center; margin: 0 auto; transition: all 0.35s ease; }
        .security-score-panel {
            min-width: 0;
            min-height: 208px;
            resize: vertical;
            overflow: auto;
            flex: 0 0 auto;
        }
        .security-score-panel .panel-body {
            padding: 14px 16px 16px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: flex-start;
            gap: 12px;
            min-height: 174px;
        }
        .score-summary {
            width: 100%;
            display: grid;
            grid-template-columns: repeat(3, minmax(0, 1fr));
            gap: 8px;
        }
        .score-summary:empty { display: none; }
        .score-chip {
            border: 1px solid rgba(74, 93, 122, 0.35);
            border-radius: 10px;
            background: rgba(255,255,255,0.025);
            padding: 8px 6px;
            text-align: center;
        }
        .score-chip strong {
            display: block;
            font-size: 17px;
            line-height: 1.1;
            font-weight: 800;
            color: var(--text);
        }
        .score-chip span {
            display: block;
            margin-top: 4px;
            font-size: 10px;
            line-height: 1.2;
            letter-spacing: 0.16em;
            text-transform: uppercase;
            color: var(--muted);
        }
        .remediation-panel { min-height: 360px; }
        .remediation-panel .panel-body { padding: 20px; }
        .topology-canvas {
            height: 240px;
            border: 1px solid rgba(74, 93, 122, 0.35);
            border-radius: 12px;
            background: linear-gradient(180deg, #0b1220 0%, #101826 100%);
            box-shadow: inset 0 1px 0 rgba(255,255,255,0.02);
        }
        .alert-card, .intel-card, .remediation-card {
            border-radius: 12px;
            border: 1px solid rgba(74, 93, 122, 0.28);
            background: rgba(255,255,255,0.03);
            box-shadow: inset 0 1px 0 rgba(255,255,255,0.02);
        }
        .alert-card { padding: 12px 13px; }
        .alert-card p, .intel-card p, .remediation-card p { margin: 0; }
        .alert-meta, .intel-meta {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 10px;
            margin-bottom: 6px;
        }
        .alert-title, .intel-title {
            font-size: 12px;
            line-height: 1.35;
            font-weight: 700;
            color: #F8FAFC;
        }
        .alert-url, .intel-url {
            margin-top: 6px;
            font-size: 11px;
            line-height: 1.45;
            color: #94A3B8;
            word-break: break-word;
        }
        .intel-description {
            margin-top: 8px;
            font-size: 12px;
            line-height: 1.55;
            color: #D6DEE9;
        }
        .section-divider {
            border-top: 1px solid rgba(74, 93, 122, 0.28);
            margin-top: 4px;
            padding-top: 14px;
        }
        .connection-label { color: var(--muted); font-size: 10px; letter-spacing: 2px; text-transform: uppercase; }
        .connection-state.connected { color: var(--green); }
        .connection-state.disconnected { color: var(--red); }
        #rca-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); z-index: 999; backdrop-filter: blur(4px); }
        #rca-modal { display: none; position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 65%; max-width: 900px; max-height: 85vh; background: #0f172a; color: #e2e8f0; padding: 2rem; border-radius: 12px; border: 1px solid #3b82f6; z-index: 1000; overflow-y: auto; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.75); }
        ::-webkit-scrollbar { width: 4px; }
        ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 2px; }
    </style>
</head>
<body>

<div id="rca-overlay" onclick="closeRCA()"></div>
<div id="rca-modal">
    <div style="display: flex; justify-content: space-between; border-bottom: 1px solid #334155; padding-bottom: 1rem; margin-bottom: 1rem;">
        <h2 style="font-size: 1.5rem; font-weight: 900; font-style: italic; color: #fff; margin: 0;">🧠 AI ROOT CAUSE ANALYSIS</h2>
        <button onclick="closeRCA()" style="background: none; border: none; color: var(--red); font-size: 1.5rem; cursor: pointer;">✖</button>
    </div>
    <div id="rca-content" style="line-height: 1.6;">Generating...</div>
</div>

<div class="dashboard-layout">
    <header class="topbar">
        <div class="flex items-center gap-2">
            <h1 class="text-sm font-black uppercase tracking-widest text-[#0EA5E9]">■ AEGISAI</h1>
            <span class="text-xs text-gray-600">|</span>
            <span class="text-[11px] font-medium text-gray-400">Security Dashboard</span>
        </div>
        <div class="flex items-center gap-3">
            <button onclick="clearLogs()" class="text-[10px] bg-red-900/20 text-red-400 hover:text-white hover:bg-red-600 px-3 py-1.5 rounded border border-red-500/30 transition-all uppercase font-bold">
                <i class="fas fa-trash-alt mr-1"></i> Clear Feed
            </button>
            <div id="connection-status" class="flex items-center gap-2">
                <div id="status-dot" class="h-2 w-2 rounded-full bg-green-500 animate-pulse"></div>
                <span class="connection-label font-mono">AI ENGINER</span>
                <span id="status-text" class="connection-state connected text-[10px] font-mono uppercase tracking-widest">CONNECTED</span>
            </div>
        </div>
    </header>

    <div class="main-content">
        <div class="panel">
            <div class="panel-header flex justify-between">
                <span>Live Alerts</span>
                <span id="incident-count" class="text-red-500 font-bold bg-red-500/10 px-2 rounded">0</span>
            </div>
            <div class="panel-body space-y-3" id="alert-list">
                <div class="empty-state">
                    <p>Awaiting Logs...</p>
                </div>
            </div>
        </div>

        <div class="panel">
            <div class="panel-header" style="color: var(--accent);">NVIDIA DeepSeek Intelligence</div>
            <div class="panel-body flex flex-col" id="ai-intelligence">
                <div class="empty-state" style="padding-top: 4.25rem; padding-bottom: 4.25rem;">
                    <i class="fas fa-satellite-dish animate-bounce text-4xl mb-4"></i>
                    <p>Awaiting Telemetry...</p>
                </div>
            </div>
        </div>

        <div class="flex flex-col gap-4">
            <div class="panel security-score-panel" style="flex: 0 0 auto;">
                <div class="panel-header">Security Score</div>
                <div class="panel-body text-center">
                    <div id="score-circle" class="score-circle">
                        <span id="score-number" class="text-3xl font-black">100</span>
                        <span class="text-[10px] text-gray-400 uppercase">/ 100</span>
                    </div>
                    <div id="threat-level-badge" class="inline-block bg-green-500/20 text-green-500 border border-green-500/50 px-4 py-1 rounded-full text-xs font-bold uppercase tracking-widest">
                        SECURE
                    </div>
                    <div id="score-summary" class="score-summary"></div>
                </div>
            </div>
            <div class="panel remediation-panel flex-1">
                <div class="panel-header">Remediation Plan</div>
                <div class="panel-body flex flex-col" id="remediation-plan">
                    <div class="empty-state">
                        <p>Awaiting Playbook</p>
                    </div>
                </div>
            </div>
            <div class="panel" style="flex: 0 0 auto;">
                <div class="panel-header">Network Discovery</div>
                <div class="panel-body space-y-3">
                    <div class="flex gap-2">
                        <input id="scan-target" type="text" value="" class="flex-1 bg-black/40 border border-slate-700 rounded px-3 py-2 text-xs font-mono" placeholder="Leave blank for auto-detect or enter IP/hostname" />
                        <button onclick="scanNetwork()" id="scan-btn" class="bg-[#0EA5E9] hover:bg-[#38BDF8] text-black px-3 py-2 rounded text-[10px] font-black uppercase tracking-widest">
                            Run Full Scan
                        </button>
                    </div>
                    <div id="scan-status" class="text-[10px] font-mono text-gray-400 uppercase tracking-widest">Manual scan idle</div>
                    <div id="topology-map" class="topology-canvas"></div>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
    const API_ENDPOINT = "http://127.0.0.1:8000/api/v1/alerts";
    const CLEAR_ENDPOINT = "http://127.0.0.1:8000/api/v1/clear";
    const SCAN_ENDPOINT = "http://localhost:8000/scan-full";
    let allIncidents = [];
    let activeIncidentId = null;
    let topologyCy = null;
    let latestWebScan = createEmptyScanState();

    function createEmptyScanState() {
        return {
            target: null,
            vulnerabilities: [],
            alerts: [],
            intelligence_stream: [],
            severity_counts: { high: 0, medium: 0, low: 0 },
            security_score: 100,
            web_scan_status: "idle"
        };
    }

    function escapeHtml(value) {
        return String(value ?? "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;");
    }

    function getSelectedIncident() {
        return allIncidents.find((incident) => incident.id === activeIncidentId) || null;
    }

    function clampScore(score) {
        return Math.max(0, Math.min(Number(score) || 0, 100));
    }

    function getRiskClasses(risk) {
        const normalizedRisk = String(risk || "Low").toUpperCase();
        if (normalizedRisk === "HIGH") {
            return { border: "border-red-500", bg: "bg-red-500/10", text: "text-red-300" };
        }
        if (normalizedRisk === "MEDIUM") {
            return { border: "border-orange-500", bg: "bg-orange-500/10", text: "text-orange-300" };
        }
        return { border: "border-yellow-500", bg: "bg-yellow-500/10", text: "text-yellow-300" };
    }

    function applyScoreDisplay(score, color, label, pulse) {
        const scoreCircle = document.getElementById("score-circle");
        const scoreNum = document.getElementById("score-number");
        const badge = document.getElementById("threat-level-badge");
        const safeScore = Math.round(clampScore(score));

        scoreCircle.style.borderColor = color;
        scoreNum.innerText = safeScore;
        scoreNum.style.color = color;
        badge.innerText = `THREAT: ${label}`;
        badge.className = `inline-block border px-4 py-1 rounded-full text-xs font-bold uppercase tracking-widest ${pulse ? "animate-pulse" : ""}`;
        badge.style.color = color;
        badge.style.borderColor = color;
        badge.style.backgroundColor = `${color}15`;
    }

    function updateScoreDisplay(sev) {
        const config = {
            CRITICAL: { score: 12, color: "var(--critical)", label: "CRITICAL", pulse: true },
            HIGH: { score: 38, color: "var(--red)", label: "HIGH", pulse: true },
            MEDIUM: { score: 64, color: "var(--orange)", label: "ELEVATED", pulse: false },
            LOW: { score: 89, color: "var(--yellow)", label: "WARNING", pulse: false },
            INFO: { score: 100, color: "var(--green)", label: "SECURE", pulse: false }
        };

        const cfg = config[String(sev || "INFO").toUpperCase()] || config.INFO;
        applyScoreDisplay(cfg.score, cfg.color, cfg.label, cfg.pulse);
    }

    function updateScoreDisplayFromScan() {
        const score = Number.isFinite(Number(latestWebScan.security_score))
            ? clampScore(latestWebScan.security_score)
            : 100;

        if (score <= 25) {
            applyScoreDisplay(score, "var(--critical)", "CRITICAL", true);
            return;
        }
        if (score <= 50) {
            applyScoreDisplay(score, "var(--red)", "HIGH", true);
            return;
        }
        if (score <= 75) {
            applyScoreDisplay(score, "var(--orange)", "ELEVATED", false);
            return;
        }
        if (score < 100) {
            applyScoreDisplay(score, "var(--yellow)", "WARNING", false);
            return;
        }
        applyScoreDisplay(score, "var(--green)", "SECURE", false);
    }

    function refreshSecurityScore(fallbackSeverity) {
        if ((latestWebScan.vulnerabilities || []).length > 0) {
            updateScoreDisplayFromScan();
            return;
        }
        updateScoreDisplay(fallbackSeverity || "INFO");
    }

    function renderSecurityScoreSummary() {
        const scoreSummary = document.getElementById("score-summary");
        const counts = latestWebScan.severity_counts || { high: 0, medium: 0, low: 0 };
        const totalVulnerabilities = (latestWebScan.vulnerabilities || []).length;

        if (totalVulnerabilities === 0) {
            scoreSummary.innerHTML = "";
            return;
        }

        scoreSummary.innerHTML = `
            <div class="score-chip">
                <strong>${counts.high || 0}</strong>
                <span>High</span>
            </div>
            <div class="score-chip">
                <strong>${counts.medium || 0}</strong>
                <span>Medium</span>
            </div>
            <div class="score-chip">
                <strong>${counts.low || 0}</strong>
                <span>Low</span>
            </div>
        `;
    }

    function buildIncidentCard(inc) {
        const isHigh = ["high", "critical"].includes(String(inc.triage_alert.severity || "").toLowerCase());
        const borderColor = isHigh ? "border-red-500" : "border-orange-500";
        const bgAlert = isHigh ? "bg-red-500/10" : "bg-orange-500/10";
        const isActiveClass = activeIncidentId === inc.id ? "ring-2 ring-[#0EA5E9] bg-white/10" : "";

        return `
            <div onclick="selectIncident('${inc.id}')"
                 class="alert-card border-l-4 ${borderColor} ${bgAlert} ${isActiveClass} cursor-pointer hover:bg-white/10 transition-all">
                <div class="alert-meta">
                    <span class="text-[9px] font-bold px-1.5 py-0.5 rounded bg-black/50 text-gray-300 uppercase">${escapeHtml(inc.triage_alert.severity)}</span>
                    <span class="text-[9px] font-mono text-gray-500">#${escapeHtml(inc.id.substring(0, 8))}</span>
                </div>
                <p class="alert-title italic uppercase tracking-[0.14em]">${escapeHtml(inc.triage_alert.threat_type)}</p>
            </div>
        `;
    }

    function renderLiveAlerts() {
        const list = document.getElementById("alert-list");
        const scanAlerts = latestWebScan.alerts || [];
        const totalItems = scanAlerts.length + allIncidents.length;

        document.getElementById("incident-count").innerText = totalItems;

        if (totalItems === 0) {
            list.innerHTML = '<div class="empty-state"><p>Awaiting Alerts...</p></div>';
            return;
        }

        const scanMarkup = scanAlerts.map((alert) => {
            const classes = getRiskClasses(alert.risk);
            return `
                <div class="alert-card border-l-4 ${classes.border} ${classes.bg}">
                    <div class="alert-meta">
                        <span class="text-[9px] font-bold px-1.5 py-0.5 rounded bg-black/50 ${classes.text} uppercase">${escapeHtml(alert.risk)}</span>
                        <span class="text-[9px] font-mono text-sky-300">ZAP</span>
                    </div>
                    <p class="alert-title uppercase tracking-[0.14em]">${escapeHtml(alert.name)}</p>
                    <p class="alert-url">${escapeHtml(alert.url)}</p>
                </div>
            `;
        }).join("");

        const incidentMarkup = allIncidents.slice().reverse().map(buildIncidentCard).join("");
        list.innerHTML = `${scanMarkup}${incidentMarkup}`;
    }

    function renderWebIntelligenceMarkup() {
        const streamItems = latestWebScan.intelligence_stream || [];
        if (streamItems.length === 0) {
            return `
                <div class="empty-state">
                    <p>Awaiting Web Intelligence...</p>
                </div>
            `;
        }

        const targetLabel = latestWebScan.target || "AltoroMutual";
        return `
            <div class="space-y-3">
                <div class="flex items-center justify-between">
                    <span class="text-[10px] text-slate-400 font-bold uppercase">Intelligence Stream</span>
                    <span class="text-[9px] font-mono text-sky-300 uppercase">${escapeHtml(targetLabel)}</span>
                </div>
                ${streamItems.map((item) => {
                    const classes = getRiskClasses(item.risk);
                    return `
                        <div class="intel-card ${classes.bg}" style="border-color: rgba(74, 93, 122, 0.28); padding: 12px 13px;">
                            <div class="intel-meta">
                                <span class="intel-title">${escapeHtml(item.name)}</span>
                                <span class="text-[9px] uppercase ${classes.text} font-bold">${escapeHtml(item.risk)}</span>
                            </div>
                            <p class="intel-url">${escapeHtml(item.url)}</p>
                            <p class="intel-description">${escapeHtml(item.description)}</p>
                        </div>
                    `;
                }).join("")}
            </div>
        `;
    }

    function renderIntelligencePanel(incident) {
        const intelligencePanel = document.getElementById("ai-intelligence");
        const webStreamMarkup = renderWebIntelligenceMarkup();

        if (!incident) {
            intelligencePanel.innerHTML = webStreamMarkup;
            return;
        }

        intelligencePanel.innerHTML = `
            <div class="flex-1 flex flex-col gap-4">
                <div>
                    <span class="text-[10px] text-gray-400 font-bold uppercase">Input Telemetry (${escapeHtml(incident.source)})</span>
                    <div class="bg-black text-[#38BDF8] p-3 rounded font-mono text-[11px] mt-1 border-l-2 border-[#0EA5E9] break-all max-h-40 overflow-y-auto">
                        ${escapeHtml(incident.log_content)}
                    </div>
                </div>
                ${incident.deep_analysis !== "PENDING" ? `
                <div class="flex items-center gap-3 bg-[#0EA5E9]/10 p-3 rounded border border-[#0EA5E9]/20">
                    <span class="bg-[#0EA5E9] text-black px-2 py-1 rounded font-bold text-[11px]">${escapeHtml(incident.deep_analysis.mitre_t_code)}</span>
                    <span class="text-sm font-medium text-white">${escapeHtml(incident.deep_analysis.technique)}</span>
                </div>
                <button onclick="generateRCA()" class="w-full bg-[#1e3a8a] hover:bg-[#2563eb] text-white py-3 rounded text-xs font-bold uppercase tracking-widest border border-[#3b82f6] transition-colors">
                    📄 Generate RCA Report
                </button>
                ` : `<div class="p-3 text-yellow-500 animate-pulse text-xs"><i class="fas fa-brain mr-2"></i> Analyzing...</div>`}
                <div class="section-divider">
                    ${webStreamMarkup}
                </div>
            </div>
        `;
    }

    function renderScanRemediationSummary() {
        const counts = latestWebScan.severity_counts || { high: 0, medium: 0, low: 0 };
        const highRiskHotlist = (latestWebScan.alerts || []).slice(0, 3);
        return `
            <div class="space-y-4">
                <div>
                    <div class="text-[10px] text-slate-400 font-bold uppercase mb-2">OWASP ZAP Summary</div>
                    <div class="grid grid-cols-3 gap-2 text-center">
                        <div class="rounded border border-red-500/40 bg-red-500/10 px-2 py-2">
                            <div class="text-lg font-black text-red-400">${counts.high || 0}</div>
                            <div class="text-[9px] uppercase text-red-200">High</div>
                        </div>
                        <div class="rounded border border-orange-500/40 bg-orange-500/10 px-2 py-2">
                            <div class="text-lg font-black text-orange-300">${counts.medium || 0}</div>
                            <div class="text-[9px] uppercase text-orange-100">Medium</div>
                        </div>
                        <div class="rounded border border-yellow-500/40 bg-yellow-500/10 px-2 py-2">
                            <div class="text-lg font-black text-yellow-300">${counts.low || 0}</div>
                            <div class="text-[9px] uppercase text-yellow-100">Low</div>
                        </div>
                    </div>
                </div>
                ${highRiskHotlist.length > 0 ? highRiskHotlist.map((alert, index) => `
                    <div class="remediation-card flex gap-3 px-3 py-3">
                        <div class="w-5 h-5 rounded bg-red-500 text-white font-bold text-[10px] flex items-center justify-center flex-shrink-0">${index + 1}</div>
                        <p class="text-xs text-white">Prioritize remediation for ${escapeHtml(alert.name)} on ${escapeHtml(alert.url)}.</p>
                    </div>
                `).join("") : `
                    <div class="remediation-card text-xs text-slate-300 px-3 py-3">
                        No high-risk findings were detected. Medium and low findings are available in the intelligence stream for planned remediation.
                    </div>
                `}
            </div>
        `;
    }

    function renderRemediationPanel(incident) {
        const remediationPanel = document.getElementById("remediation-plan");

        if (incident && incident.deep_analysis !== "PENDING") {
            remediationPanel.innerHTML = `
                <div class="space-y-4">
                    <div class="remediation-card flex gap-3 px-3 py-3">
                        <div class="w-5 h-5 rounded bg-[#0EA5E9] text-black font-bold text-[10px] flex items-center justify-center flex-shrink-0">1</div>
                        <p class="text-xs text-white">${escapeHtml(incident.deep_analysis.remediation)}</p>
                    </div>
                    ${(latestWebScan.vulnerabilities || []).length > 0 ? `
                    <div class="section-divider">
                        ${renderScanRemediationSummary()}
                    </div>
                    ` : ""}
                    <button onclick="approveFix()" class="w-full bg-green-600 hover:bg-green-500 text-white py-2 rounded text-[10px] font-black uppercase tracking-widest transition-all">
                        ✓ Deploy Remediation
                    </button>
                </div>
            `;
            return;
        }

        if ((latestWebScan.vulnerabilities || []).length > 0) {
            remediationPanel.innerHTML = renderScanRemediationSummary();
            return;
        }

        if (incident) {
            remediationPanel.innerHTML = '<div class="empty-state"><p>Generating...</p></div>';
            return;
        }

        remediationPanel.innerHTML = '<div class="empty-state"><p>Awaiting Playbook</p></div>';
    }

    function refreshDashboardPanels() {
        const selectedIncident = getSelectedIncident();
        renderLiveAlerts();
        renderIntelligencePanel(selectedIncident);
        renderRemediationPanel(selectedIncident);
        renderSecurityScoreSummary();
        refreshSecurityScore(selectedIncident ? selectedIncident.triage_alert.severity : null);
    }

    function applyWebScanResults(scanPayload) {
        latestWebScan = {
            target: scanPayload.web_target || scanPayload.target || null,
            vulnerabilities: scanPayload.vulnerabilities || [],
            alerts: scanPayload.alerts || [],
            intelligence_stream: scanPayload.intelligence_stream || [],
            severity_counts: {
                high: Number(scanPayload.severity_counts?.high || 0),
                medium: Number(scanPayload.severity_counts?.medium || 0),
                low: Number(scanPayload.severity_counts?.low || 0)
            },
            security_score: Number.isFinite(Number(scanPayload.security_score))
                ? clampScore(scanPayload.security_score)
                : 100,
            web_scan_status: scanPayload.web_scan_status || scanPayload.status || "completed"
        };
        refreshDashboardPanels();
    }

    async function clearLogs() {
        if (!confirm("Reset incident data?")) return;
        try {
            await fetch(CLEAR_ENDPOINT, { method: "POST" });
            location.reload();
        } catch (err) {
            console.error("Reset Failed", err);
        }
    }

    async function syncDashboard() {
        try {
            const response = await fetch(API_ENDPOINT);
            if (!response.ok) throw new Error("Offline");

            const data = await response.json();
            allIncidents = data.incidents || [];

            if (activeIncidentId && !getSelectedIncident()) {
                activeIncidentId = null;
            }

            if (!activeIncidentId && allIncidents.length > 0) {
                activeIncidentId = allIncidents[allIncidents.length - 1].id;
            }

            refreshDashboardPanels();
            document.getElementById("status-dot").className = "h-2 w-2 rounded-full bg-green-500 animate-pulse";
            document.getElementById("status-text").innerText = "CONNECTED";
            document.getElementById("status-text").className = "connection-state connected text-[10px] font-mono uppercase tracking-widest";
        } catch (err) {
            refreshDashboardPanels();
            document.getElementById("status-dot").className = "h-2 w-2 rounded-full bg-red-500";
            document.getElementById("status-text").innerText = "NOT CONNECTED";
            document.getElementById("status-text").className = "connection-state disconnected text-[10px] font-mono uppercase tracking-widest";
        }
    }

    function selectIncident(id) {
        activeIncidentId = id;
        refreshDashboardPanels();
    }

    async function generateRCA() {
        if (!activeIncidentId) return;
        document.getElementById("rca-overlay").style.display = "block";
        document.getElementById("rca-modal").style.display = "block";
        document.getElementById("rca-content").innerHTML = "Analysing forensics...";
        try {
            const res = await fetch(`http://127.0.0.1:8000/api/v1/rca/${activeIncidentId}`);
            const json = await res.json();
            document.getElementById("rca-content").innerHTML = marked.parse(json.report);
        } catch (e) {
            document.getElementById("rca-content").innerHTML = "Error fetching report.";
        }
    }

    function closeRCA() {
        document.getElementById("rca-overlay").style.display = "none";
        document.getElementById("rca-modal").style.display = "none";
    }

    function approveFix() {
        alert("Remediation Plan Deployed Successfully.");
    }

    function initTopologyGraph() {
        if (topologyCy) return;
        topologyCy = cytoscape({
            container: document.getElementById("topology-map"),
            elements: [],
            style: [
                {
                    selector: 'node[type = "host"]',
                    style: {
                        "background-color": "#0EA5E9",
                        label: "data(label)",
                        color: "#E2E8F0",
                        "font-family": "Inter, Roboto, Segoe UI, system-ui, sans-serif",
                        "font-size": "11px",
                        "font-weight": "700",
                        "line-height": 1.35,
                        "text-valign": "center",
                        "text-halign": "center",
                        "border-color": "#38BDF8",
                        "border-width": 2,
                        width: 52,
                        height: 52
                    }
                },
                {
                    selector: 'node[type = "service"]',
                    style: {
                        "background-color": "#1E293B",
                        label: "data(label)",
                        color: "#E2E8F0",
                        "font-family": "Inter, Roboto, Segoe UI, system-ui, sans-serif",
                        "font-size": "10px",
                        "line-height": 1.45,
                        "text-wrap": "wrap",
                        "text-max-width": "120px",
                        "border-color": "#F97316",
                        "border-width": 2,
                        shape: "round-rectangle",
                        padding: "8px"
                    }
                },
                {
                    selector: "edge",
                    style: {
                        "line-color": "#334155",
                        "target-arrow-color": "#334155",
                        "target-arrow-shape": "triangle",
                        "curve-style": "bezier",
                        width: 2
                    }
                }
            ],
            layout: {
                name: "breadthfirst",
                directed: true,
                spacingFactor: 1.2
            }
        });
    }

    function renderTopology(topologyPayload) {
        initTopologyGraph();
        const topology = topologyPayload.topology ? topologyPayload.topology : topologyPayload;

        const nodes = (topology.nodes || []).map((node) => {
            const isHost = node.type === "host";
            const serviceMeta = [node.product, node.version].filter(Boolean).join(" ").trim();
            const label = isHost
                ? `${node.id}${node.os ? `\n${node.os}` : ""}`
                : `${node.service || "unknown"}:${node.port}${serviceMeta ? `\n${serviceMeta}` : ""}`;

            return {
                data: {
                    id: node.id,
                    type: node.type,
                    label: label
                }
            };
        });

        const edges = (topology.edges || []).map((edge) => ({
            data: {
                id: `${edge.from}->${edge.to}`,
                source: edge.from,
                target: edge.to
            }
        }));

        topologyCy.elements().remove();
        topologyCy.add([...nodes, ...edges]);
        topologyCy.layout({
            name: "breadthfirst",
            directed: true,
            spacingFactor: 1.2,
            animate: true
        }).run();
        topologyCy.fit(undefined, 28);
    }

    function sleep(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    async function pollFullScanJob(jobId, scanStatus) {
        for (let attempt = 0; attempt < 120; attempt++) {
            await sleep(2000);
            const response = await fetch(`${SCAN_ENDPOINT}?job_id=${encodeURIComponent(jobId)}`);
            const data = await response.json();
            if (!response.ok) {
                throw new Error(data.detail || "Scan polling failed");
            }

            if (data.status === "completed") {
                renderTopology(data);
                applyWebScanResults(data);
                scanStatus.innerText = data.detected_ip
                    ? `Full scan complete for ${data.detected_ip} | ${data.vulnerabilities.length} web findings`
                    : `Full scan complete | ${data.vulnerabilities.length} web findings`;
                scanStatus.className = "text-[10px] font-mono text-green-400 uppercase tracking-widest";
                return;
            }

            if (data.status === "failed") {
                applyWebScanResults(data);
                throw new Error(data.message || "OWASP ZAP scan failed");
            }

            scanStatus.innerText = data.message || "OWASP ZAP web scan running...";
        }

        scanStatus.innerText = "OWASP ZAP web scan still running (UI poll timeout)";
        scanStatus.className = "text-[10px] font-mono text-yellow-400 uppercase tracking-widest";
    }

    async function scanNetwork() {
        const targetInput = document.getElementById("scan-target");
        const scanStatus = document.getElementById("scan-status");
        const scanBtn = document.getElementById("scan-btn");
        const target = (targetInput.value || "").trim();
        const autoMode = target.length === 0;

        scanStatus.innerText = autoMode
            ? "Running full scan against detected infrastructure and AltoroMutual..."
            : `Running full scan against ${target} and AltoroMutual...`;
        scanStatus.className = "text-[10px] font-mono text-yellow-400 uppercase tracking-widest";
        scanBtn.disabled = true;
        scanBtn.classList.add("opacity-60", "cursor-not-allowed");

        try {
            const url = autoMode ? SCAN_ENDPOINT : `${SCAN_ENDPOINT}?target=${encodeURIComponent(target)}`;
            const response = await fetch(url);
            const data = await response.json();
            if (!response.ok) {
                throw new Error(data.detail || "Scan failed");
            }

            renderTopology(data);
            applyWebScanResults(data);
            if (data.status === "running" && data.job_id) {
                scanStatus.innerText = data.message || "OWASP ZAP web scan running...";
                await pollFullScanJob(data.job_id, scanStatus);
            } else {
                scanStatus.innerText = data.detected_ip
                    ? `Full scan complete for ${data.detected_ip}`
                    : `Full scan complete for ${target || "auto target"}`;
                scanStatus.className = "text-[10px] font-mono text-green-400 uppercase tracking-widest";
            }
        } catch (error) {
            scanStatus.innerText = `Scan error: ${error.message}`;
            scanStatus.className = "text-[10px] font-mono text-red-400 uppercase tracking-widest";
        } finally {
            scanBtn.disabled = false;
            scanBtn.classList.remove("opacity-60", "cursor-not-allowed");
        }
    }

    setInterval(syncDashboard, 3000);
    syncDashboard();
    initTopologyGraph();
</script>
</body>
</html>
