#!/bin/bash
# Wen Privacy Guard - build + package
#   ./build.sh            # native build (needs $ANDROID_NDK_HOME) + zip
#   ./build.sh --no-native # zip only, with a placeholder .so note
set -euo pipefail
cd "$(dirname "$0")"

# --- safety gate: fail the build if any forbidden operation appears -------
# Only scan executable code, not docs/comments explaining the ban:
# customize.sh service.sh uninstall.sh scripts/ zygisk/ webroot/js/
# (README.md and main.cpp's "NOT IMPLEMENTED" block are documentation.)
if grep -RInE '\bdd\b|lpmake|fastboot (flash|erase|format)|/dev/block/by-name/(super|system|vendor|vbmeta)|getDeviceId\(\)|getImei\(\)' \
    customize.sh service.sh uninstall.sh scripts zygisk/src webroot/js 2>/dev/null | grep -vE '^\s*[^:]+:[0-9]+:\s*(#|//)' | grep -q .; then
  echo "SAFETY GATE FAILED: forbidden operation found in executable code."
  exit 1
fi
echo "[1/3] safety gate passed"

# --- native build ----------------------------------------------------------
if [ "${1:-}" != "--no-native" ]; then
  if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    echo "ANDROID_NDK_HOME not set - run with --no-native for a zip-only build,"
    echo "or set it and re-run for the real .so."
    exit 1
  fi
  cmake -B build -S zygisk \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28
  cmake --build build
  mkdir -p zygisk_out/arm64-v8a
  cp build/libwenprivacyguard.so zygisk_out/arm64-v8a.so
  echo "[2/3] native build done"
else
  echo "[2/3] native build skipped (--no-native)"
fi

# --- package ---------------------------------------------------------------
./make_zip.sh
echo "[3/3] done"
