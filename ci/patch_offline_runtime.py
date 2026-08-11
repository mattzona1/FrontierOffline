#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_offline_runtime.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
java_root = root / "src/android/app/src/main/java/sg/gumi/bravefrontier"
brave = java_root / "BraveFrontier.java"
base = java_root / "BaseGameActivity.java"
afapp = java_root / "AFApplication.java"
manifest = root / "src/android/app/src/main/AndroidManifest.xml"

for p in (brave, base, afapp, manifest):
    if not p.exists():
        raise SystemExit(f"required offline-runtime source missing: {p}")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"offline runtime patch anchor missing: {label}")
    return text.replace(old, new, 1)


# AFApplication is instantiated before the Activity. Make that stage inert in
# offline mode so AppsFlyer cannot initialize or emit attribution traffic.
s = afapp.read_text()
s = replace_once(
    s,
    "        super.onCreate();\n\n        try {",
    "        super.onCreate();\n\n        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {\n"
    "            appsflyerInitialized = false;\n"
    "            Log.i(\"FrontierOffline\", \"AppsFlyer disabled for offline client\");\n"
    "            return;\n"
    "        }\n\n        try {",
    "AFApplication.onCreate",
)
afapp.write_text(s)


# BaseGameActivity normally creates the Google Play Games helper in onCreate
# and assumes it exists in every lifecycle callback. The offline client only
# needs Cocos2dxActivity, so skip the helper and make the callbacks null-safe.
s = base.read_text()
s = replace_once(
    s,
    "        super.onCreate(bundle);\n        mHelper = GameService.createService(this);",
    "        super.onCreate(bundle);\n"
    "        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {\n"
    "            mHelper = null;\n"
    "            return;\n"
    "        }\n"
    "        mHelper = GameService.createService(this);",
    "BaseGameActivity.onCreate",
)
s = replace_once(
    s,
    "        mHelper.onActivityResult(requestCode, resultCode, intent);",
    "        if (mHelper != null) {\n            mHelper.onActivityResult(requestCode, resultCode, intent);\n        }",
    "BaseGameActivity.onActivityResult",
)
s = replace_once(
    s,
    "        return mHelper.isSignedIn();",
    "        return mHelper != null && mHelper.isSignedIn();",
    "BaseGameActivity.isSignedIn",
)
for method in ("onPause", "onResume", "onStart", "onStop"):
    old = f"        mHelper.{method}(this);"
    new = f"        if (mHelper != null) {{\n            mHelper.{method}(this);\n        }}"
    s = replace_once(s, old, new, f"BaseGameActivity.{method}")
base.write_text(s)


# BraveFrontier's original onCreate initializes a long list of online SDKs and
# calls a JNI initialize method that has not yet been recovered. Cocos2dxActivity
# has already created the GL view by the time super.onCreate returns, so the
# offline branch can finish activity setup and return before all server-era code.
s = brave.read_text()
old = '''        super.onCreate(bundle);
        FirebaseCrashlytics.getInstance().setCrashlyticsCollectionEnabled(true);
        checkLoadedLibraries();
        context = getApplicationContext();
        act = this;
        savedInstanceState = bundle;
'''
new = '''        super.onCreate(bundle);
        checkLoadedLibraries();
        context = getApplicationContext();
        act = this;
        savedInstanceState = bundle;

        if (OFFLINE_MODE) {
            Log.i("FrontierOffline", "Starting direct offline activity path");
            setVolumeControlStream(3);
            hideSystemUI();
            isInitialized = true;
            return;
        }

        FirebaseCrashlytics.getInstance().setCrashlyticsCollectionEnabled(true);
'''
s = replace_once(s, old, new, "BraveFrontier.onCreate offline branch")

s = replace_once(
    s,
    '''    public void onBackPressed() {
        if (Cocos2dxHelper.isNativeLibraryLoaded()) {
            BraveFrontierJNI.backButtonCallback();
        }
    }
''',
    '''    public void onBackPressed() {
        if (OFFLINE_MODE) {
            super.onBackPressed();
            return;
        }
        if (Cocos2dxHelper.isNativeLibraryLoaded()) {
            BraveFrontierJNI.backButtonCallback();
        }
    }
''',
    "BraveFrontier.onBackPressed",
)

s = replace_once(
    s,
    '''    public void onPause() {
        super.onPause();
        if (BFVideoView.isInstance()) {
''',
    '''    public void onPause() {
        super.onPause();
        if (OFFLINE_MODE) {
            return;
        }
        if (BFVideoView.isInstance()) {
''',
    "BraveFrontier.onPause",
)

s = replace_once(
    s,
    '''    public void onResume() {
        super.onResume();
        hideSystemUI();
        if (BFVideoView.isInstance()) {
''',
    '''    public void onResume() {
        super.onResume();
        hideSystemUI();
        if (OFFLINE_MODE) {
            return;
        }
        if (BFVideoView.isInstance()) {
''',
    "BraveFrontier.onResume",
)

s = replace_once(
    s,
    '''    protected void onStart() {
        super.onStart();
        if (!org.cocos2dx.lib.Cocos2dxHelper.isNativeLibraryLoaded()) {
''',
    '''    protected void onStart() {
        super.onStart();
        if (OFFLINE_MODE) {
            return;
        }
        if (!org.cocos2dx.lib.Cocos2dxHelper.isNativeLibraryLoaded()) {
''',
    "BraveFrontier.onStart",
)

s = replace_once(
    s,
    '''    protected void onStop() {
        super.onStop();
        if (fiverocksInitialized) {
''',
    '''    protected void onStop() {
        super.onStop();
        if (OFFLINE_MODE) {
            return;
        }
        if (fiverocksInitialized) {
''',
    "BraveFrontier.onStop",
)
brave.write_text(s)


# Make the network disconnect enforceable at the Android sandbox level. The
# tools:node markers prevent transitive SDK manifests from re-adding these
# permissions during manifest merge.
s = manifest.read_text()
s = replace_once(
    s,
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n          xmlns:tools="http://schemas.android.com/tools">',
    "manifest tools namespace",
)
for permission in (
    "android.permission.INTERNET",
    "android.permission.ACCESS_WIFI_STATE",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.READ_PHONE_STATE",
    "android.permission.READ_PRIVILEGED_PHONE_STATE",
):
    plain = f'    <uses-permission android:name="{permission}"/>'
    marker = f'    <uses-permission android:name="{permission}" tools:node="remove"/>'
    if plain in s:
        s = s.replace(plain, marker, 1)
manifest.write_text(s)

print("Applied direct offline runtime patch:")
print(" - AppsFlyer startup disabled")
print(" - Google Play Games activity helper disabled")
print(" - BraveFrontier online SDK/JNI startup path bypassed")
print(" - offline lifecycle callbacks hardened")
print(" - INTERNET/network/phone-state permissions marked for removal")

# These helpers extend the same direct-offline architecture. Keep this ordered:
# local state/downloads first, then replace the temporary native recovery app
# with the BF Home/Quest flow, then add the local native battle on top.
import os
import subprocess
workspace = Path(os.environ.get("GITHUB_WORKSPACE", Path(__file__).resolve().parents[1]))
for helper in (
    "add_offline_player_state.py",
    "patch_offline_downloads.py",
    "patch_recovery_hub.py",
    "patch_native_battle.py",
):
    helper_path = workspace / "ci" / helper
    if not helper_path.exists():
        raise SystemExit(f"required offline helper missing: {helper_path}")
    subprocess.check_call([sys.executable, str(helper_path), str(root)])
