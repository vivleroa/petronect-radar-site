# Petronect Dashboard (site público)

Landing de consultoria + dashboard **ao vivo** das licitações abertas da Petrobras,
publicado via **GitHub Pages**. Repositório público (só dados públicos; nenhum segredo).

- `scripts/dashboard.ps1` — coleta o endpoint público do Petronect e gera `docs/index.html`.
- `.github/workflows/site.yml` — roda todo dia às 07:00 (Brasília) e atualiza a página.
- `docs/index.html` — a página servida pelo Pages.

## Publicação (uma vez)
1. **Settings → Pages** → Source: **Deploy from a branch** → branch `main`, pasta `/docs` → Save.
2. Em ~1 min o site fica em `https://<usuario>.github.io/petronect-radar-site/`.

## Personalizar (Settings → Secrets and variables → Actions → Variables)
- `EMAIL_CONTATO` — e-mail que recebe os contatos do botão (padrão: vivleroa@gmail.com).
- `MARCA` — seu @ (padrão: @consultxlicitacoes).

O radar por e-mail (privado) fica em outro repositório: `petronect-radar`.
