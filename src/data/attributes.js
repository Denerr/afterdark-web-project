/* Afterdark · Dados — Atributos e Perícias
 * Tabela canônica dos 6 atributos e das 24 perícias usadas na ficha.
 * Cada perícia pertence a um atributo (campo `attr`).
 * Lido por Afterdark.dc.html via window.AfterdarkData.attributes / .skills
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.attributes = [
  { key: 'corpo',    label: 'Corpo' },
  { key: 'reflexo',  label: 'Reflexos' },
  { key: 'mente',    label: 'Mente' },
  { key: 'presenca', label: 'Presença' },
  { key: 'instinto', label: 'Instinto' },
  { key: 'espirito', label: 'Espírito' }
];

window.AfterdarkData.skills = [
  // Corpo
  { key: 'atletismo',    label: 'Atletismo',    attr: 'corpo' },
  { key: 'luta',         label: 'Luta',         attr: 'corpo' },
  { key: 'resistencia',  label: 'Resistência',  attr: 'corpo' },
  { key: 'protecao',     label: 'Proteção',     attr: 'corpo' },
  // Reflexos
  { key: 'pontaria',     label: 'Pontaria',     attr: 'reflexo' },
  { key: 'furtividade',  label: 'Furtividade',  attr: 'reflexo' },
  { key: 'conducao',     label: 'Condução',     attr: 'reflexo' },
  { key: 'crime',        label: 'Crime',        attr: 'reflexo' },
  // Mente
  { key: 'investigacao', label: 'Investigação', attr: 'mente' },
  { key: 'conhecimento', label: 'Conhecimento', attr: 'mente' },
  { key: 'tecnologia',   label: 'Tecnologia',   attr: 'mente' },
  { key: 'medicina',     label: 'Medicina',     attr: 'mente' },
  // Presença
  { key: 'persuasao',    label: 'Persuasão',    attr: 'presenca' },
  { key: 'enganacao',    label: 'Enganação',    attr: 'presenca' },
  { key: 'intimidacao',  label: 'Intimidação',  attr: 'presenca' },
  { key: 'etiqueta',     label: 'Etiqueta',     attr: 'presenca' },
  // Instinto
  { key: 'percepcao',    label: 'Percepção',    attr: 'instinto' },
  { key: 'intuicao',     label: 'Intuição',     attr: 'instinto' },
  { key: 'rastreamento', label: 'Rastreamento', attr: 'instinto' },
  { key: 'autocontrole', label: 'Autocontrole', attr: 'instinto' },
  // Espírito
  { key: 'sensibilidade', label: 'Sensibilidade',         attr: 'espirito' },
  { key: 'ocultismo',     label: 'Ocultismo',             attr: 'espirito' },
  { key: 'rituais',       label: 'Rituais',               attr: 'espirito' },
  { key: 'resistencia_espiritual', label: 'Resistência Espiritual', attr: 'espirito' }
];
