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
