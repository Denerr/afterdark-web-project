# Afterdark / Saint Vesper — Implementação de background dinâmico com parallax otimizado

Este pacote contém 5 fundos para a tela **Escolha sua Natureza**, pensados para trocar de acordo com a opção selecionada pelo usuário.

## Arquivos incluídos

- `01-default-neutro.png` → estado inicial / nenhum selecionado
- `02-humano-comum.png` → Humano Comum
- `03-sensitivo-vampiros.png` → Sensível a Vampiros
- `04-sensitivo-lobisomens.png` → Sensível a Lobisomens
- `05-sensitivo-demonios.png` → Sensível a Demônios

---

## Mapeamento recomendado na UI

### Estado inicial
Use `01-default-neutro.png` como fundo padrão da página antes da seleção.

### Ao selecionar uma opção
- **Humano Comum** → trocar para `02-humano-comum.png`
- **Sensível a Vampiros** → trocar para `03-sensitivo-vampiros.png`
- **Sensível a Lobisomens** → trocar para `04-sensitivo-lobisomens.png`
- **Sensível a Demônios** → trocar para `05-sensitivo-demonios.png`

---

## Melhor abordagem: transição suave + pseudo-parallax leve

Para manter o site bonito e leve, a melhor solução é **não usar parallax real complexo com muitas camadas grandes animadas em tempo real**.

Em vez disso, use este combo:

1. **troca com crossfade do background principal**;
2. **leve movimento de brilho/névoa com pseudo-elementos**;
3. **pequeno deslocamento baseado no mouse apenas em desktop**;
4. **desligar ou reduzir tudo em mobile e em `prefers-reduced-motion`**.

Isso entrega uma sensação elegante de profundidade sem pesar.

---

## Estrutura recomendada

Crie uma camada fixa de fundo atrás de todo o conteúdo da tela:

```html
<div class="nature-screen">
  <div class="bg-layer bg-base"></div>
  <div class="bg-layer bg-overlay"></div>
  <div class="bg-layer bg-glow"></div>

  <main class="nature-content">
    <!-- cards e conteúdo -->
  </main>
</div>
```

### Função de cada camada
- `bg-base` → imagem principal atual
- `bg-overlay` → próxima imagem para crossfade
- `bg-glow` → brilho/névoa leve por cima para dar vida

---

## CSS base recomendado

```css
.nature-screen {
  position: relative;
  min-height: 100vh;
  overflow: hidden;
  background: #05070c;
}

.bg-layer {
  position: absolute;
  inset: 0;
  background-position: center;
  background-repeat: no-repeat;
  background-size: cover;
  will-change: transform, opacity;
  pointer-events: none;
}

.bg-base,
.bg-overlay {
  transition: opacity 420ms ease, transform 420ms ease;
}

.bg-base {
  opacity: 1;
  transform: scale(1.02);
}

.bg-overlay {
  opacity: 0;
  transform: scale(1.04);
}

.bg-glow {
  background:
    radial-gradient(circle at 50% 20%, rgba(255,255,255,0.06), transparent 35%),
    radial-gradient(circle at 50% 85%, rgba(100,140,255,0.05), transparent 25%);
  mix-blend-mode: screen;
  opacity: 0.65;
}

.nature-content {
  position: relative;
  z-index: 2;
}
```

---

## Como fazer a troca de fundo

### Lógica recomendada
1. `bg-base` mostra a imagem atual.
2. Ao clicar em uma opção, carregue a nova imagem em `bg-overlay`.
3. Anime `bg-overlay` para `opacity: 1`.
4. Depois da transição, copie a nova imagem para `bg-base` e zere `bg-overlay`.

### Exemplo em JavaScript

```js
const bgBase = document.querySelector('.bg-base');
const bgOverlay = document.querySelector('.bg-overlay');

const backgrounds = {
  default: 'images/01-default-neutro.png',
  humano: 'images/02-humano-comum.png',
  vampiro: 'images/03-sensitivo-vampiros.png',
  lobisomem: 'images/04-sensitivo-lobisomens.png',
  demonio: 'images/05-sensitivo-demonios.png'
};

let currentBg = backgrounds.default;
bgBase.style.backgroundImage = `url(${currentBg})`;

function switchBackground(nextKey) {
  const nextBg = backgrounds[nextKey];
  if (!nextBg || nextBg === currentBg) return;

  bgOverlay.style.backgroundImage = `url(${nextBg})`;
  bgOverlay.style.opacity = '1';
  bgOverlay.style.transform = 'scale(1.01)';

  setTimeout(() => {
    bgBase.style.backgroundImage = `url(${nextBg})`;
    bgOverlay.style.opacity = '0';
    bgOverlay.style.transform = 'scale(1.04)';
    currentBg = nextBg;
  }, 420);
}
```

---

## Pseudo-parallax otimizado

Em vez de mover a imagem inteira demais, aplique um deslocamento muito pequeno.

### Regra prática
- máximo de **6px a 12px** de deslocamento;
- apenas no desktop;
- usar `requestAnimationFrame`;
- nunca recalcular layout inteiro;
- mover só `transform`.

### Exemplo simples

```js
const isDesktop = window.matchMedia('(min-width: 1024px)').matches;
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (isDesktop && !reduceMotion) {
  let targetX = 0;
  let targetY = 0;
  let currentX = 0;
  let currentY = 0;

  window.addEventListener('mousemove', (e) => {
    const x = (e.clientX / window.innerWidth) - 0.5;
    const y = (e.clientY / window.innerHeight) - 0.5;

    targetX = x * 12;
    targetY = y * 12;
  });

  function animate() {
    currentX += (targetX - currentX) * 0.08;
    currentY += (targetY - currentY) * 0.08;

    bgBase.style.transform = `translate(${currentX}px, ${currentY}px) scale(1.03)`;
    bgOverlay.style.transform = `translate(${currentX * 1.2}px, ${currentY * 1.2}px) scale(1.04)`;

    requestAnimationFrame(animate);
  }

  animate();
}
```

---

## Ajuste visual por sensibilidade

Você pode reforçar o tema mudando também uma variável de cor ao selecionar cada opção.

### Sugestão de cores
- **default / neutro** → `#7aa2d9`
- **humano** → `#8db3d9`
- **vampiros** → `#c11f3b`
- **lobisomens** → `#88b4ff`
- **demônios** → `#d02a8a`

### Exemplo

```css
:root {
  --accent-glow: #7aa2d9;
}

.selection-highlight {
  box-shadow: 0 0 24px color-mix(in srgb, var(--accent-glow) 35%, transparent);
  border-color: var(--accent-glow);
}
```

```js
const accentMap = {
  default: '#7aa2d9',
  humano: '#8db3d9',
  vampiro: '#c11f3b',
  lobisomem: '#88b4ff',
  demonio: '#d02a8a'
};

function setAccent(key) {
  document.documentElement.style.setProperty('--accent-glow', accentMap[key]);
}
```

Ao selecionar uma opção:

```js
switchBackground('vampiro');
setAccent('vampiro');
```

---

## Efeito extra leve e bonito

Se quiser um refinamento extra sem pesar:

### Partículas lentas opcionais
Use apenas 6 a 12 partículas pequenas com CSS animation, bem discretas.

### Exemplo
```css
.floating-particles::before,
.floating-particles::after {
  content: '';
  position: absolute;
  inset: 0;
  background-image:
    radial-gradient(circle, rgba(255,255,255,0.18) 1px, transparent 1px);
  background-size: 180px 180px;
  opacity: 0.18;
  animation: drift 16s linear infinite;
}

@keyframes drift {
  from { transform: translateY(0px); }
  to   { transform: translateY(14px); }
}
```

Use isso com moderação.

---

## Performance: o que fazer

- comprimir as imagens em WebP/AVIF para produção;
- manter a resolução adequada ao layout real;
- pré-carregar só a imagem default;
- lazy-load das outras no primeiro hover ou ao abrir a tela;
- animar apenas `opacity` e `transform`;
- limitar o parallax a desktop;
- desligar efeito para `prefers-reduced-motion`.

---

## Performance: o que evitar

- múltiplos backgrounds gigantes animando ao mesmo tempo;
- blur pesado em tempo real;
- filtros CSS complexos em tela cheia;
- parallax por scroll com recalculação constante;
- mover camadas demais em mobile;
- usar vídeos como fundo dessa tela.

---

## Fluxo ideal de implementação

1. carregar `01-default-neutro.png`;
2. quando o usuário escolher uma opção, aplicar:
   - troca de imagem com crossfade;
   - troca da cor de destaque;
   - pequeno pseudo-parallax, se desktop;
3. manter a intensidade do efeito baixa para não competir com os cards.

---

## Resumo visual ideal

- **estado padrão** → frio, elegante, neutro;
- **humano** → urbano, estável, investigativo;
- **vampiro** → rubro, aristocrático, sedutor;
- **lobisomem** → lunar, predatório, nebuloso;
- **demônio** → magenta, infernal, ritualístico.

O objetivo é que a troca seja **sentida**, não exagerada.

