#!/usr/bin/env python3
import os, re, sys, json, io, zipfile, urllib.request, urllib.parse

ROOT = "https://www.bravefrontier.jp"
OUT = "assets/bf"
UA = "Mozilla/5.0 FrontierOfflineBuild/1.2"

CORE_ASSETS = [
    (1,"vargas_official.png"),(5,"selena_official.png"),(9,"lance_official.png"),(13,"eze_official.png"),(17,"atro_official.png"),(21,"magress_official.png"),
    (25,"zelgal_official.png"),(28,"zephu_official.png"),(31,"lario_official.png"),(34,"weiss_official.png"),(37,"luna_official.png"),(40,"mifune_official.png"),
    (43,"enemy_moerus.png"),(45,"enemy_mizurus.png"),(47,"enemy_morirus.png"),(49,"enemy_rairus.png"),(278,"enemy_caitsith.png"),(279,"enemy_imp.png")
]
EXTRA_IDS = list(range(50, 121))
ASSETS = CORE_ASSETS + [(no, f"archive_unit_{no:04d}.png") for no in EXTRA_IDS]

# Preservation resources catalogued by The Spriters Resource. These are optional because
# its CDN occasionally rejects CI traffic; successful downloads are bundled into the APK.
TSR_SINGLE = [
    ("https://www.spriters-resource.com/media/assets/95/95591.png", "bfm_backgrounds.png"),
    ("https://www.spriters-resource.com/media/assets/95/95596.png", "bfm_hud.png"),
    ("https://www.spriters-resource.com/media/assets/95/95595.png", "bfm_special_battle.png"),
    ("https://www.spriters-resource.com/media/assets/95/95593.png", "bfm_field_sprites.png"),
    ("https://www.spriters-resource.com/media/assets/95/95594.png", "bfm_unit_portraits.png"),
]
TSR_ZIPS = [
    ("https://www.spriters-resource.com/media/assets/84/86737.zip", "vargas"),
    ("https://www.spriters-resource.com/media/assets/84/86768.zip", "goblin"),
]

def get(url, referer=None):
    headers={"User-Agent":UA,"Accept":"*/*"}
    if referer: headers["Referer"] = referer
    req=urllib.request.Request(url,headers=headers)
    with urllib.request.urlopen(req,timeout=30) as r:
        return r.read(), r.headers.get_content_type()

def abs_url(path):
    path=path.replace("&amp;","&")
    if path.startswith("//"): return "https:"+path
    return urllib.parse.urljoin(ROOT+"/library/bf1/",path)

def candidates(html):
    found=[]
    for raw in re.findall(r'(?:src|href)=[\"\']([^\"\']+\.(?:png|jpg|jpeg|webp)(?:\?[^\"\']*)?)[\"\']',html,re.I):
        low=raw.lower()
        if any(x in low for x in ["logo","icon","btn","common","header","footer"]): continue
        score=0
        if "anime" in low or "sprite" in low: score += 100
        if "full" in low or "unit" in low or "chara" in low or "large" in low: score += 50
        found.append((score,abs_url(raw)))
    return sorted(found, reverse=True)

def save_best(no, filename):
    page=f"{ROOT}/library/bf1/bf1_full.php?no={no}"
    body,_=get(page)
    html=body.decode("utf-8","ignore")
    urls=candidates(html)
    if not urls: raise RuntimeError(f"no image candidate for unit {no}")
    for score,url in urls:
        try:
            data,ctype=get(url, ROOT+"/")
            if len(data) < 8000: continue
            path=os.path.join(OUT,filename)
            with open(path,"wb") as f: f.write(data)
            return {"kind":"unit_art","no":no,"file":filename,"url":url,"bytes":len(data),"content_type":ctype,"score":score}
        except Exception:
            pass
    raise RuntimeError(f"could not download usable image for {no}")

def download_tsr_single(url, filename):
    data,ctype=get(url,"https://www.spriters-resource.com/")
    if len(data)<8000: raise RuntimeError("response too small")
    with open(os.path.join(OUT,filename),"wb") as f:f.write(data)
    return {"kind":"battle_pack","file":filename,"url":url,"bytes":len(data),"content_type":ctype}

def extract_tsr_zip(url, label):
    data,ctype=get(url,"https://www.spriters-resource.com/")
    if len(data)<10000: raise RuntimeError("zip response too small")
    z=zipfile.ZipFile(io.BytesIO(data))
    added=[]
    for member in z.namelist():
        base=os.path.basename(member)
        low=base.lower()
        if not base or not low.endswith(".png"): continue
        if "unit_anime_" not in low and "unit_ills_full_" not in low: continue
        payload=z.read(member)
        if len(payload)<3000: continue
        # Preserve canonical names so Godot code can address sprite sheets directly.
        dest=base
        with open(os.path.join(OUT,dest),"wb") as f:f.write(payload)
        added.append({"kind":"sprite_sheet","pack":label,"file":dest,"url":url,"bytes":len(payload),"content_type":"image/png"})
    if not added: raise RuntimeError("no usable PNGs in zip")
    return added

def main():
    os.makedirs(OUT,exist_ok=True)
    manifest=[]
    failures=[]
    for no,filename in ASSETS:
        try:
            item=save_best(no,filename)
            manifest.append(item)
            print(f"BUNDLED {no:>3} {filename:<24} {item['bytes']/1024:.1f} KiB")
        except Exception as e:
            failures.append({"source":"official","no":no,"file":filename,"error":str(e)})
            print(f"FAILED {no} {filename}: {e}",file=sys.stderr)

    for url,filename in TSR_SINGLE:
        try:
            item=download_tsr_single(url,filename);manifest.append(item)
            print(f"BATTLE  {filename:<28} {item['bytes']/1024:.1f} KiB")
        except Exception as e:
            failures.append({"source":"tsr","file":filename,"error":str(e)})
            print(f"OPTIONAL BATTLE PACK FAILED {filename}: {e}",file=sys.stderr)

    for url,label in TSR_ZIPS:
        try:
            items=extract_tsr_zip(url,label);manifest.extend(items)
            print(f"SPRITES {label}: {len(items)} PNG files / {sum(x['bytes'] for x in items)/1024:.1f} KiB")
        except Exception as e:
            failures.append({"source":"tsr_zip","pack":label,"error":str(e)})
            print(f"OPTIONAL SPRITE PACK FAILED {label}: {e}",file=sys.stderr)

    total=sum(x["bytes"] for x in manifest)
    with open(os.path.join(OUT,"manifest.json"),"w",encoding="utf-8") as f:
        json.dump({"assets":manifest,"failures":failures,"count":len(manifest),"bytes":total},f,indent=2)
    print(f"Bundled {len(manifest)} assets / {total/1024/1024:.2f} MiB")
    if len(manifest) < 30 or total < 2_000_000:
        print("Asset payload too small; refusing to produce another deceptively tiny APK.",file=sys.stderr)
        return 2
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
