#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_recovery_hub.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
main_android = root / "src/Main_Android.cpp"
if not main_android.exists():
    raise SystemExit(f"required recovered Android source missing: {main_android}")

s = main_android.read_text()
marker = "#ifdef __ANDROID__\nclass FrontierOfflineApplication : public cocos2d::CCApplication"
start = s.rfind(marker)
if start < 0:
    raise SystemExit("temporary recovery application block not found")

# The workflow appends this temporary application as the final Android block.
# Replace only that block; leave the recovered Brave Frontier JNI callbacks above
# it untouched.
new_block = r'''#ifdef __ANDROID__
static const char* FRONTIER_OFFLINE_JNI = "sg/gumi/bravefrontier/BraveFrontierJNI";

static std::string frontierOfflineCallString(const char* method)
{
    cocos2d::JniMethodInfo info;
    if (!cocos2d::JniHelper::getStaticMethodInfo(info, FRONTIER_OFFLINE_JNI, method, "()Ljava/lang/String;"))
    {
        return "UNAVAILABLE";
    }

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
    {
        return -1;
    }
    jint balance = info.env->CallStaticIntMethod(info.classID, info.methodID, (jint)amount);
    info.env->DeleteLocalRef(info.classID);
    return (int)balance;
}

class FrontierOfflineRecoveryLayer : public cocos2d::CCLayer
{
public:
    FrontierOfflineRecoveryLayer() : m_player(NULL), m_data(NULL), m_bootstrap(NULL) {}

    static FrontierOfflineRecoveryLayer* create()
    {
        FrontierOfflineRecoveryLayer* layer = new FrontierOfflineRecoveryLayer();
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
        if (!cocos2d::CCLayer::init())
        {
            return false;
        }

        cocos2d::CCSize size = cocos2d::CCDirector::sharedDirector()->getWinSize();

        cocos2d::CCLabelTTF* title = cocos2d::CCLabelTTF::create("BRAVE FRONTIER", "Arial", 31.0f);
        title->setPosition(cocos2d::CCPoint(size.width * 0.5f, 735.0f));
        addChild(title);

        cocos2d::CCLabelTTF* subtitle = cocos2d::CCLabelTTF::create("SERVERLESS RECOVERY HUB", "Arial", 17.0f);
        subtitle->setPosition(cocos2d::CCPoint(size.width * 0.5f, 700.0f));
        addChild(subtitle);

        cocos2d::CCLabelTTF* safety = cocos2d::CCLabelTTF::create("ON-DEVICE SAVE  |  NO BILLING  |  NO SERVER", "Arial", 11.0f);
        safety->setPosition(cocos2d::CCPoint(size.width * 0.5f, 674.0f));
        addChild(safety);

        m_player = cocos2d::CCLabelTTF::create("Loading local profile...", "Arial", 14.0f);
        m_player->setPosition(cocos2d::CCPoint(size.width * 0.5f, 620.0f));
        addChild(m_player);

        m_data = cocos2d::CCLabelTTF::create("Checking packaged game data...", "Arial", 12.0f);
        m_data->setPosition(cocos2d::CCPoint(size.width * 0.5f, 585.0f));
        addChild(m_data);

        m_bootstrap = cocos2d::CCLabelTTF::create("Local initialize: CHECKING", "Arial", 12.0f);
        m_bootstrap->setPosition(cocos2d::CCPoint(size.width * 0.5f, 552.0f));
        addChild(m_bootstrap);

        cocos2d::CCLabelTTF* shopTitle = cocos2d::CCLabelTTF::create("OFFLINE SHOP - LOCAL GEM GRANTS", "Arial", 16.0f);
        shopTitle->setPosition(cocos2d::CCPoint(size.width * 0.5f, 490.0f));
        addChild(shopTitle);

        cocos2d::CCLabelTTF* l5 = cocos2d::CCLabelTTF::create("+5 Gems", "Arial", 23.0f);
        cocos2d::CCLabelTTF* l50 = cocos2d::CCLabelTTF::create("+50 Gems", "Arial", 23.0f);
        cocos2d::CCLabelTTF* l500 = cocos2d::CCLabelTTF::create("+500 Gems", "Arial", 23.0f);
        cocos2d::CCLabelTTF* lr = cocos2d::CCLabelTTF::create("Refresh Local State", "Arial", 17.0f);

        cocos2d::CCMenuItemLabel* b5 = cocos2d::CCMenuItemLabel::create(l5, this, menu_selector(FrontierOfflineRecoveryLayer::grant5));
        cocos2d::CCMenuItemLabel* b50 = cocos2d::CCMenuItemLabel::create(l50, this, menu_selector(FrontierOfflineRecoveryLayer::grant50));
        cocos2d::CCMenuItemLabel* b500 = cocos2d::CCMenuItemLabel::create(l500, this, menu_selector(FrontierOfflineRecoveryLayer::grant500));
        cocos2d::CCMenuItemLabel* br = cocos2d::CCMenuItemLabel::create(lr, this, menu_selector(FrontierOfflineRecoveryLayer::refreshCallback));

        cocos2d::CCMenu* menu = cocos2d::CCMenu::create(b5, b50, b500, br, NULL);
        menu->setPosition(cocos2d::CCPointZero);
        b5->setPosition(cocos2d::CCPoint(size.width * 0.5f, 430.0f));
        b50->setPosition(cocos2d::CCPoint(size.width * 0.5f, 370.0f));
        b500->setPosition(cocos2d::CCPoint(size.width * 0.5f, 310.0f));
        br->setPosition(cocos2d::CCPoint(size.width * 0.5f, 235.0f));
        addChild(menu, 2);

        cocos2d::CCLabelTTF* next = cocos2d::CCLabelTTF::create(
            "Recovery target: original Home -> Mistral -> Start of Adventure",
            "Arial", 11.0f);
        next->setPosition(cocos2d::CCPoint(size.width * 0.5f, 145.0f));
        addChild(next);

        cocos2d::CCLabelTTF* note = cocos2d::CCLabelTTF::create(
            "This screen is a temporary diagnostic bridge, not replacement BF artwork.",
            "Arial", 10.0f);
        note->setPosition(cocos2d::CCPoint(size.width * 0.5f, 112.0f));
        addChild(note);

        refresh();
        return true;
    }

    void grant5(cocos2d::CCObject*) { frontierOfflineGrantGems(5); refresh(); }
    void grant50(cocos2d::CCObject*) { frontierOfflineGrantGems(50); refresh(); }
    void grant500(cocos2d::CCObject*) { frontierOfflineGrantGems(500); refresh(); }
    void refreshCallback(cocos2d::CCObject*) { refresh(); }

private:
    cocos2d::CCLabelTTF* m_player;
    cocos2d::CCLabelTTF* m_data;
    cocos2d::CCLabelTTF* m_bootstrap;

    void refresh()
    {
        if (m_player)
        {
            const std::string summary = frontierOfflineCallString("getOfflinePlayerSummary");
            m_player->setString(summary.c_str());
        }
        if (m_data)
        {
            const std::string status = frontierOfflineCallString("getOfflineDataStatus");
            m_data->setString(status.c_str());
        }
        if (m_bootstrap)
        {
            const std::string init = frontierOfflineCallString("getOfflineInitializeJson");
            const bool ready = init.find("\"frontier_offline\":true") != std::string::npos
                && init.find("\"login_info\"") != std::string::npos
                && init.find("\"user_info\"") != std::string::npos;
            m_bootstrap->setString(ready ? "Local initialize: READY" : "Local initialize: ERROR");
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
        cocos2d::CCLayerColor* background = cocos2d::CCLayerColor::create(cocos2d::ccc4(20, 14, 28, 255));
        scene->addChild(background);
        scene->addChild(FrontierOfflineRecoveryLayer::create(), 1);
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
        {
            g_frontierOfflineApplication = new FrontierOfflineApplication();
        }
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
print("Replaced inert recovery splash with interactive native Cocos recovery hub:")
print(" - reads local player state through JNI")
print(" - verifies packaged master + mission/unit data")
print(" - verifies serverless initialize payload")
print(" - +5 / +50 / +500 Gem buttons write the same local wallet as Shop")
print(" - no server/network path added")
