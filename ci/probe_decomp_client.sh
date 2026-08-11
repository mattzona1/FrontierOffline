#!/usr/bin/env bash
set -uo pipefail

ROOT="${PWD}/.decompfrontier-client-probe"
rm -rf "$ROOT"
git clone --depth 1 https://github.com/decompfrontier/client.git "$ROOT"

BFCONFIG="$ROOT/src/android/app/src/main/java/sg/gumi/util/BFConfig.java"
BRAVEFRONTIER="$ROOT/src/android/app/src/main/java/sg/gumi/bravefrontier/BraveFrontier.java"
APP_GRADLE="$ROOT/src/android/app/build.gradle"
SETTINGS="$ROOT/src/android/settings.gradle"
CMAKE="$ROOT/CMakeLists.txt"
SRC_CMAKE="$ROOT/src/CMakeLists.txt"
LIBS_CMAKE="$ROOT/libs/CMakeLists.txt"
CCCOMMON="$ROOT/libs/cocos2d-x/cocos2dx/platform/android/CCCommon.cpp"
BASESCENE_HPP="$ROOT/src/BaseScene.hpp"
BASESCENE_CPP="$ROOT/src/BaseScene.cpp"
GAMESPRITE_HPP="$ROOT/src/GameSprite.hpp"
COMMONUTILS_CPP="$ROOT/src/CommonUtils.cpp"
SCRLLAYER_CPP="$ROOT/src/ScrlLayer.cpp"
NATIVE_CALLBACK_CPP="$ROOT/src/NativeCallbackHandler.cpp"

sed -i 's/final public static boolean OFFLINE_MODE = false;/final public static boolean OFFLINE_MODE = true;/' "$BFCONFIG"
sed -i "/id 'com.google.gms.google-services'/d" "$APP_GRADLE"
sed -i "/classpath 'com.google.gms:google-services:/d" "$SETTINGS"

# True offline architecture: do not launch decompfrontier's embedded HTTP
# server. Local game data/state will be resolved in-process instead.
python3 - "$BRAVEFRONTIER" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '''        if (OFFLINE_MODE) { // __DECOMP__
            it.arves100.gimuserver.OfflineMod.startOfflineServer();
        }
'''
new = '''        if (OFFLINE_MODE) { // FrontierOffline: direct/in-process offline mode
            Log.i("FrontierOffline", "Offline mode active; embedded HTTP server disabled");
        }
'''
if old not in s:
    raise SystemExit('Expected upstream OfflineMod startup block not found')
p.write_text(s.replace(old, new, 1))
PY

# Upstream currently preserves complete native dependency/header trees for
# arm64-v8a and x86_64. Build only ARM64 so CMake uses the matching recovered
# libraries instead of configuring legacy ABIs whose dependency trees are not
# present in the repository.
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

# Keep cocos2d-x 2.0.3 on C++98 while compiling only the recovered Brave
# Frontier game target as C++11. The renderer/touch JNI translation units are
# compiled directly into libgame.so so Android's name-resolved exports cannot
# be dead-stripped from the static cocos archive.
python3 - "$CMAKE" "$SRC_CMAKE" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
src = Path(sys.argv[2])

s = root.read_text()
s = s.replace('set(CMAKE_CXX_STANDARD_REQUIRED 98)', 'set(CMAKE_CXX_STANDARD_REQUIRED ON)', 1)
old = 'elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "arm")'
new = 'elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "arm" OR "${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "armv7-a")'
if old not in s:
    raise SystemExit('Expected ARM architecture branch not found in upstream CMakeLists.txt')
s = s.replace(old, new, 1)
root.write_text(s)

s = src.read_text()
needle = 'target_link_libraries(${TARGET} PRIVATE cocos2d-x picojson)'
if needle not in s:
    raise SystemExit('Expected game target link line not found in src/CMakeLists.txt')
insert = '''set_property(TARGET ${TARGET} PROPERTY CXX_STANDARD 11)
set_property(TARGET ${TARGET} PROPERTY CXX_STANDARD_REQUIRED ON)

if(ANDROID)
    target_sources(${TARGET} PRIVATE
        "${CMAKE_SOURCE_DIR}/libs/cocos2d-x/cocos2dx/platform/android/jni/Java_org_cocos2dx_lib_Cocos2dxRenderer.cpp"
        "${CMAKE_SOURCE_DIR}/libs/cocos2d-x/cocos2dx/platform/android/jni/TouchesJni.cpp")
endif()

'''
src.write_text(s.replace(needle, insert + needle, 1))
PY

# The recovered cocos CMake only globs one directory level. Restore the nested
# source groups required by cocos2d-x 2.0.3: Kazmath, array/data helpers, and
# zip/minizip support.
python3 - "$LIBS_CMAKE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
needle = 'add_library(cocos2d-x ${COCOS_LIB_TYPE} ${COCOS_SOURCES})'
if needle not in s:
    raise SystemExit('Expected cocos2d-x add_library line not found')
extra = '''file(GLOB_RECURSE COCOS_KAZMATH_SOURCES
    "${COCOS2DX_ROOT}/cocos2dx/kazmath/src/*.c")
file(GLOB COCOS_DATA_SUPPORT_SOURCES
    "${COCOS2DX_ROOT}/cocos2dx/support/data_support/*.cpp"
    "${COCOS2DX_ROOT}/cocos2dx/support/data_support/*.c")
file(GLOB COCOS_ZIP_SUPPORT_SOURCES
    "${COCOS2DX_ROOT}/cocos2dx/support/zip_support/*.cpp"
    "${COCOS2DX_ROOT}/cocos2dx/support/zip_support/*.c")
list(APPEND COCOS_SOURCES
    ${COCOS_KAZMATH_SOURCES}
    ${COCOS_DATA_SUPPORT_SOURCES}
    ${COCOS_ZIP_SUPPORT_SOURCES})

'''
p.write_text(s.replace(needle, extra + needle, 1))
PY

# Upstream references picojson 1.1.0 but does not ship the header.
mkdir -p "$ROOT/libs/picojson"
curl -fL --retry 3 https://raw.githubusercontent.com/kazuho/picojson/v1.1.0/picojson.h -o "$ROOT/libs/picojson/picojson.h"

# Linux/Android builds are case-sensitive. Restore BaseScene's actual filename
# and forward declarations needed before pointer parameters are parsed.
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

# GameSprite.hpp duplicates four definitions that also exist in GameSprite.cpp.
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

# Several useful CommonUtils implementations are preserved upstream inside a
# disabled decompilation block. Restore only the three currently required by
# live recovered code, using cocos runtime dimensions directly.
cat >> "$COMMONUTILS_CPP" <<'CPP'

// FrontierOffline recovery shims: minimal live implementations required by
// GameLayer/GameSprite while the larger decompilation block remains disabled.
int CommonUtils::getScreenWidth()
{
    cocos2d::CCDirector* director = cocos2d::CCDirector::sharedDirector();
    return director ? static_cast<int>(director->getWinSize().width) : 480;
}

int CommonUtils::getScreenHeight()
{
    cocos2d::CCDirector* director = cocos2d::CCDirector::sharedDirector();
    return director ? static_cast<int>(director->getWinSize().height) : 800;
}

cocos2d::CCPoint CommonUtils::convertPosition(float width, float height)
{
    cocos2d::CCDirector* director = cocos2d::CCDirector::sharedDirector();
    const float screenHeight = director ? director->getWinSize().height : 800.0f;
    return cocos2d::CCPoint(width, screenHeight - height);
}
CPP

# ScrlLayer.cpp was recovered as an empty translation unit even though the
# initial GameLayer path uses its constructor and two positioning methods.
cat >> "$SCRLLAYER_CPP" <<'CPP'

ScrlLayer::ScrlLayer()
{
    m_scrollPosition = cocos2d::CCPoint(0.0f, 0.0f);
    m_scrollVertical = cocos2d::CCPoint(0.0f, 0.0f);
    m_currentSize = cocos2d::CCPoint(0.0f, 0.0f);
    m_maxPosition = cocos2d::CCPoint(0.0f, 0.0f);
    m_touchScrollPosition = cocos2d::CCPoint(0.0f, 0.0f);
    m_isMoveDest = false;
    m_isVerticalScrollEnable = false;
    m_isHorizontalScrollEnable = false;
    m_reverseScroll = false;
    m_isTouchInScrollArea = false;
    m_lockDrug = false;
    m_lockScroll = false;
    m_isActive = true;
    m_offsetX = 0.0f;
    m_offsetY = 0.0f;
    m_isSlideEnable = false;
    m_slideEnable = false;
    m_touchScrollType = SCROLL_TOUCH_NONE;
    m_pScrollBar = NULL;
}

void ScrlLayer::setOffset(float x, float y)
{
    m_offsetX = x;
    m_offsetY = y;
}

void ScrlLayer::setLayerPosition(cocos2d::CCPoint point)
{
    cocos2d::CCLayer::setPosition(point);
    m_scrollPosition = point;
}
CPP

# Restore the one missing callback body and make sharedHandler safe to call.
python3 - "$NATIVE_CALLBACK_CPP" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
needle = 'NativeCallbackHandler* NativeCallbackHandler::sharedHandler()\n{\n    return NULL;\n}'
if needle not in s:
    raise SystemExit('Expected NativeCallbackHandler::sharedHandler body not found')
replacement = '''void NativeCallbackHandler::playPhonePurchaseFailCallBack()
{
}

NativeCallbackHandler* NativeCallbackHandler::sharedHandler()
{
    static NativeCallbackHandler handler;
    return &handler;
}'''
p.write_text(s.replace(needle, replacement, 1))
PY

# cocos2d-x 2.0.3 predates modern -Wformat-security defaults.
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

echo '=== BFConfig / offline / recovered-source compatibility ==='
grep -n 'OFFLINE_MODE' "$BFCONFIG" || true
grep -n 'embedded HTTP server disabled' "$BRAVEFRONTIER" || true
grep -n -A3 'abiFilters' "$APP_GRADLE" || true
grep -n 'CXX_STANDARD 11' "$SRC_CMAKE" || true
grep -n 'Cocos2dxRenderer.cpp' "$SRC_CMAKE" || true
grep -n 'TouchesJni.cpp' "$SRC_CMAKE" || true
grep -n 'COCOS_KAZMATH_SOURCES' "$LIBS_CMAKE" || true
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
