/* Afterdark · Dados — Acervo de personagens (cards oficiais de NPC)
 * characters → [{ id, name, group, oneshot, color, card, thumb }]
 *   id: identidade fixa do personagem (nunca muda; o NPC da mesa guarda imageId 'card:<id>').
 *   oneshot: elenco padrão (gota / misterios / sombras) ou null (Gerais, sem campanha obrigatória).
 *   Todos podem ser usados em qualquer mesa; o elenco padrão só vem primeiro no seletor.
 *   card: card inteiro (720 px de largura, moldura integrada); thumb: 240 px, para listas.
 * Trocar o arquivo de um card atualiza todas as mesas que usam o personagem.
 * Sem biografia, poderes ou estatísticas: só o confirmado (nome, imagem, campanha).
 * Lido por index.html via window.AfterdarkData.characters.
 *
 * Origem: Afterdark_Acervo_Final (cadastro.json, 11/10/2026). Os 6 cards de Jogadores não
 * entram (não cabe ao Mestre cadastrá-los). Convertidos para WebP em assets/cards/<grupo>/.
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.characterGroups = {
  sombras:   { name: 'Sombras Uivantes',    color: 'safira' },
  gota:      { name: 'A Última Gota',       color: 'rubi' },
  misterios: { name: 'Mistérios Vermelhos', color: 'ametista' },
  gerais:    { name: 'Gerais',              color: 'safira' }
};

window.AfterdarkData.characters = [
  // Sombras Uivantes
  { id: 'sombras-ada-weiss', name: 'Ada Weiss', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/ada-weiss.webp', thumb: 'assets/cards/sombras/ada-weiss_p.webp' },
  { id: 'sombras-adrian-kessler', name: 'Adrian Kessler', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/adrian-kessler.webp', thumb: 'assets/cards/sombras/adrian-kessler_p.webp' },
  { id: 'sombras-apostador', name: 'Apostador', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/apostador.webp', thumb: 'assets/cards/sombras/apostador_p.webp' },
  { id: 'sombras-augustus-bellamy', name: 'Augustus Bellamy', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/augustus-bellamy.webp', thumb: 'assets/cards/sombras/augustus-bellamy_p.webp' },
  { id: 'sombras-capanga', name: 'Capanga', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/capanga.webp', thumb: 'assets/cards/sombras/capanga_p.webp' },
  { id: 'sombras-cassandra-vale', name: 'Cassandra Vale', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/cassandra-vale.webp', thumb: 'assets/cards/sombras/cassandra-vale_p.webp' },
  { id: 'sombras-edward-mercer', name: 'Edward Mercer', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/edward-mercer.webp', thumb: 'assets/cards/sombras/edward-mercer_p.webp' },
  { id: 'sombras-elias-ward', name: 'Elias Ward', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/elias-ward.webp', thumb: 'assets/cards/sombras/elias-ward_p.webp' },
  { id: 'sombras-emil-strauss', name: 'Emil Strauss', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/emil-strauss.webp', thumb: 'assets/cards/sombras/emil-strauss_p.webp' },
  { id: 'sombras-gerente-de-apostas', name: 'Gerente de Apostas', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/gerente-de-apostas.webp', thumb: 'assets/cards/sombras/gerente-de-apostas_p.webp' },
  { id: 'sombras-helena-moretti', name: 'Helena Moretti', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/helena-moretti.webp', thumb: 'assets/cards/sombras/helena-moretti_p.webp' },
  { id: 'sombras-lutador-iniciante', name: 'Lutador Iniciante', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/lutador-iniciante.webp', thumb: 'assets/cards/sombras/lutador-iniciante_p.webp' },
  { id: 'sombras-lider', name: 'Líder', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/lider.webp', thumb: 'assets/cards/sombras/lider_p.webp' },
  { id: 'sombras-madame-rosalie', name: 'Madame Rosalie', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/madame-rosalie.webp', thumb: 'assets/cards/sombras/madame-rosalie_p.webp' },
  { id: 'sombras-mafioso', name: 'Mafioso', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/mafioso.webp', thumb: 'assets/cards/sombras/mafioso_p.webp' },
  { id: 'sombras-marco-moretti', name: 'Marco Moretti', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/marco-moretti.webp', thumb: 'assets/cards/sombras/marco-moretti_p.webp' },
  { id: 'sombras-milo-vane', name: 'Milo Vane', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/milo-vane.webp', thumb: 'assets/cards/sombras/milo-vane_p.webp' },
  { id: 'sombras-operario', name: 'Operário', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/operario.webp', thumb: 'assets/cards/sombras/operario_p.webp' },
  { id: 'sombras-otto-kern', name: 'Otto Kern', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/otto-kern.webp', thumb: 'assets/cards/sombras/otto-kern_p.webp' },
  { id: 'sombras-rocco-bell', name: 'Rocco Bell', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/rocco-bell.webp', thumb: 'assets/cards/sombras/rocco-bell_p.webp' },
  { id: 'sombras-vigia', name: 'Vigia', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/vigia.webp', thumb: 'assets/cards/sombras/vigia_p.webp' },
  { id: 'sombras-viktor-reiter', name: 'Viktor Reiter', group: 'sombras', oneshot: 'sombras', color: 'safira', card: 'assets/cards/sombras/viktor-reiter.webp', thumb: 'assets/cards/sombras/viktor-reiter_p.webp' },
  // A Última Gota
  { id: 'gota-armand-montreux', name: 'Armand Montreux', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/armand-montreux.webp', thumb: 'assets/cards/gota/armand-montreux_p.webp' },
  { id: 'gota-bastien-lacroix', name: 'Bastien Lacroix', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/bastien-lacroix.webp', thumb: 'assets/cards/gota/bastien-lacroix_p.webp' },
  { id: 'gota-celeste-valerbrun', name: 'Celeste Valerbrun', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/celeste-valerbrun.webp', thumb: 'assets/cards/gota/celeste-valerbrun_p.webp' },
  { id: 'gota-clara-salles', name: 'Clara Salles', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/clara-salles.webp', thumb: 'assets/cards/gota/clara-salles_p.webp' },
  { id: 'gota-domenico-ardenti', name: 'Domenico Ardenti', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/domenico-ardenti.webp', thumb: 'assets/cards/gota/domenico-ardenti_p.webp' },
  { id: 'gota-elise-braird', name: 'Elise Braird', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/elise-braird.webp', thumb: 'assets/cards/gota/elise-braird_p.webp' },
  { id: 'gota-gabriel-rossi', name: 'Gabriel Rossi', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/gabriel-rossi.webp', thumb: 'assets/cards/gota/gabriel-rossi_p.webp' },
  { id: 'gota-helena-alencourt', name: 'Helena Alencourt', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/helena-alencourt.webp', thumb: 'assets/cards/gota/helena-alencourt_p.webp' },
  { id: 'gota-helena-vellar', name: 'Helena Vellar', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/helena-vellar.webp', thumb: 'assets/cards/gota/helena-vellar_p.webp' },
  { id: 'gota-isolde-werner', name: 'Isolde Werner', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/isolde-werner.webp', thumb: 'assets/cards/gota/isolde-werner_p.webp' },
  { id: 'gota-lorcan-verdanza', name: 'Lorcan Verdanza', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/lorcan-verdanza.webp', thumb: 'assets/cards/gota/lorcan-verdanza_p.webp' },
  { id: 'gota-lucien-moreau', name: 'Lucien Moreau', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/lucien-moreau.webp', thumb: 'assets/cards/gota/lucien-moreau_p.webp' },
  { id: 'gota-matteo-salazar', name: 'Matteo Salazar', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/matteo-salazar.webp', thumb: 'assets/cards/gota/matteo-salazar_p.webp' },
  { id: 'gota-mendigo-vampiro', name: 'Mendigo Vampiro', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/mendigo-vampiro.webp', thumb: 'assets/cards/gota/mendigo-vampiro_p.webp' },
  { id: 'gota-mae-da-celeste-valerbrun', name: 'Mãe da Celeste Valerbrun', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/mae-da-celeste-valerbrun.webp', thumb: 'assets/cards/gota/mae-da-celeste-valerbrun_p.webp' },
  { id: 'gota-mae-da-seraphine-alencourt', name: 'Mãe da Seraphine Alencourt', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/mae-da-seraphine-alencourt.webp', thumb: 'assets/cards/gota/mae-da-seraphine-alencourt_p.webp' },
  { id: 'gota-mae-do-armand-montreux', name: 'Mãe do Armand Montreux', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/mae-do-armand-montreux.webp', thumb: 'assets/cards/gota/mae-do-armand-montreux_p.webp' },
  { id: 'gota-mae-do-tomas-avellar', name: 'Mãe do Tomás Avellar', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/mae-do-tomas-avellar.webp', thumb: 'assets/cards/gota/mae-do-tomas-avellar_p.webp' },
  { id: 'gota-nicola-drakovic', name: 'Nicola Drakovic', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/nicola-drakovic.webp', thumb: 'assets/cards/gota/nicola-drakovic_p.webp' },
  { id: 'gota-pai-da-clara-salles', name: 'Pai da Clara Salles', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/pai-da-clara-salles.webp', thumb: 'assets/cards/gota/pai-da-clara-salles_p.webp' },
  { id: 'gota-pai-da-helena-alencourt', name: 'Pai da Helena Alencourt', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/pai-da-helena-alencourt.webp', thumb: 'assets/cards/gota/pai-da-helena-alencourt_p.webp' },
  { id: 'gota-pai-do-gabriel-rossi', name: 'Pai do Gabriel Rossi', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/pai-do-gabriel-rossi.webp', thumb: 'assets/cards/gota/pai-do-gabriel-rossi_p.webp' },
  { id: 'gota-pai-do-lorcan-verdanza', name: 'Pai do Lorcan Verdanza', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/pai-do-lorcan-verdanza.webp', thumb: 'assets/cards/gota/pai-do-lorcan-verdanza_p.webp' },
  { id: 'gota-pai-do-nicola-drakovic', name: 'Pai do Nicola Drakovic', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/pai-do-nicola-drakovic.webp', thumb: 'assets/cards/gota/pai-do-nicola-drakovic_p.webp' },
  { id: 'gota-representante-montreux', name: 'Representante Montreux', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/representante-montreux.webp', thumb: 'assets/cards/gota/representante-montreux_p.webp' },
  { id: 'gota-roman-kovac', name: 'Roman Kovac', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/roman-kovac.webp', thumb: 'assets/cards/gota/roman-kovac_p.webp' },
  { id: 'gota-seraphine-alencourt', name: 'Seraphine Alencourt', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/seraphine-alencourt.webp', thumb: 'assets/cards/gota/seraphine-alencourt_p.webp' },
  { id: 'gota-theo-durand', name: 'Théo Durand', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/theo-durand.webp', thumb: 'assets/cards/gota/theo-durand_p.webp' },
  { id: 'gota-tomas-avellar', name: 'Tomás Avellar', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/tomas-avellar.webp', thumb: 'assets/cards/gota/tomas-avellar_p.webp' },
  { id: 'gota-viktor-malek', name: 'Viktor Malek', group: 'gota', oneshot: 'gota', color: 'rubi', card: 'assets/cards/gota/viktor-malek.webp', thumb: 'assets/cards/gota/viktor-malek_p.webp' },
  // Mistérios Vermelhos
  { id: 'misterios-demonio-barman', name: 'Demônio Barman', group: 'misterios', oneshot: 'misterios', color: 'ametista', card: 'assets/cards/misterios/demonio-barman.webp', thumb: 'assets/cards/misterios/demonio-barman_p.webp' },
  { id: 'misterios-demonio-crupie', name: 'Demônio Crupiê', group: 'misterios', oneshot: 'misterios', color: 'ametista', card: 'assets/cards/misterios/demonio-crupie.webp', thumb: 'assets/cards/misterios/demonio-crupie_p.webp' },
  { id: 'misterios-demonio-gerente', name: 'Demônio Gerente', group: 'misterios', oneshot: 'misterios', color: 'ametista', card: 'assets/cards/misterios/demonio-gerente.webp', thumb: 'assets/cards/misterios/demonio-gerente_p.webp' },
  { id: 'misterios-demonio-mafioso', name: 'Demônio Mafioso', group: 'misterios', oneshot: 'misterios', color: 'ametista', card: 'assets/cards/misterios/demonio-mafioso.webp', thumb: 'assets/cards/misterios/demonio-mafioso_p.webp' },
  { id: 'misterios-humano-apostador', name: 'Humano Apostador', group: 'misterios', oneshot: 'misterios', color: 'ametista', card: 'assets/cards/misterios/humano-apostador.webp', thumb: 'assets/cards/misterios/humano-apostador_p.webp' },
  { id: 'misterios-mizuki-kurohana', name: 'Mizuki Kurohana', group: 'misterios', oneshot: 'misterios', color: 'ametista', card: 'assets/cards/misterios/mizuki-kurohana.webp', thumb: 'assets/cards/misterios/mizuki-kurohana_p.webp' },
  { id: 'misterios-seguranca-do-eclipse', name: 'Segurança do Eclipse', group: 'misterios', oneshot: 'misterios', color: 'ametista', card: 'assets/cards/misterios/seguranca-do-eclipse.webp', thumb: 'assets/cards/misterios/seguranca-do-eclipse_p.webp' },
  { id: 'misterios-torr-eybscott', name: 'Torr Eybscott', group: 'misterios', oneshot: 'misterios', color: 'ametista', card: 'assets/cards/misterios/torr-eybscott.webp', thumb: 'assets/cards/misterios/torr-eybscott_p.webp' },
  { id: 'misterios-valentin-marlowe', name: 'Valentin Marlowe', group: 'misterios', oneshot: 'misterios', color: 'ametista', card: 'assets/cards/misterios/valentin-marlowe.webp', thumb: 'assets/cards/misterios/valentin-marlowe_p.webp' },
  // Gerais
  { id: 'gerais-abel-rourke', name: 'Abel Rourke', group: 'gerais', oneshot: null, color: 'safira', card: 'assets/cards/gerais/abel-rourke.webp', thumb: 'assets/cards/gerais/abel-rourke_p.webp' },
  { id: 'gerais-augusto-valmont', name: 'Augusto Valmont', group: 'gerais', oneshot: null, color: 'safira', card: 'assets/cards/gerais/augusto-valmont.webp', thumb: 'assets/cards/gerais/augusto-valmont_p.webp' },
  { id: 'gerais-aurelian-voss', name: 'Aurelian Voss', group: 'gerais', oneshot: null, color: 'safira', card: 'assets/cards/gerais/aurelian-voss.webp', thumb: 'assets/cards/gerais/aurelian-voss_p.webp' },
  { id: 'gerais-heitor-brandt', name: 'Heitor Brandt', group: 'gerais', oneshot: null, color: 'safira', card: 'assets/cards/gerais/heitor-brandt.webp', thumb: 'assets/cards/gerais/heitor-brandt_p.webp' },
  { id: 'gerais-vicente-argo', name: 'Vicente Argo', group: 'gerais', oneshot: null, color: 'safira', card: 'assets/cards/gerais/vicente-argo.webp', thumb: 'assets/cards/gerais/vicente-argo_p.webp' }
];
