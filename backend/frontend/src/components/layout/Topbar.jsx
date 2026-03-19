import React from 'react';
import { Trash2 } from 'lucide-react';

/**
 * Topbar Component
 * Handles branding, global AI engine status, and feed reset actions.
 */
export default function Topbar() {
  return (
    <header className="w-full h-[52px] bg-[#1A2333] border-b border-[#2A3648] flex items-center justify-between px-4 z-50">
      
      {/* Branding Section  */}
      <div className="flex items-center gap-2">
        <h1 className="text-sm font-black uppercase tracking-[3px] text-[#0EA5E9] italic">
          ■ AEGISAI
        </h1>
        <div className="h-4 w-[1px] bg-[#2A3648] mx-2"></div>
        <span className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">Security Dashboard</span>
      </div>

      {/* Stats & Actions Section  */}
      <div className="flex items-center gap-4">
        
        {/* Reset Action - Clears the current feed  */}
        <button 
          onClick={() => window.location.reload()}
          className="text-[9px] font-black uppercase tracking-widest flex items-center gap-2 px-3 py-1.5 rounded bg-red-900/10 border border-red-500/20 text-red-400 hover:bg-red-600 hover:text-white transition-all"
        >
          <Trash2 size={12} /> Clear Feed
        </button>

        {/* Engine Status Indicator  */}
        <div className="flex items-center gap-2">
          <div className="relative flex items-center justify-center">
            <div className="h-2 w-2 rounded-full bg-green-500"></div>
            <div className="absolute h-4 w-4 rounded-full border border-green-500 animate-ping opacity-20"></div>
          </div>
          <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">
            AI Enginer
          </span>
        </div>
      </div>
    </header>
  );
}
