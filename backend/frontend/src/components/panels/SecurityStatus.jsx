import React from 'react';
import { ShieldAlert, ShieldCheck, Info } from 'lucide-react';
import { calculateSecurityScore } from '../../utils/securityScore';

export default function SecurityStatus({ severity, incidentId, riskDelta = 0, averageScore = null }) {
  const score = calculateSecurityScore(severity, incidentId, riskDelta);
  const displayScore = averageScore !== null ? Math.round(averageScore) : Math.round(score);
  const selectedSeverity = (severity || 'INFO').toUpperCase();
  const centerLabel = incidentId ? selectedSeverity : 'NONE';

  const getStatusConfig = () => {
    if (displayScore > 80) return { color: '#10B981', text: 'SECURE', icon: <ShieldCheck size={16} />, bg: 'rgba(16, 185, 129, 0.1)' };
    if (displayScore > 50) return { color: '#F59E0B', text: 'WARNING', icon: <Info size={16} />, bg: 'rgba(245, 158, 11, 0.1)' };
    return { color: '#EF4444', text: 'CRITICAL', icon: <ShieldAlert size={16} />, bg: 'rgba(239, 68, 68, 0.1)' };
  };

  const config = getStatusConfig();
  const radius = 48;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (displayScore / 100) * circumference;
  const scoreLabel = averageScore !== null ? 'Average Security Score' : 'Security Score';

  return (
    <div className="h-full w-full flex items-center justify-center p-2 overflow-hidden">
      <div className="w-full max-w-[300px] flex items-center justify-center gap-4">
        <div className="relative flex items-center justify-center shrink-0">
          {/* SVG Circular Gauge */}
          <svg className="w-28 h-28 transform -rotate-90">
            <circle
              cx="56" cy="56" r={radius}
              stroke="rgba(255,255,255,0.05)" strokeWidth="8"
              fill="transparent"
            />
            <circle
              cx="56" cy="56" r={radius}
              stroke={config.color} strokeWidth="8"
              fill="transparent"
              strokeDasharray={circumference}
              style={{ strokeDashoffset: offset, transition: 'stroke-dashoffset 1s ease-in-out' }}
              strokeLinecap="round"
            />
          </svg>

          {/* Center Text */}
          <div className="absolute flex flex-col items-center justify-center text-center px-1">
            <span className="text-sm font-black uppercase tracking-[1px] text-white leading-tight">
              {centerLabel}
            </span>
            <span className="text-[8px] font-bold text-gray-500 uppercase">Threat Level</span>
          </div>
        </div>

        <div className="min-w-0 flex flex-col items-start gap-2">
          <p className="text-[8px] font-black uppercase tracking-[2px] text-gray-500 leading-tight">
            {scoreLabel}
          </p>
          <p className="text-2xl font-black text-soc-accent leading-none whitespace-nowrap">
            {displayScore} / 100
          </p>

          <div
            className="px-3 py-1 rounded-full border border-white/10 flex items-center gap-2"
            style={{ backgroundColor: config.bg, color: config.color }}
          >
            {config.icon}
            <span className="text-[10px] font-black uppercase tracking-[2px]">
              {config.text}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
