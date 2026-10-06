# Gate UI 2 — Responsividade e navegação

Data: 06/10/2026 · Base: `ui/etapa-1-jogador` @ `f04ba7f` · Branch: `ui/etapa-2-responsivo`
Arquivos: `index.html`, `JWizard.dc.html`, `css/styles.css`. Sem migração.

## O que mudou

**Faixas de largura** (antes: só "< 900 px" ou não):

| Faixa | Jogador | Mestre | Menu superior |
|---|---|---|---|
| ≥ 1280 | mapa + lateral (300–360 px) | 3 colunas (268 · 1fr · 320) | completo, com breadcrumb |
| 1100–1279 | mapa + lateral (280–320 px) | **Jogadores ⇄ Cena por abas** + Ferramentas fixas (300 px) | completo, sem breadcrumb |
| 900–1099 | idem | idem | **compacto** (☰) — os botões completos estouravam a tela em 900 px |
| < 900 | uma área + barra inferior | uma área com abas Jogadores / Cena / Ferramentas | compacto |

**Celular (jogador):**
- Barra inferior fixa **Mesa · Ficha · Grupo · Testes · Mais**, com seção ativa marcada
  (traço dourado + `aria-current`) e selo de testes pendentes. "Mais" abre Cena, Diário,
  NPCs, Pistas e Inventário acima da barra. O botão flutuante fica só no desktop.
- Retorno padronizado: Testes, **Grupo** (antes sem retorno) e Diário mostram "← Mesa" +
  título da seção. Ficha, NPCs e Inventário fecham com "✕ Fechar".
- Espaço reservado no fim da página para a barra + safe area (`viewport-fit=cover`,
  `env(safe-area-inset-bottom)`); com campo de texto em foco a barra sai da frente.
- Resumo do personagem compacto (avatar 44 px, nome 18 px); os botões de acesso ficam na
  barra inferior.

**Toque e teclado:** alvos de ≥ 44 px em Mapa/Cena, abrir/adiar teste, reenviar, fechar,
itens do menu, abas do Mestre, botões do menu compacto e ± das perícias. Foco visível
(contorno no dourado já usado no tema) para teclado.

**Wizard:** perícias em colunas que se ajustam (1 coluna no celular; antes 2 fixas
estouravam 390 px); Idade/Origem encolhem (antes o campo Origem passava da tela).

## Testes

Larguras exatas verificadas com o app em iframes da mesma origem (a janela do Chrome tem
escala, então redimensionar não dá a largura exata). Corte horizontal = elemento fora da
largura que não está dentro de um contêiner com rolagem.

| Verificação | Resultado |
|---|---|
| Jogador em 1440, 1280, 1279, 1024, 900, 899, 768, 390 — base + Grupo, Testes, Diário, Ficha, Pistas | Sem corte (antes: "Cadastrar" saía 6 px em 900) |
| Mestre em 390, 900 e 1024 — Jogadores, Cena, Ferramentas | Sem corte |
| Landing, Perfil, Papel, Lobby do Mestre, Entrar, Início em 390/768/1024 | Sem corte |
| Wizard, 7 passos em 390 (nome longo, fraqueza longa) | Sem corte (antes: passos 1 e 5 cortavam) |
| Barra inferior não cobre conteúdo | OK — último bloco termina em 696 px, barra começa em 721 px |
| "Mais" acima da barra | OK — último item termina em 715 px |
| Teclado virtual | OK — campo em foco: barra some; ao sair: volta |
| Retorno consistente | OK — Grupo, Testes e Diário com "← Mesa"; Mesa limpa a seção |
| Somar/remover pontos no wizard com os novos botões | OK |
| Regressão | Mestre recarregado: 4 relógios, 2 barras, "✓ Salvo", sem conflito; teste "Corpo + Atletismo" enviado, Kara rolou, resultado recebido |
| Cores e fundos | Inalterados; o contorno de foco usa `#e0c179` (dourado existente) |

## Ocorrência durante o teste (anterior a esta etapa)

A aba da Kara (127.0.0.2) foi retomada uma vez em uma mesa antiga ("TESTE Ponto1 Gate"),
porque o navegador ainda guardava o vínculo dela do Gate 1. A explicação mais provável é
uma corrida: ao abrir a página, a retomada automática do vínculo antigo terminou **depois**
que entrei na mesa nova pelo código, e sobrescreveu a escolha da aba. Depois de apontar a
aba para a mesa certa, F5 manteve o vínculo correto. Não alterei esse fluxo (Ponto 3);
proponho tratar na Etapa 6 (continuidade): ignorar o resultado da retomada se outro
vínculo for escolhido enquanto ela estava em andamento.

## Limitações

- Relógios do Mestre e mapas continuam com altura fixa (440 px), como antes.
- Campos de texto com `outline:none` inline mantêm só a borda como indicação de foco.
- Testado com 2 condições por personagem; muitas condições quebram linha normalmente.
