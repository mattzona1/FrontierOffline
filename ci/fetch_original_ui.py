#!/usr/bin/env python3
import os, json, urllib.request

OUT = "assets/bf/original"
BASE = "https://raw.githubusercontent.com/aMytho/brave-frontier-godot/main/"
UA = "FrontierOfflineBuild/2.0"

ASSETS = {
    "battle_ui.png": "Battle/UI/battle_ui.png",
    "battle_header.png": "Battle/UI/battle_header_ip5.png",
    "battle_auto_up.png": "Battle/UI/battle_auto_btn1.png",
    "battle_auto_down.png": "Battle/UI/battle_auto_btn2.png",
    "battle_speed_up.png": "Battle/UI/battle_speed_btn1_1.png",
    "battle_speed_down.png": "Battle/UI/battle_speed_btn2_1.png",
    "battle_target_mark.png": "Battle/UI/battle_target_mark.png",
    "battle_footer.png": "Battle/UI/iphx_footer.png",
}

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read(), r.headers.get_content_type()

def main():
    os.makedirs(OUT, exist_ok=True)
    manifest=[]
    total=0
    for dest, src in ASSETS.items():
        url=BASE+src
        data, ctype=get(url)
        if len(data) < 1000:
            raise RuntimeError(f"Original asset too small: {src}")
        path=os.path.join(OUT,dest)
        with open(path,"wb") as f: f.write(data)
        total += len(data)
        manifest.append({"file":dest,"source":src,"url":url,"bytes":len(data),"content_type":ctype})
        print(f"ORIGINAL {dest:<26} {len(data)/1024:.1f} KiB")
    with open(os.path.join(OUT,"manifest.json"),"w",encoding="utf-8") as f:
        json.dump({"count":len(manifest),"bytes":total,"assets":manifest},f,indent=2)
    if len(manifest) != len(ASSETS):
        return 2
    print(f"Bundled {len(manifest)} preserved original UI assets / {total/1024:.1f} KiB")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
