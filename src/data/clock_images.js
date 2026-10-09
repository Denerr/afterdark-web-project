/* Afterdark · Dados — Imagens padrão do aviso de conclusão, por tipo de relógio
 * clockImages → { '<tipo>': 'assets/...' }  (tipos: ver clockTheme em themes.js)
 * Usada quando o relógio não tem "Imagem da conclusão" própria. Sem padrão para o tipo,
 * o aviso mantém o fundo atual (gradiente na cor do tipo).
 * Lido por index.html via window.AfterdarkData.clockImages.
 *
 * As imagens padrão (Ameaça, Investigação, Tensão, Ritual, Perda de Controle,
 * Perseguição) serão adicionadas quando os arquivos forem enviados (decisão de 09/10/2026).
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.clockImages = {};
