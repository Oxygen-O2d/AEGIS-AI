import React, { useState } from 'react';
import { X, Zap, Terminal } from 'lucide-react';

export default function RemediationPlan({ remediation }) {
  // Logic to determine if we are ready to show the plan
  const hasData = remediation && remediation !== "PENDING";
  const [showSteps, setShowSteps] = useState(false);

  return (
    <div className="h-full flex flex-col">
      {!hasData ? (
        /* Empty State */
        <div className="flex-1 flex flex-col items-center justify-center opacity-30 text-center p-6">
          <Terminal size={32} className="mb-3 text-gray-500" />
          <p className="font-mono text-[10px] uppercase tracking-[3px]">
            Analyzing Vector...
          </p>
          <p className="text-[9px] text-gray-600 mt-2 italic">Awaiting AI-Generated Playbook</p>
        </div>
      ) : (
        /* Active Playbook State */
        <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
          
          {/* Header Section */}
          <div className="flex items-center gap-3 mb-4 p-3 rounded-lg bg-green-500/5 border border-green-500/20">
            <Zap size={16} className="text-yellow-400 fill-yellow-400" />
            <div>
              <h4 className="text-[10px] font-black text-white uppercase tracking-widest">Response Playbook</h4>
              <p className="text-[9px] text-green-500 font-bold uppercase">Ready for Execution</p>
            </div>
          </div>

          <div className="flex-1 flex items-center justify-center border border-dashed border-[#2A3648] rounded-lg text-center px-4">
            <p className="text-[11px] text-gray-400 uppercase tracking-[2px] font-mono">
              Click Show Steps to view the response playbook.
            </p>
          </div>

          {/* Action Button Section */}
          <div className="pt-4 mt-4 border-t border-white/5">
            <button 
              onClick={() => setShowSteps(true)}
              className="w-full group relative flex items-center justify-center gap-3 bg-green-600 hover:bg-green-500 text-white py-4 rounded-xl text-[11px] font-black uppercase tracking-[2px] transition-all shadow-[0_0_20px_rgba(22,163,74,0.2)] active:scale-[0.98]"
            >
              <Zap size={18} className="group-hover:scale-110 transition-transform" />
              <span>Show Steps</span>
              
              {/* Subtle Scanline effect on button */}
              <div className="absolute inset-0 w-full h-full bg-gradient-to-b from-white/10 to-transparent opacity-20 pointer-events-none"></div>
            </button>
            <p className="text-[8px] text-center text-gray-500 mt-3 font-mono uppercase tracking-tighter">
              Action will be logged to Audit Trail (ADMIN_ROOT)
            </p>
          </div>
        </div>
      )}

      {hasData && showSteps && (
        <div className="fixed inset-0 z-[160] flex items-center justify-center bg-[radial-gradient(circle_at_top,#0ea5e933,transparent_45%),rgba(2,6,23,0.9)] backdrop-blur-md p-6 animate-in fade-in duration-300" onClick={() => setShowSteps(false)}>
          <div
            className="w-full max-w-5xl h-[84vh] bg-gradient-to-b from-[#0f1b3a] via-[#0b1735] to-[#09132c] border border-[#38bdf8]/45 rounded-2xl shadow-[0_0_90px_rgba(14,165,233,0.25)] overflow-hidden flex flex-col"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between px-6 py-5 border-b border-cyan-300/15 bg-black/40 flex-none">
              <div className="flex items-center gap-4">
                <div className="h-3 w-3 rounded-full bg-red-500 shadow-[0_0_14px_#ef4444] animate-pulse"></div>
                <div>
                  <h3 className="text-[30px] leading-none font-black italic text-white uppercase tracking-tighter">Response Playbook</h3>
                  <p className="text-[12px] text-cyan-100/70 mt-1 uppercase tracking-[2px]">Review and execute in sequence</p>
                </div>
              </div>
              <button
                onClick={() => setShowSteps(false)}
                className="h-11 w-11 rounded-xl border border-white/15 hover:border-red-400 hover:text-red-400 hover:bg-red-500/10 text-gray-300 flex items-center justify-center transition-colors"
                aria-label="Close remediation steps"
              >
                <X size={22} />
              </button>
            </div>

            <div className="flex-1 p-10 space-y-6 overflow-y-auto custom-scrollbar bg-gradient-to-b from-[#0b1735] to-[#0a142d]">
              <div className="rounded-2xl border border-cyan-300/20 bg-cyan-300/5 p-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.08)]">
                <span className="text-[13px] font-black text-cyan-300 uppercase block mb-3 tracking-[2px]">Step 1: Containment</span>
                <p className="text-[20px] text-slate-100 leading-relaxed font-semibold">
                  {remediation}
                </p>
              </div>

              <div className="rounded-2xl border border-slate-300/15 bg-slate-300/5 p-6">
                <span className="text-[13px] font-black text-slate-100 uppercase block mb-3 tracking-[2px]">Step 2: Eradication</span>
                <p className="text-[20px] text-slate-100/95 leading-relaxed">
                  Flush session tokens and rotate API credentials for affected service identity.
                </p>
              </div>

              <div className="rounded-2xl border border-slate-300/15 bg-slate-300/5 p-6">
                <span className="text-[13px] font-black text-slate-100 uppercase block mb-3 tracking-[2px]">Step 3: Recovery</span>
                <p className="text-[20px] text-slate-100/95 leading-relaxed">
                  Enable enhanced logging on the affected container for the next 24 hours.
                </p>
              </div>
            </div>

            <div className="p-5 border-t border-cyan-300/15 bg-black/40 flex justify-end flex-none">
              <button
                onClick={() => setShowSteps(false)}
                className="px-8 py-3 rounded-xl bg-cyan-400/10 hover:bg-cyan-300 hover:text-[#021425] border border-cyan-300/35 text-cyan-100 text-[11px] font-black uppercase tracking-[2px] transition-all shadow-[0_0_20px_rgba(34,211,238,0.15)]"
              >
                Acknowledge Steps
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}