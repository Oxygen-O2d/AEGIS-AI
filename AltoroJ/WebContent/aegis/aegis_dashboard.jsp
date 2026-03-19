<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" isELIgnored="true" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AEGISAI — Security Dashboard</title>
    <link rel="icon" type="image/svg+xml" href="favicon.svg">
    
    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&family=Rajdhani:wght@500;600;700&family=Space+Grotesk:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    
    <!-- External Libs -->
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    
    <!-- Theme & Global Styles -->
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        'soc-bg': '#060B12',
                        'soc-surface': '#121924',
                        'soc-accent': '#0EA5E9',
                        'soc-border': '#2A3648',
                        'soc-red': '#EF4444',
                    },
                    fontFamily: {
                        sans: ['Space Grotesk', 'sans-serif'],
                        mono: ['"JetBrains Mono"', 'monospace'],
                        display: ['Rajdhani', 'sans-serif'],
                    }
                }
            }
        }
    </script>
    <style>
        :root {
            --color-soc-bg: #060B12;
            --color-soc-surface: #121924;
            --color-soc-accent: #0EA5E9;
            --color-soc-border: #2A3648;
        }
        body, html {
            height: 100vh;
            width: 100vw;
            margin: 0;
            padding: 0;
            overflow: hidden;
            background-color: var(--color-soc-bg);
            color: #E2E8F0;
            font-family: 'Space Grotesk', sans-serif;
        }

        .soc-panel {
            background-color: var(--color-soc-surface);
            border: 1px solid var(--color-soc-border);
            border-radius: 0.75rem;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
            display: flex;
            flex-direction: column;
            overflow: hidden;
            height: 100%;
        }

        .panel-header {
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.15em;
            text-transform: uppercase;
            color: var(--color-soc-accent);
            padding: 0.75rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
            background-color: rgba(0, 0, 0, 0.2);
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-family: 'Rajdhani', sans-serif;
        }

        .custom-scrollbar::-webkit-scrollbar { width: 4px; }
        .custom-scrollbar::-webkit-scrollbar-thumb {
            background: var(--color-soc-border);
            border-radius: 10px;
        }

        .resize-handle {
            flex: 0 0 8px;
            cursor: row-resize;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            z-index: 10;
            transition: background-color 0.2s;
        }
        .resize-handle:hover, .resize-handle:active { background-color: rgba(14, 165, 233, 0.12); }
        .resize-handle-grip { display: flex; gap: 3px; align-items: center; }
        .resize-handle-grip span { width: 4px; height: 4px; border-radius: 50%; background: var(--color-soc-border); transition: background 0.2s; }
        .resize-handle:hover .resize-handle-grip span { background: var(--color-soc-accent); }

        @keyframes shimmer { 0% { transform: translateX(-100%); } 100% { transform: translateX(100%); } }
        @keyframes spin-slow { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        .animate-shimmer { animation: shimmer 1.5s infinite; }
        .animate-spin-slow { animation: spin-slow 3s linear infinite; }

        .forensic-key-table { width: auto; max-width: 100%; table-layout: auto; border-collapse: collapse; }
        .forensic-key-table th, .forensic-key-table td { padding: 0.6rem 0.75rem; vertical-align: top; text-align: left; }
        .forensic-key-table .forensic-key-cell { color: #cbd5e1; font-weight: 700; letter-spacing: 0.01em; }
        .forensic-key-table .forensic-value-cell { color: #e2e8f0; font-weight: 600; word-break: break-word; }
        .prose h3 { color: #0EA5E9; font-weight: 900; text-transform: uppercase; border-bottom: 1px solid rgba(14, 165, 233, 0.2); padding-bottom: 0.5rem; margin-top: 2rem !important; }

        /* Animation Classes */
        .fade-in { animation: fadeIn 0.5s ease-out forwards; }
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
        .slide-in-right { animation: slideInRight 0.4s ease-out forwards; }
        @keyframes slideInRight { from { transform: translateX(20px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
    </style>
</head>
<body class="flex flex-col">

    <!-- OVERLAY: RCA FORENSICS MODAL -->
    <div id="rcaModal" class="hidden fixed inset-0 z-[100] flex items-center justify-center bg-black/90 backdrop-blur-lg p-6 opacity-0 transition-opacity duration-300">
        <div class="bg-[#0f172a] border border-[#0EA5E9]/40 w-full max-w-5xl h-[85vh] rounded-2xl overflow-hidden shadow-[0_0_80px_rgba(14,165,233,0.2)] flex flex-col">
            <div class="flex justify-between items-center border-b border-white/10 p-6 flex-none bg-black/40">
                <div class="flex items-center gap-4">
                    <div class="h-3 w-3 rounded-full bg-red-600 animate-pulse shadow-[0_0_10px_#ef4444]"></div>
                    <h2 class="text-2xl font-black italic text-white uppercase tracking-tighter font-display">AI Forensic Inquest</h2>
                </div>
                <button onclick="closeRcaModal()" class="text-gray-500 hover:text-red-500 transition-all hover:rotate-90 text-3xl p-2">✕</button>
            </div>
            <div id="rcaModalBody" class="flex-1 overflow-y-auto p-12 custom-scrollbar relative bg-[#0b1120]">
                <!-- Loaders or Content injected here -->
            </div>
            <div class="p-6 border-t border-white/5 bg-black/40 flex justify-end">
                <button onclick="closeRcaModal()" class="px-10 py-3 bg-white/5 hover:bg-soc-accent hover:text-black border border-white/10 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all duration-300">
                    Acknowledge Findings
                </button>
            </div>
        </div>
    </div>

    <!-- OVERLAY: REMEDIATION STEPS -->
    <div id="remediationOverlay" class="hidden fixed inset-0 z-[160] flex items-center justify-center bg-[radial-gradient(circle_at_top,#0ea5e933,transparent_45%),rgba(2,6,23,0.9)] backdrop-blur-md p-6 opacity-0 transition-opacity duration-300">
        <div class="w-full max-w-5xl h-[84vh] bg-gradient-to-b from-[#0f1b3a] via-[#0b1735] to-[#09132c] border border-[#38bdf8]/45 rounded-2xl shadow-[0_0_90px_rgba(14,165,233,0.25)] overflow-hidden flex flex-col">
            <div class="flex items-center justify-between px-6 py-5 border-b border-cyan-300/15 bg-black/40 flex-none">
                <div class="flex items-center gap-4">
                    <div class="h-3 w-3 rounded-full bg-red-500 shadow-[0_0_14px_#ef4444] animate-pulse"></div>
                    <div>
                        <h3 class="text-[30px] leading-none font-black italic text-white uppercase tracking-tighter">Response Playbook</h3>
                        <p class="text-[12px] text-cyan-100/70 mt-1 uppercase tracking-[2px]">Review and execute in sequence</p>
                    </div>
                </div>
                <button onclick="closeRemediation()" class="h-11 w-11 rounded-xl border border-white/15 hover:border-red-400 hover:text-red-400 hover:bg-red-500/10 text-gray-300 flex items-center justify-center transition-colors">
                    <i data-lucide="x"></i>
                </button>
            </div>
            <div id="remediationBody" class="flex-1 p-10 space-y-6 overflow-y-auto custom-scrollbar bg-gradient-to-b from-[#0b1735] to-[#0a142d]">
                <!-- Steps injected here -->
            </div>
            <div class="p-5 border-t border-cyan-300/15 bg-black/40 flex justify-end flex-none">
                <button onclick="closeRemediation()" class="px-8 py-3 rounded-xl bg-cyan-400/10 hover:bg-cyan-300 hover:text-[#021425] border border-cyan-300/35 text-cyan-100 text-[11px] font-black uppercase tracking-[2px] transition-all">
                    Acknowledge Steps
                </button>
            </div>
        </div>
    </div>

    <!-- HEADER: TOPBAR -->
    <header class="w-full h-[52px] bg-[#1A2333] border-b border-[#2A3648] flex items-center justify-between px-4 z-50 flex-none">
        <div class="flex items-center gap-2">
            <h1 class="text-sm font-black uppercase tracking-[3px] text-[#0EA5E9] italic font-display flex items-center gap-2">
                <img src="Logo.png" class="h-10 w-auto" alt="AEGIS Logo">
                AEGISAI
            </h1>
            <div class="h-4 w-[1px] bg-[#2A3648] mx-2"></div>
            <span class="text-[10px] font-bold text-gray-500 uppercase tracking-widest">Security Dashboard</span>
        </div>
        <div class="flex items-center gap-4">
            <button onclick="window.location.reload()" class="text-[9px] font-black uppercase tracking-widest flex items-center gap-2 px-3 py-1.5 rounded bg-red-900/10 border border-red-500/20 text-red-400 hover:bg-red-600 hover:text-white transition-all">
                <i data-lucide="trash-2" class="w-3 h-3"></i> Clear Feed
            </button>
            <div class="flex items-center gap-2">
                <div class="relative flex items-center justify-center">
                    <div id="connectionStatusDot" class="h-2 w-2 rounded-full bg-green-500"></div>
                    <div class="absolute h-4 w-4 rounded-full border border-green-500 animate-ping opacity-20"></div>
                </div>
                <span class="text-[10px] font-black text-gray-400 uppercase tracking-widest">AI Enginer</span>
            </div>
        </div>
    </header>

    <!-- MAIN DASHBOARD CONTENT -->
    <main class="flex-1 p-4 grid grid-cols-[335px_1fr_340px] gap-4 min-h-0 overflow-hidden">
        
        <!-- Left Column: Alerts Feed -->
        <section class="soc-panel">
            <div class="panel-header">
                <span><i data-lucide="radio" class="inline mr-2 text-red-500 animate-pulse"></i> Live Alerts</span>
                <span id="incident-count" class="text-red-500 font-bold bg-red-500/10 px-2 rounded">0</span>
            </div>
            <div id="threatFeed" class="flex-1 overflow-y-auto p-3 space-y-3 custom-scrollbar">
                <div class="text-center py-10 opacity-30">
                    <p class="font-mono text-[10px] uppercase tracking-widest text-gray-500">Awaiting Logs...</p>
                </div>
            </div>
        </section>

        <!-- Center Column: Visualization & Intel -->
        <section class="flex flex-col min-h-0" id="centerColRef">
            <!-- Topology Panel -->
            <div class="soc-panel relative" style="height: 60%; flex: none;" id="centerPanelTop">
                <div class="panel-header">Infrastructure Topology</div>
                <div class="flex-1 flex flex-col bg-[#0B1018] overflow-hidden">
                    <div class="p-3 border-b border-white/5 bg-black/40 flex items-center gap-2">
                        <input id="scanTargetInput" placeholder="Leave blank for auto-detect or enter IP/hostname" class="flex-1 bg-black/60 border border-[#2A3648] rounded px-3 py-2 text-[13px] font-mono outline-none focus:border-soc-accent">
                        <button onclick="dashboard.runScan()" class="px-4 py-2.5 rounded-md bg-[#0EA5E9] hover:bg-[#38BDF8] text-[#001018] text-[12px] font-black uppercase tracking-wide border border-[#7DD3FC] shadow-[0_0_18px_rgba(14,165,233,0.28)] transition-all" id="scanBtn">Scan Network</button>
                    </div>
                    <div class="px-3 py-2 text-[11px] font-mono uppercase tracking-wide text-gray-300 flex items-center gap-2 border-b border-white/5">
                        <div class="flex items-center gap-2" id="scanStatusArea">
                            <i data-lucide="activity" class="w-3 h-3"></i> <span id="scanStatusText">Manual scan idle</span>
                        </div>
                        <div class="ml-auto flex items-center gap-1">
                            <button onclick="dashboard.handleZoom(-0.15)" class="p-1 rounded border border-white/10 hover:bg-white/10 text-gray-400"><i data-lucide="zoom-out" class="w-3 h-3"></i></button>
                            <button onclick="dashboard.handleZoom(0.15)" class="p-1 rounded border border-white/10 hover:bg-white/10 text-gray-400"><i data-lucide="zoom-in" class="w-3 h-3"></i></button>
                            <button onclick="dashboard.resetView()" class="p-1 rounded border border-white/10 hover:bg-white/10 text-gray-400"><i data-lucide="rotate-ccw" class="w-3 h-3"></i></button>
                            <span class="ml-1 text-[11px] text-soc-accent" id="zoomLevelText">100%</span>
                        </div>
                    </div>
                    <div class="flex-1 relative overflow-hidden" id="topologyContainer" onmousedown="dashboard.handleMouseDown(event)" onmousemove="dashboard.handleMouseMove(event)" onmouseup="dashboard.handleMouseUp(event)" onmouseleave="dashboard.handleMouseUp(event)" onwheel="dashboard.handleWheel(event)">
                        <!-- SVG Injected here -->
                        <div id="topologyEmpty" class="h-full flex items-center justify-center text-center opacity-35">
                            <div>
                                <i data-lucide="search" class="mx-auto mb-3 text-soc-accent w-8 h-8"></i>
                                <p class="font-mono text-[13px] uppercase tracking-[2px]">Run Scan Network to map hosts/services</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="resize-handle" id="centerHandle">
                <div class="resize-handle-grip"><span></span><span></span><span></span></div>
            </div>

            <!-- Intel Panel -->
            <div class="soc-panel p-5 min-h-0 flex-1 flex flex-col" id="centerPanelBottom">
                <div class="panel-header -mx-5 -mt-5 mb-5 border-b-white/5">NVIDIA Intelligence Stream</div>
                <div class="flex-1 overflow-y-auto custom-scrollbar space-y-4" id="intelStream">
                    <div class="h-full flex items-center justify-center opacity-20 text-[10px] font-mono tracking-widest uppercase text-center italic">
                        Systems Nominal. Awaiting Alert Trigger...
                    </div>
                </div>
            </div>
        </section>

        <!-- Right Column: Status & Remediation -->
        <section class="flex flex-col min-h-0" id="rightColRef">
            <!-- Security Score Panel -->
            <div class="soc-panel overflow-hidden" style="height: 40%; flex: none;" id="rightPanelTop">
                <div class="panel-header">Security Score</div>
                <div class="flex-1 flex items-center justify-center p-2 overflow-hidden" id="securityStatusSection">
                    <div class="w-full max-w-[300px] flex items-center justify-center gap-4">
                        <div class="relative flex items-center justify-center shrink-0">
                            <svg class="w-28 h-28 transform -rotate-90">
                                <circle cx="56" cy="56" r="48" stroke="rgba(255,255,255,0.05)" strokeWidth="8" fill="transparent" />
                                <circle id="scoreRing" cx="56" cy="56" r="48" stroke="#10B981" stroke-width="8" fill="transparent" stroke-dasharray="301.6" stroke-dashoffset="0" style="transition: stroke-dashoffset 1s ease-in-out;" stroke-linecap="round" />
                            </svg>
                            <div class="absolute flex flex-col items-center justify-center text-center px-1">
                                <span class="text-sm font-black uppercase tracking-[1px] text-white leading-tight" id="scoreSeverityLabel">NONE</span>
                                <span class="text-[8px] font-bold text-gray-500 uppercase">Threat Level</span>
                            </div>
                        </div>
                        <div class="min-w-0 flex flex-col items-start gap-2">
                            <p class="text-[8px] font-black uppercase tracking-[2px] text-gray-500 leading-tight">Average Security Score</p>
                            <p class="text-2xl font-black text-soc-accent leading-none whitespace-nowrap"><span id="scoreNumber">100</span> / 100</p>
                            <div id="scoreVerdictBadge" class="px-3 py-1 rounded-full border border-white/10 flex items-center gap-2 bg-green-500/10 text-green-500">
                                <i data-lucide="shield-check" class="w-3 h-3"></i>
                                <span class="text-[10px] font-black uppercase tracking-[2px]">SECURE</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="resize-handle" id="rightHandle">
                 <div class="resize-handle-grip"><span></span><span></span><span></span></div>
            </div>

            <!-- Remediation Playbook Panel -->
            <div class="soc-panel flex-1 min-h-0 overflow-hidden">
                <div class="panel-header">Remediation Playbook</div>
                <div class="flex-1 overflow-y-auto custom-scrollbar p-5" id="remediationPanel">
                    <div class="h-full flex flex-col items-center justify-center opacity-30 text-center p-6">
                        <i data-lucide="terminal" class="mb-3 text-gray-500 w-8 h-8"></i>
                        <p class="font-mono text-[10px] uppercase tracking-[3px]">Analyzing Vector...</p>
                        <p class="text-[9px] text-gray-600 mt-2 italic">Awaiting AI-Generated Playbook</p>
                    </div>
                </div>
            </div>
        </section>
    </main>

    <!-- CORE APPLICATION LOGIC -->
    <script>
        const API_URL = "http://127.0.0.1:8000/api/v1/alerts";
        const SCAN_URL = "http://127.0.0.1:8000/scan-full";

        // --- DASHBOARD STATE ---
        const state = {
            incidents: [],
            activeId: null,
            reconAlerts: [],
            reconIntel: null,
            reconStatus: 'idle',
            reconTarget: '',
            zoom: 1,
            pan: { x: 0, y: 0 },
            isDragging: false,
            dragOrigin: { x: 0, y: 0 },
            isRcaLoading: false,
            topology: { nodes: [], edges: [] }
        };

        // --- UTILS ---
        function calculateSecurityScore(severity, id, riskDelta = 0) {
            const baseScores = { critical: 15, high: 35, medium: 65, info: 95, none: 100 };
            const currentSev = severity?.toLowerCase() || 'none';
            const baseValue = baseScores[currentSev] || 100;
            let entropy = 0;
            if (id) {
                const lastChar = String(id).slice(-1);
                entropy = parseInt(lastChar, 16) || 0;
            }
            const penalty = Number.isFinite(Number(riskDelta)) ? Number(riskDelta) : 0;
            const rawScore = currentSev === 'none' ? 100 - penalty : baseValue + (entropy % 10) - penalty;
            return Math.min(100, Math.max(5, rawScore));
        }

        function escapeHtml(val) {
            return String(val || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
        }

        // --- CORE UI FUNCTIONS ---
        const dashboard = {
            init() {
                lucide.createIcons();
                this.setupResizers();
                this.startPolling();
                this.render(true); // Forced first render
            },

            setupResizers() {
                const setup = (handleId, panelId, containerId) => {
                    const h = document.getElementById(handleId);
                    const p = document.getElementById(panelId);
                    const c = document.getElementById(containerId);
                    let active = false, start, startSize;
                    h.onmousedown = (e) => { 
                        active = true; start = e.clientY; startSize = p.offsetHeight; 
                        document.body.style.cursor = 'row-resize';
                    };
                    window.addEventListener('mousemove', (e) => {
                        if (!active) return;
                        const delta = e.clientY - start;
                        const nextSize = Math.max(100, Math.min(startSize + delta, c.offsetHeight - 100));
                        p.style.height = nextSize + 'px';
                    });
                    window.addEventListener('mouseup', () => { active = false; document.body.style.cursor = ''; });
                };
                setup('centerHandle', 'centerPanelTop', 'centerColRef');
                setup('rightHandle', 'rightPanelTop', 'rightColRef');
            },

            async startPolling() {
                const fetchIncidents = async () => {
                    try {
                        const res = await fetch(API_URL);
                        const data = await res.json();
                        const incoming = data.incidents || [];
                        
                        // Dirty check to prevent unnecessary re-renders (Fixes "Tweaking")
                        const hasChanged = JSON.stringify(incoming) !== JSON.stringify(state.incidents);
                        
                        if (hasChanged) {
                            state.incidents = incoming;
                            if (!state.activeId && incoming.length > 0) {
                                state.activeId = incoming[incoming.length - 1].id;
                            }
                            this.render();
                        }
                        const statusDot = document.getElementById('connectionStatusDot');
                        if (statusDot) {
                             statusDot.classList.remove('bg-gray-500');
                             statusDot.classList.add('bg-green-500');
                        }
                    } catch (e) {
                         const statusDot = document.getElementById('connectionStatusDot');
                         if (statusDot) {
                              statusDot.classList.remove('bg-green-500');
                              statusDot.classList.add('bg-gray-500');
                         }
                    }
                };
                setInterval(fetchIncidents, 3000);
                fetchIncidents();
            },

            render(force = false) {
                // Individual component renders
                this.renderThreatFeed();
                this.renderIntelStream();
                this.renderSecurityScore();
                this.renderRemediation();
                this.renderTopology();
                
                // Only refresh icons if something actually changed or forced
                if (force || document.querySelectorAll('[data-lucide-id]').length === 0) {
                    lucide.createIcons();
                }
            },

            renderThreatFeed() {
                const container = document.getElementById('threatFeed');
                const badge = document.getElementById('incident-count');
                const total = state.incidents.length + state.reconAlerts.length;
                badge.innerText = total;

                if (total === 0) {
                    container.innerHTML = '<div class="text-center py-10 opacity-30"><p class="font-mono text-[10px] uppercase tracking-widest text-gray-500">Awaiting Logs...</p></div>';
                    return;
                }

                let html = '';
                // Recon Alerts
                state.reconAlerts.forEach((alert, idx) => {
                    html += `
                        <div class="p-3 rounded-lg border-l-4 border-red-500 bg-red-500/10 border-t border-r border-b border-white/5 slide-in-right">
                             <div class="flex justify-between items-center mb-1">
                                <div class="flex items-center gap-2">
                                     <i data-lucide="alert-triangle" class="text-red-500 w-3 h-3"></i>
                                     <span class="text-[9px] font-black px-1.5 py-0.5 rounded bg-black/50 text-red-300 uppercase tracking-tighter">Recon High</span>
                                </div>
                             </div>
                             <p class="text-xs font-bold uppercase tracking-tighter italic text-red-200">${escapeHtml(alert.message || alert.type)}</p>
                             <div class="mt-2 text-[9px] text-gray-300 break-all font-mono opacity-60">${escapeHtml(alert.data || '')}</div>
                        </div>
                    `;
                });

                // Incidents
                [...state.incidents].reverse().forEach(inc => {
                    const sev = (inc.triage_alert?.severity || 'info').toLowerCase();
                    const isHigh = sev === 'high' || sev === 'critical';
                    const isActive = state.activeId === inc.id;
                    const border = isHigh ? 'border-red-500' : (sev === 'medium' ? 'border-orange-500' : 'border-blue-500');
                    const bg = isActive ? 'ring-1 ring-soc-accent bg-white/10' : 'hover:bg-white/10 bg-white/5 border-t border-r border-b border-white/5';
                    const icon = isHigh ? 'shield-alert' : 'info';
                    const iconColor = isHigh ? 'text-red-500' : 'text-blue-400';

                    html += `
                        <div onclick="dashboard.setActiveId('${inc.id}')" class="p-3 rounded-lg border-l-4 ${border} ${bg} cursor-pointer transition-all duration-200 group slide-in-right">
                            <div class="flex justify-between items-center mb-1">
                                <div class="flex items-center gap-2">
                                     <i data-lucide="${icon}" class="${iconColor} w-3 h-3"></i>
                                     <span class="text-[9px] font-black px-1.5 py-0.5 rounded bg-black/50 text-gray-300 uppercase tracking-tighter">${sev.toUpperCase()}</span>
                                </div>
                                <span class="text-[8px] font-mono text-gray-600">#${inc.id.slice(0,8)}</span>
                            </div>
                            <p class="text-xs font-bold uppercase tracking-tighter italic ${isActive ? 'text-soc-accent' : 'text-white'}">${escapeHtml(inc.triage_alert?.threat_type || 'Unknown')}</p>
                            <div class="mt-2 flex items-center justify-between">
                                <span class="text-[8px] font-mono text-gray-500 uppercase">${inc.source}</span>
                                ${isActive ? '<div class="h-1.5 w-1.5 rounded-full bg-soc-accent animate-pulse shadow-[0_0_8px_#0EA5E9]"></div>' : ''}
                            </div>
                        </div>
                    `;
                });
                container.innerHTML = html;
            },

            setActiveId(id) {
                state.activeId = id;
                this.render();
            },

            renderIntelStream() {
                const container = document.getElementById('intelStream');
                const activeInc = state.incidents.find(i => i.id === state.activeId);
                const hasRecon = state.reconIntel && Object.values(state.reconIntel).some(v => Number(v) > 0);
                
                if (!activeInc && !hasRecon && state.reconStatus === 'idle') {
                    container.innerHTML = '<div class="h-full flex items-center justify-center opacity-20 text-[10px] font-mono tracking-widest uppercase text-center italic">Systems Nominal. Awaiting Alert Trigger...</div>';
                    return;
                }

                let html = '';
                if (hasRecon || state.reconStatus !== 'idle') {
                    html += `
                        <div class="bg-[#111827] border border-[#2A3648] rounded-lg p-3 fade-in">
                            <p class="text-[12px] font-black uppercase tracking-wide text-soc-accent mb-2">Recon Intelligence ${state.reconTarget ? `(${state.reconTarget})` : ''}</p>
                            <p class="text-[12px] text-gray-300 uppercase tracking-wide mb-3">Status: ${state.reconStatus}</p>
                            ${state.reconIntel ? `
                                <div class="grid grid-cols-2 gap-2 text-[12px]">
                                    <div class="bg-black/40 rounded px-2 py-1">Subdomains: ${state.reconIntel.subdomains || 0}</div>
                                    <div class="bg-black/40 rounded px-2 py-1">Emails: ${state.reconIntel.emails || 0}</div>
                                    <div class="bg-black/40 rounded px-2 py-1">DNS Records: ${state.reconIntel.dns_records || 0}</div>
                                    <div class="bg-black/40 rounded px-2 py-1">Breaches: ${state.reconIntel.breaches || 0}</div>
                                    <div class="bg-black/40 rounded px-2 py-1 text-soc-accent">Risk Delta: ${state.reconIntel.risk_delta || 0}</div>
                                </div>
                            ` : ''}
                        </div>
                    `;
                }

                if (activeInc) {
                    html += `
                        <div class="bg-black/50 p-4 rounded-lg border border-white/5 font-mono text-[13px] text-soc-accent break-all leading-relaxed shadow-inner fade-in">
                            <span class="text-gray-500 text-[11px] block mb-2 font-bold tracking-wide uppercase">Raw Telemetry:</span>
                            ${escapeHtml(activeInc.log_content || JSON.stringify(activeInc, null, 2))}
                        </div>
                        <button onclick="dashboard.handleGenerateRCA()" class="w-full bg-[#1e3a8a] hover:bg-blue-600 text-white py-4 rounded-lg text-[12px] font-black uppercase tracking-wide border border-blue-400 transition-all flex items-center justify-center gap-2 shadow-lg active:scale-95 group">
                             <i data-lucide="zap" class="w-4 h-4 group-hover:scale-125 transition-transform"></i> Analyze Incident Forensics
                        </button>
                    `;
                }
                container.innerHTML = html;
            },

            renderSecurityScore() {
                if (state.incidents.length === 0) {
                    document.getElementById('scoreRing').style.strokeDashoffset = 0;
                    document.getElementById('scoreNumber').innerText = '100';
                    document.getElementById('scoreSeverityLabel').innerText = 'NONE';
                    return;
                }

                const calculateAvg = () => {
                    const scores = state.incidents.map(inc => calculateSecurityScore(inc.triage_alert?.severity, inc.id, inc.intel_summary?.risk_delta || 0));
                    const avg = scores.reduce((a,b)=>a+b, 0) / scores.length;
                    const hasCrit = state.incidents.some(i => i.triage_alert?.severity?.toLowerCase() === 'critical');
                    const highCount = state.incidents.filter(i => i.triage_alert?.severity?.toLowerCase() === 'high').length;
                    if (highCount > 2) return Math.min(avg, 29);
                    if (hasCrit) return Math.min(avg, 25);
                    if (highCount > 0) return Math.min(avg, 48);
                    return avg;
                };

                const avg = Math.round(calculateAvg());
                const ring = document.getElementById('scoreRing');
                const circ = 2 * Math.PI * 48; // 301.6
                const offset = circ - (avg / 100) * circ;
                ring.style.strokeDashoffset = offset;
                document.getElementById('scoreNumber').innerText = avg;

                const activeInc = state.incidents.find(i => i.id === state.activeId);
                const sevLabel = document.getElementById('scoreSeverityLabel');
                const badge = document.getElementById('scoreVerdictBadge');
                
                sevLabel.innerText = activeInc ? (activeInc.triage_alert?.severity || 'INFO').toUpperCase() : 'NONE';
                
                if (avg > 80) {
                    ring.style.stroke = '#10B981';
                    badge.className = 'px-3 py-1 rounded-full border border-white/10 flex items-center gap-2 bg-green-500/10 text-green-500';
                    badge.innerHTML = '<i data-lucide="shield-check" class="w-3 h-3"></i> <span class="text-[10px] font-black uppercase tracking-[2px]">SECURE</span>';
                } else if (avg > 50) {
                    ring.style.stroke = '#F59E0B';
                    badge.className = 'px-3 py-1 rounded-full border border-white/10 flex items-center gap-2 bg-orange-500/10 text-orange-400';
                    badge.innerHTML = '<i data-lucide="info" class="w-3 h-3"></i> <span class="text-[10px] font-black uppercase tracking-[2px]">WARNING</span>';
                } else {
                    ring.style.stroke = '#EF4444';
                    badge.className = 'px-3 py-1 rounded-full border border-white/10 flex items-center gap-2 bg-red-500/10 text-red-500';
                    badge.innerHTML = '<i data-lucide="shield-alert" class="w-3 h-3"></i> <span class="text-[10px] font-black uppercase tracking-[2px]">CRITICAL</span>';
                }
            },

            renderRemediation() {
                const container = document.getElementById('remediationPanel');
                const activeInc = state.incidents.find(i => i.id === state.activeId);
                const rem = activeInc?.deep_analysis?.remediation;
                const hasData = rem && rem !== "PENDING";

                if (!hasData) {
                    container.innerHTML = `
                         <div class="h-full flex flex-col items-center justify-center opacity-30 text-center p-6">
                            <i data-lucide="terminal" class="mb-3 text-gray-500 w-8 h-8"></i>
                            <p class="font-mono text-[10px] uppercase tracking-[3px]">Analyzing Vector...</p>
                            <p class="text-[9px] text-gray-600 mt-2 italic">Awaiting AI-Generated Playbook</p>
                        </div>
                    `;
                    return;
                }

                container.innerHTML = `
                    <div class="flex flex-col h-full fade-in">
                        <div class="flex items-center gap-3 mb-4 p-3 rounded-lg bg-green-500/5 border border-green-500/20">
                            <i data-lucide="zap" class="text-yellow-400 fill-yellow-400 w-4 h-4"></i>
                            <div>
                                <h4 class="text-[10px] font-black text-white uppercase tracking-widest">Response Playbook</h4>
                                <p class="text-[9px] text-green-500 font-bold uppercase">Ready for Execution</p>
                            </div>
                        </div>
                        <div class="flex-1 flex items-center justify-center border border-dashed border-[#2A3648] rounded-lg text-center px-4">
                            <p class="text-[11px] text-gray-400 uppercase tracking-[2px] font-mono leading-relaxed">Click Show Steps to view the response playbook.</p>
                        </div>
                        <div class="pt-4 mt-4 border-t border-white/5">
                            <button onclick="dashboard.openRemediation()" class="w-full relative group flex items-center justify-center gap-3 bg-green-600 hover:bg-green-500 text-white py-4 rounded-xl text-[11px] font-black uppercase tracking-[2px] transition-all shadow-[0_0_20px_rgba(22,163,74,0.2)] active:scale-[0.98]">
                                <i data-lucide="zap" class="w-4.5 h-4.5"></i> <span>Show Steps</span>
                            </button>
                            <p class="text-[8px] text-center text-gray-500 mt-3 font-mono uppercase tracking-tighter">Action will be logged to Audit Trail (ADMIN_ROOT)</p>
                        </div>
                    </div>
                `;
            },

            openRemediation() {
                const activeInc = state.incidents.find(i => i.id === state.activeId);
                const overlay = document.getElementById('remediationOverlay');
                const body = document.getElementById('remediationBody');
                
                body.innerHTML = `
                    <div class="rounded-2xl border border-cyan-300/20 bg-cyan-300/5 p-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.08)]">
                        <span class="text-[13px] font-black text-cyan-300 uppercase block mb-3 tracking-[2px]">Step 1: Containment</span>
                        <p class="text-[20px] text-slate-100 leading-relaxed font-semibold">${activeInc?.deep_analysis?.remediation || 'Automate network isolation for targeted service host.'}</p>
                    </div>
                    <div class="rounded-2xl border border-slate-300/15 bg-slate-300/5 p-6">
                        <span class="text-[13px] font-black text-slate-100 uppercase block mb-3 tracking-[2px]">Step 2: Eradication</span>
                        <p class="text-[20px] text-slate-100/95 leading-relaxed">Flush session tokens and rotate API credentials for affected service identity.</p>
                    </div>
                    <div class="rounded-2xl border border-slate-300/15 bg-slate-300/5 p-6">
                        <span class="text-[13px] font-black text-slate-100 uppercase block mb-3 tracking-[2px]">Step 3: Recovery</span>
                        <p class="text-[20px] text-slate-100/95 leading-relaxed">Enable enhanced logging on the affected container for the next 24 hours.</p>
                    </div>
                `;
                overlay.classList.remove('hidden');
                setTimeout(()=>overlay.classList.remove('opacity-0'), 10);
                lucide.createIcons();
            },

            renderTopology() {
                const container = document.getElementById('topologyContainer');
                const empty = document.getElementById('topologyEmpty');
                
                if (state.topology.nodes.length === 0) {
                    empty.classList.remove('hidden');
                    return;
                }
                empty.classList.add('hidden');

                // Graph Viz Logic
                const hosts = state.topology.nodes.filter(n => n.type === 'host');
                const nodeMap = new Map(state.topology.nodes.map(n => [n.id, n]));

                const positionedHosts = hosts.map((h, i) => ({
                    ...h, x: 150, y: 90 + i * 160, width: 220
                }));

                const positionedServices = [];
                positionedHosts.forEach(h => {
                    const connections = state.topology.edges.filter(e => e.from === h.id);
                    connections.forEach((e, idx) => {
                        const s = nodeMap.get(e.to);
                        if (!s) return;
                        positionedServices.push({
                            ...s, x: h.x + 220 + 52, y: h.y - 25 + idx * 62, width: 200, hostId: h.id
                        });
                    });
                });

                let svgContent = `<g transform="translate(${state.pan.x} ${state.pan.y}) scale(${state.zoom})">`;
                
                // Lines
                positionedServices.forEach(s => {
                    const h = positionedHosts.find(host => host.id === s.hostId);
                    svgContent += `<line x1="${h.x + 220}" y1="${h.y + 22}" x2="${s.x}" y2="${s.y + 18}" stroke="#334155" stroke-width="2" />`;
                });

                // Hosts
                positionedHosts.forEach(h => {
                    svgContent += `
                        <g transform="translate(${h.x}, ${h.y})">
                            <rect width="220" height="44" rx="10" fill="#0EA5E9" fill-opacity="0.22" stroke="#38BDF8" stroke-width="2" />
                            <text x="12" y="18" fill="#E2E8F0" font-size="12" font-weight="700">${escapeHtml(h.id)}</text>
                            <text x="12" y="33" fill="#94A3B8" font-size="10">${escapeHtml(h.os || 'OS Unknown')}</text>
                        </g>
                    `;
                });

                // Services
                positionedServices.forEach(s => {
                    svgContent += `
                        <g transform="translate(${s.x}, ${s.y})">
                            <rect width="200" height="44" rx="10" fill="#1E293B" stroke="#F97316" stroke-width="1.5" />
                            <text x="12" y="16" fill="#E2E8F0" font-size="11" font-weight="700">${escapeHtml(s.service)}:${s.port}</text>
                            <text x="12" y="29" fill="#94A3B8" font-size="10">${escapeHtml(s.product || 'unknown')}</text>
                        </g>
                    `;
                });

                svgContent += '</g>';
                container.innerHTML = `<svg width="100%" height="100%" class="cursor-grab">${svgContent}</svg>`;
            },

            // Interactivity
            handleZoom(delta) { 
                state.zoom = Math.max(0.5, Math.min(state.zoom + delta, 3)); 
                document.getElementById('zoomLevelText').innerText = Math.round(state.zoom * 100) + '%';
                this.renderTopology(); 
            },
            resetView() { state.zoom = 1; state.pan = {x:0,y:0}; document.getElementById('zoomLevelText').innerText = '100%'; this.renderTopology(); },
            handleWheel(e) { e.preventDefault(); this.handleZoom(e.deltaY > 0 ? -0.1 : 0.1); },
            handleMouseDown(e) { state.isDragging = true; state.dragOrigin = { x: e.clientX - state.pan.x, y: e.clientY - state.pan.y }; },
            handleMouseMove(e) { if(state.isDragging) { state.pan = { x: e.clientX - state.dragOrigin.x, y: e.clientY - state.dragOrigin.y }; this.renderTopology(); } },
            handleMouseUp() { state.isDragging = false; },

            async runScan() {
                const target = document.getElementById('scanTargetInput').value;
                const btn = document.getElementById('scanBtn');
                btn.disabled = true; btn.innerText = 'Scanning...';
                document.getElementById('scanStatusText').innerText = target ? `Scanning ${target}...` : 'Scanning detected server IP...';

                try {
                    const url = target ? `${SCAN_URL}?target=${encodeURIComponent(target)}` : SCAN_URL;
                    const res = await fetch(url);
                    const data = await res.json();
                    state.topology = data.topology || { nodes: data.nodes || [], edges: data.edges || [] };
                    state.reconIntel = data.intel_summary;
                    state.reconStatus = data.status || 'completed';
                    state.reconTarget = data.detected_ip || target;
                    if (data.status === 'running' && data.job_id) {
                         this.pollScan(data.job_id);
                    }
                } catch(e) {}
                btn.disabled = false; btn.innerText = 'Scan Network';
                this.render();
            },

            async pollScan(jobId) {
                for(let i=0; i<60; i++) {
                    await new Promise(r => setTimeout(r, 2000));
                    const res = await fetch(`${SCAN_URL}?job_id=${encodeURIComponent(jobId)}`);
                    const data = await res.json();
                    state.reconIntel = data.intel_summary;
                    state.reconStatus = data.status;
                    if (data.status === 'completed' || data.status === 'failed') {
                         state.topology = data.topology || { nodes: data.nodes || [], edges: data.edges || [] };
                         this.render();
                         return;
                    }
                    this.render();
                }
            },

            handleGenerateRCA() {
                if (!state.activeId) return;
                const modal = document.getElementById('rcaModal');
                const body = document.getElementById('rcaModalBody');
                modal.classList.remove('hidden');
                setTimeout(()=>modal.classList.remove('opacity-0'), 10);
                
                body.innerHTML = `
                    <div class="absolute inset-0 flex flex-col items-center justify-center bg-[#0f172a] z-50">
                        <div class="relative flex items-center justify-center mb-10">
                            <i data-lucide="loader-2" class="text-[#0EA5E9] animate-spin-slow w-16 h-16"></i>
                            <i data-lucide="activity" class="absolute text-[#0EA5E9] animate-pulse w-8 h-8"></i>
                        </div>
                        <p class="text-xs font-black uppercase tracking-[8px] text-[#0EA5E9] animate-pulse">Reconstructing Vector</p>
                    </div>`;
                lucide.createIcons();

                fetch(`http://127.0.0.1:8000/api/v1/rca/${state.activeId}`)
                    .then(r => r.json())
                    .then(data => {
                        setTimeout(() => {
                            if (data.report_json) {
                                body.innerHTML = this.renderStructuredRca(data.report_json);
                            } else {
                                body.innerHTML = '<div class="prose prose-invert max-w-none">' + marked.parse(data.report || '# No Data') + '</div>';
                            }
                            lucide.createIcons();
                        }, 1200);
                    })
                    .catch(e => {
                        body.innerHTML = '<p class="text-red-500 font-bold uppercase tracking-widest text-center mt-10">Alert: Connection to NVIDIA Inference Engine timed out.</p>';
                    });
            },

            renderStructuredRca(json) {
                const details = Object.entries(json.key_details || {}).map(([k,v]) => `<tr><th class="forensic-key-cell">${escapeHtml(k)}</th><td class="forensic-value-cell">${escapeHtml(v)}</td></tr>`).join('');
                const steps = (json.response_steps || []).map((s,i) => `<li><p><strong>${i+1}. ${escapeHtml(s.title || '')}</strong></p><p>${escapeHtml(s.action)}</p></li>`).join('');
                const checklist = (json.post_incident_checklist || []).map(li => `<li>${escapeHtml(li)}</li>`).join('');

                return `
                    <div class="prose prose-invert max-w-none fade-in">
                        <section><h3>Executive Summary</h3><p>${escapeHtml(json.executive_summary)}</p></section>
                        <section><h3>Key Details</h3><table class="forensic-key-table"><tbody>${details}</tbody></table></section>
                        <section><h3>Root Cause</h3><p><strong>What:</strong> ${escapeHtml(json.root_cause?.what_happened)}</p><p><strong>How:</strong> ${escapeHtml(json.root_cause?.how_it_happened)}</p></section>
                        <section><h3>Response Steps</h3><ol>${steps}</ol></section>
                        <section><h3>Post-Incident Checklist</h3><ul>${checklist}</ul></section>
                    </div>
                `;
            }
        };

        function closeRcaModal() { const m = document.getElementById('rcaModal'); m.classList.add('opacity-0'); setTimeout(()=>m.classList.add('hidden'), 300); }
        function closeRemediation() { const m = document.getElementById('remediationOverlay'); m.classList.add('opacity-0'); setTimeout(()=>m.classList.add('hidden'), 300); }

        window.dashboard = dashboard;
        window.closeRcaModal = closeRcaModal;
        window.closeRemediation = closeRemediation;
        
        document.addEventListener('DOMContentLoaded', () => dashboard.init());
    </script>
</body>
</html>
