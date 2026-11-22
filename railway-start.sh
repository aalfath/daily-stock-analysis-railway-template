#!/bin/sh
# Railway start script for Daily Stock Analysis.
# 1. Keeps reports on the volume.
# 2. Forces the admin login on (upstream reads ADMIN_AUTH_ENABLED only from its .env file,
#    and defaults to off) and sets the admin password from ADMIN_PASSWORD, so the
#    dashboard is never open and the first visitor can't pick the password.
# 3. Runs the web server (which also runs the daily schedule) and exits non-zero on any
#    unexpected stop, so Railway's ON_FAILURE restart policy restarts it.
set -eu

DATA_DIR=/app/data
ENV_FILE="${ENV_FILE:-$DATA_DIR/runtime.env}"
PORT="${PORT:-8000}"
export ENV_FILE PORT

mkdir -p "$DATA_DIR/reports"
if [ ! -L /app/reports ]; then
  if rmdir /app/reports 2>/dev/null || [ ! -e /app/reports ]; then
    ln -s "$DATA_DIR/reports" /app/reports
  else
    echo "railway-start: /app/reports is not empty or is a mount; reports stay there" >&2
  fi
fi

# One LLM key for any provider: LLM_API_KEY + LLM_MODEL (LiteLLM "provider/model") and,
# for OpenAI-compatible gateways, LLM_BASE_URL. Mapped to the variables upstream reads.
# Provider-specific variables you set yourself (GEMINI_API_KEY, OPENAI_API_KEY, ...) win.
if [ -n "${LLM_MODEL:-}" ] && [ -z "${LITELLM_MODEL:-}" ]; then
  export LITELLM_MODEL="$LLM_MODEL"
fi
if [ -n "${LLM_API_KEY:-}" ]; then
  case "${LITELLM_MODEL:-gemini/}" in
    gemini/*)    [ -n "${GEMINI_API_KEY:-}${GEMINI_API_KEYS:-}" ] || export GEMINI_API_KEY="$LLM_API_KEY" ;;
    anthropic/*) [ -n "${ANTHROPIC_API_KEY:-}${ANTHROPIC_API_KEYS:-}" ] || export ANTHROPIC_API_KEY="$LLM_API_KEY" ;;
    deepseek/*)  [ -n "${DEEPSEEK_API_KEY:-}${DEEPSEEK_API_KEYS:-}" ] || export DEEPSEEK_API_KEY="$LLM_API_KEY" ;;
    *)           [ -n "${OPENAI_API_KEY:-}${OPENAI_API_KEYS:-}" ] || export OPENAI_API_KEY="$LLM_API_KEY" ;;
  esac
fi
if [ -n "${LLM_BASE_URL:-}" ] && [ -z "${OPENAI_BASE_URL:-}" ]; then
  export OPENAI_BASE_URL="$LLM_BASE_URL"
fi

python - <<'PY'
import base64, hashlib, hmac, os, re, secrets, sys
from pathlib import Path

data = Path("/app/data")
env_path = Path(os.environ["ENV_FILE"])
env_path.parent.mkdir(parents=True, exist_ok=True)

lines = env_path.read_text().splitlines() if env_path.exists() else None
if lines is None:
    # First boot: upstream defaults, with one analysis worker so a 0.5 GB service copes.
    lines = [
        "# Created by the Railway template on first boot.",
        "# Settings you save in the web UI are written to this file (on the volume).",
        "STOCK_LIST=600519,300750,002594",
        "MAX_WORKERS=1",
        "SCHEDULE_ENABLED=false",
        "SCHEDULE_TIME=18:00",
    ]
    print("railway-start: created", env_path)
lines = [l for l in lines if not re.match(r"\s*(export\s+)?ADMIN_AUTH_ENABLED\s*=", l)]
lines.append("ADMIN_AUTH_ENABLED=true")
tmp = env_path.with_name(env_path.name + ".tmp")
tmp.write_text("\n".join(lines) + "\n")
tmp.chmod(0o600)
tmp.replace(env_path)

pw = os.environ.get("ADMIN_PASSWORD", "")
if len(pw.strip()) < 6:
    sys.exit("railway-start: ADMIN_PASSWORD must be set (6 characters or more)")

def derive(p, salt):
    return hashlib.pbkdf2_hmac("sha256", p.encode(), salt=salt, iterations=100_000)

def record(p):
    salt = secrets.token_bytes(32)
    return base64.standard_b64encode(salt).decode() + ":" + base64.standard_b64encode(derive(p, salt)).decode()

def matches(path, p):
    try:
        s, h = path.read_text().strip().split(":", 1)
        return hmac.compare_digest(derive(p, base64.standard_b64decode(s)), base64.standard_b64decode(h))
    except Exception:
        return False

cred = data / ".admin_password_hash"           # upstream's credential file
marker = data / ".railway_admin_password_applied"  # which ADMIN_PASSWORD value we last applied
if not cred.exists() or not matches(marker, pw):
    for path in (cred, marker):
        t = path.with_name(path.name + ".tmp")
        t.write_text(record(pw))
        t.chmod(0o600)
        t.replace(path)
    print("railway-start: admin password set from ADMIN_PASSWORD")
PY

stopping=0
python main.py --serve-only --host 0.0.0.0 --port "$PORT" &
app=$!
trap 'stopping=1; kill -TERM "$app" 2>/dev/null || true' TERM INT

# Watchdog: upstream serves HTTP from a background thread while the main thread sleeps,
# so a dead web server would otherwise leave a running but useless container.
(
  sleep 180
  fails=0
  while kill -0 "$app" 2>/dev/null; do
    if curl -fsS -m 10 -o /dev/null "http://127.0.0.1:$PORT/api/health"; then
      fails=0
    else
      fails=$((fails + 1))
      echo "railway-start: health check failed ($fails/5)" >&2
    fi
    if [ "$fails" -ge 5 ]; then
      echo "railway-start: web server not answering, stopping so Railway restarts it" >&2
      kill -TERM "$app" 2>/dev/null || true
      sleep 20
      kill -KILL "$app" 2>/dev/null || true
      exit 0
    fi
    sleep 30
  done
) &

rc=0
while :; do
  set +e
  wait "$app"
  rc=$?
  set -e
  kill -0 "$app" 2>/dev/null || break
done

if [ "$stopping" = 1 ]; then
  exit 0
fi
[ "$rc" -eq 0 ] && rc=1
echo "railway-start: app stopped unexpectedly (exit $rc)" >&2
exit "$rc"
