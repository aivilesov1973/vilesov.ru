#!/usr/bin/env bash
# Проверка, что сайт реально отдаёт страницу, а не 404/заглушку Pages.
# Использование: smoke.sh [URL] [ожидаемый_текст]
set -uo pipefail

URL="${1:-https://vilesov.ru/}"
EXPECTED="${2:-Александр Вилесов}"
ATTEMPTS="${SMOKE_ATTEMPTS:-12}"
DELAY="${SMOKE_DELAY:-10}"

body="$(mktemp)"
trap 'rm -f "$body"' EXIT

code="000"
for attempt in $(seq 1 "$ATTEMPTS"); do
  code=$(curl -s -m 20 -o "$body" -w '%{http_code}' "$URL") || code="000"
  if [ "$code" = "200" ] && grep -qF "$EXPECTED" "$body"; then
    echo "OK: $URL -> $code, ожидаемый текст найден"
    exit 0
  fi
  echo "попытка $attempt/$ATTEMPTS: http $code"
  if [ "$attempt" -lt "$ATTEMPTS" ]; then sleep "$DELAY"; fi
done

echo "::error::Сайт не отдаёт ожидаемое содержимое: $URL (последний код: $code)"
head -c 500 "$body" || true
echo
exit 1
