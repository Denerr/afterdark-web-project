/* Afterdark · Dados — Imagens padrão do aviso de conclusão, por tipo de relógio
 * clockImages → { '<tipo>': 'assets/...' }  (tipos: ver clockTheme em themes.js)
 * Usada quando o relógio não tem "Imagem da conclusão" própria; a imagem própria, quando
 * existe, sempre substitui a padrão. Sem padrão para o tipo, o aviso mantém o fundo atual.
 * Lido por index.html via window.AfterdarkData.clockImages.
 *
 * Origem: Saint_Vesper_Relógios_Padrão (versões aprovadas em 09/10/2026, 1920 × 1080),
 * reduzidas para 1280 × 720 em WebP em assets/clocks/ (o aviso tem no máximo 680 px).
 */
(window.AfterdarkData = window.AfterdarkData || {});

window.AfterdarkData.clockImages = {
  'Ameaça':            'assets/clocks/ameaca.webp',
  'Investigação':      'assets/clocks/investigacao.webp',
  'Tensão':            'assets/clocks/tensao.webp',
  'Facção':            'assets/clocks/faccao.webp',
  'Objetivo':          'assets/clocks/objetivo.webp',
  'Perda de Controle': 'assets/clocks/perda-de-controle.webp',
  'Ritual':            'assets/clocks/ritual.webp',
  'Perseguição':       'assets/clocks/perseguicao.webp',
  'Exposição Pública': 'assets/clocks/exposicao-publica.webp'
};
