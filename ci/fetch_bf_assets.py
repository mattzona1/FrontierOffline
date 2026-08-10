#!/usr/bin/env python3
import os, re, sys, json, urllib.request, urllib.parse

ROOT = "https://www.bravefrontier.jp"
OUT = "assets/bf"
UA = "Mozilla/5.0 FrontierOfflineBuild/1.0"
ASSETS = [
    (1,"vargas_official.png"),(5,"selena_official.png"),(9,"lance_official.png"),(13,"eze_official.png"),(17,"atro_official.png"),(21,"magress_official.png"),
    (25,"zelgal_official.png"),(28,"zephu_official.png"),(31,"lario_official.png"),(34,"weiss_official.png"),(37,"luna_official.png"),(40,"mifune_official.png"),
    (43,"enemy_moerus.png"),(45,"enemy_mizurus.png"),(47,"enemy_morirus.png"),(49,"enemy_rairus.png"),(278,"enemy_caitsith.png"),(279,"enemy_imp.png")
]

def get(url, referer=None):
    headers={"User-Agent":UA}
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
    # Prefer high-scoring original image; skip tiny responses.
    for score,url in urls:
        try:
            data,ctype=get(url, ROOT+"/")
            if len(data) < 8000: continue
            path=os.path.join(OUT,filename)
            with open(path,"wb") as f: f.write(data)
            return {"no":no,"file":filename,"url":url,"bytes":len(data),"content_type":ctype,"score":score}
        except Exception:
            pass
    raise RuntimeError(f"could not download usable image for {no}")

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
            failures.append({"no":no,"file":filename,"error":str(e)})
            print(f"FAILED {no} {filename}: {e}",file=sys.stderr)
    total=sum(x["bytes"] for x in manifest)
    with open(os.path.join(OUT,"manifest.json"),"w",encoding="utf-8") as f:
        json.dump({"assets":manifest,"failures":failures,"count":len(manifest),"bytes":total},f,indent=2)
    print(f"Bundled {len(manifest)} assets / {total/1024/1024:.2f} MiB")
    # The build must contain a meaningful offline art payload.
    if len(manifest) < 12 or total < 2_000_000:
        print("Asset payload too small; refusing to produce another deceptively tiny APK.",file=sys.stderr)
        return 2
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
