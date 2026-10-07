# Gate UI 7 — Entrada, lobby e conta

Data: 06/10/2026 · Base: `main` @ `fee0b62` (UI 6 em produção)

Sem migração: tudo é cliente.

## O que mudou

### 7A Entrada pública

As duas ações da página inicial ("Entrar na Mesa", que levava a uma escolha de papel, e
"Tenho um código") concorriam e quase repetiam o mesmo caminho. Agora são **dois destinos
distintos**, mantendo os mesmos estilos, a arte, o logo e o fundo:

| Botão | Destino |
|---|---|
| **Entrar com código** (principal) | direto à tela do código |
| **Criar ou acessar minhas mesas** | com conta: lista de mesas do Perfil; sem conta: começa uma mesa nova (o Mestre pode jogar sem conta neste aparelho) |

O texto da conta deixou de dizer "só para salvar suas mesas": agora diz que **ela guarda
seus personagens e suas mesas** para continuar em qualquer dispositivo, e ganhou o atalho
"Já tem conta? Entrar".

### 7B Lobby do Mestre

Um resumo logo abaixo do título diz **o que falta para iniciar**:

- **Aprovados X de Y**;
- **Ficha concluída, aguardando sua aprovação: N**;
- **Ainda sem ficha: N**;
- **Tudo pronto para iniciar**, quando é o caso.

É só leitura. A guarda real continua no banco (`master_start_session`) e em
`_startGate`, ambos inalterados; o teste confirma que o início segue bloqueado.

### 7C Lobby do jogador

"Ficha concluída" e "aprovada pelo Mestre" voltaram a ser estados **distintos** também
para o jogador. Antes, a ficha concluída aparecia só como "Aguardando aprovação". Agora:

- a própria ficha: "Ficha concluída · aguardando o Mestre" → "✓ Aprovada pelo Mestre";
- os colegas: "Ficha concluída · aguardando o Mestre" / "Aprovado pelo Mestre".

### 7D Perfil · Mesas

- **Prioridade:** as mesas aparecem em seções. **"Em jogo · continue de onde parou"**
  (em andamento antes de pausada) vem no topo, depois **"Outras mesas"**, depois
  **"Arquivadas (N)"**, recolhida mas a um clique.
- **Ação principal por status:** "Continuar" (destacado) para mesa em jogo, "Abrir lobby"
  para mesa aguardando jogadores, "Abrir" para as demais. O fluxo de retomada
  (`openTable`) é o mesmo.
- **"Continuar" virou botão.** Era um `<span>`, inalcançável pelo teclado. Agora tem 44 px.
- **Ações destrutivas separadas da leitura:**
  - O antigo "Excluir", colado ao "Continuar", **só arquivava**: o nome enganava.
  - Agora ele fica atrás de "Gerenciar", como "Arquivar mesa", com a explicação "Dá para
    restaurar depois, em Arquivadas".
  - A exclusão definitiva continua só nas arquivadas, com a confirmação em dois passos
    ("Apagar de vez? Não dá para desfazer.").
- **Estado vazio:** sem mesas, o Perfil explica o próximo passo.

## Identidade visual

Nenhum fundo, imagem, logo ou fonte foi alterado. A checagem do diff acusou um único valor
literal novo, `#d2a23a59`. É o âmbar `#d2a23a` com transparência que o lobby do jogador já
desenha hoje (`{{ mySheetCol }}59`), então não é uma cor nova na tela.

## Testes

| Suíte | Resultado |
|---|---|
| Navegador — etapa 7 | **42/42** |
| SQL `ponto1` / `ponto2` / `ponto2b` / `ponto3` / `ponto5` + paridade | **52 / 73 / 24 / 32 / 16 + 24** |
| Varredura de chaves duplicadas no `renderVals` (732 chaves) | **nenhuma** |

No navegador, conferi:

- os destinos dos dois botões, com e sem conta;
- os atalhos de login e cadastro;
- a ordem das seções do Perfil e as ações por status;
- que **nenhum botão destrutivo fica visível** antes de "Gerenciar";
- o arquivamento, as arquivadas e a confirmação em dois passos;
- os números do lobby e a guarda de início inalterada;
- os rótulos do lobby do jogador;
- a criação de mesa e de personagem, que continuam funcionando;
- entrada, Perfil e lobby a 390, 768 e 1440 px sem corte.

Também vi capturas das quatro telas.

**Falha encontrada no próprio teste:** a asserção "nada destrutivo ao lado de Continuar"
usava `^excluir$` com a flag `m` num texto em que eu tinha juntado todas as linhas, então
ela nunca falharia. Foi refeita pelo DOM (nenhum botão visível "Excluir"/"Arquivar…").

## Limitações

- O menu superior global (Home, Mesas, Personagens, Perfil, Entrar, Cadastrar) não foi
  alterado nesta etapa.
- O Perfil lista as mesas **do Mestre**; vínculos como jogador não aparecem ali (como antes).
- "1 aprovados · 3/8" no cabeçalho da lista de jogadores do lobby do Mestre é texto
  pré-existente, sem concordância de número.

---

# Fechamento do plano de UI/UX

| Etapa | Commit | Migração | Estado |
|---|---|---|---|
| 1 Painel do jogador | `f04ba7f` | — | em produção |
| 2 Responsividade e navegação | `608e0b8` | — | em produção |
| 3 Painel do Mestre e contexto das ações | `40489fb` + correção `33226b5` | — | em produção |
| 4 Perícias explicadas na criação | `3341b7c` (+ `729b4c5`) | — | em produção |
| 5 Filtragem de perícias nos testes | `bccb73f` | `migration_skill_pairs.sql` (aplicada) | em produção |
| 6 Feedback, acessibilidade e continuidade | `fee0b62` | — | em produção |
| 7 Entrada, lobby e conta | este commit | — | aguardando push |

Regressão dos planos anteriores, executada a cada etapa: SQL dos Pontos 1, 2, 2B e 3, mais
o par atributo/perícia e a paridade. A paleta, os fundos e o logo foram conferidos por
checagem do diff em todas as etapas.
