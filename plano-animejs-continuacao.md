# Plano Anime.js — Continuação (handoff entre instâncias)

Este arquivo existe para permitir que outra instância/sessão retome exatamente de onde esta parou, seguindo o mesmo plano já combinado. Ele resume o objetivo, as decisões técnicas já tomadas, o que já foi implementado e commitado, e o que está em andamento (inclusive código já escrito mas ainda **não commitado**).

## 1. Objetivo

Adicionar animações (via Anime.js) ao fluxo de criação de personagem do Afterdark (`JChar.dc.html` → `JWizard.dc.html`, 7 etapas), sem comprometer a arquitetura atual do site (estático, sem build step, React carregado por CDN, motor de template próprio `support.js`/`.dc.html`).

## 2. Documentos já existentes no repositório (ordem de leitura recomendada)

1. **`instrucao-personagem-animejs.md`** — auditoria visual completa da tela de criação de personagem hoje: cores, imagens (`nat-*.png`, `bg-arquivo.png`), tipografia, e o parallax que já existia antes de qualquer mudança.
2. **`instrucao-implementa-animejs.md`** — plano arquitetural conceitual completo, escrito por outra IA sem conhecer as limitações reais do projeto (propõe `character-creation/motion/`, `controllers/`, etc. como se houvesse build step).
3. **`inst-claudio.md`** — minha resposta (Claude) traduzindo aquele plano pra dentro das limitações reais do projeto: sem ES modules, sem pastas novas, e a **regra central**: uma propriedade CSS só pode ter um dono (React/template OU Anime.js, nunca os dois no mesmo elemento no mesmo momento).
4. **`inst-johnny.md`** — síntese adaptada por uma segunda IA ("Johnny"), reconciliando o plano original com as restrições do `inst-claudio.md`. Define as 6 fases de implementação (ver seção 4) e critérios de aceitação técnicos. **Este é o documento-guia da implementação** — leia-o primeiro se for continuar o trabalho.
5. **Este arquivo** — status de execução do plano do `inst-johnny.md`.

## 3. Regra técnica central (não violar)

Quando um elemento no `.dc.html` tem `style="prop: {{ x }}"`, o React reaplica esse valor a cada re-render (mesmo em re-renders não relacionados, como cada tecla digitada em qualquer input da página). Se o Anime.js também mexer nessa mesma propriedade nesse mesmo elemento, o React vai sobrescrever o valor animado no próximo re-render.

**Regra:** cada propriedade CSS animável tem um dono só. Se o Anime.js precisa controlar `opacity`/`transform` de um elemento, esse elemento não pode ter essa propriedade vinda de `{{ }}` no template — nem como valor estático simples (ex: `opacity:1` fixo no HTML também conta como "React é dono", porque o valor ainda faz parte do objeto de estilo que o React reaplica a cada render). Nesses casos, o valor inicial é setado via JS (ex: `_initPxSlots()`), nunca via atributo no template.

Essa regra já orientou toda a implementação até aqui e continua valendo para o que falta.

## 4. As 6 fases do plano (`inst-johnny.md`, seção 16)

| Fase | Conteúdo | Status |
|---|---|---|
| 1 | Preparação segura: CDN do Anime.js, `prefers-reduced-motion`, pré-carregamento de imagens, hooks `data-motion` | ✅ Commitada |
| 2 | Encapsular o parallax existente (listener com ciclo de vida próprio) | ✅ Commitada |
| 3 | Transições animadas entre as 7 etapas do wizard | ✅ Commitada |
| 4 | Crossfade dos fundos da Etapa 2 (Natureza) via Anime.js | ✅ Commitada |
| 5 | Feedbacks visuais nas etapas 3-7 (fraquezas, atributos, perícias, histórico, resumo) | ✅ Commitada e testada (Playwright) |
| 6 | Mobile e performance | ⬜ Não iniciada |

## 5. O que já está commitado (Fases 1-4)

Commits no branch `main` (mais recente primeiro), todos **locais** — o push pro GitHub é feito manualmente pelo usuário, exceto quando ele pede explicitamente (como este arquivo):

- (Fase 5, ver seção 6) — feedbacks visuais nas etapas 3-7.
- `e01636b` — Fase 4: crossfade dos fundos da Natureza via Anime.js.
- `4a9342b` — Fase 3: transições animadas entre as 7 etapas do personagem.
- `1375157` — Fase 2: encapsula o listener de parallax da Etapa 2.
- `05f5acc` — Fase 1: preparação segura pra animações da criação de personagem.

Resumo funcional do que já existe e funciona (testado com Playwright, 0 erros de console em todos os casos):

- **Anime.js** carregado via CDN (`https://cdn.jsdelivr.net/npm/animejs@3.2.2/lib/anime.min.js`), acessível como `window.anime`.
- **`_prefersReducedMotion()`** — helper central que todo controlador de movimento consulta antes de animar.
- **`_preloadMotionAssets()`** — pré-carrega `nat-default.png` no mount e as 4 imagens de Natureza logo depois via `requestIdleCallback`.
- **Parallax da Etapa 2 encapsulado**: `_parallaxEnable()`/`_parallaxDisable()`/`_syncParallax()`/`_canParallax()` — ativa só na Etapa 2, respeita `prefers-reduced-motion` e `pointer:fine` (sem parallax de toque no mobile), desativa e reseta ao sair.
- **Transições entre etapas**: `_wizGoToStep(nextStep, direction)`/`_wizAnimateIn(el, direction, done)` — anima a saída da etapa atual (desliza + fade), só então troca `wizStep`, anima a entrada da nova etapa depois que o React confirma o novo DOM (callback do `setState`). Trava contra cliques duplicados (`_wizTransitioning`). Direção diferente pra avançar (entra pela direita) e voltar (entra pela esquerda). Se o Anime.js não carregar ou `prefers-reduced-motion` estiver ativo, a troca acontece direto sem animar.
- **Crossfade dos fundos da Natureza**: `_switchPxBg(key)`/`_crossfadePxSlots(fromLetter,toLetter,url)`/`_initPxSlots()` — os slots A/B (`[data-motion="background-slot-a/b"]`) não têm mais NENHUM binding de `opacity` no template; o Anime.js é o único dono dessa propriedade. `anime.remove()` cancela crossfades anteriores em trocas rápidas entre cards (hover rápido pelos 4 cards de Natureza converge pra um estado limpo, sem fila de animações).
- **Hooks `data-motion` já presentes no HTML** (marcadores estáveis, sem lógica de animação própria — servem de alvo pro JS): `wizard-step`, `step-title`, `step-section` (um por etapa), `nature-card` (4x, Etapa 2), `background-slot-a`/`background-slot-b`, `nature-ring`, `particle-field`, `char-title`, `char-path` (na tela `JChar.dc.html`).
- `componentWillUnmount` marca `this._unmounted=true`; todos os callbacks de animação checam essa flag antes de chamar `setState` (evita erro de setState em componente desmontado).

## 6. Fase 5 — CONCLUÍDA e testada

O código descrito abaixo (que uma sessão anterior tinha escrito só no working tree, nunca commitado, e por isso não sobreviveu à troca de sessão/máquina) foi reescrito do zero seguindo esta mesma especificação, validado com `node --check`, checado quanto ao balanceamento de tags, e testado num navegador real via Playwright (fluxo completo de criação de personagem, incluindo os bumps de fraqueza/atributo/perícia, o stagger das Etapas 6/7, o comportamento com `prefers-reduced-motion`, e regressão das Fases 1-4). Todos os testes passaram, 0 erros de console.

### O que foi adicionado (`index.html`)

```js
// bloco 8 do MOTION (feedbacks de validação/confirmação)
_bumpEl(el){
  if(!el||!window.anime||this._prefersReducedMotion()||this._unmounted) return;
  window.anime.remove(el);
  window.anime({targets:el,scale:[1.32,1],duration:240,easing:'easeOutBack'});
}
_staggerReveal(selector){
  if(this._unmounted||this._prefersReducedMotion()||!window.anime) return;
  const els=document.querySelectorAll(selector);
  if(!els.length) return;
  window.anime({targets:els,opacity:[0,1],translateY:[10,0],duration:320,delay:window.anime.stagger(70),easing:'easeOutQuad'});
}
_wizStepEntranceExtras(step){
  if(step===6) this._staggerReveal('[data-motion="history-prompt"]');
  if(step===7) this._staggerReveal('[data-motion="summary-card"]');
}
```

- `_wizStepEntranceExtras(nextStep)` é chamado dentro do `complete` callback de `_wizAnimateIn`, em `_wizGoToStep` — ou seja, o stagger das Etapas 6/7 só dispara DEPOIS que a animação de entrada da etapa (Fase 3) já terminou. Isso cria um reveal em dois estágios: o container inteiro entra deslizando, e só depois o conteúdo interno (perguntas do histórico / cards do resumo) cascateia.
- `toggleWeak(w)`, `incAttr(k)`, `decAttr(k)`, `incSkill(k)`, `decSkill(k)` foram reescritos: cada um agora calcula ANTES do `setState` se a ação seria bloqueada (limite de 3 fraquezas, atributo/perícia no máximo ou sem pontos, atributo/perícia já no mínimo), e só chama `_bumpEl(...)` no callback do `setState` se a ação NÃO foi bloqueada. Isso evita "confirmar visualmente" uma ação que na verdade não mudou nada.

### O que foi adicionado (`JWizard.dc.html`)

Apenas atributos `data-motion`/`data-*-key` novos, sem nenhuma mudança de layout ou de binding existente:

- Etapa 3: a caixinha de check de cada fraqueza ganhou `data-motion="weak-check" data-weak-text="{{ w.txt }}"` (não é o row inteiro porque o row tem `transition:.18s` universal no CSS, que brigaria com o pulso do Anime.js — o check interno não tem transition própria).
- Etapa 4: o valor numérico de cada atributo ganhou `data-motion="attr-value" data-attr-key="{{ a.key }}"`.
- Etapa 5: o valor numérico de cada perícia ganhou `data-motion="skill-value" data-skill-key="{{ a.key }}"`.
- Etapa 6: cada pergunta-guia ganhou `data-motion="history-prompt"`.
- Etapa 7: os 7 cards do resumo (Identidade, Natureza, Atributos, Perícias, Fraquezas, Histórico, Resumo Narrativo) ganharam `data-motion="summary-card"`.

Confirmado (antes de qualquer teste em navegador) que nenhum desses elementos tem `opacity`/`transform` vindo de `{{ }}` no template — todos estão livres para o Anime.js, respeitando a regra central da seção 3.

### Testes executados (Playwright, headless Chromium)

Script isolado no scratchpad da sessão (não faz parte do repositório): login → criação de personagem → Etapas 1-7.

1. **Fluxo feliz completo**: seleciona natureza não-humana, marca 3 fraquezas (confirma bump/`scale` em cada uma, e confirma que a 4ª tentativa — bloqueada — NÃO dispara bump), distribui os 3 pontos de atributo (confirma bump a cada incremento válido), distribui os pontos de perícia até liberar o botão Continuar, preenche o histórico, chega na Etapa 6 (confirma stagger reveal das perguntas-guia) e na Etapa 7 (confirma os 7 cards do resumo e o stagger reveal deles). 0 erros de console.
2. **`prefers-reduced-motion: reduce`**: marcar uma fraqueza atualiza o estado (checkbox reflete a escolha) sem nenhuma chamada ao `anime.js` — a ação continua funcional, só sem animar.
3. **Regressão Fases 1-4**: parallax ainda reage a `mousemove` na Etapa 2, crossfade entre naturezas não gera erro, e a transição de ida/volta entre etapas (Continuar/Voltar) funciona.

**Login de teste usado**: `afterdark-flow-1783615750480@mailinator.com` / senha `senha123` (conta real no Supabase de produção, já tem personagem/mesas de teste acumulados — o usuário disse que vai limpar isso depois, não é prioridade).

## 7. Fase 6 — não iniciada

Conteúdo previsto (`inst-johnny.md`, Fase 6): reduzir partículas no mobile, pausar loops invisíveis quando a aba não está ativa, otimizar formato de imagens (WebP/AVIF), testar em dispositivos modestos. Nenhum código escrito ainda.

## 8. Notas operacionais pra quem continuar

- **Sem build step, sem npm no projeto em si** — só os scripts de teste Playwright (isolados numa pasta de scratchpad, fora do repositório) usam npm.
- **Fluxo de teste**: subir `python -m http.server 8765` na raiz, rodar scripts Playwright que already existem/foram escritos ao longo da sessão anterior (nomes citados acima). Esses arquivos de teste NÃO fazem parte do repositório (ficam num diretório de scratchpad temporário da sessão) — se a nova instância não tiver acesso a eles, terá que recriá-los; a lógica de cada um está descrita nos commits das Fases 1-4 (`git log`) e pode ser reconstruída a partir das mensagens de commit, que são bem detalhadas.
- **Git**: por padrão, só commitar localmente — quem faz `git push` é o usuário, manualmente, quando quiser (ele mencionou que o deploy no Netlify está pausado até resolver créditos). Arquivos `.md` de planejamento/instrução (como este) **não devem ser commitados por padrão** — só quando o usuário pedir explicitamente pra aquele arquivo específico (é o caso deste aqui).
- **Sempre verificar antes de animar uma propriedade**: procurar no `.dc.html` correspondente se aquele elemento já tem a propriedade-alvo vinda de `{{ }}` antes de fazer o Anime.js mexer nela. Se tiver, ou anima um elemento filho/wrapper separado sem esse binding, ou remove o binding do template e passa a inicializar via JS (como foi feito com os slots A/B na Fase 4).
