/* Afterdark · Dados — Conteúdo de demonstração (seed)
 * Estado inicial das coleções que o protótipo exibe e o usuário manipula:
 * personagens, mesas, jogadores no lobby, relógios, barras de estresse,
 * NPCs, pistas e o diário (log).
 *
 * O componente clona este objeto na montagem (hidratação) — então editar em
 * tela nunca altera estes valores de origem. Lido via window.AfterdarkData.seed
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.seed = {
  // Personagens salvos no perfil do usuário
  characters: [
    { id: 'ch1', name: 'Helena Voss', role: 'A Legista', sens: 'vampiros', usedIn: 'A Última Gota', photo: null,
      attrs: { corpo: 1, reflexo: 2, mente: 3, presenca: 2, instinto: 1 }, skills: { analise: 3, investigacao: 2, ocultismo: 2, percepcao: 2 },
      weaknesses: ['Sono irregular', 'Fascínio desconfortável por sangue', 'Sensação de frio perto de vampiros antigos'],
      bio: 'Legista do Centro Cívico. Viu sangue se mover sozinho numa autópsia — e nunca mais dormiu direito.' },
    { id: 'ch2', name: 'Estêvão Cruz', role: 'O Estivador', sens: 'lobisomens', usedIn: null, photo: null,
      attrs: { corpo: 3, reflexo: 2, mente: 1, presenca: 1, instinto: 2 }, skills: { atletismo: 3, sobrevivencia: 2, intimidacao: 2, percepcao: 1 },
      weaknesses: ['Impulsividade', 'Dificuldade de ignorar ameaças', 'Reações instintivas a cheiro de sangue'],
      bio: 'Trabalha as docas desde menino. Sente quando algo grande e faminto se aproxima na neblina.' },
    { id: 'ch3', name: 'Ciro Almeida', role: 'O Apostador', sens: 'demonios', usedIn: 'Mistérios Vermelhos', photo: null,
      attrs: { corpo: 2, reflexo: 2, mente: 2, presenca: 3, instinto: 1 }, skills: { persuasao: 3, furtividade: 2, analise: 2, percepcao: 1 },
      weaknesses: ['Vozes', 'Sonhos com ofertas, contratos ou portas abertas', 'Atração perigosa por desejo, fama, prazer ou poder'],
      bio: 'Frequentador de mesas de jogo clandestinas. Ouve sussurros que prometem a sorte — por um preço.' }
  ],

  // Mesas no perfil do usuário
  tables: [
    { id: 't1', name: 'A Última Gota', type: 'One-shot', faction: 'Vampiros', role: 'jogador', status: 'Em andamento', theme: 'vampire', target: 'j_panel' },
    { id: 't2', name: 'Mistérios Vermelhos', type: 'One-shot', faction: 'Demônios', role: 'mestre', status: 'Aguardando jogadores', theme: 'demon', target: 'm_lobby' },
    { id: 't3', name: 'Crônicas de Saint Vesper', type: 'Campanha', faction: 'Misto', role: 'mestre', status: 'Capítulo II em progresso', theme: 'human', target: 'm_session' }
  ],

  // Jogadores conectados no lobby / sessão
  players: [
    { id: 'p1', player: 'Marlon', char: 'Estêvão Cruz', nick: 'O Estivador', sens: 'lobisomens', status: 'pronto', cond: 'normal', attrs: { corpo: 3, reflexo: 2, mente: 1, presenca: 1, instinto: 2 }, skills: { atletismo: 3, sobrevivencia: 2, intimidacao: 2, percepcao: 1 }, wounds: [], conditions: [] },
    { id: 'p2', player: 'Clara', char: 'Helena Voss', nick: 'A Legista', sens: 'vampiros', status: 'pronto', cond: 'abalado', attrs: { corpo: 1, reflexo: 2, mente: 3, presenca: 2, instinto: 1 }, skills: { analise: 3, investigacao: 2, ocultismo: 2, percepcao: 2 }, wounds: [{ lvl: 'leve', desc: 'Corte superficial' }], conditions: ['Abalado'] },
    { id: 'p3', player: 'Dário', char: 'Ciro Almeida', nick: 'O Apostador', sens: 'demonios', status: 'aguardando', cond: 'pressao', attrs: { corpo: 2, reflexo: 2, mente: 2, presenca: 3, instinto: 1 }, skills: { persuasao: 3, furtividade: 2, analise: 2, percepcao: 1 }, wounds: [], conditions: ['Tentado'] },
    { id: 'p4', player: 'Bea', char: '—', nick: 'criando ficha', sens: 'demonios', status: 'criando', cond: 'fora', attrs: {}, skills: {}, wounds: [], conditions: [] }
  ],

  // Relógios da sessão
  clocks: [
    { id: 'c1', name: 'A Sociedade Rubra percebe', type: 'Ameaça', seg: 8, fill: 3, vis: 'todos', scope: 'mesa', playerId: null },
    { id: 'c2', name: 'Quem comprou o sangue falso?', type: 'Investigação', seg: 8, fill: 4, vis: 'todos', scope: 'mesa', playerId: null },
    { id: 'c3', name: 'A polícia chega', type: 'Tensão', seg: 6, fill: 1, vis: 'todos', scope: 'mesa', playerId: null },
    { id: 'c4', name: 'Instinto Bestial Desperta', type: 'Perda de Controle', seg: 6, fill: 2, vis: 'mestre', scope: 'mesa', playerId: null },
    { id: 'c5', name: 'Sede de sangue de Helena', type: 'Perda de Controle', seg: 4, fill: 1, vis: 'jogador', scope: 'player', playerId: 'p2' }
  ],

  // Barras de estresse vinculadas a jogadores / relógios
  stressBars: [
    { id: 'st1', playerId: 'p2', name: 'Sede de Sangue', level: 1, max: 4, clockId: 'c5' },
    { id: 'st2', playerId: 'p1', name: 'Fúria Contida', level: 0, max: 4, clockId: 'c4' }
  ],

  // NPCs e seu estágio de revelação (1 silhueta → 4 retrato completo)
  npcs: [
    { id: 'n1', name: 'Aurelian Voss', faction: 'Sociedade Rubra', reveal: 4, theme: 'vampire', desc: 'Patriarca de sangue antigo. O sorriso nunca alcança os olhos.' },
    { id: 'n2', name: '???', faction: 'Desconhecido', reveal: 1, theme: 'demon', desc: 'Uma silhueta no camarote. Cheira a fumaça e promessas.' },
    { id: 'n3', name: 'O Carniceiro', faction: 'A Matilha', reveal: 3, theme: 'werewolf', desc: 'Apelido sussurrado nas docas. Ninguém viu o rosto e contou.' },
    { id: 'n4', name: 'Augusto Valmont', faction: 'Centro Cívico', reveal: 4, theme: 'human', desc: 'Político impecável. Ordem pública como fachada.' }
  ],

  // Pistas e seu estado (oculta / encontrada / analisada / ...)
  clues: [
    { id: 'k1', name: 'Taça com resíduo', type: 'Objeto', status: 'analisada', txt: 'Sangue antigo misturado a algo sintético. Alguém adultera o estoque.' },
    { id: 'k2', name: 'Recibo rasgado', type: 'Documento', status: 'encontrada', txt: 'Carga registrada para um galpão nas Docas. Assinatura ilegível.' },
    { id: 'k3', name: 'Cinzas adocicadas', type: 'Rastro', status: 'oculta', txt: '—' }
  ],

  // Diário / histórico de eventos da sessão
  log: [
    { icon: '◈', t: 'Cena 2',     txt: 'O grupo entrou no salão de leilões da Sociedade Rubra.' },
    { icon: '⚄', t: 'Teste',      txt: 'Helena analisou a taça — Sucesso Completo. Sangue antigo adulterado.' },
    { icon: '◷', t: 'Relógio',    txt: '"A Sociedade Rubra percebe" avançou para 3/8.' },
    { icon: '✕', t: 'Ferimento',  txt: 'Helena sofreu Ferimento Leve — corte superficial.' }
  ]
};
