# Afterdark — Implementação do favicon

Este pacote contém as versões em PNG (e um `.ico` extra) do favicon **Eclipse Carmesim dourado/vermelho** para o site do Afterdark.

## Arquivos incluídos

- `afterdark-favicon-master-1254.png` → arquivo mestre em alta qualidade
- `favicon-16x16.png` → favicon padrão pequeno
- `favicon-32x32.png` → favicon padrão principal
- `favicon-48x48.png` → tamanho extra útil para alguns navegadores
- `favicon.ico` → formato clássico com múltiplos tamanhos
- `apple-touch-icon.png` → ícone para iPhone/iPad
- `android-chrome-192x192.png` → ícone Android/PWA
- `android-chrome-512x512.png` → ícone Android/PWA em alta resolução

---

## Estrutura recomendada

Coloque os arquivos em uma pasta como:

```text
/public/favicon/
```

ou, se o projeto usar outra convenção:

```text
/assets/favicon/
```

---

## Implementação básica no HTML

No `<head>` do site, adicione:

```html
<link rel="icon" type="image/x-icon" href="/favicon/favicon.ico">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon/favicon-16x16.png">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="48x48" href="/favicon/favicon-48x48.png">
<link rel="apple-touch-icon" sizes="180x180" href="/favicon/apple-touch-icon.png">
```

---

## Se quiser suporte para Android / PWA

Adicione também:

```html
<link rel="icon" type="image/png" sizes="192x192" href="/favicon/android-chrome-192x192.png">
<link rel="icon" type="image/png" sizes="512x512" href="/favicon/android-chrome-512x512.png">
<meta name="theme-color" content="#0b0b10">
```

Se o site usar `manifest.webmanifest`, inclua algo como:

```json
{
  "name": "Afterdark",
  "short_name": "Afterdark",
  "icons": [
    {
      "src": "/favicon/android-chrome-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/favicon/android-chrome-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ],
  "theme_color": "#0b0b10",
  "background_color": "#0b0b10",
  "display": "standalone"
}
```

---

## Recomendação prática

Se quiser a implementação mais segura e simples, use no mínimo:

- `favicon.ico`
- `favicon-32x32.png`
- `apple-touch-icon.png`

Isso já cobre muito bem a maior parte dos casos.

---

## Dica visual

Como esse favicon tem fundo escuro e brilho rubro/dourado:

- ele funciona melhor em abas com tema claro ou escuro;
- o tamanho **32x32** tende a ficar com a melhor leitura;
- em **16x16**, o símbolo continua legível por ser simples e central.

---

## Observação de cache

Se o navegador não atualizar o favicon imediatamente:

1. faça um hard refresh;
2. limpe cache;
3. ou altere a URL do arquivo temporariamente:

```html
<link rel="icon" href="/favicon/favicon-32x32.png?v=2">
```

Isso força o navegador a buscar a nova versão.
