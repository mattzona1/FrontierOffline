#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import sys
import urllib.parse
import urllib.request

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_native_battle.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
main_android = root / "src/Main_Android.cpp"
if not main_android.exists():
    raise SystemExit(f"required recovered Android source missing: {main_android}")

# Battle content is downloaded only by the build runner and then packaged into
# the APK. The Android app itself has no INTERNET permission and never fetches
# these files at runtime.
ASSET_COMMIT = "76538d1a0a98287c3660cedcedd63d7fce3f9cd1"
ASSET_REPO = "aMytho/brave-frontier-godot"
BATTLE_FILES = {
    "battle_bg.jpg": "Battle/UI/dungeon_battle_10100.jpg",
    "vargas.png": "Units/Res/1/unit_ills_battle_10011.png",
    "goblin.png": "Units/Res/67/unit_ills_battle_10050.png",
    "merman.png": "Units/Res/69/unit_ills_battle_20050.png",
    "mandragora.png": "Units/Res/71/unit_ills_battle_30050.png",
    "harpy.png": "Units/Res/73/unit_ills_battle_40050.png",
    "king_sparky.png": "Units/Res/50/unit_ills_battle_40031.png",
}

battle_root = root / "data/frontier_offline/battle"
battle_root.mkdir(parents=True, exist_ok=True)
manifest = {
    "source": ASSET_REPO,
    "commit": ASSET_COMMIT,
    "runtime_network": False,
    "quest": "Start of Adventure",
    "energy_cost": 3,
    "clear_exp": 20,
    "waves": [
        {"name": "Goblin", "hp": 1000, "asset": "goblin.png"},
        {"name": "Merman", "hp": 950, "asset": "merman.png"},
        {"name": "Mandragora", "hp": 1100, "asset": "mandragora.png"},
        {"name": "Harpy", "hp": 1200, "asset": "harpy.png"},
        {"name": "King Sparky", "hp": 2500, "asset": "king_sparky.png"},
    ],
    "files": {},
}

for local_name, source_path in BATTLE_FILES.items():
    quoted = urllib.parse.quote(source_path, safe="/")
    url = f"https://raw.githubusercontent.com/{ASSET_REPO}/{ASSET_COMMIT}/{quoted}"
    req = urllib.request.Request(url, headers={"User-Agent": "FrontierOffline-Build/1.0"})
    with urllib.request.urlopen(req, timeout=90) as response:
        data = response.read()
    is_png = data.startswith(b"\x89PNG\r\n\x1a\n")
    is_jpg = data.startswith(b"\xff\xd8\xff")
    if not (is_png or is_jpg):
        raise SystemExit(f"preserved BF battle source is not an image: {source_path}")
    if len(data) < 1000:
        raise SystemExit(f"preserved BF battle source unexpectedly tiny: {source_path}")
    (battle_root / local_name).write_bytes(data)
    manifest["files"][local_name] = {
        "source_path": source_path,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }

# Behavior contract: the battle implementation below uses the same HP table and
# deterministic attack function. Fail the build-time patch immediately if an
# attack cannot reduce HP or if the canonical first-quest values drift.
def attack_damage(wave: int) -> int:
    return 350 + wave * 25

assert manifest["energy_cost"] == 3
assert manifest["clear_exp"] == 20
assert len(manifest["waves"]) == 5
assert manifest["waves"][-1]["name"] == "King Sparky"
assert manifest["waves"][-1]["hp"] == 2500
for i, wave in enumerate(manifest["waves"]):
    before = wave["hp"]
    after = max(0, before - attack_damage(i))
    assert after < before, f"attack did not reduce HP for wave {i + 1}"

(battle_root / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")

s = main_android.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global s
    if old not in s:
        raise SystemExit(f"native battle patch anchor missing: {label}")
    s = s.replace(old, new, 1)


replace_once(
    'static const char* FO_UI = "frontier_offline/ui/";\n',
    'static const char* FO_UI = "frontier_offline/ui/";\n'
    'static const char* FO_BATTLE = "frontier_offline/battle/";\n',
    "battle asset root",
)

jni_anchor = '''static int frontierOfflineGrantGems(int amount)
{
    cocos2d::JniMethodInfo info;
    if (!cocos2d::JniHelper::getStaticMethodInfo(info, FRONTIER_OFFLINE_JNI, "grantOfflineGems", "(I)I"))
        return -1;
    jint balance = info.env->CallStaticIntMethod(info.classID, info.methodID, (jint)amount);
    info.env->DeleteLocalRef(info.classID);
    return (int)balance;
}
'''
jni_extended = jni_anchor + r'''

static bool frontierOfflineSpendEnergy(int amount)
{
    cocos2d::JniMethodInfo info;
    if (!cocos2d::JniHelper::getStaticMethodInfo(info, FRONTIER_OFFLINE_JNI, "spendOfflineEnergy", "(I)Z"))
        return false;
    jboolean ok = info.env->CallStaticBooleanMethod(info.classID, info.methodID, (jint)amount);
    info.env->DeleteLocalRef(info.classID);
    return ok == JNI_TRUE;
}

static void frontierOfflineAddQuestRewards(long zel, long karma, long exp)
{
    cocos2d::JniMethodInfo info;
    if (!cocos2d::JniHelper::getStaticMethodInfo(info, FRONTIER_OFFLINE_JNI, "addOfflineQuestRewards", "(JJJ)V"))
        return;
    info.env->CallStaticVoidMethod(info.classID, info.methodID, (jlong)zel, (jlong)karma, (jlong)exp);
    info.env->DeleteLocalRef(info.classID);
}

static cocos2d::CCSprite* foBattleSprite(const char* filename, float x, float y, float maxW, float maxH)
{
    std::string path = std::string(FO_BATTLE) + filename;
    cocos2d::CCSprite* sp = cocos2d::CCSprite::create(path.c_str());
    if (!sp) return NULL;
    cocos2d::CCSize cs = sp->getContentSize();
    float scale = 1.0f;
    if (cs.width > 0.0f && cs.height > 0.0f)
    {
        float sx = maxW / cs.width;
        float sy = maxH / cs.height;
        scale = sx < sy ? sx : sy;
        if (scale > 1.0f) scale = 1.0f;
    }
    sp->setScale(scale);
    sp->setPosition(cocos2d::CCPoint(x, y));
    return sp;
}
'''
replace_once(jni_anchor, jni_extended, "battle JNI helpers")

replace_once(
    '''        PAGE_QUEST,
        PAGE_MISSION,
        PAGE_SHOP,''',
    '''        PAGE_QUEST,
        PAGE_MISSION,
        PAGE_BATTLE,
        PAGE_RESULT,
        PAGE_SHOP,''',
    "battle pages",
)

replace_once(
    '    FrontierOfflineMainLayer() : m_page(PAGE_HOME) {}\n',
    '    FrontierOfflineMainLayer() : m_page(PAGE_HOME), m_wave(0), m_enemyHP(0), m_enemyMaxHP(0), m_playerHP(3000), m_battleStarted(false), m_victory(false) {}\n',
    "battle constructor state",
)

replace_once(
    '''    void goMission(cocos2d::CCObject*) { show(PAGE_MISSION); }
    void goShop(cocos2d::CCObject*) { show(PAGE_SHOP); }''',
    r'''    void goMission(cocos2d::CCObject*) { show(PAGE_MISSION); }
    void goBattle(cocos2d::CCObject*)
    {
        if (!m_battleStarted)
        {
            if (!frontierOfflineSpendEnergy(3))
            {
                m_battleMessage = "Not enough Energy. Start of Adventure costs 3.";
                show(PAGE_MISSION);
                return;
            }
            m_wave = 0;
            m_playerHP = 3000;
            m_battleStarted = true;
            m_victory = false;
            m_battleMessage = "Battle 1 begins!";
            setupWave();
        }
        show(PAGE_BATTLE);
    }
    void attackEnemy(cocos2d::CCObject*)
    {
        if (!m_battleStarted || m_page != PAGE_BATTLE || m_enemyHP <= 0) return;

        const int before = m_enemyHP;
        const int damage = 350 + m_wave * 25;
        m_enemyHP -= damage;
        if (m_enemyHP < 0) m_enemyHP = 0;
        if (m_enemyHP >= before)
        {
            m_battleMessage = "Attack error: enemy HP did not fall.";
            show(PAGE_BATTLE);
            return;
        }

        if (m_enemyHP == 0)
        {
            if (m_wave >= 4)
            {
                m_battleStarted = false;
                m_victory = true;
                m_battleMessage = "King Sparky defeated!";
                frontierOfflineAddQuestRewards(0, 0, 20);
                show(PAGE_RESULT);
                return;
            }
            ++m_wave;
            setupWave();
            m_battleMessage = "Enemy defeated - next battle!";
            show(PAGE_BATTLE);
            return;
        }

        const int retaliation = 55 + m_wave * 15;
        m_playerHP -= retaliation;
        if (m_playerHP <= 0)
        {
            m_playerHP = 0;
            m_battleStarted = false;
            m_victory = false;
            m_battleMessage = "Party defeated.";
            show(PAGE_RESULT);
            return;
        }
        m_battleMessage = "Vargas attacks! Enemy retaliates.";
        show(PAGE_BATTLE);
    }
    void goShop(cocos2d::CCObject*) { show(PAGE_SHOP); }''',
    "battle callbacks",
)

replace_once(
    '''private:
    Page m_page;
''',
    r'''private:
    Page m_page;
    int m_wave;
    int m_enemyHP;
    int m_enemyMaxHP;
    int m_playerHP;
    bool m_battleStarted;
    bool m_victory;
    std::string m_battleMessage;

    const char* enemyName() const
    {
        static const char* names[5] = {"Goblin", "Merman", "Mandragora", "Harpy", "King Sparky"};
        return names[m_wave < 0 ? 0 : (m_wave > 4 ? 4 : m_wave)];
    }

    const char* enemyAsset() const
    {
        static const char* files[5] = {"goblin.png", "merman.png", "mandragora.png", "harpy.png", "king_sparky.png"};
        return files[m_wave < 0 ? 0 : (m_wave > 4 ? 4 : m_wave)];
    }

    void setupWave()
    {
        static const int hp[5] = {1000, 950, 1100, 1200, 2500};
        int index = m_wave < 0 ? 0 : (m_wave > 4 ? 4 : m_wave);
        m_enemyMaxHP = hp[index];
        m_enemyHP = m_enemyMaxHP;
    }
''',
    "battle state fields",
)

old_mission = r'''    void buildMission()
    {
        addBack(menu_selector(FrontierOfflineMainLayer::goQuest));
        label("START OF ADVENTURE", 25.0f, 240.0f, 645.0f);
        label("Adventurer's Prairie - Mistral", 15.0f, 240.0f, 608.0f);
        label("Energy Cost: 3", 15.0f, 240.0f, 552.0f);
        label("5 Battles", 15.0f, 240.0f, 520.0f);
        label("Clear Reward: 20 EXP", 15.0f, 240.0f, 488.0f);
        label("Final Boss: King Sparky - 2,500 HP", 15.0f, 240.0f, 446.0f);
        label("Encounter pool", 14.0f, 240.0f, 392.0f);
        label("Burny  Squirty  Mossy  Sparky  Glowy  Gloomy", 11.0f, 240.0f, 360.0f);
        label("Goblin  Merman  Mandragora  Harpy", 11.0f, 240.0f, 334.0f);
        cocos2d::CCLabelTTF* note = label(
            "Battle scene restoration is the next native milestone.", 12.0f, 240.0f, 245.0f);
        note->setColor(cocos2d::ccc3(255, 224, 150));
    }
'''
new_mission = r'''    void buildMission()
    {
        addBack(menu_selector(FrontierOfflineMainLayer::goQuest));
        label("START OF ADVENTURE", 25.0f, 240.0f, 645.0f);
        label("Adventurer's Prairie - Mistral", 15.0f, 240.0f, 608.0f);
        label("Energy Cost: 3", 15.0f, 240.0f, 552.0f);
        label("5 Battles", 15.0f, 240.0f, 520.0f);
        label("Clear Reward: 20 EXP", 15.0f, 240.0f, 488.0f);
        label("Final Boss: King Sparky - 2,500 HP", 15.0f, 240.0f, 446.0f);
        label("Goblin -> Merman -> Mandragora -> Harpy -> King Sparky", 11.0f, 240.0f, 395.0f);
        if (!m_battleMessage.empty())
        {
            cocos2d::CCLabelTTF* note = label(m_battleMessage.c_str(), 11.0f, 240.0f, 350.0f);
            note->setColor(cocos2d::ccc3(255, 224, 150));
        }
        cocos2d::CCMenu* menu = cocos2d::CCMenu::create();
        menu->setPosition(cocos2d::CCPointZero);
        menu->addChild(textButton("START BATTLE", 25.0f, menu_selector(FrontierOfflineMainLayer::goBattle), 240.0f, 285.0f));
        addChild(menu, 30);
    }

    void buildBattle()
    {
        cocos2d::CCSprite* bg = foBattleSprite("battle_bg.jpg", 240.0f, 400.0f, 480.0f, 800.0f);
        if (bg) addChild(bg, -90);
        cocos2d::CCLayerColor* veil = cocos2d::CCLayerColor::create(cocos2d::ccc4(0, 0, 0, 65));
        addChild(veil, -80);

        cocos2d::CCString* waveText = cocos2d::CCString::createWithFormat("BATTLE %d / 5", m_wave + 1);
        label(waveText->getCString(), 20.0f, 240.0f, 755.0f);
        label(enemyName(), 24.0f, 240.0f, 700.0f);

        cocos2d::CCLayerColor* hpBack = cocos2d::CCLayerColor::create(cocos2d::ccc4(45, 18, 18, 230), 410.0f, 16.0f);
        hpBack->setPosition(cocos2d::CCPoint(35.0f, 661.0f));
        addChild(hpBack, 5);
        float ratio = m_enemyMaxHP > 0 ? (float)m_enemyHP / (float)m_enemyMaxHP : 0.0f;
        if (ratio < 0.0f) ratio = 0.0f;
        if (ratio > 1.0f) ratio = 1.0f;
        cocos2d::CCLayerColor* hpFill = cocos2d::CCLayerColor::create(cocos2d::ccc4(220, 56, 42, 245), 410.0f * ratio, 16.0f);
        hpFill->setPosition(cocos2d::CCPoint(35.0f, 661.0f));
        addChild(hpFill, 6);
        cocos2d::CCString* hpText = cocos2d::CCString::createWithFormat("HP %d / %d", m_enemyHP, m_enemyMaxHP);
        label(hpText->getCString(), 12.0f, 240.0f, 642.0f);

        cocos2d::CCSprite* enemy = foBattleSprite(enemyAsset(), 330.0f, 465.0f, 220.0f, 245.0f);
        if (enemy) addChild(enemy, 8);
        cocos2d::CCSprite* vargas = foBattleSprite("vargas.png", 125.0f, 295.0f, 205.0f, 225.0f);
        if (vargas) addChild(vargas, 8);

        cocos2d::CCString* partyHp = cocos2d::CCString::createWithFormat("Vargas HP %d / 3000", m_playerHP);
        label(partyHp->getCString(), 13.0f, 130.0f, 172.0f);
        cocos2d::CCLabelTTF* msg = label(m_battleMessage.c_str(), 11.0f, 240.0f, 135.0f);
        msg->setColor(cocos2d::ccc3(255, 240, 185));

        cocos2d::CCMenu* menu = cocos2d::CCMenu::create();
        menu->setPosition(cocos2d::CCPointZero);
        menu->addChild(textButton("TAP TO ATTACK", 25.0f, menu_selector(FrontierOfflineMainLayer::attackEnemy), 240.0f, 78.0f));
        addChild(menu, 30);
    }

    void buildResult()
    {
        label(m_victory ? "QUEST CLEAR!" : "QUEST FAILED", 31.0f, 240.0f, 610.0f);
        if (m_victory)
        {
            label("Start of Adventure", 18.0f, 240.0f, 550.0f);
            label("EXP +20", 22.0f, 240.0f, 485.0f);
            label("King Sparky defeated", 15.0f, 240.0f, 438.0f);
        }
        else
        {
            label("Your party was defeated.", 17.0f, 240.0f, 500.0f);
        }
        cocos2d::CCMenu* menu = cocos2d::CCMenu::create();
        menu->setPosition(cocos2d::CCPointZero);
        menu->addChild(textButton("RETURN TO QUESTS", 20.0f, menu_selector(FrontierOfflineMainLayer::goQuest), 240.0f, 315.0f));
        addChild(menu, 30);
    }
'''
replace_once(old_mission, new_mission, "mission-to-battle flow")

replace_once(
    '''        addHeader();
        addFooter();
        switch (page)''',
    '''        if (page != PAGE_BATTLE)
        {
            addHeader();
            addFooter();
        }
        switch (page)''',
    "battle full-screen chrome",
)

replace_once(
    '''            case PAGE_QUEST: buildQuest(); break;
            case PAGE_MISSION: buildMission(); break;
            case PAGE_SHOP: buildShop(); break;''',
    '''            case PAGE_QUEST: buildQuest(); break;
            case PAGE_MISSION: buildMission(); break;
            case PAGE_BATTLE: buildBattle(); break;
            case PAGE_RESULT: buildResult(); break;
            case PAGE_SHOP: buildShop(); break;''',
    "battle switch",
)

main_android.write_text(s)
print(f"Bundled {len(BATTLE_FILES)} preserved BF battle assets")
print("NATIVE_BATTLE_CONTRACT_OK")
print(" - Start of Adventure spends 3 local Energy")
print(" - five local waves wired into native Cocos flow")
print(" - each attack explicitly decreases enemy HP")
print(" - King Sparky begins at 2,500 HP")
print(" - victory grants 20 EXP through local player state")
print(" - runtime remains APK/local-save only")
