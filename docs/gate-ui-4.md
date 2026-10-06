# Gate UI 4 — Perícias explicadas na criação

Data: 06/10/2026 · Base: `main` @ `40489fb` (UI 3 em produção)

## O que mudou

- **Catálogo como fonte única.** `src/data/attributes.js` ganhou `intro` em cada atributo. Wizard, ficha e testes leem daí; não há texto duplicado em
  template. Os textos dizem **o que a perícia cobre em jogo** — nenhum bônus, custo ou
  efeito mecânico.
- **Wizard, etapa 5:** o texto de cada grupo aparece sob o nome do atributo, no desktop e
  no celular, sem depender de hover. Os controles `−`/`+` continuam à direita, alinhados,
  com 44 px.
- **Pontos restantes sempre visíveis:** saíram do meio do parágrafo para um contador
  fixo (`sticky`) que acompanha a rolagem da lista de 24 perícias.

Custo, limite de +3 por perícia e total de pontos **não foram alterados**.

## Os textos

As introduções dos 6 grupos usam **os textos enviados pelo autor**, exatamente como
escritos. Seguindo a decisão aprovada ("descrições por grupo de atributo"), **não há
descrição por perícia**: uma primeira versão desta etapa tinha descrições individuais (15
adaptadas do sistema oficial e 9 rascunhos), removidas ao receber os textos — ficam no
histórico do git (`90a05f7`) se um dia forem úteis.

### Divergências encontradas entre o app e o sistema oficial (não alteradas)

O plano manda conferir a redação com o sistema e **não** mudar regras. **Decisão do
autor: vale o que está definido no site** — o documento do sistema é que será atualizado
(registro em separado).

1. **A lista de perícias é diferente.** O oficial tem 16 (Armas Brancas, Briga, Disparo,
   Esquiva, Lábia, Submundo, Vontade…); o app tem 24, e só 9 nomes coincidem.
2. **Pontos na criação:** o wizard diz "Distribua 24 pontos"; o sistema (`mecânica-
   afterdark.md`, 8.1) diz **10**.
3. **Rituais × Ocultismo:** o oficial resolve "Ritual ofensivo" com
   `1d10 + Espírito + Ocultismo` — a perícia Rituais do app não aparece nessa fórmula.

## Testes

| Suíte | Resultado |
|---|---|
| Navegador — versão final (textos do autor, posição sob cada atributo, contador, valores, 7 etapas, 390–1280 px) | **15/15** |
| Navegador — primeira versão (geometria descrição/controles, limite +3) | **25/25** |
| Navegador — regressão (painel do Mestre geral/combate, painel e ficha do jogador) | **2/2** |
| SQL `ponto1` / `ponto2` / `ponto2b` / `ponto3` | **52 / 73 / 24 / 32** |

Nenhuma cor fora da paleta atual e nenhum background tocado (checagem do diff).

### Falha encontrada e corrigida durante o gate

**O contador grudava atrás da barra superior.** O site tem uma barra fixa de 54 px, e o
contador com `top:0` ficava escondido sob ela. O primeiro teste passou **em falso**:
checava se o contador estava dentro do viewport, não se estava visível. Corrigi para
`top:62px` e reescrevi a verificação com `elementFromPoint` (o ponto central do contador
precisa ser o próprio contador). **Teste de mutação:** voltei temporariamente para `top:0`
e a verificação nova falhou nos dois tamanhos, como deveria — depois restaurei.

## Limitações

- Os textos aparecem no wizard; ficha e testes leem o mesmo catálogo, mas não os exibem.
- O `top:62px` depende da altura fixa da barra (54 px). Se a barra mudar, o contador
  precisa acompanhar.

## Validação

Aceites atendidos: todos os conjuntos de perícias têm a explicação do autor,
legíveis em desktop e celular sem competir com os controles; somar/remover e
avançar/voltar preservam valores; as 7 etapas e animações seguem funcionando; nenhuma
regra, cor ou imagem alterada.
