#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: add_offline_bootstrap.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
java_root = root / "src/android/app/src/main/java/sg/gumi/bravefrontier"
jni = java_root / "BraveFrontierJNI.java"
bootstrap = java_root / "OfflineBootstrap.java"

if not jni.exists():
    raise SystemExit(f"required JNI source missing: {jni}")

bootstrap.write_text(r'''package sg.gumi.bravefrontier;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Builds the account/initialize state for FrontierOffline entirely in-process.
 *
 * This deliberately is not an HTTP/server emulator. It is a local bridge
 * between the recovered native client, OfflinePlayerState, and static data
 * physically packaged in the APK. As more of the original response parser is
 * recovered, fields can be mapped from this normalized payload into the exact
 * legacy packet layout without ever introducing a network dependency.
 */
public final class OfflineBootstrap {
    private static final String SIGNAL_KEY = "FOFFLINE";

    private OfflineBootstrap() {
    }

    private static JSONObject profile() throws JSONException {
        OfflinePlayerState.initialize();
        return new JSONObject(OfflinePlayerState.snapshotJson());
    }

    public static String buildInitializeJson() {
        try {
            JSONObject p = profile();
            JSONObject root = new JSONObject();
            root.put("frontier_offline", true);
            root.put("schema_version", 1);

            JSONObject login = new JSONObject();
            login.put("account_id", p.optString("account_id", "OFFLINE-00000001"));
            login.put("handle_name", p.optString("handle_name", "Offline Summoner"));
            login.put("user_id", p.optString("user_id", "OFFLINE"));
            login.put("tutorial_end_flag", p.optBoolean("tutorial_end_flag", true));
            login.put("tutorial_status", p.optInt("tutorial_status", 12));
            login.put("debug_mode", false);
            root.put("login_info", login);

            JSONObject user = new JSONObject();
            user.put("level", p.optInt("level", 1));
            user.put("exp", p.optLong("exp", 0L));
            user.put("energy", p.optInt("energy", 20));
            user.put("max_energy", p.optInt("max_energy", 20));
            user.put("zel", p.optLong("zel", 0L));
            user.put("karma", p.optLong("karma", 0L));
            user.put("brave_coin", p.optLong("brave_coin", 0L));
            user.put("free_gems", OfflineGemStore.getGems());
            user.put("arena_orbs", p.optInt("arena_orbs", 3));
            user.put("max_unit_count", p.optInt("max_unit_count", 50));
            user.put("max_friend_count", p.optInt("max_friend_count", 200));
            user.put("max_warehouse_count", p.optInt("max_warehouse_count", 10));
            user.put("quest_progress", p.optString("quest_progress", "MISTRAL:0"));
            user.put("quests_completed", p.optInt("quests_completed", 0));
            root.put("user_info", user);

            JSONObject signal = new JSONObject();
            signal.put("key", SIGNAL_KEY);
            root.put("signal_key", signal);

            JSONObject arena = new JSONObject();
            arena.put("user_id", login.optString("user_id"));
            arena.put("league_id", 1);
            arena.put("ranking_class", "F");
            root.put("challenge_arena_user_info", arena);

            JSONObject journal = new JSONObject();
            journal.put("user_id", login.optString("user_id"));
            root.put("summoner_journal", journal);

            JSONObject daily = new JSONObject();
            daily.put("id", 1);
            daily.put("current_day", 1);
            daily.put("message", "Offline daily login state");
            root.put("daily_login_rewards", daily);

            JSONObject data = new JSONObject();
            data.put("defines", OfflineMasterData.has("system/defines.json"));
            data.put("features", OfflineMasterData.has("system/features.json"));
            data.put("gacha", OfflineMasterData.has("system/gacha.json"));
            data.put("mission_mst", OfflineMasterData.has("recovery/server/system/mission_mst.json"));
            data.put("unit_mst", OfflineMasterData.has("recovery/server/system/unit_mst.json"));
            data.put("item_mst", OfflineMasterData.has("recovery/server/system/item_mst.json"));
            data.put("skill_mst", OfflineMasterData.has("recovery/server/system/skill_mst.json"));
            data.put("user_level_mst", OfflineMasterData.has("recovery/server/system/user_level_mst.json"));
            root.put("local_data", data);

            return root.toString();
        } catch (JSONException ex) {
            return "{\"frontier_offline\":true,\"bootstrap_error\":\"json\"}";
        }
    }

    public static String playerSummary() {
        try {
            JSONObject p = profile();
            return "Rank " + p.optInt("level", 1)
                    + "   Energy " + p.optInt("energy", 20) + "/" + p.optInt("max_energy", 20)
                    + "   Zel " + p.optLong("zel", 0L)
                    + "   Karma " + p.optLong("karma", 0L)
                    + "   Gems " + OfflineGemStore.getGems();
        } catch (JSONException ex) {
            return "Local player state unavailable";
        }
    }

    public static String dataStatus() {
        boolean master = OfflineMasterData.has("system/defines.json")
                && OfflineMasterData.has("system/features.json")
                && OfflineMasterData.has("system/gacha.json");
        boolean game = OfflineMasterData.has("recovery/server/system/mission_mst.json")
                && OfflineMasterData.has("recovery/server/system/dungeon_mst.json")
                && OfflineMasterData.has("recovery/server/system/unit_mst.json")
                && OfflineMasterData.has("recovery/server/system/item_mst.json")
                && OfflineMasterData.has("recovery/server/system/skill_mst.json");
        return "Master data: " + (master ? "READY" : "MISSING")
                + "   Mission/Unit data: " + (game ? "READY" : "MISSING");
    }

    public static boolean isCoreDataReady() {
        return dataStatus().indexOf("MISSING") < 0;
    }
}
''')

s = jni.read_text()
anchor = '    private static String replaceGooglePlayStoreName(String input, String playStoreName, String companyName) {'
insert = '''    public static String getOfflineInitializeJson() {
        return OfflineBootstrap.buildInitializeJson();
    }

    public static String getOfflinePlayerSummary() {
        return OfflineBootstrap.playerSummary();
    }

    public static String getOfflineDataStatus() {
        return OfflineBootstrap.dataStatus();
    }

    public static boolean isOfflineCoreDataReady() {
        return OfflineBootstrap.isCoreDataReady();
    }

'''
if anchor not in s:
    raise SystemExit("offline bootstrap JNI anchor missing")
if 'getOfflineInitializeJson()' not in s:
    s = s.replace(anchor, insert + anchor, 1)
jni.write_text(s)

print("Added serverless local initialize/bootstrap layer:")
print(" - account/login state generated from OfflinePlayerState")
print(" - user currencies/capacities/quest progress sourced locally")
print(" - master/recovery data readiness included")
print(" - JNI exposes initialize JSON, player summary, and data status")
print(" - no socket, URL, token exchange, or server runtime")
