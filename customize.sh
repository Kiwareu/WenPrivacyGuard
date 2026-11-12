#!/system/bin/sh
# Wen Privacy Guard - customize.sh (runs at flash time, in recovery/manager)
# Safety rules enforced here, before anything is installed:
#  1. No partition operations. No writes to dynamic partitions
#     (super / system / vendor / odm / product / vbmeta) anywhere here.
#     (build.sh greps for them and fails the build if they appear.)
#  2. Exactly one root solution. Magisk built-in Zygisk must be OFF:
#     this module needs Zygisk Next / ReZygisk / NeoZygisk.
#  3. Nothing is enabled by default. config.json is created all-off.
#  4. Root-type detection runs now AND at every boot (service.sh).
#     Temporary-root devices get high-risk features hidden in WebUI.

ui_print "  Wen Privacy Guard 1.0.0"
ui_print "  Free / opt-in / reversible. No spoofing, no license bypass."

# --- exactly one root solution -------------------------------------------
ROOT_COUNT=0; ROOT_NAME=""
command -v magisk >/dev/null 2>&1 && { ROOT_COUNT=$((ROOT_COUNT+1)); ROOT_NAME="Magisk"; }
command -v ksud >/dev/null 2>&1 && { ROOT_COUNT=$((ROOT_COUNT+1)); ROOT_NAME="KernelSU"; }
command -v apd >/dev/null 2>&1 && { ROOT_COUNT=$((ROOT_COUNT+1)); ROOT_NAME="APatch"; }

if [ "$ROOT_COUNT" -eq 0 ]; then
  ui_print "  ! No supported root solution found (Magisk 24+ / KernelSU 0.6.6+ / APatch 0.10+)."
  exit 1
fi
if [ "$ROOT_COUNT" -gt 1 ]; then
  ui_print "  ! Multiple root solutions installed. Keep only one, then re-flash."
  exit 1
fi
ui_print "  Root: $ROOT_NAME"

# --- Zygisk variant --------------------------------------------------------
ZN=false; RZ=false; NEO=false
[ -d /data/adb/modules/zygisksu ] && [ ! -f /data/adb/modules/zygisksu/disable ] && ZN=true
[ -d /data/adb/modules/rezygisk ] && [ ! -f /data/adb/modules/rezygisk/disable ] && RZ=true
[ -d /data/adb/modules/neozygisk ] && [ ! -f /data/adb/modules/neozygisk/disable ] && NEO=true
if [ "$ZN" = false ] && [ "$RZ" = false ] && [ "$NEO" = false ]; then
  ui_print "  ! Zygisk Next / ReZygisk / NeoZygisk not found or disabled."
  ui_print "  ! Install one of them first. Magisk built-in Zygisk is not supported."
  exit 1
fi
if [ "$ROOT_NAME" = "Magisk" ]; then
  Z=$(magisk --sqlite "SELECT value FROM settings WHERE key='zygisk';" 2>/dev/null)
  if [ "$Z" = "value=1" ]; then
    ui_print "  ! Turn OFF Magisk built-in Zygisk first (it conflicts with Next/ReZygisk)."
    exit 1
  fi
fi
ui_print "  Zygisk runtime: OK"

# --- Android version -------------------------------------------------------
API=$(getprop ro.build.version.sdk 2>/dev/null)
if [ -n "$API" ] && [ "$API" -lt 28 ]; then
  ui_print "  ! Android 9 (API 28) or newer is required."
  exit 1
fi

# --- install files, all-off config ----------------------------------------
set_perm_recursive "$MODPATH" 0 0 0755 0644
[ -f "$MODPATH/zygisk/arm64-v8a.so" ] && set_perm "$MODPATH/zygisk/arm64-v8a.so" 0 0 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/scripts/root_detect.sh" 0 0 0755
set_perm "$MODPATH/scripts/apply_telemetry.sh" 0 0 0755

# Fresh install only: never overwrite a user's existing choices.
if [ ! -f /data/adb/wenprivacyguard/config.json ]; then
  mkdir -p /data/adb/wenprivacyguard
  cp "$MODPATH/config.example.json" /data/adb/wenprivacyguard/config.json
  chmod 0600 /data/adb/wenprivacyguard/config.json
  ui_print "  Config created (all features OFF)."
else
  ui_print "  Existing config kept - your choices were not reset."
fi

# Root-type detection now, so WebUI shows the right state on first open.
sh "$MODPATH/scripts/root_detect.sh" "$MODPATH" >/dev/null 2>&1 || true

ui_print "  Done. Reboot, then open WebUI. Everything stays OFF until you tick it."
ui_print "  What this module does NOT do: IMEI / MAC / SIM / GAID / Widevine"
ui_print "  spoofing, Play-source forgery, license-check or signature bypass."
ui_print "  Those are intentionally not implemented - see README.md."
