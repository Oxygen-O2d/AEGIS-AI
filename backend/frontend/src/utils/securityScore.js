export function calculateSecurityScore(severity, incidentId, riskDelta = 0) {
  const baseScores = {
    critical: 15,
    high: 35,
    medium: 65,
    info: 95,
    none: 100,
  };

  const currentSev = severity?.toLowerCase() || 'none';
  const baseValue = baseScores[currentSev] || 100;

  let entropy = 0;
  if (incidentId) {
    const lastChar = incidentId.toString().slice(-1);
    entropy = parseInt(lastChar, 16) || 0;
  }

  const penalty = Number.isFinite(Number(riskDelta)) ? Number(riskDelta) : 0;
  const rawScore = currentSev === 'none'
    ? 100 - penalty
    : baseValue + (entropy % 10) - penalty;

  return Math.min(100, Math.max(5, rawScore));
}
