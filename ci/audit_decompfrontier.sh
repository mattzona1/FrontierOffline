#!/usr/bin/env bash
set -euo pipefail

ROOT="${PWD}/.decompfrontier"
rm -rf "$ROOT"
mkdir -p "$ROOT"

clone_repo() {
  local name="$1"
  local url="$2"
  echo "==> cloning $name"
  git clone --depth 1 "$url" "$ROOT/$name"
}

clone_repo client https://github.com/decompfrontier/client.git
clone_repo server https://github.com/decompfrontier/server.git
clone_repo offline-diff https://github.com/decompfrontier/offline-diff.git

CLIENT="$ROOT/client"
SERVER="$ROOT/server"
DIFF="$ROOT/offline-diff"

BFCONFIG="$CLIENT/src/android/app/src/main/java/sg/gumi/util/BFConfig.java"
BUILD_GRADLE="$CLIENT/src/android/app/build.gradle"

[[ -f "$BFCONFIG" ]] || { echo "Missing BFConfig.java"; exit 10; }
[[ -f "$BUILD_GRADLE" ]] || { echo "Missing Android build.gradle"; exit 11; }
[[ -f "$SERVER/CMakeLists.txt" ]] || { echo "Missing server CMakeLists.txt"; exit 12; }
[[ -f "$DIFF/README.MD" || -f "$DIFF/README.md" ]] || { echo "Missing offline-diff README"; exit 13; }

echo "==> enabling upstream offline mode in audit workspace"
sed -i 's/final public static boolean OFFLINE_MODE = false;/final public static boolean OFFLINE_MODE = true;/' "$BFCONFIG"
grep -q 'OFFLINE_MODE = true' "$BFCONFIG"

echo "==> checking localhost offline patch contract"
grep -R -q '127\.0\.0\.1' "$DIFF" || { echo "offline-diff no longer advertises localhost routing"; exit 14; }

echo "==> Android client configuration"
grep -E 'applicationId|compileSdkVersion|minSdkVersion|targetSdkVersion|ndkVersion|versionName' "$BUILD_GRADLE" || true

echo "==> Online SDK dependencies to neutralize for a true offline build"
grep -E 'firebase|facebook|appsflyer|tapjoy|billing|play-services|pusher' "$BUILD_GRADLE" || true

echo "==> Server deploy payload"
find "$SERVER/deploy" -type f 2>/dev/null | wc -l
find "$SERVER/deploy/system" -type f -name '*.json' 2>/dev/null | wc -l

echo "==> Offline patch files"
find "$DIFF" -type f | sed "s#$DIFF/##" | head -200

echo "==> AUDIT_OK"
