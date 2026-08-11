#!/usr/bin/env bash
set -uo pipefail

ROOT="${PWD}/.decompfrontier-client-probe"
rm -rf "$ROOT"
git clone --depth 1 https://github.com/decompfrontier/client.git "$ROOT"

BFCONFIG="$ROOT/src/android/app/src/main/java/sg/gumi/util/BFConfig.java"
APP_GRADLE="$ROOT/src/android/app/build.gradle"
SETTINGS="$ROOT/src/android/settings.gradle"

sed -i 's/final public static boolean OFFLINE_MODE = false;/final public static boolean OFFLINE_MODE = true;/' "$BFCONFIG"

# The offline build must not require a Firebase project merely to configure Gradle.
# Keep runtime classes for this first probe; only remove the google-services Gradle plugin.
sed -i "/id 'com.google.gms.google-services'/d" "$APP_GRADLE"
sed -i "/classpath 'com.google.gms:google-services:/d" "$SETTINGS"

echo '=== BFConfig ==='
grep -n 'OFFLINE_MODE' "$BFCONFIG" || true

echo '=== Gradle version ==='
cd "$ROOT/src/android"
chmod +x gradlew
./gradlew --version

echo '=== Assemble debug ==='
set +e
./gradlew :app:assembleDebug --stacktrace --no-daemon 2>&1 | tee "${GITHUB_WORKSPACE:-$PWD}/decomp-client-build.log"
code=${PIPESTATUS[0]}
set -e

echo "BUILD_EXIT_CODE=$code"
if [ "$code" -eq 0 ]; then
  find app/build/outputs -type f -name '*.apk' -print -exec ls -lh {} \;
  echo 'DECOMP_CLIENT_BUILD_OK'
else
  echo 'DECOMP_CLIENT_BUILD_BLOCKED'
fi
exit "$code"
