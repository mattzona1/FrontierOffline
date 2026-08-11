#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import urllib.request

if len(sys.argv) != 2:
    raise SystemExit("usage: bundle_offline_master_data.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
# The recovered client overrides Android's normal app/src/main/assets source and
# maps Gradle assets to <client>/data. Put offline master data in that original
# asset tree so it is physically packaged into the APK.
assets = root / "data/frontier_offline/system"
java_root = root / "src/android/app/src/main/java/sg/gumi/bravefrontier"
assets.mkdir(parents=True, exist_ok=True)
java_root.mkdir(parents=True, exist_ok=True)

SERVER_COMMIT = "7cc0ebd3be79ca561874f70224c3ed924224583b"
BASE = f"https://raw.githubusercontent.com/decompfrontier/server/{SERVER_COMMIT}/deploy/system"

# Static/master tables only. No server executable, session, account endpoint or
# runtime HTTP component is included. These become ordinary APK assets.
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
    "summon_tickets_v2.json",
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
    "first_desc.json",
    "sound.json",
    "unit_exp_pattern.json",
    "user_level.json",
    "extra_passive_skills.json",
    "town_facility.json",
    "town_facility_lv.json",
    "town_location.json",
    "town_location_lv.json",
    "trophy.json",
    "trophy_grade.json",
    "trophy_group.json",
    "TEMP_daily_tasks.json",
    "TEMP_daily_tasks_bonus.json",
    "TEMP_daily_tasks_prizes.json",
    "challenge.json",
    "challenge_grade.json",
    "challenge_hr.json",
    "challenge_item.json",
    "challenge_mis.json",
    "challenge_mvp.json",
    "challenge_rank_reward.json",
    "challenge_reward.json",
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
    with urllib.request.urlopen(req, timeout=90) as response:
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
# or server process are involved at runtime; callers ask AssetManager directly.
(java_root / "OfflineMasterData.java").write_text(r'''package sg.gumi.bravefrontier;

import android.content.Context;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public final class OfflineMasterData {
    private static final String ROOT = "frontier_offline/";

    private OfflineMasterData() {
    }

    private static Context context() {
        Context c = BraveFrontier.getAppContext();
        if (c == null && BraveFrontier.getActivity() != null) {
            c = BraveFrontier.getActivity().getApplicationContext();
        }
        return c;
    }

    public static byte[] readBytes(String relativePath) {
        if (relativePath == null || relativePath.isEmpty()
                || relativePath.startsWith("/") || relativePath.contains("..")
                || relativePath.contains("\\")) {
            return null;
        }
        Context c = context();
        if (c == null) return null;
        try (InputStream in = c.getAssets().open(ROOT + relativePath);
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[16384];
            int count;
            while ((count = in.read(buffer)) > 0) {
                out.write(buffer, 0, count);
            }
            return out.toByteArray();
        } catch (IOException ex) {
            return null;
        }
    }

    public static String readText(String relativePath) {
        byte[] data = readBytes(relativePath);
        return data == null ? null : new String(data, StandardCharsets.UTF_8);
    }

    public static String readJson(String name) {
        if (name == null || name.contains("/") || name.contains("\\") || !name.endsWith(".json")) {
            return null;
        }
        return readText("system/" + name);
    }

    public static boolean has(String relativePath) {
        return readBytes(relativePath) != null;
    }
}
''')

# Import only static data from the preserved Mission-and-Units recovery release.
# The helper verifies its pinned SHA-256 and explicitly excludes executable
# server/library formats before anything is placed under the Android assets tree.
workspace = Path(os.environ.get("GITHUB_WORKSPACE", Path(__file__).resolve().parents[1]))
recovery_helper = workspace / "ci" / "bundle_recovery_release.py"
if not recovery_helper.exists():
    raise SystemExit(f"required recovery-data helper missing: {recovery_helper}")
subprocess.check_call([sys.executable, str(recovery_helper), str(root)])

print(f"Bundled {len(FILES)} offline master-data files ({total:,} bytes total)")
print("Runtime source: APK assets only; no HTTP/server dependency")
