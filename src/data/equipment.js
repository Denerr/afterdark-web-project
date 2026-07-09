/* Afterdark · Dados — Catálogo de Equipamento (Biblioteca do Mestre)
 * catalog.weapons → armas concedíveis (bônus de ataque, dano, alcance, ruído)
 * catalog.items   → itens concedíveis
 * É o estado inicial da biblioteca; o Mestre pode acrescentar mais em jogo.
 * Lido por Afterdark.dc.html via window.AfterdarkData.catalog
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.catalog = {
  weapons: [
    { id: 'w1', name: 'Faca',              bonus: 0, dano: 2, alcance: 'Corpo a corpo', ruido: 'Baixo',      desc: 'Silenciosa e pessoal.' },
    { id: 'w2', name: 'Bastão',            bonus: 0, dano: 3, alcance: 'Corpo a corpo', ruido: 'Médio',      desc: 'Improvisado, contundente.' },
    { id: 'w3', name: 'Pistola',           bonus: 1, dano: 3, alcance: 'Curto/Médio',   ruido: 'Alto',       desc: 'Confiável, mas barulhenta.' },
    { id: 'w4', name: 'Revólver pesado',   bonus: 1, dano: 4, alcance: 'Médio',         ruido: 'Alto',       desc: 'Poder de parada considerável.' },
    { id: 'w5', name: 'Escopeta curta',    bonus: 0, dano: 5, alcance: 'Curto',         ruido: 'Muito alto', desc: 'Devastadora de perto, impossível de esconder.' },
    { id: 'w6', name: 'Estaca de carvalho', bonus: 0, dano: 3, alcance: 'Corpo a corpo', ruido: 'Baixo',     desc: 'Contra vampiros — sobrenatural.' }
  ],
  items: [
    { id: 'i1', name: 'Lanterna',            desc: 'Afasta a escuridão por um tempo.' },
    { id: 'i2', name: 'Kit de legista',      desc: '+1 em análises de corpo e sangue.' },
    { id: 'i3', name: 'Crucifixo de prata',  desc: 'Desconforta criaturas profanas.' },
    { id: 'i4', name: 'Frasco de água benta', desc: 'Uso único contra o profano.' }
  ]
};
