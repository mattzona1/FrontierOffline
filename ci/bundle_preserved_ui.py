#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import sys
import urllib.parse
import urllib.request

if len(sys.argv) != 2:
    raise SystemExit("usage: bundle_preserved_ui.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
out_root = root / "data/frontier_offline/ui"
out_root.mkdir(parents=True, exist_ok=True)

# Preserved Brave Frontier UI resources from the aMytho preservation project.
# These are fetched only at build time and become ordinary APK assets. Runtime
# never contacts GitHub, Gumi, or any other network service.
SOURCE_COMMIT = "76538d1a0a98287c3660cedcedd63d7fce3f9cd1"
REPO = "aMytho/brave-frontier-godot"
FILES = {
    "header.png": "Menu/Header/header.png",
    "header_ui.png": "Menu/Header/header_ui.png",
    "footer_base.png": "Menu/Footer/footer_base.png",
    "footer_btn.png": "Menu/Footer/footer_btn.png",
    "nav_home.png": "Menu/Footer/home.png",
    "nav_unit.png": "Menu/Footer/unit.png",
    "nav_town.png": "Menu/Footer/town.png",
    "nav_shop.png": "Menu/Footer/shop.png",
    "nav_summon.png": "Menu/Footer/summon.png",
    "nav_social.png": "Menu/Footer/social.png",
    "home_quest.png": "Menu/Launch Icons/home_win_quest.png",
    "home_gate.png": "Menu/Launch Icons/home_win_gate.png",
    "home_arena.png": "Menu/Launch Icons/home_win_arena.png",
    "home_position.png": "Menu/Launch Icons/home_position_mark.png",
    "home_character_frame.png": "Menu/SubMenu/Home/home_character_frame_bg.png",
    "home_character_bg.png": "Menu/SubMenu/Home/Characters/background.png",
}

manifest = {
    "source": REPO,
    "commit": SOURCE_COMMIT,
    "runtime_network": False,
    "files": {},
}

total = 0
for local_name, source_path in FILES.items():
    quoted = urllib.parse.quote(source_path, safe="/")
    url = f"https://raw.githubusercontent.com/{REPO}/{SOURCE_COMMIT}/{quoted}"
    req = urllib.request.Request(url, headers={"User-Agent": "FrontierOffline-Build/1.0"})
    with urllib.request.urlopen(req, timeout=90) as response:
        data = response.read()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise SystemExit(f"preserved UI source was not PNG: {source_path}")
    if len(data) < 500:
        raise SystemExit(f"preserved UI source unexpectedly tiny: {source_path}")
    (out_root / local_name).write_bytes(data)
    digest = hashlib.sha256(data).hexdigest()
    manifest["files"][local_name] = {
        "source_path": source_path,
        "bytes": len(data),
        "sha256": digest,
    }
    total += len(data)
    print(f"Bundled preserved UI {local_name}: {len(data):,} bytes")

manifest["total_bytes"] = total
(out_root / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")

print(f"Bundled {len(FILES)} preserved Brave Frontier UI assets ({total:,} bytes)")
print("Runtime source: APK assets only; no network access")
