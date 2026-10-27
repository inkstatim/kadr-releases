#!/bin/bash
# Установка и обновление Kadr одной командой (вставить в «Терминал» и нажать Enter):
#   curl -fsSL https://raw.githubusercontent.com/inkstatim/kadr-releases/main/install.sh | bash
# Скачивает последнюю версию, кладёт Kadr в «Программы» и запускает.
set -euo pipefail

URL="https://github.com/inkstatim/kadr-releases/releases/latest/download/Kadr.dmg"
DEST="${KADR_INSTALL_DIR:-/Applications}"
TMP="$(mktemp -d)"
MNT="$TMP/mnt"

cleanup() {
  hdiutil detach -quiet "$MNT" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() { echo "✗ $1" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || fail "Kadr работает только на macOS."
major="$(sw_vers -productVersion | cut -d. -f1)"
(( major >= 14 )) || fail "Нужна macOS 14 или новее, у вас $(sw_vers -productVersion)."

# Без прав администратора в /Applications не записать — ставим в свою папку «Программы».
if [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

echo "⬇ Скачиваю Kadr…"
curl -fL --progress-bar -o "$TMP/Kadr.dmg" "$URL" || fail "Не удалось скачать. Проверьте интернет и попробуйте ещё раз."

hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MNT" "$TMP/Kadr.dmg" || fail "Файл скачался с ошибкой. Попробуйте ещё раз."
codesign --verify --deep --strict "$MNT/Kadr.app" 2>/dev/null || fail "Подпись Kadr не прошла проверку — установка отменена."

# Обновление: закрыть запущенный Kadr, чтобы заменить его.
if pgrep -xq Kadr; then
  echo "Закрываю запущенный Kadr…"
  osascript -e 'tell application id "dev.inkstatim.kadr" to quit' >/dev/null 2>&1 || true
  for _ in {1..20}; do pgrep -xq Kadr || break; sleep 0.25; done
  pkill -x Kadr 2>/dev/null || true
fi

echo "📦 Устанавливаю в ${DEST}…"
rm -rf "$DEST/Kadr.app"
ditto "$MNT/Kadr.app" "$DEST/Kadr.app"
xattr -dr com.apple.quarantine "$DEST/Kadr.app" 2>/dev/null || true

open "$DEST/Kadr.app"
echo "✓ Готово! Kadr запущен — значок появился в строке меню вверху экрана."
