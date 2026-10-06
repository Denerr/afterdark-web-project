/* Afterdark · Dados — Atributos e Perícias
 * Tabela canônica dos 6 atributos e das 24 perícias usadas na ficha.
 * Cada perícia pertence a um atributo (campo `attr`).
 * Lido por Afterdark.dc.html via window.AfterdarkData.attributes / .skills
 *
 * `intro` descreve o GRUPO de perícias de cada atributo (decisão aprovada: a
 * explicação é por grupo, não por perícia). Texto definido pelo autor do jogo.
 * Não descreve bônus, custo nem efeito mecânico: as regras ficam no sistema.
 * Este arquivo é a ÚNICA fonte desses textos.
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.attributes = [
  { key: 'corpo',    label: 'Corpo',    intro: 'Força e preparo físico para superar obstáculos, lutar, suportar esforço e proteger.' },
  { key: 'reflexo',  label: 'Reflexos', intro: 'Precisão e coordenação para mirar, agir discretamente, conduzir e executar ações manuais delicadas.' },
  { key: 'mente',    label: 'Mente',    intro: 'Raciocínio e conhecimento para investigar, compreender informações, lidar com tecnologia e prestar cuidados médicos.' },
  { key: 'presenca', label: 'Presença', intro: 'Habilidade social para convencer, enganar, intimidar e circular em diferentes ambientes sociais.' },
  { key: 'instinto', label: 'Instinto', intro: 'Atenção e percepção intuitiva para reconhecer perigos, interpretar sinais, seguir rastros e manter o controle.' },
  { key: 'espirito', label: 'Espírito', intro: 'Afinidade e firmeza diante do sobrenatural para sentir fenômenos, compreender o oculto, realizar rituais e resistir a influências espirituais.' }
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
