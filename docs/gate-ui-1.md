# Gate UI 1 — Painel do jogador

Data: 06/10/2026 · Base: `main` @ `acc7d90` · Branch: `ui/etapa-1-jogador`
Plano: `Afterdark_Plano_Atualizacao_UI_UX.md`, Etapa 1. Só `index.html`; sem migração.

## Decisões gerais do plano (aprovadas)

- Descrições de perícias por **grupo de atributo**, com o texto fornecido pelo responsável (Etapa 4).
- Combate ganha **campo de alvo** salvo no próprio pedido; ferimento sugerido vai para o alvo (Etapa 3).
- Sem combinações cruzadas atributo × perícia (Etapa 5).
- Ordem 1 → 7; Etapa 4 já deixa o catálogo pronto para a 5.

## O que mudou

| Antes | Depois |
|---|---|
| Grid de 3 colunas fixas `320px · 1fr · 340px`; mapa com ~1/3 da largura | `1fr · minmax(300px,360px)`; a coluna da ficha saiu do grid e o mapa ganhou a largura dela |
| Ficha completa ocupando a coluna esquerda inteira | **Resumo** no cabeçalho (nome, Natureza, saúde/condições, barras próprias de estresse, 6 atributos) + **painel "Ficha completa"** com atributos, perícias, fraquezas, estado e identidade (idade, origem, aparência, roupas, personalidade, manifestação, marcas, histórico — só campos preenchidos) |
| Testes, Diário e Grupo empilhados na lateral | **Abas** Testes / Grupo / Diário; selo com a quantidade de testes pendentes na aba Testes |
| NPCs e Inventário só pelo menu flutuante | Botões NPCs / Pistas / Inventário no resumo (mesmos painéis e permissões); menu continua |
| Menu do desktop sem Ficha/Testes/Diário | Menu com todas as áreas; no desktop Testes/Grupo/Diário abrem a aba, no celular continuam em foco |
| Histórico "Kara Valéria Montenegro · Instint…" truncado | Sem o próprio nome; texto inteiro no `title` |

Preservados: cores, fundos, fontes e animações; relógios **imediatamente abaixo do mapa** com
a mesma filtragem; notificação de teste ("Abrir teste" / "Depois"); fila; cancelamento;
reenvio; overlays de NPCs/Inventário.

Notificação e foco: um teste novo **não troca a aba** — aparece a notificação e o selo na aba
Testes. "Abrir teste" (notificação ou chip "teste pendente") é a ação explícita que abre a aba.

## Testes (Chrome, Supabase real)

Mesa "UI Etapa 1" (SV-VCD9). Mestre logado (127.0.0.1), Kara visitante (127.0.0.2, ficha
completa), Rook visitante (localhost, ficha mínima). Relógios: 2 da mesa, 1 secreto do
Mestre, 1 pessoal da Kara. Estresse da Kara: um público, um só do titular. Ferimento e
condições aplicados. Dois testes na fila.

| Critério | Resultado |
|---|---|
| Mapa utilizável com ficha, Grupo e teste preenchidos | OK — mapa ~2/3 da largura (antes ~1/3) |
| Abas preservam seleção, rascunhos e resultado durante polling | OK — rolagem iniciada em Testes, troca para Grupo durante a animação: resultado enviado (Mestre recebeu "Sucesso Parcial"), aba Grupo e card do Rook continuaram abertos após vários ciclos |
| Teste pendente perceptível sem interromper | OK — novo teste com Kara na aba Grupo: notificação + selo "1"; aba não mudou |
| Fila, cancelamento e reenvio | OK — fila "+1 na fila" e selo 2→1; cancelamento com Kara em Grupo: "Teste cancelado", selo some, aba não muda; falha simulada no envio com troca para Diário: "Reenviar resultado" disponível ao voltar, reenvio com **os mesmos dados** ([8]), Mestre com o resultado e log 1× |
| Relógios abaixo do mapa e privacidade | OK — Kara: 2 da mesa + "Fome de Kara"; Rook: só os 2 da mesa; nenhum vê o secreto |
| Ficha completa sem exposição a colegas | OK — Rook não recebe nem renderiza "Paranoia", "Fome de Kara", fraquezas ou histórico da Kara; a ficha dele mostra só os próprios campos (vazios omitidos) |
| Cores e backgrounds | OK — nenhum valor de cor/fundo novo; reutilizados os do painel |

Celular (modo estreito simulado — a janela do Chrome não aceitou redimensionar): menu abre
Grupo/Testes/Diário em foco, Ficha abre o painel, Mapa volta; sem corte horizontal.

Prints: antes/depois na mesma janela (topo, relógios e painel da ficha), anexados na conversa.

## Limitações / para as próximas etapas

- No celular o resumo fica alto (atributos e botões quebram linha) → Etapa 2.
- Foco "Grupo" no celular ainda sem "← Voltar" (previsto na Etapa 2).
- O menu flutuante cobre o canto inferior direito do conteúdo da lateral → Etapa 2.
- O título interno "⚄ Testes" repete o nome da aba; mantido para o celular, onde não há abas.
- Aba escolhida não sobrevive ao F5 (volta para Testes).
