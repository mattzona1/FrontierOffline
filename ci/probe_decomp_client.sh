#!/usr/bin/env bash
set -uo pipefail

ROOT="${PWD}/.decompfrontier-client-probe"
rm -rf "$ROOT"
git clone --depth 1 https://github.com/decompfrontier/client.git "$ROOT"

BFCONFIG="$ROOT/src/android/app/src/main/java/sg/gumi/util/BFConfig.java"
APP_GRADLE="$ROOT/src/android/app/build.gradle"
SETTINGS="$ROOT/src/android/settings.gradle"
CMAKE="$ROOT/CMakeLists.txt"

sed -i 's/final public static boolean OFFLINE_MODE = false;/final public static boolean OFFLINE_MODE = true;/' "$BFCONFIG"

# The offline build must not require a Firebase project merely to configure Gradle.
# Keep runtime classes for this first probe; only remove the google-services Gradle plugin.
sed -i "/id 'com.google.gms.google-services'/d" "$APP_GRADLE"
sed -i "/classpath 'com.google.gms:google-services:/d" "$SETTINGS"

# Modern Android CMake reports the 32-bit ARM processor as armv7-a, while the
# reverse-engineered client bootstrap only recognizes "arm". Both map to the
# same preserved armeabi-v7a library set.
python3 - "$CMAKE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = 'elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "arm")'
new = 'elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "arm" OR "${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "armv7-a")'
if old not in s:
    raise SystemExit('Expected ARM architecture branch not found in upstream CMakeLists.txt')
p.write_text(s.replace(old, new, 1))
PY

# Upstream references picojson 1.1.0 in CMake but the header is not actually
# present in the repository. Supply the matching single-header dependency so
# CMake can advance to compiling the decompiled client.
mkdir -p "$ROOT/libs/picojson"
curl -fL --retry 3 \
  https://raw.githubusercontent.com/kazuho/picojson/v1.1.0/picojson.h \
  -o "$ROOT/libs/picojson/picojson.h"

echo '=== BFConfig ==='
grep -n 'OFFLINE_MODE' "$BFCONFIG" || true
echo '=== Android arch compatibility ==='
grep -n 'armv7-a' "$CMAKE" || true
echo '=== picojson ==='
ls -lh "$ROOT/libs/picojson/picojson.h"

echo '=== Gradle version ==='
cd "$ROOT/src/android"
chmod +x gradlew
./gradlew --version

echo '=== Assemble debug ==='
set +e
./gradlew :app:assembleDebug --stacktrace --no-daemon 2>&1 | tee "${GITHUB_WORKSPACE:-$PWD}/decomp-client-build.log"
code=${PIPESTATUS[0]}
set -e

echo "BUILD_EXIT_CODE=$code" | tee -a "${GITHUB_WORKSPACE:-$PWD}/decomp-client-build.log"
if [ "$code" -eq 0 ]; then
  find app/build/outputs -type f -name '*.apk' -print -exec ls -lh {} \; | tee -a "${GITHUB_WORKSPACE:-$PWD}/decomp-client-build.log"
  echo 'DECOMP_CLIENT_BUILD_OK' | tee -a "${GITHUB_WORKSPACE:-$PWD}/decomp-client-build.log"
else
  echo 'DECOMP_CLIENT_BUILD_BLOCKED' | tee -a "${GITHUB_WORKSPACE:-$PWD}/decomp-client-build.log"
fi
exit "$code"
