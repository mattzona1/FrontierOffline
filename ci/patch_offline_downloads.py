#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_offline_downloads.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
p = root / "src/android/app/src/main/java/sg/gumi/util/AsyncFileLoad.java"
if not p.exists():
    raise SystemExit(f"AsyncFileLoad.java missing: {p}")

s = p.read_text()

# Add standard Java I/O imports used by the APK-asset path. Existing HTTP
# imports can remain for source compatibility, but OFFLINE_MODE returns before
# an HttpGet or connection is ever constructed.
anchor = 'import sg.gumi.bravefrontier.BraveFrontierJNI;\n'
imports = '''import sg.gumi.bravefrontier.BraveFrontierJNI;

import android.content.res.AssetManager;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
'''
if anchor not in s:
    raise SystemExit("AsyncFileLoad import anchor missing")
s = s.replace(anchor, imports, 1)

run_anchor = '''    @Override
    public void run() {
        try {
'''
run_replace = '''    private byte[] readAsset(String assetPath) {
        if (assetPath == null || assetPath.isEmpty()) return null;
        try {
            AssetManager assets = BraveFrontier.getAppContext().getAssets();
            try (InputStream in = assets.open(assetPath);
                 ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[16384];
                int count;
                while ((count = in.read(buffer)) > 0) {
                    out.write(buffer, 0, count);
                }
                return out.toByteArray();
            }
        } catch (Throwable ignored) {
            return null;
        }
    }

    /**
     * Resolve an old remote resource request against files physically bundled
     * inside the APK. The candidate list intentionally contains no network or
     * localhost fallback. As restoration grows, complete original asset paths
     * can be placed under client/data and this resolver will pick them up.
     */
    private byte[] readOfflineAsset(String requested) {
        if (requested == null) return null;
        String normalized = requested.trim().replace('\\\\', '/');
        int query = normalized.indexOf('?');
        if (query >= 0) normalized = normalized.substring(0, query);
        int fragment = normalized.indexOf('#');
        if (fragment >= 0) normalized = normalized.substring(0, fragment);

        // Strip scheme/host without opening or resolving anything.
        int scheme = normalized.indexOf("://");
        if (scheme >= 0) {
            int pathStart = normalized.indexOf('/', scheme + 3);
            normalized = pathStart >= 0 ? normalized.substring(pathStart + 1) : "";
        }
        while (normalized.startsWith("/")) normalized = normalized.substring(1);
        while (normalized.startsWith("./")) normalized = normalized.substring(2);

        String base = normalized;
        int slash = base.lastIndexOf('/');
        if (slash >= 0) base = base.substring(slash + 1);

        LinkedHashSet<String> candidates = new LinkedHashSet<>();
        if (!normalized.isEmpty()) {
            candidates.add(normalized);
            candidates.add("frontier_offline/" + normalized);
        }
        if (!base.isEmpty()) {
            candidates.add("frontier_offline/system/" + base);
            candidates.add("frontier_offline/" + base);
            candidates.add(base);
        }

        for (String candidate : candidates) {
            byte[] local = readAsset(candidate);
            if (local != null) {
                android.util.Log.i("FrontierOffline", "Resolved packaged asset: " + candidate);
                return local;
            }
        }
        return null;
    }

    private void runOffline() {
        byte[] local = readOfflineAsset(downloadurl);
        data = local;
        downloadedLen = local == null ? 0 : local.length;
        contentLength = downloadedLen;
        error = local == null ? "Offline asset not packaged: " + downloadurl : null;

        BraveFrontier.getActivity().getGLView().queueEvent(
                new DownloadCallbackEvent(obj, data, error));
        data = null;
    }

    @Override
    public void run() {
        if (BFConfig.OFFLINE_MODE) {
            runOffline();
            return;
        }
        try {
'''
if run_anchor not in s:
    raise SystemExit("AsyncFileLoad run anchor missing")
s = s.replace(run_anchor, run_replace, 1)

p.write_text(s)
print("Patched AsyncFileLoad for APK-only offline resolution")
print(" - every OFFLINE_MODE request resolves from AssetManager")
print(" - bundled system/master JSON is addressable by original basename")
print(" - unbundled resources fail locally with a deterministic callback")
print(" - HttpGet/connection code is unreachable in OFFLINE_MODE")
