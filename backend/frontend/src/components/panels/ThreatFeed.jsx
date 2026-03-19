import React from 'react';
import { ShieldAlert, Info, AlertTriangle, Radio } from 'lucide-react';

export default function ThreatFeed({ incidents, activeId, onSelect, externalAlerts = [] }) {
  const hasAnyAlerts = externalAlerts.length > 0 || incidents.length > 0;
  const totalAlerts = incidents.length + externalAlerts.length;

  return (
    <div className="glass-panel h-full rounded-xl flex flex-col overflow-hidden">
      {/* Header */}
      <div className="text-[10px] font-bold tracking-[2.5px] uppercase text-gray-500 p-3 border-b border-white/5 flex justify-between items-center bg-black/20">
        <span><Radio size={12} className="inline mr-2 text-red-500 animate-pulse" /> Live Alerts</span>
        <span id="incident-count" className="text-red-500 font-bold bg-red-500/10 px-2 rounded">
          {totalAlerts}
        </span>
      </div>

      {/* Alert List */}
      <div className="flex-1 overflow-y-auto p-3 space-y-3 custom-scrollbar">
        {!hasAnyAlerts ? (
          <div className="text-center py-10 opacity-30">
            <p className="font-mono text-[10px] uppercase tracking-widest">Awaiting Logs...</p>
          </div>
        ) : (
          <>
            {externalAlerts.map((alert, index) => (
              <div
                key={`recon-${alert.type}-${index}`}
                className="p-3 rounded-lg border-l-4 border-red-500 bg-red-500/10 border-t border-r border-b border-white/5"
              >
                <div className="flex justify-between items-center mb-1">
                  <div className="flex items-center gap-2">
                    <AlertTriangle size={10} className="text-red-500" />
                    <span className="text-[9px] font-black px-1.5 py-0.5 rounded bg-black/50 text-red-300 uppercase tracking-tighter">
                      Recon High
                    </span>
                  </div>
                </div>
                <p className="text-xs font-bold uppercase tracking-tighter italic text-red-200">
                  {alert.message || alert.type}
                </p>
                <div className="mt-2 text-[9px] text-gray-300 break-all font-mono">
                  {alert.data}
                </div>
              </div>
            ))}

            {[...incidents].reverse().map((inc) => {
              const sev = inc.triage_alert.severity.toLowerCase();
              const isHigh = sev === 'high' || sev === 'critical';
              
              // Visual logic for severity
              const borderColor = isHigh ? 'border-red-500' : sev === 'medium' ? 'border-orange-500' : 'border-blue-500';
              const bgColor = isHigh ? 'bg-red-500/5' : 'bg-white/5';
              const isActive = activeId === inc.id;

              return (
                <div 
                  key={inc.id}
                  onClick={() => onSelect(inc.id)}
                  className={`
                    p-3 rounded-lg border-l-4 ${borderColor} ${bgColor} 
                    cursor-pointer transition-all duration-200 group
                    ${isActive ? 'ring-1 ring-soc-accent bg-white/10' : 'hover:bg-white/10 border-t border-r border-b border-white/5'}
                  `}
                >
                  <div className="flex justify-between items-center mb-1">
                    <div className="flex items-center gap-2">
                      {isHigh ? <ShieldAlert size={10} className="text-red-500" /> : <Info size={10} className="text-blue-400" />}
                      <span className="text-[9px] font-black px-1.5 py-0.5 rounded bg-black/50 text-gray-300 uppercase tracking-tighter">
                        {inc.triage_alert.severity}
                      </span>
                    </div>
                    <span className="text-[8px] font-mono text-gray-600 group-hover:text-gray-400">
                      #{inc.id.substring(0, 8)}
                    </span>
                  </div>
                  
                  <p className={`text-xs font-bold uppercase tracking-tighter italic transition-colors ${isActive ? 'text-soc-accent' : 'text-white'}`}>
                    {inc.triage_alert.threat_type}
                  </p>
                  
                  <div className="mt-2 flex items-center justify-between">
                    <span className="text-[8px] font-mono text-gray-500 uppercase">{inc.source}</span>
                    {isActive && <div className="h-1 w-1 rounded-full bg-soc-accent animate-ping"></div>}
                  </div>
                </div>
              );
            })}
          </>
        )}
      </div>
    </div>
  );
}
