#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import sys
import urllib.parse
import urllib.request

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_recovery_hub.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
main_android = root / "src/Main_Android.cpp"
if not main_android.exists():
    raise SystemExit(f"required recovered Android source missing: {main_android}")

# Bundle preserved BF interface pieces at build time. Runtime remains completely
# offline: these become ordinary APK assets under frontier_offline/ui.
UI_COMMIT = "76538d1a0a98287c3660cedcedd63d7fce3f9cd1"
UI_REPO = "aMytho/brave-frontier-godot"
UI_FILES = {
    "header.png": "Menu/Header/header.png",
    "header_ui.png": "Menu/Header/header_ui.png",
    "footer_base.png": "Menu/Footer/footer_base.png",
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
ui_root = root / "data/frontier_offline/ui"
ui_root.mkdir(parents=True, exist_ok=True)
ui_manifest = {"source": UI_REPO, "commit": UI_COMMIT, "runtime_network": False, "files": {}}
ui_total = 0
for local_name, source_path in UI_FILES.items():
    quoted = urllib.parse.quote(source_path, safe="/")
    url = f"https://raw.githubusercontent.com/{UI_REPO}/{UI_COMMIT}/{quoted}"
    req = urllib.request.Request(url, headers={"User-Agent": "FrontierOffline-Build/1.0"})
    with urllib.request.urlopen(req, timeout=90) as response:
        data = response.read()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise SystemExit(f"preserved BF UI source is not PNG: {source_path}")
    if len(data) < 500:
        raise SystemExit(f"preserved BF UI source unexpectedly tiny: {source_path}")
    (ui_root / local_name).write_bytes(data)
    ui_manifest["files"][local_name] = {
        "source_path": source_path,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }
    ui_total += len(data)
ui_manifest["total_bytes"] = ui_total
(ui_root / "manifest.json").write_text(json.dumps(ui_manifest, indent=2, sort_keys=True) + "\n")

s = main_android.read_text()
marker = "#ifdef __ANDROID__\nclass FrontierOfflineApplication : public cocos2d::CCApplication"
start = s.rfind(marker)
if start < 0:
    raise SystemExit("temporary recovery application block not found")

# The upstream decompilation does not currently contain the original high-level
# Home/Quest scene implementations. This native Cocos layer restores that flow
# on top of the recovered client plumbing while using local state and preserved
# BF UI resources only. The recovery diagnostics remain behind a small button.
new_block = r'''#ifdef __ANDROID__
static const char* FRONTIER_OFFLINE_JNI = "sg/gumi/bravefrontier/BraveFrontierJNI";
static const char* FO_UI = "frontier_offline/ui/";

static std::string frontierOfflineCallString(const char* method)
{
    cocos2d::JniMethodInfo info;
    if (!cocos2d::JniHelper::getStaticMethodInfo(info, FRONTIER_OFFLINE_JNI, method, "()Ljava/lang/String;"))
        return "UNAVAILABLE";
    jstring value = (jstring)info.env->CallStaticObjectMethod(info.classID, info.methodID);
    std::string result = "UNAVAILABLE";
    if (value)
    {
        const char* chars = info.env->GetStringUTFChars(value, NULL);
        if (chars)
        {
            result = chars;
            info.env->ReleaseStringUTFChars(value, chars);
        }
        info.env->DeleteLocalRef(value);
    }
    info.env->DeleteLocalRef(info.classID);
    return result;
}

static int frontierOfflineGrantGems(int amount)
{
    cocos2d::JniMethodInfo info;
    if (!cocos2d::JniHelper::getStaticMethodInfo(info, FRONTIER_OFFLINE_JNI, "grantOfflineGems", "(I)I"))
        return -1;
    jint balance = info.env->CallStaticIntMethod(info.classID, info.methodID, (jint)amount);
    info.env->DeleteLocalRef(info.classID);
    return (int)balance;
}

static cocos2d::CCSprite* foSprite(const char* filename, float x, float y, float maxW, float maxH)
{
    std::string path = std::string(FO_UI) + filename;
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

static cocos2d::CCMenuItemImage* foImageButton(
    const char* filename,
    cocos2d::CCObject* target,
    cocos2d::SEL_MenuHandler selector,
    float x, float y, float maxW, float maxH)
{
    std::string path = std::string(FO_UI) + filename;
    cocos2d::CCMenuItemImage* item = cocos2d::CCMenuItemImage::create(
        path.c_str(), path.c_str(), target, selector);
    if (!item) return NULL;
    cocos2d::CCSize cs = item->getContentSize();
    float scale = 1.0f;
    if (cs.width > 0.0f && cs.height > 0.0f)
    {
        float sx = maxW / cs.width;
        float sy = maxH / cs.height;
        scale = sx < sy ? sx : sy;
        if (scale > 1.0f) scale = 1.0f;
    }
    item->setScale(scale);
    item->setPosition(cocos2d::CCPoint(x, y));
    return item;
}

class FrontierOfflineMainLayer : public cocos2d::CCLayer
{
public:
    enum Page
    {
        PAGE_HOME,
        PAGE_QUEST,
        PAGE_MISSION,
        PAGE_SHOP,
        PAGE_UNIT,
        PAGE_TOWN,
        PAGE_SUMMON,
        PAGE_SOCIAL,
        PAGE_DEBUG
    };

    FrontierOfflineMainLayer() : m_page(PAGE_HOME) {}

    static FrontierOfflineMainLayer* create()
    {
        FrontierOfflineMainLayer* layer = new FrontierOfflineMainLayer();
        if (layer && layer->init())
        {
            layer->autorelease();
            return layer;
        }
        delete layer;
        return NULL;
    }

    virtual bool init()
    {
        if (!cocos2d::CCLayer::init()) return false;
        show(PAGE_HOME);
        return true;
    }

    void goHome(cocos2d::CCObject*) { show(PAGE_HOME); }
    void goQuest(cocos2d::CCObject*) { show(PAGE_QUEST); }
    void goMission(cocos2d::CCObject*) { show(PAGE_MISSION); }
    void goShop(cocos2d::CCObject*) { show(PAGE_SHOP); }
    void goUnit(cocos2d::CCObject*) { show(PAGE_UNIT); }
    void goTown(cocos2d::CCObject*) { show(PAGE_TOWN); }
    void goSummon(cocos2d::CCObject*) { show(PAGE_SUMMON); }
    void goSocial(cocos2d::CCObject*) { show(PAGE_SOCIAL); }
    void goDebug(cocos2d::CCObject*) { show(PAGE_DEBUG); }
    void grant5(cocos2d::CCObject*) { frontierOfflineGrantGems(5); show(PAGE_SHOP); }
    void grant50(cocos2d::CCObject*) { frontierOfflineGrantGems(50); show(PAGE_SHOP); }
    void grant500(cocos2d::CCObject*) { frontierOfflineGrantGems(500); show(PAGE_SHOP); }

private:
    Page m_page;

    cocos2d::CCLabelTTF* label(const char* text, float size, float x, float y)
    {
        cocos2d::CCLabelTTF* l = cocos2d::CCLabelTTF::create(text, "Arial", size);
        l->setPosition(cocos2d::CCPoint(x, y));
        addChild(l, 20);
        return l;
    }

    cocos2d::CCMenuItemLabel* textButton(
        const char* text, float size, cocos2d::SEL_MenuHandler selector, float x, float y)
    {
        cocos2d::CCLabelTTF* l = cocos2d::CCLabelTTF::create(text, "Arial", size);
        cocos2d::CCMenuItemLabel* item = cocos2d::CCMenuItemLabel::create(l, this, selector);
        item->setPosition(cocos2d::CCPoint(x, y));
        return item;
    }

    void addHeader()
    {
        cocos2d::CCSize size = cocos2d::CCDirector::sharedDirector()->getWinSize();
        cocos2d::CCSprite* h = foSprite("header.png", size.width * 0.5f, 760.0f, 480.0f, 94.0f);
        if (h) addChild(h, 5);
        std::string player = frontierOfflineCallString("getOfflinePlayerSummary");
        cocos2d::CCLabelTTF* stats = label(player.c_str(), 10.5f, size.width * 0.5f, 746.0f);
        stats->setColor(cocos2d::ccc3(255, 244, 202));
    }

    void addFooter()
    {
        cocos2d::CCSize size = cocos2d::CCDirector::sharedDirector()->getWinSize();
        cocos2d::CCSprite* footer = foSprite("footer_base.png", size.width * 0.5f, 45.0f, 480.0f, 88.0f);
        if (footer) addChild(footer, 5);

        cocos2d::CCMenu* menu = cocos2d::CCMenu::create();
        menu->setPosition(cocos2d::CCPointZero);
        struct NavSpec { const char* file; cocos2d::SEL_MenuHandler cb; };
        NavSpec specs[6] = {
            {"nav_home.png", menu_selector(FrontierOfflineMainLayer::goHome)},
            {"nav_unit.png", menu_selector(FrontierOfflineMainLayer::goUnit)},
            {"nav_town.png", menu_selector(FrontierOfflineMainLayer::goTown)},
            {"nav_shop.png", menu_selector(FrontierOfflineMainLayer::goShop)},
            {"nav_summon.png", menu_selector(FrontierOfflineMainLayer::goSummon)},
            {"nav_social.png", menu_selector(FrontierOfflineMainLayer::goSocial)}
        };
        for (int i = 0; i < 6; ++i)
        {
            cocos2d::CCMenuItemImage* item = foImageButton(
                specs[i].file, this, specs[i].cb, 40.0f + i * 80.0f, 47.0f, 72.0f, 66.0f);
            if (item) menu->addChild(item);
        }
        addChild(menu, 30);
    }

    void addBack(cocos2d::SEL_MenuHandler cb)
    {
        cocos2d::CCMenu* menu = cocos2d::CCMenu::create();
        menu->setPosition(cocos2d::CCPointZero);
        cocos2d::CCMenuItemLabel* back = textButton("< Back", 17.0f, cb, 48.0f, 690.0f);
        menu->addChild(back);
        addChild(menu, 30);
    }

    void buildHome()
    {
        cocos2d::CCSize size = cocos2d::CCDirector::sharedDirector()->getWinSize();
        label("HOME", 18.0f, size.width * 0.5f, 686.0f);

        cocos2d::CCSprite* frame = foSprite("home_character_frame.png", size.width * 0.5f, 598.0f, 455.0f, 120.0f);
        if (frame) addChild(frame, 2);
        label("Offline Summoner", 16.0f, size.width * 0.5f, 604.0f);
        cocos2d::CCLabelTTF* offline = label("Local save active - no server connection", 11.0f, size.width * 0.5f, 578.0f);
        offline->setColor(cocos2d::ccc3(180, 235, 180));

        cocos2d::CCMenu* menu = cocos2d::CCMenu::create();
        menu->setPosition(cocos2d::CCPointZero);
        cocos2d::CCMenuItemImage* quest = foImageButton(
            "home_quest.png", this, menu_selector(FrontierOfflineMainLayer::goQuest),
            size.width * 0.5f, 410.0f, 390.0f, 180.0f);
        if (quest) menu->addChild(quest);
        cocos2d::CCMenuItemImage* gate = foImageButton(
            "home_gate.png", this, menu_selector(FrontierOfflineMainLayer::goSummon),
            135.0f, 245.0f, 190.0f, 110.0f);
        if (gate) menu->addChild(gate);
        cocos2d::CCMenuItemImage* arena = foImageButton(
            "home_arena.png", this, menu_selector(FrontierOfflineMainLayer::goSocial),
            345.0f, 245.0f, 190.0f, 110.0f);
        if (arena) menu->addChild(arena);
        cocos2d::CCMenuItemLabel* debug = textButton(
            "Offline Debug", 10.0f, menu_selector(FrontierOfflineMainLayer::goDebug),
            430.0f, 116.0f);
        menu->addChild(debug);
        addChild(menu, 30);
    }

    void buildQuest()
    {
        addBack(menu_selector(FrontierOfflineMainLayer::goHome));
        label("MISTRAL", 27.0f, 240.0f, 650.0f);
        label("Adventurer's Prairie", 20.0f, 240.0f, 600.0f);
        label("The first steps of a Summoner's journey.", 12.0f, 240.0f, 568.0f);

        cocos2d::CCLayerColor* card = cocos2d::CCLayerColor::create(cocos2d::ccc4(55, 43, 34, 225), 430.0f, 155.0f);
        card->setPosition(cocos2d::CCPoint(25.0f, 355.0f));
        addChild(card, 3);
        label("Start of Adventure", 24.0f, 240.0f, 472.0f);
        label("Energy 3     Battles 5     EXP 20", 15.0f, 240.0f, 430.0f);
        label("Boss: King Sparky", 14.0f, 240.0f, 394.0f);

        cocos2d::CCMenu* menu = cocos2d::CCMenu::create();
        menu->setPosition(cocos2d::CCPointZero);
        cocos2d::CCMenuItemLabel* mission = textButton(
            "ENTER QUEST", 23.0f, menu_selector(FrontierOfflineMainLayer::goMission), 240.0f, 310.0f);
        menu->addChild(mission);
        addChild(menu, 30);
    }

    void buildMission()
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

    void buildShop()
    {
        addBack(menu_selector(FrontierOfflineMainLayer::goHome));
        label("SHOP", 28.0f, 240.0f, 650.0f);
        label("Purchases disabled - local Gem utility", 14.0f, 240.0f, 612.0f);
        label(frontierOfflineCallString("getOfflinePlayerSummary").c_str(), 11.0f, 240.0f, 570.0f);
        cocos2d::CCMenu* menu = cocos2d::CCMenu::create();
        menu->setPosition(cocos2d::CCPointZero);
        menu->addChild(textButton("+5 Gems", 26.0f, menu_selector(FrontierOfflineMainLayer::grant5), 240.0f, 480.0f));
        menu->addChild(textButton("+50 Gems", 26.0f, menu_selector(FrontierOfflineMainLayer::grant50), 240.0f, 405.0f));
        menu->addChild(textButton("+500 Gems", 26.0f, menu_selector(FrontierOfflineMainLayer::grant500), 240.0f, 330.0f));
        addChild(menu, 30);
        label("All changes persist only on this device.", 12.0f, 240.0f, 250.0f);
    }

    void buildPlaceholder(const char* title, const char* message)
    {
        addBack(menu_selector(FrontierOfflineMainLayer::goHome));
        label(title, 28.0f, 240.0f, 640.0f);
        label(message, 14.0f, 240.0f, 500.0f);
    }

    void buildDebug()
    {
        addBack(menu_selector(FrontierOfflineMainLayer::goHome));
        label("OFFLINE RECOVERY DEBUG", 22.0f, 240.0f, 650.0f);
        label(frontierOfflineCallString("getOfflinePlayerSummary").c_str(), 12.0f, 240.0f, 590.0f);
        label(frontierOfflineCallString("getOfflineDataStatus").c_str(), 11.0f, 240.0f, 548.0f);
        std::string init = frontierOfflineCallString("getOfflineInitializeJson");
        bool ready = init.find("\"frontier_offline\":true") != std::string::npos
            && init.find("\"login_info\"") != std::string::npos
            && init.find("\"user_info\"") != std::string::npos;
        label(ready ? "Local initialize: READY" : "Local initialize: ERROR", 13.0f, 240.0f, 505.0f);
        label("APK assets + on-device save only", 12.0f, 240.0f, 448.0f);
        label("No billing | No login server | No Internet permission", 11.0f, 240.0f, 416.0f);
    }

    void show(Page page)
    {
        m_page = page;
        removeAllChildrenWithCleanup(true);
        cocos2d::CCLayerColor* bg = cocos2d::CCLayerColor::create(cocos2d::ccc4(19, 13, 24, 255));
        addChild(bg, -100);
        addHeader();
        addFooter();
        switch (page)
        {
            case PAGE_HOME: buildHome(); break;
            case PAGE_QUEST: buildQuest(); break;
            case PAGE_MISSION: buildMission(); break;
            case PAGE_SHOP: buildShop(); break;
            case PAGE_UNIT: buildPlaceholder("UNIT", "Local unit roster restoration is in progress."); break;
            case PAGE_TOWN: buildPlaceholder("TOWN", "Town data is packaged; native facilities are being restored."); break;
            case PAGE_SUMMON: buildPlaceholder("SUMMON", "Summon tables are local. Summon animation/roster flow is next."); break;
            case PAGE_SOCIAL: buildPlaceholder("SOCIAL / ARENA", "Online social services are disabled in this offline build."); break;
            case PAGE_DEBUG: buildDebug(); break;
        }
    }
};

class FrontierOfflineApplication : public cocos2d::CCApplication
{
public:
    virtual bool applicationDidFinishLaunching()
    {
        cocos2d::CCDirector* director = cocos2d::CCDirector::sharedDirector();
        cocos2d::CCEGLView* view = cocos2d::CCEGLView::sharedOpenGLView();
        director->setOpenGLView(view);
        view->setDesignResolutionSize(480.0f, 800.0f, kResolutionShowAll);
        director->setDisplayStats(false);
        director->setAnimationInterval(1.0 / 60.0);

        cocos2d::CCScene* scene = cocos2d::CCScene::create();
        scene->addChild(FrontierOfflineMainLayer::create(), 1);
        director->runWithScene(scene);
        return true;
    }

    virtual void applicationDidEnterBackground()
    {
        cocos2d::CCDirector::sharedDirector()->stopAnimation();
    }

    virtual void applicationWillEnterForeground()
    {
        cocos2d::CCDirector::sharedDirector()->startAnimation();
    }
};

static FrontierOfflineApplication* g_frontierOfflineApplication = NULL;

extern "C" JNIEXPORT void JNICALL Java_org_cocos2dx_lib_Cocos2dxRenderer_nativeInit(
    JNIEnv* env, jobject thiz, jint width, jint height)
{
    cocos2d::CCDirector* director = cocos2d::CCDirector::sharedDirector();
    if (!director->getOpenGLView())
    {
        cocos2d::CCEGLView* view = cocos2d::CCEGLView::sharedOpenGLView();
        view->setFrameSize(width, height);
        if (!g_frontierOfflineApplication)
            g_frontierOfflineApplication = new FrontierOfflineApplication();
        cocos2d::CCApplication::sharedApplication()->run();
    }
    else
    {
        cocos2d::ccDrawInit();
        cocos2d::ccGLInvalidateStateCache();
        cocos2d::CCShaderCache::sharedShaderCache()->reloadDefaultShaders();
        cocos2d::CCTextureCache::reloadAllTextures();
        director->setGLDefaultValues();
    }
}
#endif
'''

main_android.write_text(s[:start] + new_block)
print(f"Bundled {len(UI_FILES)} preserved BF UI assets ({ui_total:,} bytes)")
print("Replaced recovery hub with native offline BF flow:")
print(" - Home uses preserved header/footer/nav/launch art")
print(" - Quest routes Mistral -> Adventurer's Prairie -> Start of Adventure")
print(" - Start of Adventure details: 3 Energy / 5 battles / 20 EXP / King Sparky")
print(" - Shop remains local +5/+50/+500 Gems only")
print(" - Social/network features remain disabled")
print(" - recovery diagnostics retained behind Offline Debug")
