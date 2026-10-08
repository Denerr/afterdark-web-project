/* Afterdark · Dados — Mapas das cenas
 * maps → catálogo de mapas que o Mestre pode associar a uma cena.
 *   { id, name, src, oneshot }
 *   src: imagem dentro do site; oneshot: chave do one-shot (gota / misterios / sombras).
 * A cena guarda só o id; trocar o arquivo aqui atualiza todas as cenas que o usam.
 * No formulário de cena, a mesa de um one-shot vê só os mapas dele; mesa sem one-shot
 * (campanha) vê todos.
 * Lido por index.html via window.AfterdarkData.maps.
 *
 * Origem: Mapas_Oficiais_Afterdark (seleção oficial de 08/10/2026, 1536 × 1024 px),
 * convertidos para WebP (qualidade 82) em assets/maps/<one-shot>/.
 * Academia_Rubra_03 ficou de fora: o arquivo enviado é idêntico ao 02.
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.maps = [
  // A Última Gota
  { id: 'gota-academia-1', oneshot: 'gota', name: 'Academia Rubra · 1', src: 'assets/maps/gota/academia_rubra_01.webp' },
  { id: 'gota-academia-2', oneshot: 'gota', name: 'Academia Rubra · 2', src: 'assets/maps/gota/academia_rubra_02.webp' },
  { id: 'gota-academia-4', oneshot: 'gota', name: 'Academia Rubra · 4', src: 'assets/maps/gota/academia_rubra_04.webp' },
  // Mistérios Vermelhos
  { id: 'misterios-eclipse-1', oneshot: 'misterios', name: 'Clube Eclipse · 1', src: 'assets/maps/misterios/clube_eclipse_01.webp' },
  { id: 'misterios-eclipse-2', oneshot: 'misterios', name: 'Clube Eclipse · 2', src: 'assets/maps/misterios/clube_eclipse_02.webp' },
  { id: 'misterios-eclipse-3', oneshot: 'misterios', name: 'Clube Eclipse · 3', src: 'assets/maps/misterios/clube_eclipse_03.webp' },
  // Sombras Uivantes
  { id: 'sombras-arena-terreo',  oneshot: 'sombras', name: 'Arena · Térreo',        src: 'assets/maps/sombras/arena_terreo.webp' },
  { id: 'sombras-arena-vip',     oneshot: 'sombras', name: 'Arena · VIP',           src: 'assets/maps/sombras/arena_vip.webp' },
  { id: 'sombras-beco-chao',     oneshot: 'sombras', name: 'Beco · Chão',           src: 'assets/maps/sombras/beco_chao.webp' },
  { id: 'sombras-beco-telhados', oneshot: 'sombras', name: 'Beco · Telhados',       src: 'assets/maps/sombras/beco_telhados.webp' },
  { id: 'sombras-fabrica-1',     oneshot: 'sombras', name: 'Fábrica · Térreo',      src: 'assets/maps/sombras/fabrica_terreo.webp' },
  { id: 'sombras-fabrica-2',     oneshot: 'sombras', name: 'Fábrica · 2º andar',    src: 'assets/maps/sombras/fabrica_segundo_andar.webp' },
  { id: 'sombras-fabrica-3',     oneshot: 'sombras', name: 'Fábrica · 3º andar',    src: 'assets/maps/sombras/fabrica_terceiro_andar.webp' }
];
