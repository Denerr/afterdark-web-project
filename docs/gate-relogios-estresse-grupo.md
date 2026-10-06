# Gate — Relógios, estresse e grupo no painel dos jogadores

Data: 06/10/2026 · Base: `main` @ `13f1ef9` (Ponto 2 concluído e publicado)

## Reconciliação do plano com o código

O plano foi escrito sobre `951b8c9`, antes do Ponto 2. A **Etapa 2.1 já estava quase toda
entregue** por ele:

| Item da 2.1 | Situação ao começar |
|---|---|
| Usar `memberId` real, remover o ID fixo `p2` | **Feito** no Ponto 2 (`selfId`, `stressDraft`, `clockDraft`) |
| RPC de leitura que valida conta/token e deriva a mesa do membro | **Feito** (`player_get_session`, `player_get_lobby`) |
| Projeção com lista explícita de campos, sem cópia integral do JSON | **Feito** |
| Fechar as leituras antigas permissivas | **Feito** (3 funções removidas, grant de `anon` revogado) |
| Não devolver tokens nem `char_data` integral de colegas | **Feito** |
| **Preservar último estado válido em falha e sinalizar reconexão** | **Faltava** — implementado aqui |

O que sobrou da 2.1, portanto, foi só o item de resiliência — que virou pré-requisito real:
com relógios na tela do jogador e polling de 3 s, uma falha de leitura apagava os relógios.

## Etapa 2.1 — Leitura resiliente

`_loadTableSession` passou a distinguir três situações: **sucesso**, **ausência confirmada**
de dados e **falha de leitura**. Em falha, preserva o último estado válido e liga
`sessionStale`, que a seção Relógios mostra como "Reconectando…". Estado vazio só entra
quando o banco confirma que a mesa não tem estado. Também descarta resposta atrasada de
outro vínculo, comparando o contexto antes e depois do `await`.

**7/7 asserções** (falha preserva, sinaliza, reconecta, limpa aviso, ausência confirmada
zera, resposta atrasada descartada).

## Etapa 2.2 — Relógios abaixo do mapa

Dois defeitos reais na lógica de visibilidade, encontrados ao implementar:

1. **`revealClock` destruía o escopo individual.** Alternava entre `todos` e `mestre`, então
   revelar um relógio de personagem o tornava **público para a mesa**. Agora revelar devolve
   o relógio ao seu público — mesa ou titular.
2. **Os gatilhos `avancar` e `completar` nunca disparavam.** `createClock` gravava
   `vis:'mestre'` e nada reavaliava. Agora `advanceClock` dispara uma vez e marca
   `revealDone`: reduzir depois não volta a ocultar, e uma ocultação explícita do Mestre não
   é desfeita por avanço posterior.

Também: normalização de relógio antigo/inválido preservando `id`, `fill`, `seg`, titular e
estado de revelação; rótulos do Mestre distinguindo público / individual / oculto (antes
havia só "Visível a todos" vs "Oculto"); aviso quando um relógio individual está sem
titular, caso em que não chega a ninguém.

Interface: seção **Relógios imediatamente abaixo do mapa**, na visualização Mapa, em grade
`auto-fill` que quebra em linhas no desktop e empilha no celular. Card com nome, tipo,
anel segmentado e progresso textual (`3/6`); relógio individual rotulado "Seu personagem".
Nenhum controle de avançar/reduzir/revelar/excluir. A seção inteira desaparece quando não há
relógio permitido — não anuncia a existência de relógios secretos. Destaque discreto uma vez
por alteração confirmada, respeitando `prefers-reduced-motion`.

**13/13 (interface)** e **14/14 (lógica)**.

## Etapa 2.3 — Barras de estresse

Modelo de visibilidade novo: `todos` | `titular` | `mestre`, com seletor no formulário do
Mestre e troca por clique na barra. Barra antiga sem o campo assume **`titular`** — padrão
conservador pedido pelo plano.

**Mudança de comportamento registrada:** antes, barra sem titular (`playerId` vazio) era
tratada como "da mesa". Agora ela só é pública se o Mestre marcar `todos`. A tela avisa
quando uma barra `titular` está sem titular, caso em que não chega a ninguém.

Vazamento corrigido: a barra carregava o `clockId` de um relógio oculto do Mestre. O nome
não aparecia na tela, mas o identificador chegava ao navegador. Agora o banco **remove a
chave** `clockId` quando o relógio não é visível ao destinatário.

Validação de `max` e `level` (positivo, dentro dos limites) na normalização.

**24/24 (SQL)** e **15/15 (interface)**.

## Etapa 2.4 — Grupo

Seção **Grupo** na coluna direita do painel do jogador, irmã de Testes e Diário — os
relógios ficam onde estão, abaixo do mapa. No desktop aparece junto das outras caixas; no
celular é alcançada pelo menu do jogador (`Grupo` entrou em `menuKeys` nas duas larguras).

Card: inicial como avatar, nome do personagem, nome de exibição, "Você" no próprio card e
saúde resumida. Clicar abre o **resumo público inline** — não o modal de ficha do Mestre —
com Natureza, gravidade dos ferimentos, condições e barras públicas de estresse.

Decisões de privacidade:

- **Ferimento vai por gravidade, não por descrição.** O plano pede "categoria/gravidade
  autorizada sem copiar descrições secretas"; a decisão anterior do Ponto 2 foi "colegas
  veem ferimentos". Conciliei: `player_get_lobby` devolve dos colegas só `id` e `lvl`, e o
  card mostra "Ferimento grave". Ferimento personalizado vira a categoria genérica
  "Ferimento". A **própria** ficha segue inteira, por `player_get_state`.
- **Avatar é sempre a inicial.** O mapeamento de foto por nome existente (`photoMap`) casa
  o personagem da mesa com um personagem salvo do usuário logado — coincidência de nome
  cruzaria fichas de pessoas diferentes. A seção Grupo não usa isso.
- **Nenhum "Online".** Vínculo na mesa não é presença e não há heartbeat.
- Cards não oferecem aprovar, remover nem alterar nada.

O resumo aberto é guardado por **ID do membro**, não pelo objeto, então o polling troca a
lista a cada ciclo sem fechar o resumo.

**20/20.**

## Ambiente e divisão dos testes

- **SQL (Postgres 15 em Docker, Supabase simulado):** prova a filtragem **no servidor** —
  quem recebe cada relógio, cada barra, e a limpeza do vínculo e do ferimento.
- **Navegador (Chrome via Playwright, 3 origens independentes):** prova a **interface** —
  posição abaixo do mapa, ausência de controles, estados vazios, responsividade a 390 px,
  resumo do grupo, menu no celular — injetando o estado já filtrado que o servidor enviaria.

Essa divisão foi deliberada: a migração nova só vai para produção no fim deste ciclo, então
o teste de navegador não podia depender dela. O que o navegador verifica não é a autorização
(isso é o SQL), e sim o que a tela faz com uma resposta já autorizada.

| Suíte | Resultado |
|---|---|
| `ponto1_tests` (regressão) | **52/52** |
| `ponto2_tests` (regressão) | **73/73** |
| `ponto2b_tests` (novo) | **24/24** |
| Navegador 2.1 / 2.2 / 2.2b / 2.3 / 2.4 | **7 / 13 / 14 / 15 / 20** |
| **Total** | **218 asserções, 0 falhas** |

`migration_player_projection.sql` aplicada três vezes sem erro. `index.html` validado com
`node --check`.

## Falhas encontradas e corrigidas durante o gate

1. `STRESS_VIS` escrito como `chave: valor,` dentro do corpo da classe — campo de classe
   exige `=` e `;`. Erro meu, pego pelo `node --check`.
2. **O painel Grupo não renderizava.** Minha âncora de inserção casou o `</sc-if>` do modal
   de overlay, não o da coluna direita: o bloco ficou dentro de `overlayOpen` e só apareceria
   com um modal aberto. O diagnóstico demorou porque o template-fonte continua no HTML, então
   procurar o marcador em `outerHTML` dava falso positivo. Bloco movido para dentro de
   `showRightCol`.
3. Regressão no `ponto2_tests`: a asserção "Ana vê os ferimentos da Bia" checava a
   **descrição** do ferimento, que a nova projeção não envia. Atualizada para afirmar que a
   colega vê a **gravidade**, que **não** vê a descrição, e que a titular continua vendo o
   texto — registrando o refinamento em vez de escondê-lo.
4. Três defeitos dos meus próprios testes: `innerText` aplica `text-transform:uppercase`
   (comparações passaram a ignorar caixa); a chave de estado da ferramenta do Mestre é
   `masterTool`, não `tool`; e eu afirmava que o cabeçalho do jogador mostra "sem relógio"
   nas barras, quando ele **não exibe vínculo de relógio nenhum** — mais restritivo que o
   exigido. Uma dessas asserções estava passando por motivo errado (o nome do relógio vinha
   da seção Relógios, não da barra).

## Ordem de implantação

Diferente do Ponto 2, **a ordem aqui é livre**. `migration_player_projection.sql` só
substitui duas funções; não altera tabela, policy nem grant. O cliente funciona antes e
depois dela: sem a migração, a filtragem de estresse e a limpeza do ferimento acontecem só
no navegador; com ela, acontecem no banco. Não há janela em que o site fique quebrado.

Ainda assim, aplicar a migração é o que move a garantia do cliente para o servidor — sem
ela, um jogador que inspecione a resposta da API ainda vê barras `titular` de colegas e a
descrição dos ferimentos.

## Limitações conhecidas

- **Nenhuma sessão real com Mestre e dois jogadores foi executada neste ciclo.** O fluxo
  ponta a ponta contra o Supabase real foi validado no Gate 2; aqui os testes de navegador
  injetam estado. Vale uma sessão de conferência depois do deploy, sobretudo para ver o
  destaque do relógio avançando ao vivo e o Grupo atualizando entre dispositivos.
- Durante a sessão, cada jogador faz 3 chamadas por ciclo de 3 s (`player_get_session`,
  `player_get_state`, `player_get_lobby`). Aceitável nesta escala; é tema do Ponto 3 junto
  com a estratégia de transporte.
- A visibilidade de teste (`testDraft.vis`) continua sem interface — sempre `publico`.
- O relógio individual sem titular escolhido não chega a ninguém. A tela avisa, mas o
  `select` não semeia um padrão a partir da lista de jogadores.
- "Pedir ajuda" / interação direta entre jogadores não foi implementada — o plano a coloca
  explicitamente fora deste pacote.
- `index.html:2945` (`WEAK[w.sens].map`) e `index.html:2974` (`THEME[n.theme].acc`) seguem
  sem guarda contra chave desconhecida. Não alcançáveis pela interface; registrado no Gate 2.

## Validação

Aceites 2.1 a 2.4 atendidos, com as duas mudanças de comportamento registradas acima
(barra sem titular; ferimento por gravidade). Regressão dos Pontos 1 e 2 passando.

**Pendente:** aplicar `migration_player_projection.sql` e publicar o `index.html`.
