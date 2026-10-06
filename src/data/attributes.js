/* Afterdark · Dados — Atributos e Perícias
 * Tabela canônica dos 6 atributos e das 24 perícias usadas na ficha.
 * Cada perícia pertence a um atributo (campo `attr`).
 * Lido por Afterdark.dc.html via window.AfterdarkData.attributes / .skills
 *
 * `intro` (atributo) e `desc` (perícia) explicam O QUE a perícia cobre em jogo.
 * Não descrevem bônus, custo nem efeito mecânico: as regras ficam no sistema.
 * Este arquivo é a ÚNICA fonte desses textos — wizard, ficha e testes leem daqui.
 *
 * Origem de cada texto (conferir antes de publicar):
 *   [oficial]   adaptado de mecanica-afterdark-att-18-06-26.md, seção 4.2
 *   [rascunho]  escrito para o app; a perícia não tem descrição no sistema oficial
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.attributes = [
  { key: 'corpo',    label: 'Corpo',    intro: 'Força, fôlego e aguentar o tranco.' },             // [rascunho]
  { key: 'reflexo',  label: 'Reflexos', intro: 'Velocidade, precisão e mãos rápidas.' },           // [rascunho]
  { key: 'mente',    label: 'Mente',    intro: 'Raciocínio, estudo e domínio técnico.' },          // [rascunho]
  { key: 'presenca', label: 'Presença', intro: 'Como você afeta as pessoas ao seu redor.' },       // [rascunho]
  { key: 'instinto', label: 'Instinto', intro: 'Atenção, faro e sangue frio.' },                   // [rascunho]
  { key: 'espirito', label: 'Espírito', intro: 'Sua ligação com o que existe além do véu.' }       // [rascunho]
];

window.AfterdarkData.skills = [
  // Corpo
  { key: 'atletismo',    label: 'Atletismo',    attr: 'corpo',
    desc: 'Correr, saltar, escalar, nadar e manter o fôlego em esforço físico.' },                    // [rascunho]
  { key: 'luta',         label: 'Luta',         attr: 'corpo',
    desc: 'Combate corpo a corpo, com ou sem armas: golpes, agarrões e imobilizações.' },             // [oficial: Briga + Armas Brancas]
  { key: 'resistencia',  label: 'Resistência',  attr: 'corpo',
    desc: 'Suportar dor, fadiga, venenos, doenças e esforço prolongado.' },                          // [oficial]
  { key: 'protecao',     label: 'Proteção',     attr: 'corpo',
    desc: 'Bloquear, cobrir e se interpor para proteger a si ou a outra pessoa.' },                  // [rascunho]
  // Reflexos
  { key: 'pontaria',     label: 'Pontaria',     attr: 'reflexo',
    desc: 'Armas de fogo e outros ataques à distância.' },                                           // [oficial: Disparo]
  { key: 'furtividade',  label: 'Furtividade',  attr: 'reflexo',
    desc: 'Esconder-se, invadir, seguir alguém e mover-se sem chamar atenção.' },                    // [oficial]
  { key: 'conducao',     label: 'Condução',     attr: 'reflexo',
    desc: 'Dirigir sob pressão: perseguições, fugas e manobras arriscadas.' },                       // [rascunho]
  { key: 'crime',        label: 'Crime',        attr: 'reflexo',
    desc: 'Abrir fechaduras, furtar e arrombar — ações ilegais que pedem mão rápida.' },             // [rascunho]
  // Mente
  { key: 'investigacao', label: 'Investigação', attr: 'mente',
    desc: 'Analisar cenas, reconstruir eventos e encontrar pistas.' },                               // [oficial]
  { key: 'conhecimento', label: 'Conhecimento', attr: 'mente',
    desc: 'História, ciência, línguas e saberes acadêmicos.' },                                      // [rascunho]
  { key: 'tecnologia',   label: 'Tecnologia',   attr: 'mente',
    desc: 'Câmeras, computadores, grampos, arquivos e sistemas.' },                                  // [oficial]
  { key: 'medicina',     label: 'Medicina',     attr: 'mente',
    desc: 'Tratar ferimentos, fazer autópsias, identificar drogas, venenos e causas de morte.' },     // [oficial]
  // Presença
  { key: 'persuasao',    label: 'Persuasão',    attr: 'presenca',
    desc: 'Convencer, negociar e seduzir — ganhar alguém pela conversa.' },                          // [oficial: Lábia]
  { key: 'enganacao',    label: 'Enganação',    attr: 'presenca',
    desc: 'Mentir, enganar e manipular sem ser percebido.' },                                        // [oficial: Lábia]
  { key: 'intimidacao',  label: 'Intimidação',  attr: 'presenca',
    desc: 'Ameaçar, pressionar, impor medo ou autoridade.' },                                        // [oficial]
  { key: 'etiqueta',     label: 'Etiqueta',     attr: 'presenca',
    desc: 'Circular em ambientes formais, conhecer protocolos e não destoar da elite.' },            // [rascunho]
  // Instinto
  { key: 'percepcao',    label: 'Percepção',    attr: 'instinto',
    desc: 'Perceber detalhes, emboscadas, movimentos, sons e presenças.' },                          // [oficial]
  { key: 'intuicao',     label: 'Intuição',     attr: 'instinto',
    desc: 'Ler pessoas e situações: notar tensão, mentiras e intenções escondidas.' },               // [rascunho]
  { key: 'rastreamento', label: 'Rastreamento', attr: 'instinto',
    desc: 'Seguir rastros, pegadas e sinais de passagem.' },                                         // [rascunho]
  { key: 'autocontrole', label: 'Autocontrole', attr: 'instinto',
    desc: 'Resistir a impulsos, medo, raiva, fome, compulsões e perda de controle.' },               // [oficial]
  // Espírito
  { key: 'sensibilidade', label: 'Sensibilidade',         attr: 'espirito',
    desc: 'Usar a própria sensibilidade para perceber, resistir ou interagir com o sobrenatural.' }, // [oficial: seção 5]
  { key: 'ocultismo',     label: 'Ocultismo',             attr: 'espirito',
    desc: 'Rituais, símbolos, entidades, anomalias e conhecimento sobrenatural.' },                  // [oficial]
  { key: 'rituais',       label: 'Rituais',               attr: 'espirito',
    desc: 'Conduzir rituais e práticas sobrenaturais com preparo.' },                                // [rascunho]
  { key: 'resistencia_espiritual', label: 'Resistência Espiritual', attr: 'espirito',
    desc: 'Resistir a coerção mental, pressão psíquica, medo sobrenatural e dominação.' }            // [oficial: Vontade]
];
