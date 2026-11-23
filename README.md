[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/daily-stock-analys-2?utm_medium=integration&utm_source=button&utm_campaign=daily-stock-analysis)

# Daily Stock Analysis on Railway

A Railway template for [Daily Stock Analysis](https://github.com/ZhuLinsen/daily_stock_analysis)
(MIT), an LLM-powered stock analysis dashboard for A-share, Hong Kong and US watchlists:
market data, news, a decision dashboard, scheduled reports and push notifications.

**Version:** v3.35.0, official image
`zhulinsen/daily_stock_analysis:v3.35.0@sha256:0a62ca6e930a9c8fdac447d4306a9210166ca4b3eb8896b3a31f457361cf0d95`.

## What it deploys

One service built from this repo's `Dockerfile`:

- the web dashboard and REST API on Railway's `PORT`, with a public domain and the
  health check `/api/health`;
- the daily scheduler, inside the same process (off until you turn it on in Settings);
- a volume at `/app/data` with the SQLite database, the settings file `runtime.env`
  (what you save in the web UI), generated reports and the admin password hash.

What the wrapper changes compared with the stock image:

- **Login is always on.** Upstream ships with the dashboard open (its `ADMIN_AUTH_ENABLED`
  is off and is read only from its settings file). The start script turns it on at every
  start and sets the admin password from `ADMIN_PASSWORD`, so nobody else can open the
  dashboard or claim the first-login password.
- Settings and reports are kept on the volume, so they survive redeploys.
- Uses as little memory as it can (about 400 MB once running): `MAX_WORKERS=1` on first boot
  (raise it in Settings on a bigger plan), native thread pools sized to one CPU, and the
  Feishu/Lark SDK (about 130 MB) loaded only when `FEISHU_APP_ID` is set. Feishu webhook
  notifications work without it; for the Feishu app bot, set `FEISHU_APP_ID` and restart.
- If the web server stops, the container exits non-zero, so Railway restarts it.

## Variables

| Variable | Default | What it is |
|---|---|---|
| `LLM_API_KEY` | (you enter it) | API key of your LLM provider (Gemini, OpenAI, Anthropic, DeepSeek or any OpenAI-compatible gateway). Required for analysis. |
| `LLM_MODEL` | `gemini/gemini-3.6-flash` | LiteLLM model name, `provider/model`, for example `openai/gpt-6.1-sol`, `anthropic/claude-sonnet-4-6`, `deepseek/deepseek-v4-flash`. |
| `LLM_BASE_URL` | empty | Only for OpenAI-compatible gateways (use an `openai/...` model), for example `https://api.siliconflow.cn/v1`. |
| `ADMIN_PASSWORD` | generated | Dashboard password. Change it here and redeploy to reset it. |
| `PORT` | `8000` | Port the web server listens on. |

These variables override the same settings in the web UI. Everything else (stock list,
schedule, search providers, notification channels, more LLM channels) is set in the web
UI's Settings page and saved on the volume. Upstream's full list of settings is in its
[`.env.example`](https://github.com/ZhuLinsen/daily_stock_analysis/blob/v3.35.0/.env.example);
any of them can also be added as a Railway variable.

## After deploying

1. Open the service's public URL and sign in with `ADMIN_PASSWORD` (service → Variables).
2. In Settings, set your stock list and, if you want daily reports, turn on the schedule
   and pick a time (the default time zone is `Asia/Shanghai`; set a `TZ` variable to change it).
3. Run an analysis from the home page.

**Memory: give it 1 GB if you can.** The service settles at about 400 MB, but starting up
and the first requests peak at about 430-500 MB. In our tests with a 0.5 GB / 1 vCPU limit
(Railway's Free plan), two deploys out of three ran cleanly; the third was killed for
memory twice on its first requests, restarted by itself and then stayed up at about
0.40 GB. Upstream recommends 1 GB for full analysis runs over long stock lists. On a
0.5 GB service keep one worker and a short stock list.

This software produces AI-generated analysis, not financial advice.

## Updates

This repo pins the upstream image by version and digest. When a new upstream release is
tested, the pin is bumped here with an entry in [CHANGELOG.md](CHANGELOG.md), and Railway
shows "update available" on your deployment. Your data on the volume is kept.

## Licence

The template files are MIT. Daily Stock Analysis is MIT, by ZhuLinsen and contributors.
