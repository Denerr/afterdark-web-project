# Afterdark — Página Web de RPG de Mesa

Página web do **Afterdark**, um RPG investigativo noir em Saint Vesper.
Projeto **simples em HTML + CSS + JS**, sem build, sem npm e sem instalação —
é só abrir no navegador.

## Estrutura dos arquivos

```
export/
├── index.html          → estrutura, interface e lógica da página
├── css/
│   └── styles.css      → estilos globais (reset, cores base, animações)
├── support.js          → motor de renderização (carrega o React via CDN)
├── src/
│   └── data/           → dados do jogo, fáceis de editar:
│       ├── attributes.js   (atributos e as 24 perícias)
│       ├── natures.js      (sensibilidades)
│       ├── adventures.js   (one-shots e capítulos)
│       ├── themes.js
│       ├── equipment.js
│       └── seed.js         (personagens/jogadores de exemplo)
└── assets/
    └── images/         → fundo da tela inicial e capas dos one-shots
```

## Como abrir no Visual Studio Code

1. Abra a pasta `export/` no VS Code (**Arquivo → Abrir Pasta**).
2. Instale a extensão **Live Server** (autor: Ritwick Dey), se ainda não tiver.
3. Clique com o botão direito em `index.html` → **Open with Live Server**.
4. O navegador abre a página automaticamente.

> **Por que Live Server?** Os dados do jogo são carregados de arquivos `.js`
> locais. Abrir o `index.html` com clique duplo (`file://`) pode fazer o
> navegador bloquear esse carregamento. O Live Server serve os arquivos por
> `http://` e resolve isso. Qualquer servidor local simples funciona — por
> exemplo, com Python: `python -m http.server` dentro da pasta `export/`.

## Requisitos

- **Conexão com a internet na primeira carga:** o React e as fontes são
  buscados de CDNs públicas. Depois de carregado, o navegador guarda em cache.

## Onde editar cada coisa

- **Textos, cores e layout das telas:** `index.html` (os estilos ficam inline,
  ao lado de cada elemento; os globais estão em `css/styles.css`).
- **Regras e conteúdo do jogo** (perícias, atributos, aventuras, personagens de
  exemplo): arquivos em `src/data/`.
- **Animações e cores base:** `css/styles.css`.
