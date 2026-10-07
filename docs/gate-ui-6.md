# Gate UI 6 — Feedback, acessibilidade e continuidade

Data: 06/10/2026 · Base: `main` @ `33226b5` (UI 5 em produção, migração aplicada)

Sem migração nesta etapa: tudo é cliente.

## O que mudou

### 6.1 Erros no contexto da ação

Antes, todo erro ia para um único aviso flutuante que **sumia em 4,5 s**, longe da ação. O
aviso continua existindo, mas agora o erro **também fica junto da ação que falhou** até
ela dar certo ou até o usuário dispensar (✕).

| Contexto | Onde aparece | Nova tentativa |
|---|---|---|
| Teste (enviar, cancelar) | sob o botão de envio | reenvia com a **mesma chave** (o banco não duplica) |
| Consequência (ferimento, condição) | topo do painel de ferramentas, visível em qualquer ferramenta | repete com a **mesma chave `op`** (o ferimento não duplica) |
| Lobby do Mestre (aprovar, remover, iniciar) | junto do botão de iniciar | — |
| Ficha (concluir no wizard ou no perfil) | sobre os botões do wizard | o próprio "Confirmar" |
| Jogador (prontidão, sair da mesa) | no lobby do jogador | repete a **ação que falhou**, não a outra |

Bloqueios que já aparecem ao vivo (por exemplo, "Escolha uma perícia de Corpo") não são
duplicados como erro.

**Dois defeitos corrigidos aqui:**

- **Sair da mesa dava falso sucesso.** Em falha, `leaveTable` mostrava o aviso e seguia em
  frente: tirava o jogador da tela e esquecia o vínculo, enquanto no banco ele continuava
  membro. Agora o jogador fica na mesa, os *pollings* seguem ativos e a nova tentativa
  conclui a saída. Os *pollings* só param depois da saída confirmada.
- **Criar personagem no perfil com clique duplo** gerava duas inserções (`insert` direto,
  sem chave de idempotência). Agora há uma trava enquanto a primeira está em andamento.
  Validado por mutação: sem a trava, o teste falha.

### 6.2 Visibilidade escrita, com o mesmo vocabulário

**Todos / Só titular / Só mestre**, em relógios, estresse e no formulário de criação de
relógio. No centro do painel do Mestre, um relógio oculto era marcado **só pelo ícone ⦿**;
agora cada relógio tem a visibilidade escrita sob o tipo.

**Defeito encontrado e corrigido (vindo do plano de relógios, em produção desde `2845eb5`):**
o objeto devolvido pela renderização tinha a chave `hasPlayerClocks` **duas vezes**: uma
para o Mestre ("há relógios individuais") e outra que eu criei para o jogador ("há
relógios que eu vejo"). Vale a última, então no painel do Mestre a seção "Relógios de
jogador" seguia a regra do jogador. Ela **sumia quando só havia relógios individuais** e
aparecia vazia quando só havia públicos. A chave do jogador virou `hasMyClocks`. Uma
varredura automática das 712 chaves do objeto confirmou que essa era a única duplicada, e
o histórico mostra que ela não existia antes daquele commit.

### 6.3 Estados reais

O aviso "Reconectando…" do jogador ficava **dentro da seção de relógios**, então sumia
justamente quando não havia relógio permitido. Foi para o resumo do personagem, sempre
visível ("Reconectando… mostrando o último estado recebido"). Não existe selo de
"conectado": nada aparece quando está tudo certo. O Mestre já tinha o `saveChip` real do
Ponto 3.

### 6.4 Corrida na retomada do vínculo

Esta é a corrida registrada na Etapa 2: a retomada automática terminava **depois** de o
jogador entrar em outra mesa pelo código e sobrescrevia a escolha. Toda escolha explícita
de contexto agora incrementa um contador: entrar com código, escolher papel, sair da mesa,
abrir outra mesa e sair da conta. Se o contador mudou enquanto a retomada esperava o
banco, ela descarta o próprio resultado. O teste de controle confirma que, sem escolha no
meio, a retomada continua funcionando.

### 6.5 Rascunho da criação de personagem

- **Salvo enquanto o wizard está aberto** (a cada mudança, com intervalo) e **recuperado
  depois de F5**, com o aviso "Rascunho recuperado" e a opção "Descartar e começar de
  novo".
- **Escopo:** quem cria (conta, ou o vínculo do visitante) + onde (perfil, ou a mesa).
  Rascunho de uma mesa não aparece em outra, nem no perfil de outra conta. O rascunho fica
  preso ao contexto em que o wizard **começou**: mesmo que a mesa mude com o wizard aberto,
  ele nunca é gravado na chave de outro contexto.
- **Onde fica:** só no `localStorage` do navegador da própria pessoa, nunca no estado da
  mesa.
- **Limpeza:** ao concluir, ao descartar, ao sair da mesa (só o rascunho daquela mesa) e ao
  sair da conta (todos; pensando em computador compartilhado).
- **Beco sem saída corrigido:** um visitante que dava F5 no meio da criação voltava a um
  lobby que **não tinha como criar a ficha**. Agora a retomada sem ficha leva ao wizard com
  o rascunho, e o lobby sem ficha tem o botão "Criar ficha" com a explicação do próximo
  passo.

**Dois defeitos meus, pegos pelo teste antes do commit:**

- A comparação "mudou desde a última gravação?" incluía o horário, então qualquer
  redesenho regravava o rascunho. Uma aba antiga do wizard, acordada pela sincronização
  entre abas, recriava o rascunho que o logout acabara de apagar.
- A marca "rascunho recuperado" ficava presa ao trocar de contexto.

### 6.6 Acessibilidade e estados vazios

- **18 botões só com símbolo** (−, +, ✕, ←) ganharam `aria-label` com ação **e** item
  ("Avançar relógio Ritual", "Excluir barra Sede de Sangue"). A varredura final não acha
  nenhum botão visível sem rótulo.
- Os botões −/+ de **atributo** no wizard tinham 30 px; passaram a 44 px, como as perícias.
  Conferido de 360 a 1440 px, sem corte.
- **Estados vazios com o próximo passo** onde não havia nenhum: Relógios e Estresse do
  Mestre, Diário e NPCs do jogador. Nenhum revela quantidade ou existência de algo oculto.

### 6.7 Busca no acervo

A Biblioteca do Mestre ganhou um campo de busca rotulado. Ele filtra só o que o próprio
Mestre já tem, sem consultar o banco, ignora maiúsculas e acentos ("basta" acha "Bastão")
e avisa quando não encontra nada.

### 6.8 Polling sem roubar contexto

Conferido: um campo em edição continua focado e com o texto digitado ao longo de vários
ciclos de *polling*. O mesmo vale para a seleção do formulário de testes, a aba e o resumo
aberto do Grupo. **O acesso é removido quando o item deixa de existir:** a ficha de um
jogador aberta pelo Mestre fecha se ele sai da mesa, e o colega que sai some do Grupo.

## Testes

| Suíte | Resultado |
|---|---|
| Navegador 6.1 — erros, retry, falso sucesso, clique duplo | **26/26** |
| Navegador 6.2–6.5 — vocabulário, colisão, reconexão, corrida, rascunho | **26/26** |
| Navegador 6.5 — sair da mesa limpa só o rascunho daquela mesa | **2/2** |
| Navegador 6.6–6.8 — rótulos, vazios, busca, polling, responsividade | **24/24** |
| Navegador — wizard etapa 4 em 7 larguras | **7/7** |
| Navegador — barra do Mestre em 11 larguras, com aviso no painel | **11/11** |
| SQL `ponto1` / `ponto2` / `ponto2b` / `ponto3` / `ponto5` + paridade | **52 / 73 / 24 / 32 / 16 + 24** |

As falhas de rede foram simuladas interceptando o cliente Supabase (`_sb`); **nada foi ao
banco real**. Nenhuma cor fora da paleta e nenhum fundo tocado (checagem do diff). Conferi
capturas de tela dos avisos no painel do Mestre, no wizard a 390 px e no aviso de rascunho.

## Limitações

- O aviso persistente cobre os cinco contextos de maior impacto. Ações de gestão da mesa
  (salvar, pausar, arquivar, excluir) seguem com o aviso flutuante e o `saveChip` do
  Ponto 3.
- O rascunho do wizard é por navegador: não acompanha a pessoa para outro dispositivo.
- Duas abas no wizard do mesmo contexto: vale o rascunho da última aba que **mudou** algo.
- O logout limpa os rascunhos deste navegador, mas não fecha um wizard aberto em outra aba.
- A busca existe só na Biblioteca (6 armas e 4 itens hoje); as bibliotecas de ferimentos e
  condições ainda não têm busca.
