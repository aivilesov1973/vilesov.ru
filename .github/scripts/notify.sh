#!/usr/bin/env bash
# Отправка уведомления в Telegram.
# Секреты TELEGRAM_BOT_TOKEN и TELEGRAM_CHAT_ID задаются в Settings → Secrets.
# Если они не заданы, шаг не падает: пишет предупреждение и выходит с кодом 0.
set -uo pipefail

missing=""
[ -z "${TELEGRAM_BOT_TOKEN:-}" ] && missing="TELEGRAM_BOT_TOKEN"
[ -z "${TELEGRAM_CHAT_ID:-}" ] && missing="${missing:+$missing, }TELEGRAM_CHAT_ID"
if [ -n "$missing" ]; then
  echo "::warning::пустые секреты: $missing — уведомление пропущено"
  exit 0
fi

# Секрет легко скопировать с переводом строки или пробелом на конце —
# curl в таком случае падает с «Malformed input to a URL function».
trim() {
  local v="${1:-}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}
TELEGRAM_BOT_TOKEN="$(trim "$TELEGRAM_BOT_TOKEN")"
TELEGRAM_CHAT_ID="$(trim "$TELEGRAM_CHAT_ID")"

if ! printf '%s' "$TELEGRAM_BOT_TOKEN" | grep -Eq '^[0-9]+:[A-Za-z0-9_-]{20,}$'; then
  echo "::error::TELEGRAM_BOT_TOKEN не похож на токен бота: длина ${#TELEGRAM_BOT_TOKEN}, ожидается вид 123456789:AA..."
  exit 1
fi
if ! printf '%s' "$TELEGRAM_CHAT_ID" | grep -Eq '^-?[0-9]+$'; then
  echo "::error::TELEGRAM_CHAT_ID должен быть числом, а пришло ${#TELEGRAM_CHAT_ID} символов — вставлено не то значение"
  exit 1
fi

repo="${REPO:-}" workflow="${WORKFLOW:-}" status="${STATUS:-unknown}"
run_url="${RUN_URL:-}" commit="${COMMIT:-}" jobs="${JOBS:-}"

case "$status" in
  success)  icon="✅" ;;
  failure)  icon="🔴" ;;
  cancelled) icon="⚪" ;;
  test)     icon="🧪" ;;
  *)        icon="ℹ️" ;;
esac

msg="${icon} <b>${WORKFLOW:-deploy}</b>: ${status}"
[ -n "$repo" ]    && msg="${msg}
Репозиторий: ${repo}"
[ -n "$jobs" ]    && msg="${msg}
Джобы: ${jobs}"
[ -n "$commit" ]  && msg="${msg}
Коммит: <code>${commit:0:7}</code>"
[ -n "$run_url" ] && msg="${msg}
${run_url}"

resp=$(curl -sS -m 20 -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "parse_mode=HTML" \
  --data-urlencode "text=${msg}" \
  --data-urlencode "disable_web_page_preview=true" \
  -w '\n%{http_code}') || true

code=$(printf '%s\n' "$resp" | tail -n1 | tr -d '[:space:]')
if [ "$code" = "200" ]; then
  echo "Уведомление отправлено в Telegram"
  exit 0
fi

echo "::error::Telegram вернул ${code:-нет ответа}: $(printf '%s\n' "$resp" | sed '$d')"
exit 1
