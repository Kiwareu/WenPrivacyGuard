#!/system/bin/sh
# Wen Privacy Guard - uninstall: restore everything we disabled, then clean up.
# Reversible by design: every disable was `pm disable-user --user 0`, so
# `pm enable` restores it. Nothing was uninstalled, nothing was written to /system.
MODDIR=/data/adb/modules/wenprivacyguard
CFG="$MODDIR/config.json"

if [ -f "$CFG" ]; then
  # Best-effort restore: parse the component keys out of config.json with
  # plain shell tools (no jq dependency on device).
  for pkg in $(grep -o '"com\.[a-zA-Z0-9._]*"' "$CFG" | tr -d '"' | sort -u); do
    pm enable --user 0 "$pkg" >/dev/null 2>&1
  done
fi

# Also re-enable the curated list, in case config was edited by hand.
for pkg in com.mobiletools.systemhelper com.miui.analytics com.xiaomi.misystem com.miui.miservice com.oppo.opporesearch com.coloros.safecenter com.vivo.analytics com.bbk.account; do
  pm enable --user 0 "$pkg" >/dev/null 2>&1
done

rm -rf /data/adb/wenprivacyguard /data/system/wenprivacyguard_* 2>/dev/null
exit 0
