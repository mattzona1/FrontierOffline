#!/usr/bin/env bash
set -uo pipefail

ROOT="${PWD}/.decompfrontier-client-probe"
rm -rf "$ROOT"
git clone --depth 1 https://github.com/decompfrontier/client.git "$ROOT"

BFCONFIG="$ROOT/src/android/app/src/main/java/sg/gumi/util/BFConfig.java"
APP_GRADLE="$ROOT/src/android/app/build.gradle"
SETTINGS="$ROOT/src/android/settings.gradle"
CMAKE="$ROOT/CMakeLists.txt"
CCCOMMON="$ROOT/libs/cocos2d-x/cocos2dx/platform/android/CCCommon.cpp"
BASESCENE_HPP="$ROOT/src/BaseScene.hpp"
BASESCENE_CPP="$ROOT/src/BaseScene.cpp"
GAMESPRITE_HPP="$ROOT/src/GameSprite.hpp"

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

# The recovered game source itself uses C++11 features (constexpr and braced
# initializers), despite the upstream bootstrap currently forcing C++98.
# Modernize only the language level; cocos2d-x 2.0.3 remains source-compatible.
python3 - "$CMAKE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
s = s.replace('set(CMAKE_CXX_STANDARD 98)', 'set(CMAKE_CXX_STANDARD 11)', 1)
s = s.replace('set(CMAKE_CXX_STANDARD_REQUIRED 98)', 'set(CMAKE_CXX_STANDARD_REQUIRED ON)', 1)
old = 'elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "arm")'
new = 'elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "arm" OR "${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "armv7-a")'
if old not in s:
    raise SystemExit('Expected ARM architecture branch not found in upstream CMakeLists.txt')
s = s.replace(old, new, 1)
p.write_text(s)
PY

# Upstream references picojson 1.1.0 but does not ship the header. Its CMake
# already exposes libs/picojson as the include directory and Pch.hpp includes
# <picojson.h>, so place the missing header exactly there.
mkdir -p "$ROOT/libs/picojson"
curl -fL --retry 3 https://raw.githubusercontent.com/kazuho/picojson/v1.1.0/picojson.h -o "$ROOT/libs/picojson/picojson.h"

# Linux/Android builds are case-sensitive. The recovered BaseScene source uses
# the original Windows-style lowercase filename even though the header is
# BaseScene.hpp. BaseScene also needs forward declarations before its pointer
# parameters are parsed; GameLayer.hpp includes NodeStatus only afterwards.
python3 - "$BASESCENE_CPP" "$BASESCENE_HPP" <<'PY'
from pathlib import Path
import sys
cpp = Path(sys.argv[1])
hpp = Path(sys.argv[2])
s = cpp.read_text()
if '#include "baseScene.hpp"' not in s:
    raise SystemExit('Expected recovered baseScene.hpp include not found')
cpp.write_text(s.replace('#include "baseScene.hpp"', '#include "BaseScene.hpp"', 1))

s = hpp.read_text()
needle = '#pragma once\n'
if needle not in s:
    raise SystemExit('BaseScene.hpp pragma not found')
insert = '\nclass GameSprite;\nclass NodeStatus;\n'
hpp.write_text(s.replace(needle, needle + insert, 1))
PY

# GameSprite.hpp contains inline definitions for four accessors that are also
# present in GameSprite.cpp. Keep the recovered out-of-line implementations and
# turn the header copies back into declarations to avoid ODR redefinitions.
python3 - "$GAMESPRITE_HPP" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
repls = {
    'float getHeight() { return getContentSize().height * getScaleY(); }': 'float getHeight();',
    'float getLeft() { return getPosition().x - (getContentSize().width * (getScaleX() / 2)); }': 'float getLeft();',
    'float getTop() { return getPosition().y - (getContentSize().height * (getScaleY() / 2)); }': 'float getTop();',
    'float getWidth() { return getContentSize().width * getScaleX(); }': 'float getWidth();',
}
for old, new in repls.items():
    if old not in s:
        raise SystemExit('Expected GameSprite inline accessor not found: ' + old)
    s = s.replace(old, new, 1)
p.write_text(s)
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

echo '=== BFConfig / ABI / recovered-source compatibility ==='
grep -n 'OFFLINE_MODE' "$BFCONFIG" || true
grep -n -A3 'abiFilters' "$APP_GRADLE" || true
grep -n 'CMAKE_CXX_STANDARD' "$CMAKE" || true
grep -n 'armv7-a' "$CMAKE" || true
grep -n 'class NodeStatus' "$BASESCENE_HPP" || true
grep -n 'BaseScene.hpp' "$BASESCENE_CPP" || true
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
