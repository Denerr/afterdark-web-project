# Gate UI 3 — Painel do mestre e contexto das ações

Data: 06/10/2026 · Base: `main` @ `608e0b8` (UI 1 e 2 em produção)

## O que mudou

### Ferramentas agrupadas por tarefa

As 10 ferramentas eram uma faixa plana de abas com `min-width:33%` — quatro linhas de
abas antes de chegar ao conteúdo. Agora a navegação tem dois níveis:

| Grupo | Ferramentas |
|---|---|
| Ações | Testes (geral e combate seguem como sub-abas) |
| Personagens | Estresse, Ferimentos, Condições |
| Investigação | Relógios, **Pistas**, NPCs |
| Condução | Cenas, Roteiro, Narrativa |
| Acervo | Biblioteca |

O grupo ativo é **derivado** de `masterTool`, não guardado em paralelo: não existe um
segundo estado capaz de desincronizar. Trocar de grupo mantém a ferramenta se ela já
pertence a ele; senão abre a primeira. O segundo nível desaparece em grupo de uma só
ferramenta (Ações e Acervo).

**Pistas é uma adição, não um reagrupamento.** O `clues` já era calculado no `renderVals`
do Mestre, mas **nenhum template o consumia** — ele não tinha como ver a lista de pistas
nem o status delas. O plano nomeia "pistas" no grupo Investigação, então acrescentei um
painel somente leitura (nome, status e texto). O status continua mudando só pelos relógios
de Investigação; não inventei controle manual. Se você preferir fora do escopo desta etapa,
é só remover o painel e a chave `pistas` do grupo.

### Atacante, alvo e destinatário da consequência

Este era o defeito antigo: no combate os três papéis eram a mesma pessoa, e o ferimento
sugerido voltava para o próprio atacante. O painel até exibia "Alvo: <nome>", mas o nome
era do atacante.

- `testDraft` ganhou `atkTargetKind` (`membro` | `npc`) e `atkTargetId`.
- O alvo viaja no **próprio pedido** (`params`, que é jsonb livre) — **sem migração**.
- Combate sem alvo escolhido **bloqueia o envio** com motivo. O alvo não "cai" no atacante
  por omissão, que era a origem do bug.
- `rollMaster` passa `targetId` = alvo e `attackerId`/`attackerName`/`targetName` separados.
- `_cleanResult` lê o alvo de `params.atkTargetId`; a confirmação mostra
  **"Atacante: X → Alvo: Y"**.
- Uma linha de contexto no formulário mostra `Executa: … → Alvo: …` enquanto o Mestre monta
  o teste.
- Atacante igual ao alvo é **permitido com aviso**, nunca por omissão.

**Alvo NPC é honesto sobre o limite do modelo.** `master_member_consequence` só aceita
membro da mesa, então um NPC não tem onde guardar ferimento. Escolher "NPC / adversário"
avisa que o resultado é narrado e **não sugere ferimento automático** — em vez de simular
uma seleção que o banco não sustenta.

**Pedido antigo** (sem alvo nos params) continua valendo: o resultado é registrado
normalmente, mas **não há sugestão automática**, em vez de ferir o atacante como antes.

### Histórico recolhível

O "Log de acontecimentos" tinha `max-height:190px` com rolagem. Agora mostra os **3
registros recentes** com a contagem total e um botão "Ver todos os N registros"; expandido,
vira a lista completa rolável. Com 3 ou menos registros, não há botão.

### Estado de salvamento

**Nada a fazer:** o Ponto 3 já exibe `saveStatus` real pelo "saveChip" (salvando / salvo /
falha / offline, com nova tentativa). Conferi em vez de recriar — não há selo fictício.

## Identidade visual

Checagem automática do diff: as 23 cores introduzidas foram comparadas com todas as cores
do `index.html` anterior. Duas eram inéditas (`#e9a0ad` e `rgba(196,30,58,.16)`, que eu
havia usado no seletor de alvo) e foram trocadas pelo padrão já existente para seletores
segmentados — `rgba(198,163,94,.16)` / `#c6a35e` / `#e0c179`, o mesmo de `visModeOptions` e
`stressVisOptions`. **Resultado: nenhuma cor fora da paleta atual, e nenhum background,
imagem ou `url()` tocado.**

## Testes

| Suíte | Resultado |
|---|---|
| Navegador 3A — atacante/alvo/consequência | **20/20** |
| Navegador 3B/3C/3D — grupos, Pistas, log, salvamento | **25/25** |
| Navegador — responsividade do Mestre + regressão do jogador | **20/20** |
| SQL `ponto1` / `ponto2` / `ponto2b` / `ponto3` | **52 / 73 / 24 / 32** |
| **Total** | **246 asserções, 0 falhas** |

Responsividade do painel do Mestre conferida em **1440, 1280, 1279, 1024, 900, 899, 768 e
390 px**, sem corte horizontal em nenhuma. Botões de grupo com **44 px** de alvo de toque,
mantendo o critério da Etapa 2. Pistas com nome longo a 390 px sem estourar.

Regressão conferida: relógios seguem imediatamente abaixo do mapa (posição no DOM, não só
presença), relógio oculto do Mestre continua fora do cliente, barra própria no resumo, aba
Grupo listando participantes, e o painel do jogador sem corte em 1440/1024/900/390 px.

### Falhas encontradas e corrigidas durante o gate

1. `setTestDraft` não existe — o método é `setDraft`. Pego pelo primeiro teste.
2. Duas cores minhas estavam fora da paleta (acima). Pego pela checagem do diff, não a olho.
3. Três defeitos dos meus próprios testes:
   - Esperei 60 ms pelo resultado da rolagem, mas `doRoll` anima ~650 ms antes de assentar.
     Isso deu um falso negativo **e** um falso positivo: a asserção "alvo NPC nunca sugere
     ferimento" passava porque nenhuma rolagem havia assentado. Agora o teste conta os
     acertos de controle antes de afirmar a ausência de sugestão.
   - No mobile o painel de ferramentas fica atrás da aba `masterPanel:'ferramentas'`
     (Etapa 2); o teste media alvos de toque numa coluna não renderizada.
   - A lateral do jogador virou abas na Etapa 1: o Grupo só renderiza com `sideTab:'grupo'`.
     A asserção antiga passava só pelo rótulo da aba.

## Limitações

- O alvo do ataque só aceita **membro da mesa** ou **NPC genérico**. Um NPC nomeado como
  alvo com ferimento persistido exigiria tabela própria para adversários — registrado como
  necessidade técnica, não simulado na interface.
- `testDraft.vis` (visibilidade do teste) continua sem interface: sempre `publico`.
- O par atributo/perícia ainda não é filtrado — é a Etapa 5. Hoje o combate aceita
  "Corpo + Análise", e o padrão `analise` do rascunho geral não existe na lista de perícias.
- Pistas é somente leitura: o Mestre não cria nem revela pista manualmente, só pelos
  relógios de Investigação.
- Nenhuma sessão real com Mestre e dois jogadores foi executada nesta etapa; os testes de
  navegador injetam estado. O fluxo ponta a ponta contra o Supabase real foi validado nos
  gates anteriores.
- Herdadas: altura fixa de 440 px no mapa, `outline:none` em campos de texto.

## Validação

Aceites da Etapa 3 atendidos: todas as ferramentas anteriores acessíveis, contexto coerente
ao trocar de ferramenta e voltar, atacante e alvo distintos com a consequência atingindo o
alvo confirmado, validação no banco preservada (nenhuma regra ou fórmula de RPG alterada) e
nenhuma mudança de cor ou background.

**Sem migração nesta etapa.** O alvo viaja no `params` do pedido, que já é jsonb livre.

## Correção posterior (06/10/2026) — barra de grupos espremida

**Defeito apontado pelo autor:** com a coluna de ferramentas estreita, os nomes dos grupos
transbordavam e ficavam uns por cima dos outros. A causa era o `flex:1;min-width:20%` dos
botões, que forçava os 5 numa linha só. A coluna tem **298–318 px em todas as larguras de
desktop**, então o defeito aparecia de 900 px para cima e no celular (≤ 390 px); só a faixa
de 600–899 px escapava.

**Por que o teste desta etapa não pegou:** ele mediu corte horizontal da *página*, não se o
texto de cada *botão* cabia nele.

**Correção:** cada botão passou a ter a largura do próprio texto (`flex:1 1 auto;
white-space:nowrap`), e a fileira quebra em 2 linhas quando não cabe. Medido botão a botão
em 16 larguras (1920 a 360 px): nenhum texto cortado, nenhuma sobreposição, 44 px de altura.
São 2 linhas onde a coluna é estreita e 1 onde há espaço. As pílulas do segundo nível
também foram conferidas. A mesma medição, rodada no código anterior, acusou 13 das 16
larguras com problema.

