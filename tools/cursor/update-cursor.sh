#!/usr/bin/env bash
set -euo pipefail

APPDIR=$HOME/programs/cursor
APPIMAGE_URL="https://api2.cursor.sh/updates/download/golden/linux-x64/cursor/"
PARTIAL="${APPDIR}/cursor.AppImage.part"
TARGET="${APPDIR}/cursor.AppImage"

mkdir -p "$APPDIR"
rm -f "$PARTIAL"
if ! wget --tries=2 -O "$PARTIAL" "$APPIMAGE_URL"; then
	rm -f "$PARTIAL"
	exit 1
fi
mv "$PARTIAL" "$TARGET"
chmod +x "$TARGET"
