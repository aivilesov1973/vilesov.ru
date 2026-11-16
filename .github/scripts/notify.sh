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

problems=0
if ! printf '%s' "$TELEGRAM_BOT_TOKEN" | grep -Eq '^[0-9]+:[A-Za-z0-9_-]{20,}$'; then
  colons=$(printf '%s' "$TELEGRAM_BOT_TOKEN" | tr -cd ':' | wc -c | tr -d ' ')
  nonascii=$(printf '%s' "$TELEGRAM_BOT_TOKEN" | LC_ALL=C tr -d '\000-\177' | wc -c | tr -d ' ')
  echo "::error::TELEGRAM_BOT_TOKEN не похож на токен бота: длина ${#TELEGRAM_BOT_TOKEN} (норма ~46), двоеточий: $colons (нужно ровно 1), не-ASCII символов: $nonascii"
  problems=1
fi
if ! printf '%s' "$TELEGRAM_CHAT_ID" | grep -Eq '^-?[0-9]+$'; then
  digits=$(printf '%s' "$TELEGRAM_CHAT_ID" | tr -cd '0-9' | wc -c | tr -d ' ')
  echo "::error::TELEGRAM_CHAT_ID должен быть числом: пришло ${#TELEGRAM_CHAT_ID} символов, из них цифр: $digits (должны быть все)"
  problems=1
fi
[ "$problems" -eq 0 ] || exit 1

repo="${REPO:-}" workflow="${WORKFLOW:-}" status="${STATUS:-unknown}"
run_url="${RUN_URL:-}" commit="${COMMIT:-}" jobs="${JOBS:-}"

case "$status" in
  success)  icon="✅" ;;
  failure)  icon="🔴" ;;
  cancelled) icon="⚪" ;;
  test)     icon="🧪" ;;
  *)        icon="ℹ️" ;;
esac

# человеческая формулировка: good — всё работает, bad — хоть что-то упало
case "$status" in
  test|success) word="good" ;;
  failure)      word="bad" ;;
  *)            word="$status" ;;
esac

msg="${icon} <b>🌐 Сайт</b> · ${WORKFLOW:-deploy}: ${word}"
[ -n "$jobs" ]    && msg="${msg}
Джобы: ${jobs}"
# коммит не показываем — в тестовых и плановых сообщениях это шум.
# ссылку на прогон даём только при реальном сбое, чтобы было куда перейти.
if [ "$status" = "failure" ] && [ -n "$run_url" ]; then
  msg="${msg}
${run_url}"
fi

resp=$(curl -sS -m 20 -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "parse_mode=HTML" \
  --data-urlencode "text=${msg}" \
  --data-urlencode "disable_web_page_preview=true" \
  -w '\n%{http_code}') || true

code=$(printf '%s\n' "$resp" | tail -n1 | tr -d '[:space:]')
if [ "$code" = "200" ]; then
  echo "Уведомление отправлено в Telegram: $(printf '%s' "$msg" | head -n1)"
  exit 0
fi

echo "::error::Telegram вернул ${code:-нет ответа}: $(printf '%s\n' "$resp" | sed '$d')"
exit 1
