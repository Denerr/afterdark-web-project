/* Afterdark · Dados — Temas visuais
 * themes     → paleta por facção (demon / vampire / werewolf / human)
 * clockTheme → cor de cada tipo de relógio (também serve de lista de tipos)
 * Lido por Afterdark.dc.html via window.AfterdarkData.themes / .clockTheme
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.themes = {
  demon:    { acc: '#d6308a', bg: '#150812', surf: '#2a1230', glow: 'rgba(214,48,138,.45)' },
  vampire:  { acc: '#c41e3a', bg: '#16080b', surf: '#2e1117', glow: 'rgba(196,30,58,.42)' },
  werewolf: { acc: '#7ea6d4', bg: '#0a1018', surf: '#16202e', glow: 'rgba(126,166,212,.4)' },
  human:    { acc: '#b9a06a', bg: '#0c1419', surf: '#1a2733', glow: 'rgba(185,160,106,.35)' }
};

window.AfterdarkData.clockTheme = {
  'Ameaça': '#c41e3a',
  'Investigação': '#c6a35e',
  'Tensão': '#d6452f',
  'Facção': '#b9a06a',
  'Objetivo': '#7ea6d4',
  'Perda de Controle': '#a9b89a',
  'Ritual': '#d6308a',
  'Perseguição': '#7ea6d4',
  'Exposição Pública': '#e0c179'
};
