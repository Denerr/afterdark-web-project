# Afterdark — Matriz de acesso (Ponto 2)

Referência de quem pode ler e escrever o quê. Vale a partir de `migration_rls_p2.sql`.

## Papéis

| Papel | Como é identificado |
|---|---|
| **Dono / Mestre** | `auth.uid() = tables.owner_id`. Checado por `_ad_is_owner(table_id)`. |
| **Jogador autenticado** | Linha em `table_members` com `user_id = auth.uid()`. |
| **Visitante (sem conta)** | Linha em `table_members` + token secreto entregue por `join_table_by_code`. O banco guarda só o SHA-256 em `table_member_secrets`. Checado por `_ad_member_ok(member_id, token)`. |
| **Não vinculado** | Qualquer outro. Sem acesso a dados de mesa. |
| **Espectador** | **Não implementado nesta etapa.** `&obs=1` na URL é só navegação no cliente e **não** concede autorização alguma. |

Jogador autenticado e visitante têm exatamente os mesmos direitos — a diferença é só a forma de provar identidade. Daqui em diante, "jogador" cobre os dois.

## Acesso direto às tabelas (RLS)

| Tabela | Dono / Mestre | Jogador | Não vinculado |
|---|---|---|---|
| `tables` | CRUD das próprias (inclui `master_notes` e `session_version`) | — | — |
| `table_members` | select / update / delete da própria mesa | — | — |
| `table_requests` | select / update da própria mesa | — | — |
| `table_member_secrets` | — | — | — |
| `characters` | CRUD dos próprios (por `owner_id`) | idem | — |
| `profiles` | só o próprio (inclui `master_library`) | só o próprio | — |

Nenhuma tabela tem policy de `insert` para `table_members` ou `table_requests`: entrar na mesa e criar solicitação acontecem **só por função**. `table_member_secrets` não tem policy nenhuma e está revogada de `anon` e `authenticated` — é inacessível pela API.

## Funções (todas `security definer`, `search_path` fixo)

### Jogador — exigem `member_id` + token (ou `auth.uid() = user_id`)

| Função | Devolve / faz |
|---|---|
| `join_table_by_code(code, nome)` | Cria o membro e devolve o **token uma única vez**. |
| `player_get_state(member_id, token)` | Ficha **do próprio** membro, status da mesa e as solicitações dirigidas a ele. |
| `player_get_lobby(member_id, token)` | Status da mesa + visão pública dos membros (ferimento só por gravidade). |
| `player_get_session(member_id, token)` | `session_state` **filtrado** (ver abaixo). |
| `player_answer_request(...)` | Responde uma solicitação própria; só a primeira resposta vale. |
| `player_submit_sheet(...)` | Grava a própria ficha; zera aprovação anterior. |
| `player_set_ready(...)` | Prontidão própria. |
| `player_leave_table(member_id, token)` | Remove a própria participação. |

### Mestre — exigem ser dono da mesa

`master_create_request`, `master_ack_request`, `master_cancel_request`, `master_member_consequence`, `master_set_approval`, `master_start_session`. Concedidas só a `authenticated`.

Ponto 3 (`migration_session_persistence.sql`):

| Função | Devolve / faz |
|---|---|
| `master_get_session(table_id)` | `session_state`, `master_notes`, `session_version` e status, numa leitura. |
| `master_save_session(table_id, estado, notas, versão_base)` | Grava só se `session_version = versão_base`; senão devolve `{conflict:true}` sem gravar. `notas = null` preserva as notas. |
| `master_set_status(table_id, status)` | Só `Pausada · retomar depois` ou `Encerrada`. Retomar passa por `master_start_session` (guarda de aprovação). |

O trigger `_ad_tables_version` avança `session_version` em **qualquer** escrita de
`session_state`/`master_notes`, inclusive por um cliente antigo que grave direto — assim
a escrita dele é detectada como conflito pelo cliente novo, e não sobrescrita.

### Auxiliares fechadas

`_ad_hash`, `_ad_member_ok`, `_ad_is_owner`, `_ad_member_table`, `_ad_members_guard` — revogadas de `public`, `anon` e `authenticated`.

## Separação de conteúdo

O `session_state` é um JSON único escrito pelo Mestre. O jogador **nunca** recebe o documento inteiro: `player_get_session` monta a resposta no banco, campo por campo.

| Conteúdo | O que o jogador recebe |
|---|---|
| `clocks` | Só `vis = 'todos'`, mais os `vis = 'jogador'` com `playerId` igual ao próprio membro. `vis = 'mestre'` não sai do servidor. |
| `npcs` | Só `reveal >= 3`. Abaixo disso a linha não é enviada — nem borrada. |
| `clues` | Só `status <> 'oculta'`. |
| `stressBars` | Por visibilidade, não por titularidade — ver a tabela abaixo. O `clockId` é **removido** quando aponta para um relógio que o destinatário não pode ver. |
| `log` | Só entradas com `vis = 'todos'` ou `vis = <próprio member_id>`. |
| `scene`, `inventory`, `library` | Íntegros — são o conteúdo público da mesa. |
| `master_notes` (roteiro, narrativa, marcações) | **Nada.** Fica em coluna própria de `tables`; nenhuma função de jogador lê essa coluna. |

### Visibilidade no log

Cada entrada carrega `vis`:

| Valor | Quem vê |
|---|---|
| `'todos'` | Mesa inteira |
| `'mestre'` | Só o Mestre |
| `<member_id>` | Aquele jogador e o Mestre |
| **ausente** | Tratada como `'mestre'` — **log legado não vaza para jogadores** |

Resultado de teste herda a visibilidade do próprio teste (`params.vis`): `publico` → `todos`, `jogador` → o destinatário, `mestre` → só o Mestre. Ver `_logVis()` no cliente.

### Visibilidade dos relógios

Um relógio separa **a quem pertence** de **quem pode ver**:

| `visMode` (intenção do Mestre) | `vis` enquanto oculto | `vis` ao revelar | Quem vê revelado |
|---|---|---|---|
| `todos` / `parcial` | — | `todos` | mesa inteira |
| `jogador` | — | `jogador` | só o titular (`playerId`) |
| `mestre` | `mestre` | `todos` ou `jogador` | conforme o escopo |
| `avancar` | `mestre` | idem, no primeiro avanço | conforme o escopo |
| `completar` | `mestre` | idem, ao completar | conforme o escopo |

`revealDone` marca que a revelação já foi resolvida. Um gatilho dispara **uma vez** e fica:
reduzir o relógio depois não volta a ocultá-lo, e uma ocultação explícita do Mestre não é
desfeita por um avanço posterior. Revelar um relógio individual devolve ele ao **titular**,
não à mesa — antes, revelar tornava qualquer relógio público.

Um relógio marcado como individual **sem titular escolhido** não chega a ninguém (o Mestre
continua vendo, porque lê o estado sem filtro). A tela do Mestre avisa.

### Visibilidade das barras de estresse

| `vis` | Mestre | Titular | Outro membro |
|---|---|---|---|
| `todos` | Sim | Sim | Sim |
| `titular` | Sim | Sim | Não |
| `mestre` | Sim | Não | Não |
| **ausente** (barra antiga) | Sim | Sim | Não — tratada como `titular` |

Barra `titular` sem titular não chega a ninguém. Isso **muda** o comportamento anterior, em
que uma barra sem dono valia como "da mesa": agora só é pública se o Mestre marcar `todos`.

### Grupo: o que um colega vê

| Campo | Chega ao colega |
|---|---|
| Nome do personagem, nome de exibição, Natureza | Sim |
| Saúde resumida (Saudável / Abalado / Ferido) | Sim |
| Ferimentos | Só `id` e **gravidade**; a descrição escrita pelo Mestre não sai |
| Condições | Sim (são rótulos curtos, já categorias) |
| Barras de estresse | Só as marcadas `todos` |
| Atributos, perícias, fraquezas, histórico | Não |
| Foto | Não — o avatar é sempre a inicial |

O avatar nunca procura foto por coincidência de nome: casar o nome do personagem da mesa
com um personagem salvo cruzaria a ficha de pessoas diferentes.

Os cards são de consulta: não oferecem aprovar, remover, alterar condição nem mexer em
barras. Não existe indicador "Online" — vínculo na mesa não é presença, e não há heartbeat.

### Visível à mesa por decisão de produto

Ferimentos e condições de **todos** os membros aparecem para todos os jogadores — é informação de jogo. O que **não** sai para terceiros é o resto da ficha: atributos, perícias, fraquezas e histórico, e a **descrição** do ferimento, que o Mestre escreve e pode ser narrativa reservada (o colega vê a gravidade; o titular vê o texto, por `player_get_state`). `player_get_lobby` devolve de cada colega apenas `id`, `player_name`, `char_name`, `status`, `char_data.sens`, `wounds` (só `id` e `lvl`), `conditions`, `sheet_ready` e `approved_at`.

## Fora de escopo nesta etapa

- **Espectador** como papel autorizado.
- **Realtime**: o transporte continua sendo polling. Realtime exigiria RLS por `auth.uid()`, e visitante não tem identidade de auth — precisaria de autenticação anônima do Supabase.
