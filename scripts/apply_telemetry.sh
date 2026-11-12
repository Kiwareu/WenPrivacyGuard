#!/system/bin/sh
# Wen Privacy Guard - apply only user-ticked telemetry components.
# ONLY allowed operation: `pm disable-user --user 0 <pkg>` (reversible).
# No uninstall, no pm uninstall, no file deletion, no partition writes.
# Packages NOT ticked in config.json are left untouched, and packages
# ticked OFF again are re-enabled (pm enable) so un-ticking undoes it.
MODDIR=${0%/*}
CFG=/data/adb/wenprivacyguard/config.json
DB="$MODDIR/scripts/telemetry_db.json"
LOG=/data/adb/wenprivacyguard/apply.log

[ -f "$CFG" ] || exit 0
[ -f "$DB" ] || exit 0

# Extract the curated package list from telemetry_db.json (no jq on device).
for pkg in $(grep -o '"package"[[:space:]]*:[[:space:]]*"[^"]*"' "$DB" | sed 's/.*"\([^"]*\)"$/\1/'); do
  # Is this package ticked true in the user's config?
  if grep -q "\"$pkg\"[[:space:]]*:[[:space:]]*true" "$CFG" 2>/dev/null; then
    # Only disable if it is currently installed for user 0.
    if pm list packages --user 0 2>/dev/null | grep -q "package:$pkg$"; then
      pm disable-user --user 0 "$pkg" >/dev/null 2>&1
      echo "$(date '+%Y-%m-%d %H:%M:%S') disabled $pkg (user opted in)" >> "$LOG"
    fi
  else
    # Not ticked: make sure a previous tick is undone.
    pm enable --user 0 "$pkg" >/dev/null 2>&1
  fi
done
exit 0
