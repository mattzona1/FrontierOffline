#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: strip_online_components.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
manifest = root / "src/android/app/src/main/AndroidManifest.xml"
if not manifest.exists():
    raise SystemExit(f"manifest not found: {manifest}")

s = manifest.read_text()
if 'xmlns:tools=' not in s:
    s = s.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n          xmlns:tools="http://schemas.android.com/tools">',
        1,
    )

# Library manifests can re-add components even after the app manifest's old
# declarations are removed. These explicit tools:node="remove" declarations
# win during manifest merge and make the resulting APK incapable of auto-
# starting the old billing, analytics, Firebase, Facebook, or transport code.
remove_nodes = '''
        <!-- FrontierOffline: remove transitive online SDK components -->
        <activity android:name="com.android.billingclient.api.ProxyBillingActivity" tools:node="remove" />
        <activity android:name="com.google.android.gms.common.api.GoogleApiActivity" tools:node="remove" />
        <activity android:name="com.facebook.FacebookActivity" tools:node="remove" />
        <activity android:name="com.facebook.CustomTabMainActivity" tools:node="remove" />
        <activity android:name="com.facebook.CustomTabActivity" tools:node="remove" />

        <receiver android:name="com.google.android.gms.analytics.AnalyticsReceiver" tools:node="remove" />
        <receiver android:name="com.google.firebase.iid.FirebaseInstanceIdReceiver" tools:node="remove" />
        <receiver android:name="com.google.android.datatransport.runtime.scheduling.jobscheduling.AlarmManagerSchedulerBroadcastReceiver" tools:node="remove" />
        <receiver android:name="com.facebook.CurrentAccessTokenExpirationBroadcastReceiver" tools:node="remove" />

        <service android:name="com.google.android.gms.analytics.AnalyticsService" tools:node="remove" />
        <service android:name="com.google.android.gms.analytics.AnalyticsJobService" tools:node="remove" />
        <service android:name="com.google.firebase.components.ComponentDiscoveryService" tools:node="remove" />
        <service android:name="com.google.android.datatransport.runtime.backends.TransportBackendDiscovery" tools:node="remove" />
        <service android:name="com.google.android.datatransport.runtime.scheduling.jobscheduling.JobInfoSchedulerService" tools:node="remove" />

        <provider android:name="com.google.firebase.provider.FirebaseInitProvider" tools:node="remove" />
        <provider android:name="com.facebook.internal.FacebookInitProvider" tools:node="remove" />
'''

if 'FrontierOffline: remove transitive online SDK components' not in s:
    if '</application>' not in s:
        raise SystemExit('application closing tag not found')
    s = s.replace('</application>', remove_nodes + '    </application>', 1)

manifest.write_text(s)
print('Added manifest-merger removals for billing/Firebase/Analytics/Facebook/DataTransport components')
