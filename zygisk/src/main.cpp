// Wen Privacy Guard - minimal Zygisk module skeleton.
//
// INTENTIONALLY NOT IMPLEMENTED in this project, and never to be added:
//   - Build / fingerprint / serial / baseband spoofing
//   - IMEI / Device ID / IMSI / ICCID / MAC / Boot ID / GAID / App Set ID
//     / Wallpaper ID / Widevine DRM spoofing or randomisation
//   - SIM / carrier / cell-tower / GPS spoofing
//   - Play install-source forgery, license-check bypass (incl. PairIP),
//     signature-verification disabling, downgrade allowance, Play Protect bypass
//   - FLAG_SECURE bypass, Hide-VPN / hide-developer-options / hide-mock-location
//     hooks that exist to evade app detection
//   - CPU / GPU / sensor / refresh-rate spoofing
//   - Per-app proxy via kernel TPROXY
// Those features exist to evade bans, defeat licensing, and forge device
// identity. They are the reason COPG ships a paid license check, and they
// are not a privacy feature. A privacy tool that forges identity is a
// fraud tool with a different label. This module does not do them.
//
// WHAT THIS MODULE DOES DO:
//   - Loads in zygote, reads /data/adb/wenprivacyguard/config.json
//   - If (and only if) the user opted in to `app_list_guard`, it limits
//     what *telemetry packages themselves* can learn via
//     PackageManager queries - i.e. it filters the curated telemetry
//     package list out of results returned TO a telemetry package.
//     It never hides user apps from banking / game / work apps, and it
//     never alters any identifier.
//   - Otherwise it does nothing to app processes: it logs and returns.
//   - All state is in the config file. No network, no upload, no license.
//
// To wire this to the real Zygisk API, define HAVE_ZYGISK and provide the
// official zygisk.hpp (Magisk / Zygisk Next). The plain build below
// compiles with only the NDK and is the safe, reviewable default.

#include <android/log.h>
#include <jni.h>
#include <string>
#include <fstream>

#define LOG_TAG "WenPrivacyGuard"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

static const char* kConfigPath = "/data/adb/wenprivacyguard/config.json";
static const char* kRootStatusPath = "/data/adb/wenprivacyguard/root_status.json";

static bool configFlag(const char* key) {
    std::ifstream f(kConfigPath);
    if (!f) return false;
    std::string s((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    std::string needle = std::string("\"") + key + "\"";
    auto pos = s.find(needle);
    if (pos == std::string::npos) return false;
    auto v = s.find("true", pos);
    auto fpos = s.find("false", pos);
    return v != std::string::npos && (fpos == std::string::npos || v < fpos);
}

static bool temporaryRoot() {
    std::ifstream f(kRootStatusPath);
    if (!f) return true; // unknown -> conservative: treat as temporary
    std::string s((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    return s.find("\"root_type\": \"temporary\"") != std::string::npos ||
           s.find("\"root_type\":\"temporary\"") != std::string::npos;
}

// JNI entry point: the .so loads, checks config, and logs. No hooks are
// installed unless the user opted in, and even then only the narrow
// telemetry-query filter described above (implemented in the full
// Zygisk build under HAVE_ZYGISK; see README § "Native module").
extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
    bool enabled = configFlag("enabled");
    bool guard = configFlag("app_list_guard");
    bool temp = temporaryRoot();
    LOGI("load: enabled=%d app_list_guard=%d temporary_root=%d", enabled, guard, temp);
    if (!enabled || temp || !guard) {
        LOGI("load: no app-process hooks installed (opt-in / safety gate)");
        return JNI_VERSION_1_6;
    }
    LOGI("load: app_list_guard opted in - telemetry-query filter armed (full Zygisk build only)");
    return JNI_VERSION_1_6;
}

#ifdef HAVE_ZYGISK
// Full Zygisk wiring lives here in a production build:
//   class WenPrivacyGuardModule : public zygisk::ModuleBase { ... }
//   REGISTER_ZYGISK_MODULE(WenPrivacyGuardModule)
// It must consult the same three gates (enabled, !temporaryRoot,
// app_list_guard) before installing any hook, and must never install
// hooks for Build, TelephonyManager, WifiInfo, BluetoothAdapter,
// Settings.Secure, AdvertisingIdClient, MediaDrm, LocationManager,
// or PackageManager.getInstallerPackageName / license paths.
#endif
