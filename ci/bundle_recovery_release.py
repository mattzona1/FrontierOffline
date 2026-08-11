#!/usr/bin/env python3
from pathlib import Path, PurePosixPath
import hashlib
import io
import json
import os
import sys
import urllib.request
import zipfile

if len(sys.argv) != 2:
    raise SystemExit("usage: bundle_recovery_release.py <decompfrontier-client-root>")

root = Path(sys.argv[1])
out_root = root / "data/frontier_offline/recovery"
out_root.mkdir(parents=True, exist_ok=True)

# Community recovery release used only as a BUILD-TIME static-data source.
# No executable/server component from this archive is packaged or launched.
URL = "https://github.com/Seltraeh/server/releases/download/Mission-and-Units-v1.0/server.zip"
EXPECTED_SHA256 = "6af8d202358e0f8015f48c4488ef77bbeece7d9c6cd7e38c6e6dfbb050bae89d"

req = urllib.request.Request(URL, headers={"User-Agent": "FrontierOffline-Build/1.0"})
with urllib.request.urlopen(req, timeout=180) as response:
    payload = response.read()

digest = hashlib.sha256(payload).hexdigest()
if digest != EXPECTED_SHA256:
    raise SystemExit(f"recovery release checksum mismatch: {digest}")

# Only static data/document formats are allowed through this extraction gate.
# In particular: no exe/dll/so/bat/ps1/server binary is copied into the APK.
ALLOWED_SUFFIXES = {
    ".json", ".csv", ".txt", ".xml", ".plist",
    ".db", ".sqlite", ".sqlite3", ".dat", ".cfg", ".ini",
}

manifest = {
    "source": "Seltraeh/server Mission-and-Units-v1.0",
    "archive_sha256": digest,
    "files": {},
}

copied = 0
copied_bytes = 0
interesting = []
with zipfile.ZipFile(io.BytesIO(payload), "r") as archive:
    for info in archive.infolist():
        if info.is_dir():
            continue
        raw_name = info.filename.replace("\\", "/")
        path = PurePosixPath(raw_name)
        if path.is_absolute() or ".." in path.parts:
            continue
        suffix = path.suffix.lower()
        if suffix not in ALLOWED_SUFFIXES:
            continue

        data = archive.read(info)
        # Avoid packaging accidental huge binary blobs with misleading suffixes.
        if len(data) > 64 * 1024 * 1024:
            continue

        # Keep the archive structure beneath recovery/ so paths remain traceable.
        dest = out_root.joinpath(*path.parts)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        item_sha = hashlib.sha256(data).hexdigest()
        rel = dest.relative_to(root / "data").as_posix()
        manifest["files"][rel] = {"bytes": len(data), "sha256": item_sha}
        copied += 1
        copied_bytes += len(data)

        lower = raw_name.lower()
        if any(token in lower for token in (
            "mission", "quest", "unit", "monster", "item", "sphere",
            "skill", "summon", "gacha", "fusion", "evol", "player",
        )):
            interesting.append(rel)

manifest["file_count"] = copied
manifest["total_bytes"] = copied_bytes
manifest["interesting_paths"] = sorted(interesting)
manifest_path = root / "data/frontier_offline/recovery_manifest.json"
manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")

if copied == 0:
    raise SystemExit("recovery archive contained no permitted static data")

print(f"Recovery data: {copied} static files, {copied_bytes:,} bytes")
print(f"Mission/unit/item-related paths: {len(interesting)}")
for path in sorted(interesting)[:80]:
    print(f"  RECOVERY_DATA {path}")
print("No executable/server component was packaged")
