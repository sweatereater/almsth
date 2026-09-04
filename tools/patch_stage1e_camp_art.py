#!/usr/bin/env python3
"""Apply the narrow, hash-gated Stage 1E camp-art corrections.

Only record_player padding and workbench exterior pale-matte alpha change.
"""
from __future__ import annotations
import argparse, hashlib, json
from collections import deque
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]; ART=ROOT/"assets"/"art"/"camp-2026-09-01"
RECORD=ART/"camp-record-player.png"; WORKBENCH=ART/"camp-workbench.png"; MANIFEST=ART/"manifest.json"
RECORD_HASH="a75599c37967d5dd64d886d066c44afc29e47e8428a2e5b288c2f2f9cd554737"; WORKBENCH_HASH="856baaec3bde125fd442c592ab61c6584b714fb8a2dba9a98ca54afa0278522d"
RECORD_FINAL="067820e5123e52111e8af6dc819fd0212c37a01c497604d6263355d6f50f3873"; WORKBENCH_PRE_CLEAN="ce932bc3ea210af54f96df69e53aa6361765a81de8ffc7da7ca3e04b999a9b63"; WORKBENCH_FINAL="c48a78418b85b14ddc8cb4a59f0af520db48a6d191cd72848de046aa10345303"
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def exterior_neutral_pixels(image):
 p=image.load();w,h=image.size;q=deque();seen=set()
 for x in range(w):q.extend(((x,0),(x,h-1)))
 for y in range(h):q.extend(((0,y),(w-1,y)))
 while q:
  x,y=q.popleft()
  if (x,y) in seen or not(0<=x<w and 0<=y<h) or p[x,y][3]>2:continue
  seen.add((x,y));q.extend(((x+1,y),(x-1,y),(x,y+1),(x,y-1),(x+1,y+1),(x+1,y-1),(x-1,y+1),(x-1,y-1)))
 return [(x,y) for x,y in seen if 0<p[x,y][3]<=2 and min(p[x,y][:3])>=150 and max(p[x,y][:3])-min(p[x,y][:3])<=24]
def attached_pale_patch_pixels(image):
 p=image.load();points=[]
 # Exact lower attached neutral trapezoid review window. Brown wood/stool
 # pixels are excluded by the neutral-channel predicate, not by a broad matte.
 for y in range(107,131):
  for x in range(64,136):
   r,g,b,a=p[x,y]
   if a>=128 and min(r,g,b)>=100 and max(r,g,b)-min(r,g,b)<=30:points.append((x,y))
 return points
def clean_workbench(image):
 exterior=exterior_neutral_pixels(image)
 if len(exterior)!=47:raise RuntimeError(f"expected exactly 47 exterior pale matte pixels, got {len(exterior)}")
 p=image.load()
 for x,y in exterior:r,g,b,a=p[x,y];p[x,y]=(r,g,b,0)
 patch=attached_pale_patch_pixels(image)
 if len(patch)!=457:raise RuntimeError(f"expected exactly 457 attached pale patch pixels, got {len(patch)}")
 for x,y in patch:r,g,b,a=p[x,y];p[x,y]=(r,g,b,0)
 return exterior,patch
def main():
 check="--check" in __import__("sys").argv
 if check:
  if sha(RECORD)!=RECORD_FINAL or sha(WORKBENCH)!=WORKBENCH_FINAL:raise RuntimeError("Stage1E camp outputs are stale")
  image=Image.open(WORKBENCH).convert("RGBA");assert not attached_pale_patch_pixels(image),"attached workbench halo survived";p=image.load();retained=sum(1 for y in range(107,131) for x in range(64,136) if p[x,y][3]>=128 and max(p[x,y][:3])-min(p[x,y][:3])>30);assert retained==269,"intended brown workbench/stool pixels changed"
  data=json.loads(MANIFEST.read_text(encoding="utf-8"));assert data["layers"]["record_player"].get("stage1e_recipe") and data["layers"]["workbench"].get("stage1e_recipe") and int(data["layers"]["workbench"]["stage1e_recipe"]["attached_pale_patch"]["cleared_pixel_count"])==457
  print("STAGE 1E CAMP PATCH CHECK PASSED: final hashes and recipes")
  return
 if sha(WORKBENCH) not in (WORKBENCH_HASH,WORKBENCH_PRE_CLEAN,WORKBENCH_FINAL):raise RuntimeError("Workbench hash is neither approved source nor Stage1E output")
 if sha(RECORD)==RECORD_HASH:
  old=Image.open(RECORD).convert("RGBA");out=Image.new("RGBA",(166,250));out.alpha_composite(old,(4,4));out.save(RECORD,optimize=False)
 elif Image.open(RECORD).size!=(166,250):raise RuntimeError("Record Player is neither approved source nor Stage 1E output")
 if sha(WORKBENCH) in (WORKBENCH_HASH,WORKBENCH_PRE_CLEAN):
  bench=Image.open(WORKBENCH).convert("RGBA")
  if sha(WORKBENCH)==WORKBENCH_PRE_CLEAN:
   # The original 47 pixels were already cleared; retain their documented
   # count while applying the lower-patch correction only.
   p=bench.load();patch=attached_pale_patch_pixels(bench)
   if len(patch)!=457:raise RuntimeError(f"expected exactly 457 attached pale patch pixels, got {len(patch)}")
   for x,y in patch:r,g,b,a=p[x,y];p[x,y]=(r,g,b,0)
  else:clean_workbench(bench)
  bench.save(WORKBENCH,optimize=False)
 manifest=json.loads(MANIFEST.read_text(encoding="utf-8"));layers=manifest["layers"]
 layers["record_player"].update({"sha256":sha(RECORD).upper(),"size":[166,250],"draw_rect_local":[652,223,166,250],"stage1e_recipe":{"source_sha256":RECORD_HASH,"padding":[4,4,3,4],"old_world_coordinate_preserved":True}})
 layers["workbench"].update({"sha256":sha(WORKBENCH).upper(),"alpha_coverage":0.631825,"stage1e_recipe":{"source_sha256":WORKBENCH_HASH,"exterior_alpha_threshold":2,"near_neutral":{"minimum_rgb":150,"maximum_channel_spread":24},"cleared_pixel_count":47,"cleared_alpha_histogram":{"1":18,"2":29},"cleared_inclusive_bbox":[3,4,170,138],"attached_pale_patch":{"window_xyxy":[64,107,136,131],"alpha_minimum":128,"minimum_rgb":100,"maximum_channel_spread":30,"cleared_pixel_count":457,"cleared_inclusive_bbox":[64,107,135,130],"retained_brown_or_wood_pixels":269,"alpha_zeroed_rgb_preserved":True},"rgb_preserved":True}})
 MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
if __name__=="__main__":main()
