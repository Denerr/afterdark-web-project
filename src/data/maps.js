/* Afterdark · Dados — Mapas das cenas
 * maps → catálogo de mapas que o Mestre pode associar a uma cena.
 *   { id, name, src }   src: caminho da imagem dentro do site (ex.: assets/maps/docas.jpg)
 * A cena guarda só o id; trocar o arquivo aqui atualiza todas as cenas que o usam.
 * Lido por index.html via window.AfterdarkData.maps.
 *
 * Os mapas padrão serão adicionados quando os arquivos forem enviados (decisão de
 * 08/10/2026); depois definimos quais aparecem em cada one-shot. Enquanto a lista
 * estiver vazia, as cenas funcionam sem mapa.
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.maps = [];
