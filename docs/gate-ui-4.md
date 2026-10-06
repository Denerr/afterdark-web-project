# Gate UI 4 — Perícias explicadas na criação

Data: 06/10/2026 · Base: `main` @ `40489fb` (UI 3 em produção)

## O que mudou

- **Catálogo como fonte única.** `src/data/attributes.js` ganhou `intro` em cada atributo
  e `desc` em cada perícia. Wizard, ficha e testes leem daí; não há texto duplicado em
  template. Os textos dizem **o que a perícia cobre em jogo** — nenhum bônus, custo ou
  efeito mecânico.
- **Wizard, etapa 5:** introdução curta sob o nome de cada atributo e descrição sob o nome
  de cada perícia, no desktop e no celular, sem depender de hover. Os controles `−`/`+`
  continuam à direita, alinhados, com 44 px. A grade passou de `minmax(230px)` para
  `minmax(280px)` para a descrição ter largura de leitura.
- **Pontos restantes sempre visíveis:** saíram do meio do parágrafo para um contador
  fixo (`sticky`) que acompanha a rolagem da lista de 24 perícias.

Custo, limite de +3 por perícia e total de pontos **não foram alterados**.

## Os textos — revisão pendente

Os textos que você aprovou numa sessão anterior **não estavam nesta conversa nem no
repositório**. Para não travar a etapa, usei a redação do sistema oficial onde ela existe
(`mecanica-afterdark-att-18-06-26.md`, seção 4.2) e escrevi rascunhos no restante. Cada
linha do catálogo está marcada com a origem. Trocar pelos seus textos é editar só esse
arquivo — nenhum código depende da redação.

| Origem | Perícias |
|---|---|
| **Oficial** (15) | Resistência, Furtividade, Investigação, Tecnologia, Medicina, Intimidação, Percepção, Autocontrole, Ocultismo; e por equivalência: Luta (Briga + Armas Brancas), Pontaria (Disparo), Persuasão e Enganação (Lábia), Resistência Espiritual (Vontade), Sensibilidade (seção 5) |
| **Rascunho** (9) | Atletismo, Proteção, Condução, Crime, Conhecimento, Etiqueta, Intuição, Rastreamento, Rituais |
| **Rascunho** (6 introduções) | Corpo, Reflexos, Mente, Presença, Instinto, Espírito |

### Divergências encontradas entre o app e o sistema oficial (não alteradas)

O plano manda conferir a redação com o sistema e **não** mudar regras. Registro para sua
decisão:

1. **A lista de perícias é diferente.** O oficial tem 16 (Armas Brancas, Briga, Disparo,
   Esquiva, Lábia, Submundo, Vontade…); o app tem 24, e só 9 nomes coincidem.
2. **Pontos na criação:** o wizard diz "Distribua 24 pontos"; o sistema (`mecânica-
   afterdark.md`, 8.1) diz **10**.
3. **Rituais × Ocultismo:** o oficial resolve "Ritual ofensivo" com
   `1d10 + Espírito + Ocultismo` — a perícia Rituais do app não aparece nessa fórmula.

## Testes

| Suíte | Resultado |
|---|---|
| Navegador — etapa 4 (textos, layout, contador, valores, 7 etapas, larguras) | **25/25** |
| Navegador — regressão (painel do Mestre geral/combate, painel e ficha do jogador) | **2/2** |
| SQL `ponto1` / `ponto2` / `ponto2b` / `ponto3` | **52 / 73 / 24 / 32** |

Conferido: as 24 descrições e 6 introduções aparecem; descrição abaixo do nome e controles
à direita (geometria medida, não só presença); somar/remover guarda o valor e o contador
acompanha; limite de +3 preservado; avançar para a etapa 6 e voltar preserva tudo; as 7
etapas renderizam sem erro; 390, 768, 900, 1024, 1280 e 1440 px sem corte horizontal.
Nenhuma cor fora da paleta atual e nenhum background tocado (checagem do diff).

### Falha encontrada e corrigida durante o gate

**O contador grudava atrás da barra superior.** O site tem uma barra fixa de 54 px, e o
contador com `top:0` ficava escondido sob ela. O primeiro teste passou **em falso**:
checava se o contador estava dentro do viewport, não se estava visível. Corrigi para
`top:62px` e reescrevi a verificação com `elementFromPoint` (o ponto central do contador
precisa ser o próprio contador). **Teste de mutação:** voltei temporariamente para `top:0`
e a verificação nova falhou nos dois tamanhos, como deveria — depois restaurei.

## Limitações

- 9 descrições e as 6 introduções são rascunhos e precisam da sua revisão.
- As descrições aparecem no wizard. Ficha e formulário de testes já leem o mesmo catálogo,
  mas não exibem a descrição — o formulário de testes será refeito na Etapa 5.
- O `top:62px` depende da altura fixa da barra (54 px). Se a barra mudar, o contador
  precisa acompanhar.

## Validação

Aceites atendidos, com a ressalva dos textos: todas as perícias e conjuntos têm explicação,
legíveis em desktop e celular sem competir com os controles; somar/remover e
avançar/voltar preservam valores; as 7 etapas e animações seguem funcionando; nenhuma
regra, cor ou imagem alterada. **"Explicação conferida" depende da sua revisão dos
rascunhos.**
