#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: add_offline_player_state.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
java_root = root / "src/android/app/src/main/java/sg/gumi/bravefrontier"
brave = java_root / "BraveFrontier.java"
jni = java_root / "BraveFrontierJNI.java"
state = java_root / "OfflinePlayerState.java"
for p in (brave, jni):
    if not p.exists():
        raise SystemExit(f"required local-state source missing: {p}")

state.write_text(r'''package sg.gumi.bravefrontier;

import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Single authoritative player profile for FrontierOffline.
 *
 * The original online game received these values from the account/initialize
 * response. In the offline build they live entirely on-device and are updated
 * transactionally through one SharedPreferences file. Server/account identity
 * is replaced with stable local IDs.
 */
public final class OfflinePlayerState {
    public static final int SCHEMA_VERSION = 1;
    private static final String PREFS = "frontier_offline_state";

    private static final String K_SCHEMA = "schema_version";
    private static final String K_ACCOUNT_ID = "account_id";
    private static final String K_USER_ID = "user_id";
    private static final String K_HANDLE = "handle_name";
    private static final String K_LEVEL = "level";
    private static final String K_EXP = "exp";
    private static final String K_ENERGY = "energy";
    private static final String K_MAX_ENERGY = "max_energy";
    private static final String K_ZEL = "zel";
    private static final String K_KARMA = "karma";
    private static final String K_BRAVE_COIN = "brave_coin";
    private static final String K_ARENA_ORBS = "arena_orbs";
    private static final String K_MAX_UNITS = "max_unit_count";
    private static final String K_MAX_FRIENDS = "max_friend_count";
    private static final String K_MAX_WAREHOUSE = "max_warehouse_count";
    private static final String K_TUTORIAL_END = "tutorial_end_flag";
    private static final String K_TUTORIAL_STATUS = "tutorial_status";
    private static final String K_QUEST_PROGRESS = "quest_progress";
    private static final String K_TOTAL_QUESTS = "quests_completed";

    private OfflinePlayerState() {
    }

    private static Context context() {
        Context c = BraveFrontier.getAppContext();
        if (c == null && BraveFrontier.getActivity() != null) {
            c = BraveFrontier.getActivity().getApplicationContext();
        }
        return c;
    }

    private static SharedPreferences prefs() {
        Context c = context();
        return c == null ? null : c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public static synchronized void initialize() {
        SharedPreferences p = prefs();
        if (p == null) return;
        if (p.getInt(K_SCHEMA, 0) >= SCHEMA_VERSION) return;

        SharedPreferences.Editor e = p.edit();
        e.putInt(K_SCHEMA, SCHEMA_VERSION);
        if (!p.contains(K_ACCOUNT_ID)) e.putString(K_ACCOUNT_ID, "OFFLINE-00000001");
        if (!p.contains(K_USER_ID)) e.putString(K_USER_ID, BraveFrontier.getLegacyDeviceUUID());
        if (!p.contains(K_HANDLE)) e.putString(K_HANDLE, "Offline Summoner");
        if (!p.contains(K_LEVEL)) e.putInt(K_LEVEL, 1);
        if (!p.contains(K_EXP)) e.putLong(K_EXP, 0L);
        if (!p.contains(K_ENERGY)) e.putInt(K_ENERGY, 20);
        if (!p.contains(K_MAX_ENERGY)) e.putInt(K_MAX_ENERGY, 20);
        if (!p.contains(K_ZEL)) e.putLong(K_ZEL, 0L);
        if (!p.contains(K_KARMA)) e.putLong(K_KARMA, 0L);
        if (!p.contains(K_BRAVE_COIN)) e.putLong(K_BRAVE_COIN, 0L);
        if (!p.contains(K_ARENA_ORBS)) e.putInt(K_ARENA_ORBS, 3);
        if (!p.contains(K_MAX_UNITS)) e.putInt(K_MAX_UNITS, 50);
        if (!p.contains(K_MAX_FRIENDS)) e.putInt(K_MAX_FRIENDS, 200);
        if (!p.contains(K_MAX_WAREHOUSE)) e.putInt(K_MAX_WAREHOUSE, 10);
        // We are restoring the main game, not replaying the old account/signup
        // tutorial bootstrap. Individual tutorial/help scenes can be restored
        // later without tying them to account creation.
        if (!p.contains(K_TUTORIAL_END)) e.putBoolean(K_TUTORIAL_END, true);
        if (!p.contains(K_TUTORIAL_STATUS)) e.putInt(K_TUTORIAL_STATUS, 12);
        if (!p.contains(K_QUEST_PROGRESS)) e.putString(K_QUEST_PROGRESS, "MISTRAL:0");
        if (!p.contains(K_TOTAL_QUESTS)) e.putInt(K_TOTAL_QUESTS, 0);
        e.apply();
    }

    private static long clampNonNegative(long value) {
        return value < 0L ? 0L : value;
    }

    public static int getLevel() {
        SharedPreferences p = prefs();
        return p == null ? 1 : Math.max(1, p.getInt(K_LEVEL, 1));
    }

    public static void setLevel(int value) {
        SharedPreferences p = prefs();
        if (p != null) p.edit().putInt(K_LEVEL, Math.max(1, value)).apply();
    }

    public static long getExp() {
        SharedPreferences p = prefs();
        return p == null ? 0L : p.getLong(K_EXP, 0L);
    }

    public static void addExp(long amount) {
        SharedPreferences p = prefs();
        if (p == null || amount <= 0L) return;
        long current = p.getLong(K_EXP, 0L);
        long next = current > Long.MAX_VALUE - amount ? Long.MAX_VALUE : current + amount;
        p.edit().putLong(K_EXP, next).apply();
    }

    public static int getEnergy() {
        SharedPreferences p = prefs();
        return p == null ? 20 : p.getInt(K_ENERGY, 20);
    }

    public static int getMaxEnergy() {
        SharedPreferences p = prefs();
        return p == null ? 20 : p.getInt(K_MAX_ENERGY, 20);
    }

    public static boolean spendEnergy(int amount) {
        if (amount < 0) return false;
        SharedPreferences p = prefs();
        if (p == null) return false;
        int current = p.getInt(K_ENERGY, 20);
        if (current < amount) return false;
        p.edit().putInt(K_ENERGY, current - amount).apply();
        return true;
    }

    public static void restoreEnergy(int amount) {
        if (amount <= 0) return;
        SharedPreferences p = prefs();
        if (p == null) return;
        int max = p.getInt(K_MAX_ENERGY, 20);
        long next = (long)p.getInt(K_ENERGY, 20) + amount;
        p.edit().putInt(K_ENERGY, (int)Math.min(max, next)).apply();
    }

    public static long getZel() {
        SharedPreferences p = prefs();
        return p == null ? 0L : p.getLong(K_ZEL, 0L);
    }

    public static void addZel(long amount) {
        SharedPreferences p = prefs();
        if (p == null || amount == 0L) return;
        long current = p.getLong(K_ZEL, 0L);
        long next;
        if (amount > 0 && current > Long.MAX_VALUE - amount) next = Long.MAX_VALUE;
        else next = clampNonNegative(current + amount);
        p.edit().putLong(K_ZEL, next).apply();
    }

    public static long getKarma() {
        SharedPreferences p = prefs();
        return p == null ? 0L : p.getLong(K_KARMA, 0L);
    }

    public static void addKarma(long amount) {
        SharedPreferences p = prefs();
        if (p == null || amount == 0L) return;
        long current = p.getLong(K_KARMA, 0L);
        long next;
        if (amount > 0 && current > Long.MAX_VALUE - amount) next = Long.MAX_VALUE;
        else next = clampNonNegative(current + amount);
        p.edit().putLong(K_KARMA, next).apply();
    }

    public static String snapshotJson() {
        initialize();
        SharedPreferences p = prefs();
        if (p == null) return "{}";
        JSONObject o = new JSONObject();
        try {
            o.put("schema_version", p.getInt(K_SCHEMA, SCHEMA_VERSION));
            o.put("account_id", p.getString(K_ACCOUNT_ID, "OFFLINE-00000001"));
            o.put("user_id", p.getString(K_USER_ID, "OFFLINE"));
            o.put("handle_name", p.getString(K_HANDLE, "Offline Summoner"));
            o.put("level", p.getInt(K_LEVEL, 1));
            o.put("exp", p.getLong(K_EXP, 0L));
            o.put("energy", p.getInt(K_ENERGY, 20));
            o.put("max_energy", p.getInt(K_MAX_ENERGY, 20));
            o.put("zel", p.getLong(K_ZEL, 0L));
            o.put("karma", p.getLong(K_KARMA, 0L));
            o.put("brave_coin", p.getLong(K_BRAVE_COIN, 0L));
            o.put("arena_orbs", p.getInt(K_ARENA_ORBS, 3));
            o.put("max_unit_count", p.getInt(K_MAX_UNITS, 50));
            o.put("max_friend_count", p.getInt(K_MAX_FRIENDS, 200));
            o.put("max_warehouse_count", p.getInt(K_MAX_WAREHOUSE, 10));
            o.put("free_gems", OfflineGemStore.getGems());
            o.put("tutorial_end_flag", p.getBoolean(K_TUTORIAL_END, true));
            o.put("tutorial_status", p.getInt(K_TUTORIAL_STATUS, 12));
            o.put("quest_progress", p.getString(K_QUEST_PROGRESS, "MISTRAL:0"));
            o.put("quests_completed", p.getInt(K_TOTAL_QUESTS, 0));
        } catch (JSONException ignored) {
            return "{}";
        }
        return o.toString();
    }

    public static void resetForTesting() {
        SharedPreferences p = prefs();
        if (p != null) p.edit().clear().apply();
        initialize();
    }
}
''')

# Initialize the player profile as soon as the app's Context/Activity globals
# exist, before any recovered native/bootstrap layer can ask for account state.
s = brave.read_text()
old = '''        context = getApplicationContext();
        act = this;
        savedInstanceState = bundle;
'''
new = '''        context = getApplicationContext();
        act = this;
        savedInstanceState = bundle;
        if (OFFLINE_MODE) {
            OfflinePlayerState.initialize();
        }
'''
if old not in s:
    raise SystemExit("OfflinePlayerState onCreate anchor missing")
brave.write_text(s.replace(old, new, 1))

# Bridge the local profile to the recovered native layer. The next scene/account
# reconstruction can request the same JSON snapshot that the Java side owns.
s = jni.read_text()
anchor = '    private static String replaceGooglePlayStoreName(String input, String playStoreName, String companyName) {'
insert = '''    public static String getOfflinePlayerStateJson() {
        return OfflinePlayerState.snapshotJson();
    }

    public static boolean spendOfflineEnergy(int amount) {
        return OfflinePlayerState.spendEnergy(amount);
    }

    public static void addOfflineQuestRewards(long zel, long karma, long exp) {
        OfflinePlayerState.addZel(zel);
        OfflinePlayerState.addKarma(karma);
        OfflinePlayerState.addExp(exp);
    }

'''
if anchor not in s:
    raise SystemExit("OfflinePlayerState JNI bridge anchor missing")
jni.write_text(s.replace(anchor, insert + anchor, 1))

print("Added unified serverless player profile:")
print(" - stable local account/user identity")
print(" - rank/EXP/energy/Zel/Karma/Brave Coin/Arena Orb state")
print(" - unit/friend/warehouse capacities")
print(" - tutorial and quest progression state")
print(" - shared Gem balance through OfflineGemStore")
print(" - JNI JSON snapshot/reward/energy bridge")
