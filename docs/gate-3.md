# Gate 3 — Ponto 3: salvamento, reconexão e isolamento por mesa

Data: 06/10/2026 · Base: `main` @ `2845eb5` · Branch: `fix/ponto-3-persistencia`

## Reconciliação com o plano

Já resolvidos antes desta etapa: erro ao gravar ficha/seleção de ficha (Ponto 1) e leitura
que preserva o último estado em falha (etapa 2.1). O resto do Ponto 3 foi implementado aqui.

Achado mais grave da análise: o Mestre regravava o `session_state` inteiro **a cada ciclo
de polling (2 s)**, mesmo sem mudança, e ao abrir uma mesa o salvamento podia disparar antes
da leitura terminar — gravando o estado de outra mesa nela.

## Decisões aprovadas

1. Duas abas do Mestre: versão otimista. A aba que tenta gravar sobre versão mais nova é
   recusada, recarrega e mostra "Essa mesa foi alterada em outra aba, recarregamos a versão
   mais recente".
2. Armas, itens, ferimentos e condições pré-cadastrados acompanham a **conta** do Mestre
   (`profiles.master_library`), em qualquer mesa e dispositivo.
3. Mesa encerrada: o jogador vê "Mesa encerrada pelo Mestre" com "Sair" (encerra o vínculo
   só no navegador; o registro na mesa fica com o Mestre). Pausa volta sozinha ao retomar.

## Implementação

- Migração `supabase/migration_session_persistence.sql` (aplicada em 06/10/2026):
  `tables.session_version` + trigger que avança a versão em qualquer escrita (inclusive de
  cliente antigo); `tables.master_notes` (roteiro, narrativa, marcações — privado);
  `profiles.master_library`; `master_get_session`, `master_save_session`, `master_set_status`.
- `index.html`:
  - `activeTableId` explícito (nome só no fluxo de criação).
  - Salvamento só quando o conteúdo persistente muda, só na mesa ativa e só depois de ela
    carregar; espera de até 800 ms com teto de 4 s; nova tentativa com espera crescente.
  - Indicador na sessão: Alterações pendentes / Salvando… / ✓ Salvo / ⚠ Falha ao salvar /
    ⚠ Sem conexão, com "Tentar de novo".
  - Salvar progresso, pausar, encerrar, trocar de mesa, criar outra mesa e logout salvam e
    confirmam antes de concluir; fechamento da aba faz uma tentativa extra (keepalive).
  - Mesa pausada abre no lobby com "Retomar RPG" (passa pela guarda de aprovação).
  - Cache local e BroadcastChannel só para mesa sem conta, com chave/canal por mesa; a chave
    global antiga é apagada.
  - Vínculo do jogador por mesa (mapa) e por aba (`sessionStorage`).
  - Jogador acompanha pausa / encerramento / mesa indisponível; "Conexão instável —
    reconectando…" e "✓ Reconectado".
  - Ficha completa na mesa e mapeamento único wizard / Perfil / vínculo / `self`.
  - Biblioteca do Mestre na conta, semeada na primeira vez com o catálogo e com as chaves
    antigas do navegador (apagadas depois de salvas).
- `MLobby.dc.html`: rótulo do botão (Iniciar / Retomar).
- Testes: `supabase/tests/ponto3_tests.sql` e `supabase/tests/run_all.sh`.

## Ambiente

- SQL: Postgres 15 em Docker, Supabase simulado, 12 migrações em ordem, uma base por suíte.
- Navegador: Chrome via extensão, Supabase real. Mestre logado em `127.0.0.1:5510`,
  Jogadora A (Kara) visitante em `127.0.0.2:5510`, Jogador B (Rook) visitante em
  `localhost:5510` — origens distintas ⇒ armazenamento e sessão independentes. Mesas de
  teste "P3 Mesa A" (SV-Y5NX) e "P3 Mesa B" (SV-H85A).
- Wizard preenchido por estado e enviado pelo caminho real (`_finishPlayerWizard`); mestre
  conduzido pelos métodos reais do app. Falhas de rede e recusa do banco simuladas
  envolvendo `fetch` na página.
- A Economia de memória do Chrome congelava/descartava as abas de jogador em segundo plano
  (IDs trocando, "renderer frozen"); foi desligada para concluir os testes.

## Critérios de aceite

| # | Critério | Resultado |
|---|---|---|
| 1 | F5 do Mestre e dos jogadores recupera mesa, ficha e progresso | OK — Mestre: relógios, roteiro com marcações, narrativa, biblioteca, jogadores. Jogadores: painel, ficha completa |
| 2 | Roteiro, narrativa e marcações reaparecem em outro dispositivo | OK — navegador do Mestre limpo (só o login): tudo voltou do banco/conta |
| 3 | Duas mesas independentes, inclusive em duas abas | OK — duas abas do Mestre em mesas diferentes; banco confirma estados separados |
| 4 | Troca rápida de mesa não grava na mesa errada | OK — mudança em A + troca imediata: A salva antes; leitura de B atrasada 3 s: nenhuma gravação em B, tela vazia; cada mesa só com o que é dela |
| 5 | Queda de conexão mantém estado; reconexão não apaga nem duplica | OK — Mestre: "Sem conexão", mudança mantida, reenvio único (versão 4→5, relógio e log 1×). Jogador: estado preservado, "reconectando…" e "✓ Reconectado" |
| 6 | Salvamento recusado mostra erro e não confirma sucesso | OK — "⚠ Falha ao salvar"; "Salvar progresso" offline não marca salvo |
| 7 | Pausa e encerramento chegam aos jogadores; retomada respeita o status | OK — pausa: aviso no jogador; retomar pelo lobby: aviso some sozinho; encerrar: tela de encerramento, inclusive após F5 |
| 8 | Logout e saída encerram pollings | OK — jogador após "Sair": 0 chamadas em 10 s, vínculo apagado do navegador, registro mantido na mesa. Mestre: 6 chamadas/5 s antes, 0 em 10 s após logout, estado limpo |
| 9 | Histórico e campos da ficha sobrevivem à reconexão | OK — idade, origem, aparência, personalidade, marcas e histórico após F5 |
| 10 | Duas abas do Mestre não sobrescrevem silenciosamente | OK — aba 2 com versão 3 recusada (banco na 4), recarregou e avisou; banco manteve a mudança da aba 1 |
| 11 | Regressão dos Pontos 1 e 2 | OK — teste ida e volta (dados [17,4,6] iguais nos dois lados, log 1×), ferimento persistido, B vê só a gravidade, não recebe teste de A, roteiro nem histórico; SQL 52 + 73 + 24 |

Extras: com o Mestre parado 12 s, **0 gravações** (antes, uma a cada 2 s); várias mudanças
agrupadas numa gravação; roteiro/narrativa ausentes da resposta do jogador; biblioteca
gravada na conta e mesclada nas mesas.

**Sessão simulada (Gate 3):** Mestre + 2 jogadores na mesma mesa cobriram rolagem com ida e
volta, consequência, segredo privado (notas do Mestre e histórico fora da resposta dos
outros), desconexão (rede derrubada no Mestre e no jogador), pausa, retomada e encerramento.

Testes SQL: **52 + 73 + 24 + 32 = 181 asserções**, 0 falhas. Migração idempotente.

## Falhas encontradas e corrigidas durante o gate

1. Cache local gravava uma chave genérica mesmo sem mesa local, e a chave global antiga
   continuava no navegador → cache só com mesa local de fato; chaves antigas apagadas.
2. **Aviso de mesa pausada aparecia com o título "Inventário".** Os nomes `overlayTitle`
   /`overlayText` já existiam no render (modal do painel do jogador) e o valor posterior
   sobrescrevia o meu → campos renomeados (`tblOv*`).
3. Recusa do banco por dados inválidos entrava no ciclo de nova tentativa automática, que
   nunca teria sucesso → mostra que o banco recusou e espera "Tentar de novo".
4. Criar uma mesa nova com outra ativa e alterações pendentes trocava a mesa ativa sem
   salvar a anterior → agora salva antes (encontrado na revisão, antes do navegador).
5. Asserção minha no `ponto3_tests.sql` esperava erro em `select` de `anon` em `tables`, que a
   RLS apenas filtra → passou a verificar 0 linhas.

## Limitações conhecidas

- Conflito entre abas: a alteração da aba que perdeu precisa ser refeita (decisão aprovada).
- O salvamento no fechamento da aba é best-effort e ignora estados acima de ~60 KB (limite
  do keepalive); ações explícitas já gravam antes.
- Durante a sessão, cada jogador ainda faz 3 chamadas por ciclo de 3 s. Não foi consolidado.
- Inventário do jogador (`inventory`) continua só local no navegador do jogador:
  `session_state` é escrito apenas pelo Mestre. Pré-existente, fora do escopo.
- Notas antigas do navegador (roteiro/narrativa globais) são adotadas pela **primeira** mesa
  aberta sem notas; se o Mestre tinha várias mesas, só uma recebe o texto antigo.
- Abas em segundo plano: com a Economia de memória ligada, o Chrome pode congelar a aba do
  jogador; ao voltar para ela, o polling retoma e o estado é recuperado.
- Pré-existentes, não alterados: `advanceClock('c1')` sem relógio `c1`; perícia `analise`
  inexistente no rascunho; ferimento sugerido no combate vai para o atacante.

## Implantação

Migração já aplicada. O cliente deste branch **depende** dela (`master_get_session`). Basta
publicar o branch. Resíduos de teste: mesas "P3 Mesa A" e "P3 Mesa B" e seus membros.

## Validação

Todos os 11 critérios do Ponto 3 atendidos, com a sessão simulada do Gate 3. Regressão dos
Pontos 1 e 2 passando. Aguardando confirmação do responsável.
