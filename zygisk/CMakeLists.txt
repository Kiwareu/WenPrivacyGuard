cmake_minimum_required(VERSION 3.18)
project(wenprivacyguard)

# Build with the Android NDK:
#   cmake -B build -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
#         -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28
#   cmake --build build
#
# Zygisk headers: this skeleton deliberately does NOT vendor the Magisk
# zygisk.hpp. For a production build, download the official headers from
# the Magisk repository (or Zygisk Next) and set ZYGISK_INCLUDE_DIR.
# Without them, the target below builds as a plain JNI .so that loads,
# logs, and does nothing to any app process - which is the safe default.
set(ZYGISK_INCLUDE_DIR "" CACHE PATH "Path to official Zygisk headers (zygisk.hpp)")

add_library(wenprivacyguard SHARED src/main.cpp)
target_include_directories(wenprivacyguard PRIVATE include ${ZYGISK_INCLUDE_DIR})
target_compile_features(wenprivacyguard PRIVATE cxx_std_17)
find_library(LOG_LIB log)
target_link_libraries(wenprivacyguard ${LOG_LIB})
set_target_properties(wenprivacyguard PROPERTIES OUTPUT_NAME "wenprivacyguard")
