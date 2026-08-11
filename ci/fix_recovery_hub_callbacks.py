#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: fix_recovery_hub_callbacks.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
main_android = root / "src/Main_Android.cpp"
s = main_android.read_text()
marker = '#ifdef __ANDROID__\nstatic const char* FRONTIER_OFFLINE_JNI = "sg/gumi/bravefrontier/BraveFrontierJNI";'
replacement = '#ifdef __ANDROID__\nusing cocos2d::SEL_MenuHandler;\nstatic const char* FRONTIER_OFFLINE_JNI = "sg/gumi/bravefrontier/BraveFrontierJNI";'
if marker not in s:
    raise SystemExit("recovery hub callback namespace anchor missing")
main_android.write_text(s.replace(marker, replacement, 1))
print("Imported legacy cocos2d::SEL_MenuHandler for menu_selector macro")
