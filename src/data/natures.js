/* Afterdark · Dados — Naturezas / Sensibilidades e Fraquezas
 * natures    → cards de Natureza (Humano Comum + 3 sensibilidades), bônus e aptidões
 * weaknesses → listas de fraquezas por sensibilidade (Etapa 3 da ficha)
 * sensAccent → cor de destaque por sensibilidade (usada em listas e relógios)
 * Lido por Afterdark.dc.html via window.AfterdarkData.natures / .weaknesses / .sensAccent
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.natures = {
  humano: {
    label: 'Humano Comum', short: 'Humano', accent: '#5f8aa6', glow: 'rgba(95,138,166,.4)',
    bonus: '+1 Mente · +1 Presença', bonusKeys: ['mente', 'presenca'], ref: 'Augusto Valmont', theme: 'human',
    effect: 'Você não manifesta uma sensibilidade sobrenatural conhecida. Sobrevive em Saint Vesper por inteligência, leitura social, preparação e coragem.',
    aptidoes: ['Capacidade de análise e adaptação social', 'Resistência diante da pressão urbana e política', 'Preparação e coragem no lugar de dons sobrenaturais'],
    limit: 'Humanos comuns não percebem fenômenos sobrenaturais ocultos — precisam de evidência, investigação ou de um sensitivo.',
    manifestLabel: null, mundane: true
  },
  vampiros: {
    label: 'Sensível a Vampiros', short: 'Vampiros', accent: '#c41e3a', glow: 'rgba(196,30,58,.45)',
    bonus: '+1 Reflexos', bonusKeys: ['reflexo'], ref: 'Aurelian Voss', theme: 'vampire',
    effect: 'Você percebe a presença de sangue, influência vampírica e jogos sociais que escondem fome, poder ou manipulação. Emoções intensas deixam rastros mais claros para você.',
    aptidoes: ['Identifica emoções: medo, raiva, tristeza, alegria, sarcasmo', 'Percebe influência vampírica e sangue antigo', 'Facilidade para investigar pessoas e ambientes sociais', 'Em locais escuros, age melhor em investigação e furtividade'],
    manifestLabel: 'Como sua sensibilidade vampírica se manifestou?'
  },
  lobisomens: {
    label: 'Sensível a Lobisomens', short: 'Lobisomens', accent: '#7ea6d4', glow: 'rgba(126,166,212,.45)',
    bonus: '+1 Corpo', bonusKeys: ['corpo'], ref: 'Abel Rourke', theme: 'werewolf',
    effect: 'Seus sentidos percebem rastros, tensão física e mudanças sutis no ambiente. Você sente perigo, caça, território marcado ou uma presença predatória próxima.',
    aptidoes: ['Sentidos aguçados de visão, audição e olfato', 'Percepção de perigo iminente e de rastros', 'Sente quando alguém está sendo caçado', 'Aptidão para proteção, perseguição e confronto físico'],
    manifestLabel: 'Como sua sensibilidade lupina se manifestou?'
  },
  demonios: {
    label: 'Sensível a Demônios', short: 'Demônios', accent: '#d6308a', glow: 'rgba(214,48,138,.45)',
    bonus: '+1 Espírito', bonusKeys: ['espirito'], ref: 'Valentin Marlowe', theme: 'demon',
    effect: 'Você percebe o sobrenatural em promessas, contratos, símbolos, ilusões e desejos bons demais para ser verdade. Pactos deixam ecos, e mentiras de tentação têm um peso particular.',
    aptidoes: ['Detecta presença sobrenatural e corrupção', 'Percebe pactos e contratos contaminados', 'Identifica ilusões, rituais e símbolos demoníacos', 'Reconhece mentiras carregadas de desejo ou poder'],
    manifestLabel: 'Como sua sensibilidade demoníaca se manifestou?'
  }
};

window.AfterdarkData.weaknesses = {
  humano: [],
  vampiros: [
    { t: 'Sono Irregular', d: 'A influência vampírica interfere no descanso. Noites longas e tensão podem deixar você inquieto, cansado ou menos concentrado.' },
    { t: 'Incômodo com Luz Forte', d: 'Claridade intensa e luz direta causam desconforto físico e prejudicam sua estabilidade em cenas expostas.' },
    { t: 'Incômodo com flashes e reflexos intensos', d: 'Flashes, espelhos e superfícies muito brilhantes provocam desorientação momentânea e perda de foco.' },
    { t: 'Sobrecarga Emocional em Multidões', d: 'Ambientes lotados despejam emoções alheias sobre você, causando cansaço, irritação ou bloqueio.' },
    { t: 'Dificuldade de distinguir emoções próprias e alheias', d: 'Sob tensão, o que você sente e o que capta dos outros se confundem, distorcendo seu julgamento.' },
    { t: 'Sensibilidade a ambientes carregados emocionalmente', d: 'Locais marcados por medo, luto ou paixão intensa deixam rastros que pesam sobre você.' }
  ],
  lobisomens: [
    { t: 'Impulsividade', d: 'Sob pressão, você tende a agir antes de analisar todas as consequências.' },
    { t: 'Dificuldade em ignorar ameaças', d: 'Perigo, provocação ou hostilidade chamam sua atenção de forma intensa e podem tirar seu foco.' },
    { t: 'Irritação diante de provocações', d: 'Desafios e desacatos diretos acendem um pavio curto difícil de conter.' },
    { t: 'Resposta agressiva quando acuado', d: 'Encurralado, seu instinto responde com força antes da razão — e nem sempre na hora certa.' },
    { t: 'Dificuldade em controlar medo ou raiva', d: 'Emoções fortes sobem rápido e custam a baixar, afetando sua postura em cena.' },
    { t: 'Incômodo com cheiros, sons ou estímulos fortes', d: 'Sentidos aguçados se voltam contra você: estímulos intensos causam desconforto e desorientação.' }
  ],
  demonios: [
    { t: 'Vozes', d: 'Em situações de tensão ou contato sobrenatural, sussurros e pensamentos estranhos podem confundir sua percepção.' },
    { t: 'Paranóia', d: 'A sensação de que algo se esconde nas entrelinhas faz você duvidar de pessoas, sinais e do próprio raciocínio.' },
    { t: 'Desconforto com símbolos religiosos', d: 'Símbolos sagrados causam desconforto físico, mental ou sobrenatural.' },
    { t: 'Sensação de estar sendo seguido ou observado', d: 'Um peso constante nas costas — olhos invisíveis que você nunca consegue localizar.' },
    { t: 'Dificuldade de distinguir intuição real e influência sobrenatural', d: 'Nem sempre dá para saber se o palpite é seu ou um sussurro plantado de fora.' },
    { t: 'Sobrecarga espiritual em ambientes carregados de rituais, contratos e símbolos', d: 'Lugares densos de magia, pactos e símbolos esgotam você, embaralhando foco e vontade.' }
  ]
};

window.AfterdarkData.sensAccent = {
  vampiros: '#c41e3a', lobisomens: '#7ea6d4', demonios: '#d6308a', humano: '#5f8aa6'
};
