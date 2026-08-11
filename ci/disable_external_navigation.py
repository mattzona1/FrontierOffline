#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: disable_external_navigation.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
webview = root / "src/android/app/src/main/java/sg/gumi/bravefrontier/webview/BFWebView.java"
client = root / "src/android/app/src/main/java/sg/gumi/bravefrontier/webview/BFWebViewClient.java"
jni = root / "src/android/app/src/main/java/sg/gumi/bravefrontier/BraveFrontierJNI.java"
for p in (webview, client, jni):
    if not p.exists():
        raise SystemExit(f"external-navigation source missing: {p}")


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"external-navigation patch anchor missing: {label}")
    return text.replace(old, new, 1)


s = webview.read_text()
s = replace_once(
    s,
    '''    public static boolean canLaunchUrl(String url) {
        Intent intent = new Intent("android.intent.action.VIEW");
''',
    '''    public static boolean canLaunchUrl(String url) {
        if (BFConfig.OFFLINE_MODE) {
            return false;
        }
        Intent intent = new Intent("android.intent.action.VIEW");
''',
    "BFWebView.canLaunchUrl",
)
s = replace_once(
    s,
    '''    public static boolean launchNewApplication(String url) {
        try {
''',
    '''    public static boolean launchNewApplication(String url) {
        if (BFConfig.OFFLINE_MODE) {
            return false;
        }
        try {
''',
    "BFWebView.launchNewApplication",
)
s = replace_once(
    s,
    '''    public static void launchNewBrowser(String url) {
        try {
''',
    '''    public static void launchNewBrowser(String url) {
        if (BFConfig.OFFLINE_MODE) {
            return;
        }
        try {
''',
    "BFWebView.launchNewBrowser",
)
s = replace_once(
    s,
    '''    public static void playYoutubeVideo(String url) {
        BFWebView.getInstance().playYoutubeVideoHelper(url);
''',
    '''    public static void playYoutubeVideo(String url) {
        if (BFConfig.OFFLINE_MODE) {
            BraveFrontierJNI.videoSkippedCallback();
            return;
        }
        BFWebView.getInstance().playYoutubeVideoHelper(url);
''',
    "BFWebView.playYoutubeVideo",
)
s = replace_once(
    s,
    '''    public static void showWebView(String url, float f, float f0, float f1, float f2) {
        BFWebView.getInstance().showWebViewHelper(url, f, f0, f1, f2);
''',
    '''    public static void showWebView(String url, float f, float f0, float f1, float f2) {
        if (BFConfig.OFFLINE_MODE) {
            return;
        }
        BFWebView.getInstance().showWebViewHelper(url, f, f0, f1, f2);
''',
    "BFWebView.showWebView",
)
webview.write_text(s)


# Never allow a WebView navigation or mailto intent in offline mode. Internal
# bfcall:// callbacks are still allowed because they are game-local events.
s = client.read_text()
s = replace_once(
    s,
    '''    public boolean shouldOverrideUrlLoading(WebView webview, WebResourceRequest webResourceRequest) {
        String s = webResourceRequest.getUrl().toString();
''',
    '''    public boolean shouldOverrideUrlLoading(WebView webview, WebResourceRequest webResourceRequest) {
        String s = webResourceRequest.getUrl().toString();
        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {
            if (s.startsWith(BRAVE_CALL)) {
                callBraveMethode(s.replace(BRAVE_CALL, ""));
            }
            return true;
        }
''',
    "BFWebViewClient.request override",
)
s = replace_once(
    s,
    '''    public boolean shouldOverrideUrlLoading(WebView webView, String url) {
        if (url.startsWith("mailto:")) {
''',
    '''    public boolean shouldOverrideUrlLoading(WebView webView, String url) {
        if (sg.gumi.util.BFConfig.OFFLINE_MODE) {
            if (url != null && url.startsWith(BRAVE_CALL)) {
                callBraveMethode(url.replace(BRAVE_CALL, ""));
            }
            return true;
        }
        if (url.startsWith("mailto:")) {
''',
    "BFWebViewClient.string override",
)
client.write_text(s)


# The old rate dialog opened Google Play/Amazon/Samsung store applications. In
# the offline build its positive button simply closes the prompt locally.
s = jni.read_text()
s = replace_once(
    s,
    '''            public void onClick(android.content.DialogInterface dialogInterface, int i) {
                String reviewUrl = null;
''',
    '''            public void onClick(android.content.DialogInterface dialogInterface, int i) {
                if (OFFLINE_MODE) {
                    sg.gumi.bravefrontier.BraveFrontierJNI.nativeRateThisAppPopupCallback(1);
                    return;
                }
                String reviewUrl = null;
''',
    "BraveFrontierJNI rate/store intent",
)
jni.write_text(s)

print("Disabled external navigation in OFFLINE_MODE:")
print(" - browser/app URL intents")
print(" - remote WebView navigation")
print(" - mailto intents")
print(" - YouTube playback entry point")
print(" - app-store/rating links")
