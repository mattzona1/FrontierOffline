#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: harden_offline_java.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
p = root / "src/android/app/src/main/java/sg/gumi/bravefrontier/BraveFrontier.java"
if not p.exists():
    raise SystemExit(f"BraveFrontier.java missing: {p}")
s = p.read_text()


def rep(old, new, label):
    global s
    if old not in s:
        raise SystemExit(f"offline Java hardening anchor missing: {label}")
    s = s.replace(old, new, 1)

rep(
'''    public static void GPGSSignIn() {
        android.util.Log.e("BraveFrontier", "Start Sign In");
''',
'''    public static void GPGSSignIn() {
        if (OFFLINE_MODE) {
            return;
        }
        android.util.Log.e("BraveFrontier", "Start Sign In");
''', "GPGSSignIn")
rep(
'''    public static void GPGSSignOut() {
        act.signOut();
''',
'''    public static void GPGSSignOut() {
        if (OFFLINE_MODE) {
            return;
        }
        act.signOut();
''', "GPGSSignOut")
rep(
'''    public static String getDeviceAdvertisingID() {
        return deviceAdvertisingID;
''',
'''    public static String getDeviceAdvertisingID() {
        if (OFFLINE_MODE) {
            return getLegacyDeviceUUID();
        }
        return deviceAdvertisingID;
''', "getDeviceAdvertisingID")
rep(
'''    public static String getDeviceUUID() {
        String devUuid = null;
''',
'''    public static String getDeviceUUID() {
        if (OFFLINE_MODE) {
            return getLegacyDeviceUUID();
        }
        String devUuid = null;
''', "getDeviceUUID")
rep(
'''    public static String[] getPermissions() {
        String[] permissions = new String[4];
''',
'''    public static String[] getPermissions() {
        if (OFFLINE_MODE) {
            return new String[0];
        }
        String[] permissions = new String[4];
''', "getPermissions")
rep(
'''    public static void googleAnalyticsSendScreenView(String screenName) {
        act.getGameService().googleAnalyticsSendScreenView(screenName);
''',
'''    public static void googleAnalyticsSendScreenView(String screenName) {
        if (OFFLINE_MODE) return;
        act.getGameService().googleAnalyticsSendScreenView(screenName);
''', "analytics screen")
rep(
'''    public static void googleAnalyticsSetUserID(String userId) {
        act.getGameService().googleAnalyticsSetUserID(userId);
''',
'''    public static void googleAnalyticsSetUserID(String userId) {
        if (OFFLINE_MODE) return;
        act.getGameService().googleAnalyticsSetUserID(userId);
''', "analytics user")
rep(
'''    public static void googleAnalyticsTrackEvent(String category, String action, String label, long value) {
        act.getGameService().googleAnalyticsTrackEvent(category, action, label, value);
''',
'''    public static void googleAnalyticsTrackEvent(String category, String action, String label, long value) {
        if (OFFLINE_MODE) return;
        act.getGameService().googleAnalyticsTrackEvent(category, action, label, value);
''', "analytics event")
rep(
'''    public static void googleAnalyticsTrackPurchase(String transactionId, String name, String id, String category, double price, long quantity, String cu) {
        act.getGameService().googleAnalyticsTrackPurchase(transactionId, name, id, category, price, quantity, cu);
''',
'''    public static void googleAnalyticsTrackPurchase(String transactionId, String name, String id, String category, double price, long quantity, String cu) {
        if (OFFLINE_MODE) return;
        act.getGameService().googleAnalyticsTrackPurchase(transactionId, name, id, category, price, quantity, cu);
''', "analytics purchase")
rep(
'''    public static boolean isSignedInToGPGS() {
        return act.isSignedIn();
''',
'''    public static boolean isSignedInToGPGS() {
        if (OFFLINE_MODE) return false;
        return act.isSignedIn();
''', "GPGS signed-in")
rep(
'''    public static void openURL(String url) {
        Intent intent = new Intent("android.intent.action.VIEW");
''',
'''    public static void openURL(String url) {
        if (OFFLINE_MODE) {
            Log.i("FrontierOffline", "Blocked external URL request");
            return;
        }
        Intent intent = new Intent("android.intent.action.VIEW");
''', "openURL")
rep(
'''    public static void requestPermissions() {
        if (!BraveFrontier.hasPermissions()) {
''',
'''    public static void requestPermissions() {
        if (OFFLINE_MODE) return;
        if (!BraveFrontier.hasPermissions()) {
''', "requestPermissions")
rep(
'''    public static void setAppsFlyeruserId(String userId) {
        try {
''',
'''    public static void setAppsFlyeruserId(String userId) {
        if (OFFLINE_MODE) return;
        try {
''', "AppsFlyer")
rep(
'''    public static void setRemoteNotificationsEnable(boolean enable) {
        NotificationService.getInstance().setRemoteNotificationsEnable(act, enable);
''',
'''    public static void setRemoteNotificationsEnable(boolean enable) {
        if (OFFLINE_MODE) return;
        NotificationService.getInstance().setRemoteNotificationsEnable(act, enable);
''', "remote notifications")
rep(
'''    public static boolean shouldShowRequestPermissionRationale() {
        String[] permissions = BraveFrontier.getPermissions();
''',
'''    public static boolean shouldShowRequestPermissionRationale() {
        if (OFFLINE_MODE) return false;
        String[] permissions = BraveFrontier.getPermissions();
''', "permission rationale")
rep(
'''    public static void showAchievements() {
        GameService gs = act.getGameService();
''',
'''    public static void showAchievements() {
        if (OFFLINE_MODE) return;
        GameService gs = act.getGameService();
''', "achievements")
rep(
'''    public static void trackEvent2(byte[] keyBytes, byte[] unk) {
        String key = (keyBytes == null) ? null : new String(keyBytes);
''',
'''    public static void trackEvent2(byte[] keyBytes, byte[] unk) {
        if (OFFLINE_MODE) return;
        String key = (keyBytes == null) ? null : new String(keyBytes);
''', "trackEvent2")
rep(
'''    public static void trackPurchase(float price, String countryValueName) {
        if (act != null) {
''',
'''    public static void trackPurchase(float price, String countryValueName) {
        if (OFFLINE_MODE) return;
        if (act != null) {
''', "trackPurchase")

p.write_text(s)
print("Hardened BraveFrontier.java for serverless/offline operation")
print(" - no runtime network permission requests")
print(" - no external URL intents")
print(" - no remote notifications")
print(" - no analytics/Appsflyer/GPGS calls")
print(" - local generated device ID used instead of phone identifiers")
