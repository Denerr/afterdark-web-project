/* Afterdark · Dados — Aventuras
 * oneshots → os 3 one-shots demonstrativos (facção, referência, tom, paleta)
 * chapters → capítulos conceituais do modo Campanha (placeholders de interface)
 * Lido por Afterdark.dc.html via window.AfterdarkData.oneshots / .chapters
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.oneshots = {
  misterios: { key: 'misterios', title: 'Mistérios Vermelhos', faction: 'Demônios · Os Caídos', ref: 'Valentin Marlowe', tone: 'Sedução · Pacto · Corrupção', summary: 'Um clube onde cada desejo tem preço. Promessas elegantes escondem contratos que ninguém deveria assinar.', dur: '3–4h', players: '3–5', ready: 6, cover: 'assets/images/cover-misterios.png', coverPos: '50% 42%', acc: '#d6308a', acc2: '#d6452f', bg: '#150812', surf: '#2a1230', glow: 'rgba(214,48,138,.45)' },
  gota: { key: 'gota', title: 'A Última Gota', faction: 'Vampiros · Sociedade Rubra', ref: 'Aurelian Voss', tone: 'Aristocracia · Sangue · Chantagem', summary: 'Um banco aristocrático, sangue que vale mais que ouro, e um segredo de família prestes a sangrar para fora.', dur: '4h', players: '3–5', ready: 6, cover: 'assets/images/cover-gota.png', coverPos: '50% 35%', acc: '#c41e3a', acc2: '#8d1426', bg: '#16080b', surf: '#2e1117', glow: 'rgba(196,30,58,.42)' },
  sombras: { key: 'sombras', title: 'Sombras Uivantes', faction: 'Lobisomens · A Matilha', ref: 'Abel Rourke', tone: 'Caçada · Território · Instinto', summary: 'Nas docas molhadas, um território foi violado. A Matilha já sentiu o cheiro — e a caçada começou.', dur: '3h', players: '3–4', ready: 6, cover: 'assets/images/cover-sombras.png', coverPos: '72% 45%', acc: '#7ea6d4', acc2: '#93a0ad', bg: '#0a1018', surf: '#16202e', glow: 'rgba(126,166,212,.4)' }
};

/* Roteiro padrão da missão em andamento — "Crônicas de Saint Vesper" (A Última Gota).
 * Lista de acontecimentos que o Mestre pode seguir cena a cena.
 * Lido por Afterdark.dc.html via window.AfterdarkData.roteiroPadrao */
window.AfterdarkData.roteiroPadrao = {
  title: 'A Última Gota',
  faction: 'Vampiros · Sociedade Rubra',
  events: [
    { phase: 'Abertura',   title: 'O convite lacrado', desc: 'O grupo recebe um convite selado a cera rubra para o leilão privado em Alta Vesper. Cada carta traz um nome — e uma dívida antiga.' },
    { phase: 'Ato I',      title: 'Salão de Leilões',  desc: 'Cristais pendem do teto como lâminas. No palco, um frasco lacrado é o lote da noite. Aurelian Voss observa, sorrindo demais.' },
    { phase: 'Ato I',      title: 'Primeiras pistas',  desc: 'Analisar a taça, ler a sala, sondar convidados. O sangue servido é antigo — e adulterado. Alguém no salão sabe demais.' },
    { phase: 'Virada',     title: 'A Sociedade Rubra percebe', desc: 'Avance o relógio de ameaça. Olhares mudam, portas se fecham. A discrição do grupo começa a custar caro.' },
    { phase: 'Ato II',     title: 'O lance fatal',     desc: 'O leilão do frasco escala. Um lance provoca uma cena — confronto, chantagem ou aliança inesperada com uma facção rival.' },
    { phase: 'Ato II',     title: 'A verdade do frasco', desc: 'Revele o conteúdo: não é sangue comum, mas a última gota de um Ancião. Quem a beber muda o equilíbrio de Saint Vesper.' },
    { phase: 'Clímax',     title: 'Fuga ou pacto',     desc: 'A polícia chega ou o instinto bestial desperta. O grupo foge pelo beco dos fundos — ou sela um pacto que os marcará para sempre.' },
    { phase: 'Desfecho',   title: 'O preço da noite',  desc: 'Resolva conforme os relógios preenchidos. Quem sai com o frasco? Quem sai vivo? A Sociedade Rubra nunca esquece um rosto.' }
  ]
};

/* Narrativa padrão — passagens de leitura em voz alta que o Mestre usa para contar a história.
 * Lido por Afterdark.dc.html via window.AfterdarkData.narrativaPadrao */
window.AfterdarkData.narrativaPadrao = {
  title: 'A Última Gota',
  passages: [
    { label: 'Abertura', text: 'Saint Vesper não dorme — apenas troca de máscara. A neblina sobe do rio carregando cheiro de cobre e perfume caro. Vocês seguem pela Alta Vesper, onde os lampiões são de sangue coagulado em vidro, e param diante de um portão de ferro trabalhado com rosas. O convite na mão de vocês pulsa, morno, como se estivesse vivo.' },
    { label: 'A entrada', text: 'As portas duplas se abrem sozinhas. Lá dentro, cristais pendem do teto como lâminas prontas para cair. Convidados de sorriso perfeito deslizam entre taças escarlates, e todos, sem exceção, viram o rosto para observar vocês entrarem. Um quarteto toca algo antigo demais para ter nome. No fundo do salão, um palco iluminado aguarda.' },
    { label: 'O lote da noite', text: 'Sobre um pedestal de veludo negro, dentro de uma redoma, repousa um frasco lacrado. O líquido dentro dele não reflete a luz — ele a engole. Aurelian Voss ergue-se ao lado do palco, ajeitando as luvas brancas, e sua voz preenche o salão sem esforço: "Meus caros, esta noite oferecemos algo que não se compra duas vezes. A última gota. E ela ainda se lembra de quem foi."' },
    { label: 'A tensão cresce', text: 'O ar fica denso. Vocês sentem olhares se demorando, portas sendo trancadas com suavidade, sorrisos que não alcançam os olhos. Em algum lugar acima do murmúrio dos lances, um relógio invisível começa a correr — e ele não corre a favor de vocês. Seja o que for que vieram fazer aqui, precisa ser feito antes que a Sociedade Rubra decida que vocês já viram demais.' }
  ]
};

window.AfterdarkData.chapters = [
  { n: 'I',   title: 'O Primeiro Sangue',          tone: 'Investigativo · Sombrio', tension: 2, dur: '3h', status: 'concluido' },
  { n: 'II',  title: 'Contratos de Meia-Noite',    tone: 'Sedução · Pacto',         tension: 3, dur: '4h', status: 'progresso' },
  { n: 'III', title: 'A Lua nas Docas',            tone: 'Caçada · Violência',      tension: 4, dur: '3h', status: 'disponivel' },
  { n: 'IV',  title: 'Cinzas da Sociedade Rubra',  tone: 'Político · Sangue',       tension: 4, dur: '4h', status: 'bloqueado' },
  { n: 'V',   title: 'O Conselho Rubro',           tone: 'Sobrenatural intenso',    tension: 5, dur: '5h', status: 'bloqueado' }
];
