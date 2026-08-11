#!/usr/bin/env bash
set -uo pipefail

ROOT="${PWD}/.decompfrontier-client-probe"
rm -rf "$ROOT"
git clone --depth 1 https://github.com/decompfrontier/client.git "$ROOT"

BFCONFIG="$ROOT/src/android/app/src/main/java/sg/gumi/util/BFConfig.java"
APP_GRADLE="$ROOT/src/android/app/build.gradle"
SETTINGS="$ROOT/src/android/settings.gradle"
CMAKE="$ROOT/CMakeLists.txt"
LIBS_CMAKE="$ROOT/libs/CMakeLists.txt"
CCCOMMON="$ROOT/libs/cocos2d-x/cocos2dx/platform/android/CCCommon.cpp"

sed -i 's/final public static boolean OFFLINE_MODE = false;/final public static boolean OFFLINE_MODE = true;/' "$BFCONFIG"
sed -i "/id 'com.google.gms.google-services'/d" "$APP_GRADLE"
sed -i "/classpath 'com.google.gms:google-services:/d" "$SETTINGS"

# Upstream currently preserves complete native dependency/header trees for
# arm64-v8a and x86_64. Build only ARM64 so CMake uses the matching recovered
# libraries instead of configuring legacy ABIs whose dependency trees are not
# present in the repository. ARM64 also matches current Android hardware.
python3 - "$APP_GRADLE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
needle = 'defaultConfig {'
pos = s.find(needle)
if pos < 0:
    raise SystemExit('defaultConfig block not found')
insert = "\n        ndk {\n            abiFilters 'arm64-v8a'\n        }"
brace_end = pos + len(needle)
s = s[:brace_end] + insert + s[brace_end:]
p.write_text(s)
PY

# Retain compatibility with modern CMake's spelling if we later probe the
# legacy 32-bit ARM target again.
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

# Upstream references picojson 1.1.0 but does not ship the header and exposes
# the wrong include root for <picojson/picojson.h>.
mkdir -p "$ROOT/libs/picojson"
curl -fL --retry 3 https://raw.githubusercontent.com/kazuho/picojson/v1.1.0/picojson.h -o "$ROOT/libs/picojson/picojson.h"
python3 - "$LIBS_CMAKE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = 'target_include_directories(picojson INTERFACE ${CMAKE_CURRENT_LIST_DIR}/picojson)'
new = 'target_include_directories(picojson INTERFACE ${CMAKE_CURRENT_LIST_DIR})'
if old not in s:
    raise SystemExit('Expected picojson include path not found in upstream libs/CMakeLists.txt')
p.write_text(s.replace(old, new, 1))
PY

# cocos2d-x 2.0.3 predates modern -Wformat-security defaults. The message is
# data, not a printf format string, so pass it through an explicit "%s".
python3 - "$CCCOMMON" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '__android_log_print(ANDROID_LOG_DEBUG, "cocos2d-x debug info",  buf);'
new = '__android_log_print(ANDROID_LOG_DEBUG, "cocos2d-x debug info", "%s", buf);'
if old not in s:
    raise SystemExit('Expected legacy Android log call not found')
p.write_text(s.replace(old, new, 1))
PY

echo '=== BFConfig / ABI / dependencies ==='
grep -n 'OFFLINE_MODE' "$BFCONFIG" || true
grep -n -A3 'abiFilters' "$APP_GRADLE" || true
grep -n 'armv7-a' "$CMAKE" || true
grep -n '__android_log_print' "$CCCOMMON" || true
ls -lh "$ROOT/libs/picojson/picojson.h"
ls -ld "$ROOT/libs/android/arm64-v8a" || true

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
