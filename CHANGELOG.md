# Changelog

Each entry is one version of this Railway template. Breaking changes are listed first.
Railway shows "update available" to everyone who deployed the template when this repo's
`main` changes; read the entry before you apply it.

## 3.35.0 (2026-11-22)

First version.

- Daily Stock Analysis [v3.35.0](https://github.com/ZhuLinsen/daily_stock_analysis/releases/tag/v3.35.0), official image `zhulinsen/daily_stock_analysis:v3.35.0@sha256:0a62ca6e930a9c8fdac447d4306a9210166ca4b3eb8896b3a31f457361cf0d95`.
- Admin login always on, password from the generated `ADMIN_PASSWORD` variable.
- Settings file (`runtime.env`), SQLite database and reports on one volume at `/app/data`.
- `LLM_API_KEY` / `LLM_MODEL` / `LLM_BASE_URL` mapped to upstream's provider variables.
- Exits non-zero if the web server stops, so Railway restarts it.
