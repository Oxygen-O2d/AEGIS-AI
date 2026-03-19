<%@ include file="header.jspf" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Subsume | SOC Autonomous Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        body { background-color: #050505; color: #e5e7eb; font-family: 'Inter', sans-serif; }
        .glass-panel { background: rgba(17, 24, 39, 0.7); backdrop-filter: blur(12px); border: 1px solid rgba(255, 255, 255, 0.08); }
        .alert-card { transition: all 0.3s ease; border-left-width: 4px; }
        .alert-card:hover { transform: translateX(5px); background: rgba(31, 41, 55, 0.5); }
        .status-pulse { animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite; }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: .5; } }
        
        /* Custom Scrollbar for Alert List and Modal */
        .custom-scrollbar::-webkit-scrollbar { width: 6px; }
        .custom-scrollbar::-webkit-scrollbar-track { background: #111827; }
        .custom-scrollbar::-webkit-scrollbar-thumb { background: #374151; border-radius: 4px; }
        
        /* RCA Modal & Markdown Styling */
        #rca-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); z-index: 999; backdrop-filter: blur(4px); }
        #rca-modal { display: none; position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 65%; max-width: 900px; background: #0f172a; color: #e2e8f0; padding: 2rem; border-radius: 12px; border: 1px solid #3b82f6; z-index: 1000; max-height: 85vh; overflow-y: auto; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.75); }
        #rca-content h3 { color: #38bdf8; margin-top: 1.5rem; margin-bottom: 0.5rem; font-size: 1.1rem; text-transform: uppercase; letter-spacing: 0.05em; font-weight: 700; }
        #rca-content p { margin-bottom: 1rem; color: #94a3b8; font-size: 0.95rem; line-height: 1.6; }
        #rca-content ol, #rca-content ul { padding-left: 1.5rem; margin-bottom: 1rem; color: #cbd5e1; font-size: 0.95rem; }
        #rca-content li { margin-bottom: 0.5rem; }
        #rca-content strong { color: #f8fafc; }
        #rca-content code { background: #000; color: #4ade80; padding: 0.2rem 0.4rem; border-radius: 4px; font-family: monospace; border: 1px solid rgba(255,255,255,0.1); }
    </style>
</head>
<body class="p-8">

    <div class="flex justify-between items-end mb-10">
        <div>
            <h1 class="text-4xl font-black tracking-tighter text-white italic">SUBSUME<span class="text-red-600">.OS</span></h1>
            <p class="text-gray-500 font-mono text-[10px] mt-1 uppercase tracking-widest">NVIDIA NIM & GROQ POWERED THREAT FABRIC</p>
        </div>
        <div class="flex items-center gap-4">
            <button onclick="clearLogs()" class="text-[10px] bg-gray-900 hover:bg-red-900/40 text-gray-400 hover:text-red-400 px-4 py-2 rounded-lg border border-white/5 transition-all uppercase font-bold">
                <i class="fas fa-trash-alt mr-2"></i> Clear Feed
            </button>
            
            <div id="connection-status" class="glass-panel px-4 py-2 rounded-lg flex items-center gap-3 border-green-500/20">
                <div class="h-2 w-2 rounded-full bg-green-500 status-pulse"></div>
                <span class="text-[10px] font-mono uppercase tracking-widest text-green-500">Engine Linked</span>
            </div>
        </div>
    </div>

    <div class="glass-panel rounded-2xl overflow-hidden shadow-2xl shadow-black">
        <div class="bg-white/5 px-6 py-4 border-b border-white/10 flex justify-between items-center">
            <h3 class="font-bold uppercase tracking-widest text-xs text-gray-400">
                <i class="fas fa-bolt mr-2 text-yellow-500"></i> Real-Time Telemetry Ingest
            </h3>
            <span id="incident-count" class="text-[10px] font-black bg-red-600/20 text-red-500 px-2 py-0.5 rounded border border-red-500/30">0 INCIDENTS</span>
        </div>
        
        <div id="alert-list" class="p-6 space-y-4 max-h-[70vh] overflow-y-auto custom-scrollbar">
            <div class="text-center py-32 opacity-20">
                <i class="fas fa-satellite-dish animate-bounce text-5xl mb-4"></i>
                <p class="font-mono text-sm uppercase tracking-widest">Awaiting AWS CloudTrail Stream...</p>
            </div>
        </div>
    </div>

    <div id="rca-overlay" onclick="closeRCA()"></div>
    <div id="rca-modal" class="custom-scrollbar">
        <div class="flex justify-between items-center mb-4 border-b border-gray-700 pb-3">
            <h2 class="text-xl font-black text-white italic tracking-tighter uppercase"><i class="fas fa-file-contract text-blue-500 mr-2"></i> AI Root Cause Analysis</h2>
            <button onclick="closeRCA()" class="text-gray-400 hover:text-red-500 transition-colors">
                <i class="fas fa-times text-xl"></i>
            </button>
        </div>
        <div id="rca-content" class="mt-4">
            </div>
        <div class="mt-6 flex justify-end">
            <button onclick="closeRCA()" class="text-[10px] font-bold uppercase tracking-widest bg-gray-800 hover:bg-gray-700 text-white px-6 py-2 rounded border border-gray-600 transition-colors">
                Close Report
            </button>
        </div>
    </div>

    <script>
        const API_ENDPOINT = "http://127.0.0.1:8000/api/v1/alerts";
        const CLEAR_ENDPOINT = "http://127.0.0.1:8000/api/v1/clear";
        const RCA_ENDPOINT = "http://127.0.0.1:8000/api/v1/rca";

        async function clearLogs() {
            if(!confirm("Resetting the Subsume Engine will wipe all current incident data. Proceed?")) return;
            try {
                await fetch(CLEAR_ENDPOINT, { method: 'POST' });
                syncDashboard();
            } catch (err) { console.error("Reset Failed", err); }
        }

        async function generateRCA(incidentId) {
            // Show the modal in a loading state
            document.getElementById('rca-overlay').style.display = 'block';
            document.getElementById('rca-modal').style.display = 'block';
            document.getElementById('rca-content').innerHTML = `
                <div class="flex flex-col items-center justify-center py-10 opacity-70">
                    <i class="fas fa-circle-notch fa-spin text-4xl text-blue-500 mb-4"></i>
                    <p class="font-mono text-sm text-blue-300 uppercase tracking-widest">Generating Forensic Report...</p>
                </div>
            `;

            try {
                const response = await fetch(`${RCA_ENDPOINT}/${incidentId}`);
                const data = await response.json();

                if (data.report) {
                    // Parse the Markdown to HTML
                    document.getElementById('rca-content').innerHTML = marked.parse(data.report);
                } else {
                    document.getElementById('rca-content').innerHTML = `<p class="text-red-500 font-mono">Error: ${data.error || 'Failed to parse report.'}</p>`;
                }
            } catch (error) {
                document.getElementById('rca-content').innerHTML = `<p class="text-red-500 font-mono">Connection Error: Ensure backend is running.</p>`;
            }
        }

        function closeRCA() {
            document.getElementById('rca-overlay').style.display = 'none';
            document.getElementById('rca-modal').style.display = 'none';
        }

        // Close modal on Escape key press
        document.addEventListener('keydown', (e) => {
            if (e.key === "Escape") closeRCA();
        });

        async function syncDashboard() {
            try {
                const response = await fetch(API_ENDPOINT);
                if (!response.ok) throw new Error('Offline');
                
                const data = await response.json();
                const incidents = data.incidents;

                document.getElementById('incident-count').innerText = `${incidents.length} INCIDENTS`;
                const list = document.getElementById('alert-list');
                
                if (incidents.length === 0) {
                    list.innerHTML = `
                        <div class="text-center py-32 opacity-20">
                            <i class="fas fa-satellite-dish animate-bounce text-5xl mb-4"></i>
                            <p class="font-mono text-sm uppercase tracking-widest">Feed Cleared. Ready for Ingest.</p>
                        </div>`;
                    return;
                }

                list.innerHTML = incidents.map(inc => {
                    const isHigh = inc.triage_alert.severity.toLowerCase() === 'high' || inc.triage_alert.severity.toLowerCase() === 'critical';
                    const colorClass = isHigh ? 'border-red-600 bg-red-950/10' : 'border-cyan-600 bg-cyan-950/10';
                    const badgeClass = isHigh ? 'bg-red-600 shadow-red-900/50' : 'bg-cyan-600 shadow-cyan-900/50';

                    return `
                        <div class="alert-card glass-panel p-5 rounded-xl ${colorClass} border-l-4">
                            <div class="flex justify-between items-start">
                                <div>
                                    <div class="flex items-center gap-2 mb-1">
                                        <span class="text-[9px] font-mono text-gray-500 bg-black/40 px-2 py-0.5 rounded border border-white/5 uppercase italic">${inc.source}</span>
                                        <span class="text-[9px] font-mono text-gray-700">#${inc.id.substring(0,8)}</span>
                                    </div>
                                    <h4 class="text-xl font-black text-white uppercase tracking-tighter italic">${inc.triage_alert.threat_type}</h4>
                                </div>
                                <span class="${badgeClass} text-[10px] px-3 py-1 rounded-full font-black text-white shadow-lg uppercase tracking-widest">
                                    ${inc.triage_alert.severity}
                                </span>
                            </div>

                            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-5">
                                <div class="space-y-2">
                                    <p class="text-[9px] font-bold text-gray-600 uppercase">Input Telemetry</p>
                                    <div class="bg-black/80 p-3 rounded-lg border border-white/5 font-mono text-[10px] text-blue-400/80 break-all">
                                        ${inc.log_content}
                                    </div>
                                </div>
                                
                                <div class="space-y-2">
                                    <p class="text-[9px] font-bold text-cyan-600 uppercase italic">NVIDIA DeepSeek Intelligence</p>
                                    ${inc.deep_analysis === "PENDING" 
                                        ? `<div class="flex items-center gap-3 text-xs text-yellow-500 p-3 bg-yellow-500/5 rounded-lg border border-yellow-500/20">
                                            <i class="fas fa-brain animate-pulse"></i> Analyzing Threat Vector...
                                           </div>`
                                        : `<div class="p-3 bg-cyan-900/10 rounded-lg border border-cyan-500/20 space-y-3">
                                            <div class="flex items-center justify-between">
                                                <div class="flex items-center gap-2">
                                                    <span class="text-[10px] font-black bg-cyan-600 px-2 py-0.5 rounded text-white">${inc.deep_analysis.mitre_t_code}</span>
                                                    <p class="text-xs font-medium text-gray-300">${inc.deep_analysis.technique}</p>
                                                </div>
                                                <button onclick="generateRCA('${inc.id}')" class="text-[9px] bg-blue-900/40 hover:bg-blue-600 border border-blue-500/30 text-blue-300 hover:text-white px-3 py-1.5 rounded transition-all font-bold uppercase tracking-widest shadow-sm">
                                                    <i class="fas fa-file-alt mr-1"></i> RCA Report
                                                </button>
                                            </div>
                                            <div class="border-t border-white/5 pt-2">
                                                <p class="text-[9px] text-gray-500 font-bold uppercase mb-1">Response Playbook</p>
                                                <code class="text-[11px] text-green-400 font-mono">${inc.deep_analysis.remediation}</code>
                                            </div>
                                           </div>`
                                    }
                                </div>
                            </div>
                        </div>
                    `;
                }).reverse().join('');

            } catch (err) {
                document.getElementById('connection-status').innerHTML = '<div class="h-2 w-2 rounded-full bg-red-500"></div><span class="text-[10px] font-mono uppercase text-red-500">Engine Offline</span>';
            }
        }

        setInterval(syncDashboard, 3000);
        syncDashboard();
    </script>
</body>
</html>