#!/bin/bash
# Cài VietIME bản mới nhất từ GitHub Releases vào ~/Library/Input Methods.
#   curl -fsSL https://raw.githubusercontent.com/QuangLe1997/VietIME/main/install.sh | bash
# Tải bằng curl nên file không bị gắn cờ cách ly (quarantine) → macOS không chặn app chưa ký Apple.
set -euo pipefail

URL="${VIETIME_URL:-https://github.com/QuangLe1997/VietIME/releases/latest/download/VietIME.zip}"
DEST="$HOME/Library/Input Methods"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Tải $URL"
curl -fsSL "$URL" -o "$TMP/VietIME.zip"
ditto -x -k "$TMP/VietIME.zip" "$TMP"
[ -d "$TMP/VietIME.app" ] || { echo "Gói tải về không có VietIME.app" >&2; exit 1; }

pkill -x VietIME 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/VietIME.app"
ditto "$TMP/VietIME.app" "$DEST/VietIME.app"
xattr -dr com.apple.quarantine "$DEST/VietIME.app" 2>/dev/null || true

"$DEST/VietIME.app/Contents/MacOS/VietIME" --register
echo "→ Đã cài VietIME $("$DEST/VietIME.app/Contents/MacOS/VietIME" --version) vào $DEST"
echo
echo "Bật: System Settings → Keyboard → Input Sources → Edit… → + → Vietnamese → VietIME."
echo "Lần đầu chưa thấy thì đăng xuất rồi đăng nhập lại. Cập nhật: chạy lại lệnh cài."
