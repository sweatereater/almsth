#!/usr/bin/env python3
"""Deterministically package independently generated Stage 1E emblems.

The packager is deliberately non-semantic: it crops supplied alpha, fits it,
re-quantizes supplied coral, and downsamples.  It never draws anatomy.
"""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]; SET=ROOT/"art"/"skills"/"body-icons"/"2026-09-01"
CANDIDATES,MASTERS,PREVIEWS=SET/"candidates",SET/"masters",SET/"previews"; RUNTIME=ROOT/"assets"/"ui"/"skill-icons"/"body"
IDS=("strong_bones","flexible_joints","strong_spine","sharp_vision","muscle_fibers","stomach","flesh_regeneration","ears","nervous_system","choose_appearance","fundamentals")
RESULT_IDS={"strong_bones":"exec-72913d58-637f-4da3-89bf-42640eb558b8.png","flexible_joints":"exec-36ad35c0-8f6c-45f1-9ae0-b9d6cfdd4b3d.png","strong_spine":"exec-2947deac-6d79-4c21-a8c4-99ebb8668990.png","sharp_vision":"exec-44650f4c-b1c9-4b4c-8b2d-5b20235824e6.png","muscle_fibers":"exec-b74fc6e8-7214-40f6-8570-d5f1bcc7a7f4.png","stomach":"exec-4c4432b1-2597-481c-9068-c0792cc284a6.png","flesh_regeneration":"exec-cd12bf96-5d6e-4679-9228-8381bab33bcc.png","ears":"exec-7e4635b9-6c5e-4cb8-9e75-60b38e537f25.png","nervous_system":"exec-afb56b5c-a82b-4c42-82ce-2e9aacb99255.png","choose_appearance":"exec-4cedddef-9b29-493f-8fc9-e6e1ca6f8ebd.png","fundamentals":"exec-8ffa8005-903d-4977-8533-951a02454e86.png"}
SPEC={"strong_bones":("symmetrical pelvis plus two load-bearing femurs planted outward; broad A silhouette; coral marrow; avoid crossed bones","pelvis-and-femurs"),"flexible_joints":("one bent knee/elbow hinge S/chevron; large rounded joint/patella; coral articulation only","hinge"),"strong_spine":("tall gently curved vertebral column ending sacrum/pelvis; vertical segmented; coral core","vertebral-column"),"sharp_vision":("wide anatomical almond eye; sharp lid; large iris/pupil; max 3 short rays; horizontal","anatomical-eye"),"muscle_fibers":("diagonal flexed upper arm/biceps cutaway; 3 broad fiber bundles; coral follows direction","biceps-cutaway"),"stomach":("asymmetric J stomach plus short esophagus/duodenum; bold pear/J; coral fold","stomach"),"flesh_regeneration":("anatomical heart plus 2 thick arteries returning circulation loop; coral vessels; no cross/pulse","heart-loop"),"ears":("large side-profile ear clear helix/concha plus one echo arc; C silhouette; no head","ear"),"nervous_system":("brain crown plus straight spinal cord plus paired thick nerve roots; vertical tree/root; not vessels","brain-spine"),"choose_appearance":("two offset profiles sharing contour, skeletal/revenant behind and human front; split identity; not theatre masks","dual-profile"),"fundamentals":("open palm five articulated fingers plus compact wrist/tendons; broad hand; no numeral","open-palm")}
PROMPT="Create one original Almsth anatomical body-skill emblem on a transparent 512×512 canvas. Subject: `{subject}`. Composition: `{composition}`. Fit every meaningful pixel inside x/y 64–447. Use flat slate `#59677A` with restrained coral `#E35D63`, strong irregular anatomical shapes, broad negative space, and a unique alpha silhouette readable at 54 px. Minimum structural stroke 24 master px and primary gap 20 master px. No full-body mannequin unless explicitly required, background, checkerboard, cast shadow, glow, frame, UI state, lock, cost, text, letters, numerals, runes, logos, badge, gore, stock imagery, or copied anatomy."
SLATE,CORAL=(0x59,0x67,0x7A),(0xE3,0x5D,0x63); SAFE_MASTER,SAFE_RUNTIME=(64,64,448,448),(16,16,112,112)
def digest(data:bytes)->str:return hashlib.sha256(data).hexdigest()
def file_digest(path:Path)->str:return digest(path.read_bytes())
def bounds(mask:np.ndarray)->list[int]:
 y,x=np.where(mask);return [] if not len(x) else [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]
def extract(path:Path):
 a=np.asarray(Image.open(path).convert("RGBA"),dtype=np.uint8); alpha=a[:,:,3]>=32; box=bounds(alpha)
 if not box:raise ValueError(f"{path}: false transparency/no cutout")
 rgb=a[:,:,:3].astype(np.int16); coral=(rgb[:,:,0]-rgb[:,:,1]>=30)&(rgb[:,:,0]-rgb[:,:,2]>=18)&alpha
 if not coral.any():raise ValueError(f"{path}: candidate has no generated coral accent")
 return Image.fromarray((alpha*255).astype(np.uint8),"L"),Image.fromarray((coral*255).astype(np.uint8),"L"),box
def normalize(mask,box,size,safe):
 l,t,r,b=box; w,h=r-l,b-t; scale=min((safe[2]-safe[0])/w,(safe[3]-safe[1])/h,(96*size/128)/max(w,h)); dw,dh=max(1,round(w*scale)),max(1,round(h*scale))
 crop=mask.crop((l,t,r,b)).resize((dw,dh),Image.Resampling.LANCZOS); out=Image.new("L",(size,size));out.paste(crop,((size-dw)//2,(size-dh)//2)); ar=np.asarray(out,dtype=np.uint8).copy();ar[:safe[1]]=0;ar[safe[3]:]=0;ar[:,:safe[0]]=0;ar[:,safe[2]:]=0
 return Image.fromarray(ar,"L")
def render(alpha,accent):
 aa=np.asarray(alpha,dtype=np.uint8); red=(np.asarray(accent,dtype=np.uint8)>=96)&(aa>0);out=np.zeros((aa.shape[0],aa.shape[1],4),dtype=np.uint8);out[:,:,:3]=SLATE;out[red,:3]=CORAL;out[:,:,3]=aa;out[aa==0,:3]=0;return Image.fromarray(out,"RGBA")
def write_sheet(images,name,bg):
 sheet=Image.new("RGBA",(11*144+52,6*152+38),(*bg,255));draw=ImageDraw.Draw(sheet);font=ImageFont.load_default();text=(240,240,240,255) if sum(bg)<300 else (25,25,25,255)
 for c,item in enumerate(IDS):draw.multiline_text((52+c*144+72,4),item.replace("_","\n"),font=font,fill=text,anchor="ma",align="center")
 for row,pixels in enumerate((128,64,54,48,41,40)):
  y=38+row*152;draw.text((6,y+76),str(pixels),font=font,fill=text,anchor="lm")
  for c,item in enumerate(IDS):icon=images[item].resize((pixels,pixels),Image.Resampling.LANCZOS);sheet.alpha_composite(icon,(52+c*144+(144-pixels)//2,y+(152-pixels)//2))
 path=PREVIEWS/name;sheet.save(path,optimize=False);return file_digest(path)
def iou(a,b):
 a,b=a>=32,b>=32;return np.count_nonzero(a&b)/max(1,np.count_nonzero(a|b))
def build(check):
 for d in (MASTERS,PREVIEWS,RUNTIME):d.mkdir(parents=True,exist_ok=True)
 records,images={},{}
 for item in IDS:
  candidate=CANDIDATES/f"{item}-stage1e.png";alpha,accent,source=extract(candidate);ma,mc=normalize(alpha,source,512,SAFE_MASTER),normalize(accent,source,512,SAFE_MASTER);master=render(ma,mc);ra,rc=ma.resize((128,128),Image.Resampling.LANCZOS),mc.resize((128,128),Image.Resampling.LANCZOS); ra=np.asarray(ra,dtype=np.uint8).copy();rc=np.asarray(rc,dtype=np.uint8).copy();ra[:16]=0;ra[112:]=0;ra[:,:16]=0;ra[:,112:]=0;rc[:16]=0;rc[112:]=0;rc[:,:16]=0;rc[:,112:]=0;ra,rc=Image.fromarray(ra,"L"),Image.fromarray(rc,"L");runtime=render(ra,rc)
  if not check:master.save(MASTERS/f"{item}.png",optimize=False);runtime.save(RUNTIME/f"{item}.png",optimize=False)
  images[item]=runtime;array=np.asarray(runtime);visible=array[:,:,3]>=32;red=np.all(array[:,:,:3]==CORAL,axis=2)&visible;ratio=float(red.sum())/max(1,float(visible.sum()))
  if not .15<=ratio<=.30:raise ValueError(f"{item}: coral coverage {ratio:.3f}; expected 15–30%")
  subject,composition=SPEC[item]; scale=min((SAFE_MASTER[2]-SAFE_MASTER[0])/(source[2]-source[0]),(SAFE_MASTER[3]-SAFE_MASTER[1])/(source[3]-source[1]),384/max(source[2]-source[0],source[3]-source[1]));dw,dh=round((source[2]-source[0])*scale),round((source[3]-source[1])*scale)
  master_path=MASTERS/f"{item}.png";runtime_path=RUNTIME/f"{item}.png"
  if not master_path.is_file() or not runtime_path.is_file():raise ValueError(f"{item}: required packaged file missing")
  records[item]={"mapping":f"res://assets/ui/skill-icons/body/{item}.png","generation_date":"2026-09-02","exact_prompt":PROMPT.format(subject=subject,composition=composition),"references":["art/skills/body-icons/2026-09-01/previews/contact-dark.png",".tmp/stage1c-previews/ru-1280x720-skill-all-icons.png"],"imagegen_result_file":RESULT_IDS[item],"candidate":f"candidates/{item}-stage1e.png","candidate_sha256":file_digest(candidate),"candidate_size":list(Image.open(candidate).size),"candidate_foreground_bbox":source,"normalization":{"crop_bbox":source,"fit_scale":scale,"master_destination_offset":[(512-dw)//2,(512-dh)//2],"runtime_downsample":"Lanczos RGBA 512->128"},"master":f"masters/{item}.png","master_sha256":file_digest(master_path),"master_pixel_sha256":digest(master.tobytes()),"master_alpha_sha256":digest(ma.tobytes()),"master_alpha_bounds":bounds(np.asarray(ma)>=32),"runtime":"../../../../assets/ui/skill-icons/body/"+item+".png","runtime_sha256":file_digest(runtime_path),"runtime_pixel_sha256":digest(runtime.tobytes()),"runtime_alpha_sha256":digest(ra.tobytes()),"runtime_alpha_bounds":bounds(np.asarray(ra)>=32),"runtime_coral_ratio":ratio}
 if len({r["runtime_alpha_sha256"] for r in records.values()})!=len(IDS):raise ValueError("Stage 1E requires eleven unique alpha hashes")
 masks={k:np.asarray(v)[:,:,3].reshape(32,4,32,4).max((1,3)) for k,v in images.items()}
 if any(iou(masks[a],masks[b])>=.82 for n,a in enumerate(IDS) for b in IDS[n+1:]):raise ValueError("32px silhouette IoU must be below .82")
 if check:
  manifest=json.loads((SET/"manifest.json").read_text())
  if manifest.get("icons")!=records:raise ValueError("manifest or packaged PNG bytes are stale; rerun packager")
  for name,digest_value in manifest.get("preview_sha256",{}).items():
   if not (PREVIEWS/name).is_file() or file_digest(PREVIEWS/name)!=digest_value:raise ValueError(f"preview {name} is missing or stale")
 else:
  previews={name:write_sheet(images,name,bg) for name,bg in [("contact-dark.png",(17,23,32)),("contact-light.png",(240,242,244)),("contact-checker.png",(232,232,232))]};manifest={"schema_version":2,"set":"body-skill-icons-2026-09-02","generation_workflow":"eleven independent built-in ImageGen generations; deterministic nonsemantic packager","master_size":[512,512],"runtime_size":[128,128],"master_safe_rect":[64,64,448,448],"runtime_safe_rect":[16,16,112,112],"palette":{"silhouette":"#59677A","anatomy":"#E35D63"},"alpha_contract":"unique alpha silhouettes; meaningful alpha is inside published safe rectangles","packager":"crop/fit/palette/alpha/downsample only; no semantic drawing","preview_sha256":previews,"icons":records};(SET/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
if __name__=="__main__":p=argparse.ArgumentParser();p.add_argument("--check",action="store_true");build(p.parse_args().check)
