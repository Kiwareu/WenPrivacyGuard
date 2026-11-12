#!/system/bin/sh
# Wen Privacy Guard - root-type detection (Section 5 of the spec)
# Writes /data/adb/wenprivacyguard/root_status.json
#   root_solution: magisk | kernelsu | apatch | none
#   bootloader_locked: true | false | unknown
#   verified_boot_state: green | yellow | orange | unknown
#   root_type: formal | temporary | none
#   high_risk_allowed: true | false
#
# Rules (conservative - when in doubt, say temporary / not allowed):
#  - formal: BL unlocked (flash.locked=0 or verifiedbootstate=orange/yellow)
#    AND a real root manager binary present AND its module dir exists.
#  - temporary: root binary present but BL still reports locked/green,
#    or vbmeta device_state=locked while a root daemon is running.
#    This is the "temp root without unlocking BL" case: hiding high-risk
#    features is mandatory, because a later relock / OTA can brick.
#  - none: no root manager found.
# This script never writes to any partition and never changes BL state.
# It only READS getprop and checks for binaries / directories.

OUT_DIR=/data/adb/wenprivacyguard
OUT="$OUT_DIR/root_status.json"
mkdir -p "$OUT_DIR"

FLASH_LOCKED=$(getprop ro.boot.flash.locked 2>/dev/null)
VBS=$(getprop ro.boot.verifiedbootstate 2>/dev/null)
VBMETA_STATE=$(getprop ro.boot.vbmeta.device_state 2>/dev/null)
BL_UNLOCKED="unknown"
[ "$FLASH_LOCKED" = "0" ] && BL_UNLOCKED="false"
[ "$FLASH_LOCKED" = "1" ] && BL_UNLOCKED="true"
[ "$VBS" = "orange" ] && BL_UNLOCKED="false"
[ "$VBS" = "yellow" ] && BL_UNLOCKED="false"
[ "$VBS" = "green" ] && BL_UNLOCKED="true"

SOLUTION="none"
command -v magisk >/dev/null 2>&1 && SOLUTION="magisk"
command -v ksud >/dev/null 2>&1 && SOLUTION="kernelsu"
command -v apd >/dev/null 2>&1 && SOLUTION="apatch"

ROOT_TYPE="none"; HIGH_RISK="false"
if [ "$SOLUTION" != "none" ]; then
  if [ "$BL_UNLOCKED" = "false" ]; then
    ROOT_TYPE="formal"; HIGH_RISK="true"
  elif [ "$BL_UNLOCKED" = "true" ]; then
    # BL locked but root daemon present = temporary root. Downgrade.
    ROOT_TYPE="temporary"; HIGH_RISK="false"
  else
    # Unknown BL state: do not assume formal. Downgrade.
    ROOT_TYPE="temporary"; HIGH_RISK="false"
  fi
fi

# vbmeta locked is a second signal for temporary root.
if [ "$VBMETA_STATE" = "locked" ] && [ "$ROOT_TYPE" = "formal" ]; then
  ROOT_TYPE="temporary"; HIGH_RISK="false"
fi

cat > "$OUT" <<EOF
{
  "root_solution": "$SOLUTION",
  "bootloader_locked": "$BL_UNLOCKED",
  "verified_boot_state": "${VBS:-unknown}",
  "vbmeta_device_state": "${VBMETA_STATE:-unknown}",
  "root_type": "$ROOT_TYPE",
  "high_risk_allowed": $HIGH_RISK,
  "checked_at": "$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null)"
}
EOF
chmod 0600 "$OUT"
echo "root_detect: solution=$SOLUTION bl_locked=$BL_UNLOCKED vbs=${VBS:-unknown} type=$ROOT_TYPE high_risk=$HIGH_RISK"
