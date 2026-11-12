#!/system/bin/sh
# Wen Privacy Guard - service.sh (runs at every boot, after boot_completed)
# Only applies what the user explicitly ticked in config.json.
# Crash guard: if we fail 3 boots in a row, stop applying and log it,
# so a bad choice can never bootloop the device.
MODDIR=${0%/*}
CFG=/data/adb/wenprivacyguard/config.json
LOG=/data/adb/wenprivacyguard/service.log
GUARD=/data/system/wenprivacyguard_bootguard

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 3
mkdir -p /data/adb/wenprivacyguard
echo "$(date '+%Y-%m-%d %H:%M:%S') boot: service start" >> "$LOG"

# Root-type detection on every boot (BL state can change after reflash).
sh "$MODDIR/scripts/root_detect.sh" "$MODDIR" >> "$LOG" 2>&1 || true

# If the previous boot never completed after our apply step, count it.
# service.sh only runs after boot_completed, so reaching here means this
# boot is healthy - reset the counter.
echo 0 > "$GUARD" 2>/dev/null; chmod 0644 "$GUARD" 2>/dev/null

# Global kill-switch: if the user turned the module off, do nothing at all.
if ! grep -q '"enabled"[[:space:]]*:[[:space:]]*true' "$CFG" 2>/dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') boot: module disabled in config, nothing applied" >> "$LOG"
  exit 0
fi

# Temporary root: refuse high-risk applies even if config says on.
# (root_detect.sh writes /data/adb/wenprivacyguard/root_status.json)
if grep -q '"root_type"[[:space:]]*:[[:space:]]*"temporary"' /data/adb/wenprivacyguard/root_status.json 2>/dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') boot: temporary root - high-risk applies skipped" >> "$LOG"
  exit 0
fi

# Apply only the ticked telemetry components, reversibly.
sh "$MODDIR/scripts/apply_telemetry.sh" >> "$LOG" 2>&1 || true
echo "$(date '+%Y-%m-%d %H:%M:%S') boot: service done" >> "$LOG"
exit 0
