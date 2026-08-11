#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_offline_store.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
store = root / "src/android/app/src/main/java/com/soomla/store/StoreController.java"
billing = root / "src/android/app/src/main/java/sg/gumi/util/GooglePlayBilling.java"
jni = root / "src/android/app/src/main/java/sg/gumi/bravefrontier/BraveFrontierJNI.java"
manifest = root / "src/android/app/src/main/AndroidManifest.xml"
offline_store = root / "src/android/app/src/main/java/sg/gumi/bravefrontier/OfflineGemStore.java"

for p in (store, billing, jni, manifest):
    if not p.exists():
        raise SystemExit(f"required offline-shop source missing: {p}")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"offline shop patch anchor missing: {label}")
    return text.replace(old, new, 1)


# A tiny on-device gem wallet. This is deliberately independent of Google Play
# and every network API. It is also exposed to JNI so the recovered native
# player-state/bootstrap layer can use the same balance as restoration advances.
offline_store.write_text(r'''package sg.gumi.bravefrontier;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.SharedPreferences;
import android.widget.Toast;

public final class OfflineGemStore {
    private static final String PREFS = "frontier_offline_state";
    private static final String KEY_GEMS = "gems";

    private OfflineGemStore() {
    }

    private static Context context() {
        Context c = BraveFrontier.getAppContext();
        if (c == null && BraveFrontier.getActivity() != null) {
            c = BraveFrontier.getActivity().getApplicationContext();
        }
        return c;
    }

    public static int getGems() {
        Context c = context();
        if (c == null) {
            return 0;
        }
        SharedPreferences prefs = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        return prefs.getInt(KEY_GEMS, 0);
    }

    public static int grantGems(int amount) {
        if (amount <= 0) {
            return getGems();
        }
        Context c = context();
        if (c == null) {
            return 0;
        }
        SharedPreferences prefs = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        long next = (long)prefs.getInt(KEY_GEMS, 0) + (long)amount;
        if (next > Integer.MAX_VALUE) {
            next = Integer.MAX_VALUE;
        }
        prefs.edit().putInt(KEY_GEMS, (int)next).apply();
        return (int)next;
    }

    private static void grantAndToast(Activity activity, int amount) {
        int balance = grantGems(amount);
        Toast.makeText(activity, "+" + amount + " Gems   Balance: " + balance,
                Toast.LENGTH_SHORT).show();
    }

    public static void showGemDialog() {
        final Activity activity = BraveFrontier.getActivity();
        if (activity == null || activity.isFinishing()) {
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                AlertDialog dialog = new AlertDialog.Builder(activity)
                        .setTitle("Offline Gem Utility")
                        .setMessage("Current Gems: " + getGems()
                                + "\n\nPurchases are disabled. Choose a local Gem grant.")
                        .setPositiveButton("+5 Gems", (d, which) -> grantAndToast(activity, 5))
                        .setNeutralButton("+50 Gems", (d, which) -> grantAndToast(activity, 50))
                        .setNegativeButton("+500 Gems", (d, which) -> grantAndToast(activity, 500))
                        .create();
                dialog.setCanceledOnTouchOutside(true);
                dialog.show();
            }
        });
    }
}
''')


# StoreController remains the original entry point used by the game's Shop.
# In offline mode opening the Store now presents only the three local grant
# options. No billing object is ever initialized and purchase callbacks never
# reach the old network/server verification path.
s = store.read_text()
s = replace_once(
    s,
    '''    public void initialize(IStoreAssets storeAssets, Activity activity, Handler handler) {
        mActivity = activity;
        mHandler = handler;
        Log.d("StoreController", "initialize store assets");
        if (storeAssets != null) {
            StoreInfo.setStoreAssets(storeAssets);
        }
        startBillingService();
    }
''',
    '''    public void initialize(IStoreAssets storeAssets, Activity activity, Handler handler) {
        mActivity = activity;
        mHandler = handler;
        Log.d("StoreController", "initialize store assets");
        if (storeAssets != null) {
            StoreInfo.setStoreAssets(storeAssets);
        }
        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {
            Log.i("FrontierOffline", "Billing initialization skipped");
            return;
        }
        startBillingService();
    }
''',
    "StoreController.initialize",
)
s = replace_once(
    s,
    '''    public void _syncItemPricesAndPurchases() {
        if (this.mGooglePlayBillingService == null) {
''',
    '''    public void _syncItemPricesAndPurchases() {
        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {
            return;
        }
        if (this.mGooglePlayBillingService == null) {
''',
    "StoreController._syncItemPricesAndPurchases",
)
s = replace_once(
    s,
    '''    public void _buyGoogleMarketItem(String str) throws Exception {
        SharedPreferences.Editor edit = PreferenceManager.getDefaultSharedPreferences(BraveFrontier.getAppContext()).edit();
''',
    '''    public void _buyGoogleMarketItem(String str) throws Exception {
        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {
            sg.gumi.bravefrontier.OfflineGemStore.showGemDialog();
            return;
        }
        SharedPreferences.Editor edit = PreferenceManager.getDefaultSharedPreferences(BraveFrontier.getAppContext()).edit();
''',
    "StoreController._buyGoogleMarketItem",
)
s = replace_once(
    s,
    '''    public void _storeOpening() {
        Log.d("StoreController", "opening store");
        this.mLock.lock();
''',
    '''    public void _storeOpening() {
        Log.d("StoreController", "opening store");
        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {
            this.mStoreOpen = true;
            sg.gumi.bravefrontier.OfflineGemStore.showGemDialog();
            return;
        }
        this.mLock.lock();
''',
    "StoreController._storeOpening",
)
s = replace_once(
    s,
    '''    public void onPurchaseStateChange(String iapData, String iapSignature, String purchase) {
        String productId;
''',
    '''    public void onPurchaseStateChange(String iapData, String iapSignature, String purchase) {
        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {
            Log.i("FrontierOffline", "Ignoring legacy purchase callback in offline mode");
            return;
        }
        String productId;
''',
    "StoreController.onPurchaseStateChange",
)
s = replace_once(
    s,
    '''    static String getPackPriceForProductID(String productId) {
        Log.d("BraveFrontier", "Get pack price");
''',
    '''    static String getPackPriceForProductID(String productId) {
        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {
            return "OFFLINE";
        }
        Log.d("BraveFrontier", "Get pack price");
''',
    "StoreController.getPackPriceForProductID",
)
s = replace_once(
    s,
    '''    private boolean startBillingService() {
        Log.d("StoreController", "startBillingService()");
        this.mLock.lock();
''',
    '''    private boolean startBillingService() {
        Log.d("StoreController", "startBillingService()");
        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {
            Log.i("FrontierOffline", "Google Play billing disabled");
            return true;
        }
        this.mLock.lock();
''',
    "StoreController.startBillingService",
)
store.write_text(s)


# Belt-and-suspenders: even if an old code path instantiates GooglePlayBilling,
# every entry point is inert when OFFLINE_MODE is set.
s = billing.read_text()
s = replace_once(
    s,
    '''    public void RequestPurchase(String productId) {
        VirtualCurrencyPack pack;
''',
    '''    public void RequestPurchase(String productId) {
        if (BFConfig.OFFLINE_MODE) {
            sg.gumi.bravefrontier.OfflineGemStore.showGemDialog();
            return;
        }
        VirtualCurrencyPack pack;
''',
    "GooglePlayBilling.RequestPurchase",
)
s = replace_once(
    s,
    '''    public void SyncItemPricesAndPurchasesThread() {

        ArrayList<String> products = new ArrayList<>();
''',
    '''    public void SyncItemPricesAndPurchasesThread() {
        if (BFConfig.OFFLINE_MODE) {
            return;
        }

        ArrayList<String> products = new ArrayList<>();
''',
    "GooglePlayBilling.SyncItemPricesAndPurchasesThread",
)
s = replace_once(
    s,
    '''    public void initialize() {
        billingClient = BillingClient.newBuilder(BraveFrontier.getActivity()).setListener(this).enablePendingPurchases().build();;
''',
    '''    public void initialize() {
        if (BFConfig.OFFLINE_MODE) {
            Log.i(TAG, "Billing client not created in offline mode");
            billingClient = null;
            return;
        }
        billingClient = BillingClient.newBuilder(BraveFrontier.getActivity()).setListener(this).enablePendingPurchases().build();;
''',
    "GooglePlayBilling.initialize",
)
billing.write_text(s)


# Make the local wallet visible to the native recovery layer without invoking
# any old purchase callback. This gives later player-state restoration one
# authoritative local balance to read/write.
s = jni.read_text()
anchor = '    private static String replaceGooglePlayStoreName(String input, String playStoreName, String companyName) {'
insert = '''    public static int getOfflineGemBalance() {
        return OfflineGemStore.getGems();
    }

    public static int grantOfflineGems(int amount) {
        return OfflineGemStore.grantGems(amount);
    }

'''
if anchor not in s:
    raise SystemExit("offline shop patch anchor missing: BraveFrontierJNI local wallet bridge")
s = s.replace(anchor, insert + anchor, 1)
jni.write_text(s)


# Expand the hard sandbox disconnect beyond Internet itself: billing, push,
# account, install-referrer and other network-era permissions are removed too.
s = manifest.read_text()
permissions = (
    "android.permission.INTERNET",
    "android.permission.ACCESS_WIFI_STATE",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.READ_PHONE_STATE",
    "android.permission.READ_PRIVILEGED_PHONE_STATE",
    "android.permission.START_BACKGROUND_SERVICE",
    "android.permission.GET_ACCOUNTS",
    "com.android.vending.BILLING",
    "com.google.android.c2dm.permission.RECEIVE",
    "com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE",
    "sg.gumi.bravefrontier.permission.C2D_MESSAGE",
)
for permission in permissions:
    plain = f'    <uses-permission android:name="{permission}"/>'
    marked = f'    <uses-permission android:name="{permission}" tools:node="remove"/>'
    if plain in s:
        s = s.replace(plain, marked, 1)

# Stop online SDK components from starting even if their libraries remain in
# the dependency graph for compatibility with the recovered Java sources.
patterns = [
    r'\s*<meta-data android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID"[^>]*/>',
    r'\s*<meta-data android:name="com\.google\.android\.gms\.games\.APP_ID"[^>]*/>',
    r'\s*<meta-data android:name="com\.google\.android\.gms\.version"[^>]*/>',
    r'\s*<activity android:name="com\.facebook\.FacebookActivity"[^>]*/>',
    r'\s*<meta-data android:name="com\.facebook\.sdk\.ApplicationId"[^>]*/>',
    r'\s*<meta-data android:name="com\.facebook\.sdk\.ClientToken"[^>]*/>',
    r'\s*<activity[^>]*android:name="sg\.gumi\.bravefrontier\.YoutubeActivity"[^>]*>\s*<meta-data[^>]*/>\s*</activity>',
    r'\s*<receiver[^>]*android:name="com\.google\.android\.gms\.analytics\.AnalyticsReceiver"[^>]*/>',
    r'\s*<service[^>]*android:name="com\.google\.android\.gms\.analytics\.AnalyticsService"[^>]*/>',
    r'\s*<service[^>]*android:name="com\.google\.android\.gms\.analytics\.AnalyticsJobService"[^>]*/>',
    r'\s*<service[^>]*android:name="com\.google\.firebase\.components\.ComponentDiscoveryService"[^>]*>.*?</service>',
    r'\s*<receiver[^>]*android:name="com\.google\.firebase\.iid\.FirebaseInstanceIdReceiver"[^>]*>.*?</receiver>',
    r'\s*<provider[^>]*android:name="com\.google\.firebase\.provider\.FirebaseInitProvider"[^>]*/>',
    r'\s*<activity[^>]*android:name="com\.google\.android\.gms\.common\.api\.GoogleApiActivity"[^>]*/>',
    r'\s*<service[^>]*android:name="com\.google\.android\.datatransport\.runtime\.backends\.TransportBackendDiscovery"[^>]*>.*?</service>',
    r'\s*<service[^>]*android:name="com\.google\.android\.datatransport\.runtime\.scheduling\.jobscheduling\.JobInfoSchedulerService"[^>]*/>',
    r'\s*<receiver[^>]*android:name="com\.google\.android\.datatransport\.runtime\.scheduling\.jobscheduling\.AlarmManagerSchedulerBroadcastReceiver"[^>]*/>',
    r'\s*<activity[^>]*android:name="com\.facebook\.CustomTabMainActivity"[^>]*/>',
    r'\s*<activity[^>]*android:name="com\.facebook\.CustomTabActivity"[^>]*>.*?</activity>',
    r'\s*<provider[^>]*android:name="com\.facebook\.internal\.FacebookInitProvider"[^>]*/>',
    r'\s*<receiver[^>]*android:name="com\.facebook\.CurrentAccessTokenExpirationBroadcastReceiver"[^>]*>.*?</receiver>',
]
for pattern in patterns:
    s = re.sub(pattern, '', s, flags=re.DOTALL)
manifest.write_text(s)

print("Applied offline Shop / hard-disconnect patch:")
print(" - Google Play billing initialization disabled")
print(" - Store opening replaced with local +5/+50/+500 Gem utility")
print(" - legacy purchase callback path disabled")
print(" - local Gem balance persisted on-device")
print(" - JNI bridge exposes local Gem balance to recovered native state")
print(" - billing/push/account/network permissions removed")
print(" - Firebase/Analytics/Facebook/YouTube network-era components removed")
