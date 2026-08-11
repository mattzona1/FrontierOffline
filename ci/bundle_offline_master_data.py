#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import sys
import urllib.request

if len(sys.argv) != 2:
    raise SystemExit("usage: bundle_offline_master_data.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
assets = root / "src/android/app/src/main/assets/frontier_offline/system"
java_root = root / "src/android/app/src/main/java/sg/gumi/bravefrontier"
assets.mkdir(parents=True, exist_ok=True)
java_root.mkdir(parents=True, exist_ok=True)

SERVER_COMMIT = "7cc0ebd3be79ca561874f70224c3ed924224583b"
BASE = f"https://raw.githubusercontent.com/decompfrontier/server/{SERVER_COMMIT}/deploy/system"

# These are static/master tables, not live server responses. Bundling them is
# the first step toward making the original client resolve former server-backed
# content from APK assets and local save state instead of HTTP.
FILES = [
    "defines.json",
    "features.json",
    "information.json",
    "banner_info.json",
    "interactive_banner_info.json",
    "notice_info.json",
    "gacha_info.json",
    "gacha.json",
    "gacha_effects.json",
    "resummon_gacha.json",
    "gift.json",
    "npc.json",
    "login_campaign.json",
    "login_campaign_reward.json",
    "dungeon_keys.json",
    "excluded_dungeons.json",
    "general_event.json",
    "brave_slots.json",
    "receipes.json",
    "help.json",
    "help_sub.json",
    "arena_rank.json",
]

manifest = {
    "source": "decompfrontier/server",
    "commit": SERVER_COMMIT,
    "files": {},
}

total = 0
for name in FILES:
    url = f"{BASE}/{name}"
    req = urllib.request.Request(url, headers={"User-Agent": "FrontierOffline-Build/1.0"})
    with urllib.request.urlopen(req, timeout=60) as response:
        data = response.read()
    # Fail the build if a source stopped being JSON instead of silently baking
    # an HTML error page into the game.
    json.loads(data.decode("utf-8-sig"))
    out = assets / name
    out.write_bytes(data)
    digest = hashlib.sha256(data).hexdigest()
    manifest["files"][name] = {"bytes": len(data), "sha256": digest}
    total += len(data)
    print(f"Bundled {name}: {len(data):,} bytes")

manifest["total_bytes"] = total
(assets.parent / "master_data_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n"
)

# Java access point for the recovered Android/native client. No sockets, URLs,
# or server process are involved at runtime; callers ask for an asset by name.
(java_root / "OfflineMasterData.java").write_text(r'''package sg.gumi.bravefrontier;

import android.content.Context;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public final class OfflineMasterData {
    private static final String ROOT = "frontier_offline/system/";

    private OfflineMasterData() {
    }

    private static Context context() {
        Context c = BraveFrontier.getAppContext();
        if (c == null && BraveFrontier.getActivity() != null) {
            c = BraveFrontier.getActivity().getApplicationContext();
        }
        return c;
    }

    public static String readJson(String name) {
        if (name == null || name.contains("/") || name.contains("\\") || !name.endsWith(".json")) {
            return null;
        }
        Context c = context();
        if (c == null) {
            return null;
        }
        try (InputStream in = c.getAssets().open(ROOT + name);
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int count;
            while ((count = in.read(buffer)) > 0) {
                out.write(buffer, 0, count);
            }
            return new String(out.toByteArray(), StandardCharsets.UTF_8);
        } catch (IOException ex) {
            return null;
        }
    }

    public static boolean has(String name) {
        return readJson(name) != null;
    }
}
''')

print(f"Bundled {len(FILES)} offline master-data files ({total:,} bytes total)")
print("Runtime source: APK assets only; no HTTP/server dependency")
