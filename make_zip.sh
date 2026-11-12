#!/bin/bash
# Package a standard Magisk / KernelSU / APatch flashable zip.
set -euo pipefail
cd "$(dirname "$0")"
VER=$(grep '^version=' module.prop | cut -d= -f2)
OUT="WenPrivacyGuard-v${VER}.zip"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

cp module.prop customize.sh service.sh uninstall.sh sepolicy.rule config.example.json "$STAGE/"
cp -r META-INF scripts webroot "$STAGE/"
mkdir -p "$STAGE/zygisk"
if [ -f zygisk_out/arm64-v8a.so ]; then
  cp zygisk_out/arm64-v8a.so "$STAGE/zygisk/arm64-v8a.so"
else
  echo "NOTE: no compiled .so found - zip will contain a placeholder." >&2
  echo "Build the native library first (see README § Build) for a flashable module." > "$STAGE/zygisk/PLACEHOLDER.txt"
fi
chmod 0755 "$STAGE/customize.sh" "$STAGE/service.sh" "$STAGE/uninstall.sh"
chmod 0755 "$STAGE/scripts/"*.sh
(cd "$STAGE" && zip -r -q "$OLDPWD/$OUT" .)
echo "Wrote $OUT"
unzip -l "$OUT"
