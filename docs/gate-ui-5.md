# Gate UI 5 — Filtragem de perícias nos testes

Data: 06/10/2026 · Base: `main` @ `729b4c5` (UI 4 em produção)

## O que mudou

### No formulário de testes do Mestre

- **O atributo filtra as perícias**, no teste geral e no combate: cada atributo lista só as
  4 perícias dele, lidas do catálogo (`src/data/attributes.js`).
- **Trocar o atributo limpa a perícia incompatível** e não escolhe outra sozinho. O select
  mostra "— escolha a perícia —" com borda de aviso, e o motivo aparece junto ao envio
  ("Escolha uma perícia de Corpo."). Reescolher o mesmo atributo preserva a perícia.
- **Envio e rolagem local ficam bloqueados** até haver um par válido. A rolagem local também
  passou a respeitar a regra, porque usa o mesmo formulário.
- **Padrões corrigidos:** o teste geral começava com a perícia `analise`, que **não existe**
  no catálogo (bônus sempre 0); agora começa em Mente + Investigação. O combate começava em
  Corpo + Atletismo e agora começa em Corpo + Luta.
- **Revalidação:** o rascunho de teste não é salvo em lugar nenhum (o antigo
  `_loadSession` foi removido no Ponto 3), mas o par é **reavaliado a cada uso**, não
  presumido. Um par cruzado ou inexistente vindo de qualquer origem é detectado, o select
  mostra "escolha", e o valor **não** é trocado em silêncio.
- **Recusa do banco traduzida:** "O banco recusou o teste: a perícia não pertence ao
  atributo escolhido."

### No banco — `migration_skill_pairs.sql`

- `_ad_skill_attr(perícia)`: tabela dos 24 pares, **gerada a partir do catálogo** e fechada
  para a API.
- `master_create_request` recusa par ausente, cruzado ou inexistente com
  `invalid_skill_for_attr`.
- **Compatibilidade:**
  - a validação vale só para pedidos **novos**;
  - um pedido já gravado com par antigo (`mente` + `analise`) continua chegando ao jogador,
    sendo respondido e reenviado — `player_answer_request` não olha o par;
  - uma nova tentativa com a mesma `client_key` de um pedido existente devolve a duplicata
    **antes** da validação, para um reenvio legítimo não virar erro.

### Paridade app × banco

`supabase/tests/parity_skills.js` compara o catálogo do app com a tabela da migração e
falha se divergirem. Entrou no `run_all.sh`. **Teste de mutação:** troquei `luta` para
`reflexo` só na migração e a paridade falhou como deveria; depois restaurei.

### Documento do sistema

Duas linhas da tabela de combate permitiam combinação cruzada e foram alinhadas ao site:

- `Faca ou bastão: Corpo ou Reflexos + Luta` virou `Corpo + Luta`;
- `Garra ou mordida: … ou perícia apropriada` virou `… ou outra perícia de Corpo`.

A seção 4.2 ganhou a regra explícita: **sem combinação cruzada**.

## Testes

| Suíte | Resultado |
|---|---|
| Navegador — etapa 5 | **29/29** |
| SQL `ponto5` (novo) | **16/16** |
| SQL `ponto1` / `ponto2` / `ponto2b` / `ponto3` | **52 / 73 / 24 / 32** |
| Paridade catálogo × banco | **24/24 pares** |

No navegador, conferi:

- listas filtradas na lógica **e** no `<select>` renderizado;
- limpeza ao trocar o atributo, bloqueio com motivo na tela e botões desabilitados;
- rolagem local que não acontece com par inválido;
- detecção de par restaurado cruzado e de `analise`;
- **fórmula intacta**: 3d20 com Mente 3, bônus = Investigação 2, total = maior d20 + perícia;
- recusa do banco com mensagem clara;
- 390 px sem corte horizontal;
- **jogador ainda rola um pedido antigo** com par inválido.

Nenhuma cor fora da paleta.

No SQL, conferi:

- pares válidos aceitos no geral e no combate;
- pares cruzados recusados (Mente + Atletismo e Reflexos + Luta), assim como a perícia
  inexistente, a perícia ausente, o atributo ausente e a grafia diferente;
- as 24 perícias do catálogo aceitas, e nenhum pedido inválido gravado;
- o pedido legado: reenvio, entrega ao jogador, resposta e resposta repetida;
- a tabela de pares fechada para a API.

### Falhas encontradas e corrigidas durante o gate

1. **Regressão real no `ponto1_tests`:** os pedidos de teste do Ponto 1 usavam
   `mente` + `analise`, ou nenhum par, e passaram a ser recusados. Os fixtures foram
   atualizados para pares válidos. A linha que reenvia com `{"label":"dup"}` ficou como
   estava, porque agora ela **prova** que a duplicata é devolvida antes da validação.
2. **Teste que não testava:** a verificação da mensagem de recusa substituía `sb`, mas
   `sb` é um *getter* sobre `_sb`. A chamada foi ao Supabase real, que recusou por falta de
   login real (nada foi gravado), e voltou a mensagem genérica. A interceptação passou para
   `_sb`, com uma asserção que confirma que ela está ativa.
3. A ordem de implantação que escrevi primeiro ("junto com o deploy") estava imprecisa.
   Corrigi para **deploy antes, migração depois**.

## Ordem de implantação

1. **Publicar o `index.html` primeiro.** O cliente novo funciona com o banco antigo, que só
   não valida o par.
2. **Aplicar `migration_skill_pairs.sql` depois.** Com o banco novo e o cliente antigo, o
   teste geral padrão (`analise`) seria recusado.

## Limitações

- A tabela de pares do banco é uma cópia do catálogo. Ao mudar uma perícia, mudar os dois e
  rodar a paridade. A migração pode ser regerada a partir do catálogo.
- Fichas antigas podem guardar pontos em `analise` (a suíte do Ponto 1 tem uma). Isso não
  afeta testes novos, porque a perícia nunca é oferecida, mas os pontos ficam inúteis nessa
  ficha.
