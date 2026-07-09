# Afterdark / Saint Vesper — Guia de uso dos backgrounds

Este pacote reúne backgrounds 16:9 pensados para reduzir o vazio das telas do site sem competir com cards, formulários, botões e textos. Todos seguem a estética oficial de Afterdark / Saint Vesper: retrô-noir sobrenatural, art déco gótico, fundo escuro, atmosfera urbana e detalhes discretos.

## Recomendação geral de aplicação

Use as imagens como `background-image` em tela cheia ou no container principal da página.

Configuração base recomendada:

```css
.page-background {
  background-size: cover;
  background-repeat: no-repeat;
  background-position: center;
}

.page-background::before {
  content: "";
  position: absolute;
  inset: 0;
  background: rgba(5, 6, 12, 0.35);
  pointer-events: none;
}
```

Para telas com formulários centrais, use overlay mais forte: `rgba(5, 6, 12, 0.45)` a `rgba(5, 6, 12, 0.60)`.

Para telas de apresentação, home ou seleção de one-shots, use overlay mais leve: `rgba(5, 6, 12, 0.20)` a `rgba(5, 6, 12, 0.35)`.

---

## 01 — `01_eclipse_carmesim.png`

**Nome interno:** Eclipse Carmesim  
**Função:** fundo institucional e neutro do site.

### Usar em

- Splash / tela de abertura.
- Cadastro.
- Login.
- Recuperar senha.
- Conta não conectada.
- Entrar na mesa.
- Identificação do jogador.

### Por quê

É o background mais neutro do pacote. O eclipse carmesim comunica o evento central do lore sem puxar para nenhuma facção específica. O centro é escuro e limpo, ideal para cards de formulário.

### CSS sugerido

```css
background-position: center center;
```

---

## 02 — `02_skyline_saint_vesper.png`

**Nome interno:** Skyline de Saint Vesper  
**Função:** fundo de chegada, introdução e identidade geral da cidade.

### Usar em

- Home / tela inicial.
- Início — Nova Aventura.
- Escolha de perfil, especialmente telas em que o usuário decide entre jogar ou mestrar.
- Páginas introdutórias com chamadas grandes.

### Por quê

Mostra Saint Vesper como cidade viva, sombria e elegante. Funciona bem quando a página precisa vender o clima do RPG antes de entrar em mecânicas.

### CSS sugerido

```css
background-position: center center;
```

---

## 03 — `03_veu_das_tres_faccoes.png`

**Nome interno:** Véu das Três Facções  
**Função:** fundo narrativo para escolhas e caminhos.

### Usar em

- Escolher papel / direção do jogador.
- Escolha do modo da sessão.
- Telas de decisão narrativa.
- Telas de apresentação das três forças principais da cidade.

### Por quê

O fundo mistura rubro, magenta e azul, sugerindo Sociedade Rubra, Os Caídos e A Matilha sem exibir símbolos de forma agressiva. É ideal para telas de escolha.

### CSS sugerido

```css
background-position: center center;
```

---

## 04 — `04_mapa_arquivado_saint_vesper.png`

**Nome interno:** Mapa Arquivado de Saint Vesper  
**Função:** fundo principal do modo Mestre.

### Usar em

- Perfil do Mestre.
- Mesas do Mestre.
- Nome da mesa.
- Capítulos da história.
- Lobby do Mestre.
- Criação e organização de sessões.

### Por quê

Transforma a interface do mestre em um dossiê urbano: mapa, rotas, marcações e investigação. Dá sensação de controle, preparação e bastidores da cidade.

### CSS sugerido

```css
background-position: center center;
```

---

## 05 — `05_arquivo_de_investigacao.png`

**Nome interno:** Arquivo de Investigação  
**Função:** fundo para personagem, ficha e perfil.

### Usar em

- Perfil do jogador.
- Criação de personagem.
- Escolha de personagem.
- Personagem pronto.
- Telas de ficha, identidade e dados pessoais do personagem.

### Por quê

A composição lembra uma mesa de investigação com documentos, fotos, envelopes e caneta. O centro é muito limpo, ótimo para formulários e cards verticais.

### CSS sugerido

```css
background-position: center center;
```

---

## 06 — `06_painel_da_mesa.png`

**Nome interno:** Painel da Mesa  
**Função:** fundo para jogo ativo e painel operacional.

### Usar em

- Painel de sessão.
- Tela ativa da mesa.
- Mapa jogável.
- Telas de controle durante a sessão.

### Por quê

É o mais discreto e funcional. Ele sugere mapa, rotas e distrito urbano sem roubar atenção dos controles, listas e painéis da sessão.

### CSS sugerido

```css
background-position: center center;
```

---

## 07 — `07_oneshot_misterios_vermelhos.png`

**Nome interno:** Mistérios Vermelhos  
**Função:** fundo específico do one-shot dos demônios / Os Caídos.

### Usar em

- Card de Mistérios Vermelhos.
- Tela de seleção de one-shots.
- Lobby desse one-shot.
- Tela de introdução narrativa do Clube Eclipse.

### Por quê

As cartas com o “?” neon comunicam pacto, aposta, cassino e mistério. A paleta magenta conversa diretamente com Os Caídos e o Distrito Vermelho.

### CSS sugerido

```css
background-position: left center;
```

---

## 08 — `08_oneshot_a_ultima_gota.png`

**Nome interno:** A Última Gota  
**Função:** fundo específico do one-shot dos vampiros / Sociedade Rubra.

### Usar em

- Card de A Última Gota.
- Tela de seleção de one-shots.
- Lobby desse one-shot.
- Tela de introdução de banco, aristocracia ou Alta Vesper.

### Por quê

A taça vampírica transbordando sangue comunica aristocracia, chantagem, linhagem e o valor simbólico do sangue. Combina com telas rubras e mais solenes.

### CSS sugerido

```css
background-position: right center;
```

---

## 09 — `09_oneshot_sombras_uivantes.png`

**Nome interno:** Sombras Uivantes  
**Função:** fundo específico do one-shot dos lobisomens / A Matilha.

### Usar em

- Card de Sombras Uivantes.
- Tela de seleção de one-shots.
- Lobby desse one-shot.
- Tela de introdução das Docas e território da Matilha.

### Por quê

O predador nas sombras com olhos brilhantes comunica caça, território e ameaça silenciosa. A paleta azul aço combina com A Matilha.

### CSS sugerido

```css
background-position: right center;
```

---

## Mapeamento rápido por tela

| Tela / Seção | Background recomendado |
|---|---|
| Splash / abertura | `01_eclipse_carmesim.png` |
| Home / tela inicial | `02_skyline_saint_vesper.png` |
| Cadastro | `01_eclipse_carmesim.png` |
| Login | `01_eclipse_carmesim.png` |
| Recuperar senha | `01_eclipse_carmesim.png` |
| Conta não conectada | `01_eclipse_carmesim.png` |
| Início — Nova Aventura | `02_skyline_saint_vesper.png` |
| Escolher perfil / direção | `03_veu_das_tres_faccoes.png` |
| Perfil do Mestre | `04_mapa_arquivado_saint_vesper.png` |
| Mesas do Mestre | `04_mapa_arquivado_saint_vesper.png` |
| Nome da mesa | `04_mapa_arquivado_saint_vesper.png` |
| Modo da sessão | `03_veu_das_tres_faccoes.png` |
| Capítulos | `04_mapa_arquivado_saint_vesper.png` |
| One-shots — seleção geral | `07`, `08` e `09` conforme card/tema; ou usar `03_veu_das_tres_faccoes.png` como fundo geral |
| Lobby | `04_mapa_arquivado_saint_vesper.png`; se for one-shot, usar o fundo específico |
| Painel de sessão | `06_painel_da_mesa.png` |
| Entrar na mesa | `01_eclipse_carmesim.png` |
| Identificação do jogador | `01_eclipse_carmesim.png` |
| Escolher personagem | `05_arquivo_de_investigacao.png` |
| Criar personagem | `05_arquivo_de_investigacao.png` |
| Usar personagem pronto | `05_arquivo_de_investigacao.png` |
| Personagem pronto / ficha | `05_arquivo_de_investigacao.png` |
| Mapa jogável | `06_painel_da_mesa.png` |

---

## Observação de legibilidade

Como as telas do site usam muitos cards escuros, o ideal é manter os backgrounds sempre com baixa intensidade. Caso algum fundo fique chamando muita atenção atrás dos textos, aplique uma camada extra:

```css
background: linear-gradient(
  rgba(5, 6, 12, 0.55),
  rgba(5, 6, 12, 0.55)
), url('/caminho/da/imagem.png');
```

Para cards centrais, também funciona adicionar uma vinheta:

```css
box-shadow: inset 0 0 180px rgba(0, 0, 0, 0.65);
```
