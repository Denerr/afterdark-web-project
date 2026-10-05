# Gate 1 — Ponto 1: testes, rolagens, ferimentos e condições

Data: 05/10/2026 · Branch: `fix/ponto-1-testes-consequencias`

## Implementação
- Migração: `supabase/migration_requests_consequences.sql` (aplicada no Supabase em 05/10/2026).
- Código: `index.html`, `MLobby.dc.html`, `JLobby.dc.html`.
- Testes SQL: `supabase/tests/ponto1_tests.sql` (Postgres 15 local, ambiente Supabase simulado).
- Decisões: token secreto por membro (hash no banco); transporte por polling (2–3 s);
  relógio avança só no Mestre; aprovação obrigatória para todos os jogadores.

## Ambiente do teste de aceite
- Mestre: Chrome, conta real logada, origem `http://127.0.0.1:5510`.
- Jogador A (Kara): visitante, origem `http://127.0.0.2:5510`.
- Jogador B (Rook): visitante, origem `http://localhost:5510`.
- Origens diferentes ⇒ `localStorage`, sessão Supabase e BroadcastChannel independentes.
- Supabase real; mesa de teste "TESTE Ponto1 Gate" (SV-7NYJ).
- Abas de jogador em segundo plano: Anime.js desligado nelas (`window.anime=null`) e
  cliques disparados via DOM, porque o Chrome congela rAF/timers de abas ocultas.

## Critérios de aceite
| # | Critério | Resultado |
|---|---|---|
| 1 | Teste para A chega a A e não a B | OK — tela e resposta da API de B sem solicitações |
| 2 | Rolagem de A chega ao Mestre com dados/fórmula/resultado | OK — dados [2,11,6], 11 vs 15, Falha idênticos nos dois lados |
| 3 | Dois testes não se sobrescrevem; repetição não duplica | OK — fila (+1 na fila); clique duplo = 1 rolagem; 2ª resposta via API = `duplicate:true`, original preservado |
| 4 | Geral e combate completam ida e volta | OK — geral e combate (erro e acerto); acerto gera sugestão de ferimento aplicada |
| 5 | Sem alvo válido, envio bloqueado sem erro | OK — botão desabilitado com motivo; nenhuma solicitação criada; banco recusa alvo sem ficha/fora da mesa |
| 6 | Ferimento/condição persistem após polling e F5 | OK — após ciclos de polling, F5 do Mestre e F5 de A |
| 7 | Ficha do jogador mostra consequências; remoção persiste | OK — "Abalado · Ferimento Moderado" em A; remoção chega a A |
| 8 | Consequências de A não aparecem em B | OK |
| 9 | Prontidão/aprovação persistem; guarda de início | OK — aprovação sobrevive a F5; início bloqueado na tela e no banco (`players_not_approved`) até todos aprovados |
| 10 | Falha de rede sem falso sucesso; retry não duplica | OK — Mestre: erro exibido, retry com mesma chave (4 registros, não 5). Jogador: resultado guardado, "Reenviar"; após F5 reenviado sem nova rolagem e registrado 1 vez |
| 11 | Cadastro, login, ficha, convite, lobby | OK para login, ficha, convite, lobby e retomada por F5. Cadastro e personagem do Perfil não foram alterados (diff sem mudanças nesses trechos); cadastro não testado no navegador |

Testes SQL: 51/51 asserções; migração idempotente (executada duas vezes).

## Falhas encontradas e corrigidas durante o gate
1. "Continuar" numa mesa ainda não iniciada abria a sessão direto, contornando o lobby e
   a guarda → agora abre o lobby.
2. Card "Sua ficha" no lobby do jogador mostrava "✓ Pronto" fixo → mostra
   Aprovado / Aguardando aprovação / Ficha pendente.
3. Resultado do jogador sumia em ~3 s quando havia outro teste na fila → fica visível
   ~6 s antes de abrir o próximo.
4. (Observação da revisão) Notificação do jogador ficava na tela após o teste ser
   cancelado ou executado → cancelado: vira "Teste cancelado pelo Mestre", sem botões, e
   some em ~4,5 s (o próximo da fila só abre depois); executado: some ao rolar e quando a
   resposta é confirmada. Validado no navegador: cancelamento simples, rolagem com a
   notificação aberta e cancelamento com outro teste na fila.

## Limitações conhecidas (escopo dos próximos pontos)
- Leituras antigas ainda abertas (`members_select_all`, `get_table_session_state`) → Ponto 2.
- Visitante que perde o `localStorage` perde o vínculo e precisa reentrar pelo código.
- Rolagem calculada no cliente do jogador (regra preservada; anti-trapaça fora do ciclo).
- Log da sessão persiste via `session_state` com salvamento sem confirmação → Ponto 3.
- Pré-existente, não alterado: `advanceClock('c1')` registra "Um relógio avançou" mesmo
  sem relógio `c1`; rascunho padrão de teste usa perícia `analise`, que não existe na
  lista (bônus 0); no combate o ferimento sugerido vai para o próprio atacante.
- Ao aplicar a migração antes do deploy, o site publicado não consegue salvar a ficha do
  jogador (o trigger bloqueia o update direto antigo) → fazer o deploy deste branch.

## Validação
Todos os critérios aplicáveis do Ponto 1 atendidos. Aguardando confirmação do
responsável para iniciar o Ponto 2.
