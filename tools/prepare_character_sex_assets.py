"""Prepare approved character-sheet cutouts locally; never generate or repaint art.

Pillow + numpy only. Native cutouts retain source RGB exactly; reviewed masks remove
paper/ground, then premultiplied-alpha resampling produces the runtime canvases.
The existing five female head icons and all world sprites are read-only inputs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'art/characters/sex-selection'
RECIPE = PACK / 'recipe.json'
FORMS = ['skeleton', 'zombie', 'ghoul', 'revenant', 'almost-human']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def polygon_mask(size, polygons, offset=(0, 0)):
    result = Image.new('L', size)
    draw = ImageDraw.Draw(result)
    for polygon in polygons:
        draw.polygon([(x-offset[0], y-offset[1]) for x, y in polygon], fill=255)
    return result


def flood_component(binary, seed):
    work = Image.fromarray(np.where(binary, 255, 0).astype('uint8')).copy()
    x, y = seed
    if not (0 <= x < work.width and 0 <= y < work.height) or work.getpixel((x, y)) != 255:
        raise ValueError(f'Component seed is not in its region: {seed}')
    ImageDraw.floodfill(work, (x, y), 128)
    return np.asarray(work) == 128


def cutout(source, entry):
    box = entry['crop']
    crop = source.crop(box).convert('RGB')
    pixels = np.asarray(crop)
    candidate = pixels.min(axis=2) >= entry.get('paper_threshold', 177)
    work = Image.fromarray(np.where(candidate, 255, 0).astype('uint8')).copy()
    seeds = [(x, 0) for x in range(work.width)] + [(x, work.height-1) for x in range(work.width)]
    seeds += [(0, y) for y in range(work.height)] + [(work.width-1, y) for y in range(work.height)]
    seeds += [(x-box[0], y-box[1]) for x, y in entry.get('paper_seeds', [])]
    for seed in seeds:
        if work.getpixel(seed) == 255:
            ImageDraw.floodfill(work, seed, 128)
    mask = np.asarray(work) != 128
    if entry.get('feet'):
        feet = polygon_mask(crop.size, entry['feet'], box[:2])
        mask[max(0, entry['ground_y']-box[1]):] &= np.asarray(feet)[max(0, entry['ground_y']-box[1]):] > 0
    if entry.get('include'):
        mask &= np.asarray(polygon_mask(crop.size, entry['include'], box[:2])) > 0
    if entry.get('exclude'):
        mask &= np.asarray(polygon_mask(crop.size, entry['exclude'], box[:2])) == 0
    seed = (entry['body_seed'][0]-box[0], entry['body_seed'][1]-box[1])
    mask = flood_component(mask, seed)
    # Remove only the paper blend at the OUTER edge; light bone/shirts inside
    # the silhouette are untouched. No recolouring or global white threshold.
    alpha = Image.fromarray(mask.astype('uint8') * 255)
    edge = mask & (np.asarray(alpha.filter(ImageFilter.MinFilter(3))) == 0)
    values = np.where(edge, np.clip((214-pixels.min(axis=2).astype(float))/65, 0, 1), 1)
    alpha = Image.fromarray(np.rint(mask * values * 255).astype('uint8'))
    result = crop.convert('RGBA')
    result.putalpha(alpha)
    return result, alpha


def body_canvas(native, entry, eye_span):
    bounds = native.getbbox()
    scale = eye_span / (entry['feet_y']-entry['eye'][1])
    # Baseline is exact; anatomical foot center is kept at canvas x132.
    width = max(1, round((bounds[2]-bounds[0])*scale))
    height = max(1, round((bounds[3]-bounds[1])*scale))
    resized = native.crop(bounds).convert('RGBa').resize((width,height), Image.Resampling.LANCZOS).convert('RGBA')
    x = round(132 - (entry['feet_x']-entry['crop'][0]-bounds[0])*scale)
    y = 696-height
    canvas = Image.new('RGBA', (264,704))
    canvas.alpha_composite(resized, (x,y))
    return canvas, {'scale': scale, 'eye_to_foot_target': eye_span, 'paste_xy':[x,y]}


def head_canvas(native, entry):
    scale = 56/(entry['chin_y']-entry['eye'][1])
    box=entry['crop']
    transform=(1/scale,0,entry['eye'][0]-box[0]-115/scale,
               0,1/scale,entry['eye'][1]-box[1]-105/scale)
    return native.convert('RGBa').transform((264,264), Image.Transform.AFFINE,
        transform, resample=Image.Resampling.BICUBIC).convert('RGBA')


def preview(outputs):
    font_path=Path('C:/Windows/Fonts/arial.ttf')
    font=ImageFont.truetype(str(font_path), 18) if font_path.exists() else ImageFont.load_default()
    for theme,bg in [('dark',(18,23,32)),('light',(238,236,226))]:
        sheet=Image.new('RGB',(1320,1504),bg)
        draw=ImageDraw.Draw(sheet)
        for row,sex in enumerate(['female','male']):
            for col,form in enumerate(FORMS):
                p=ROOT/f'assets/ui/character-fullbody/{sex}/form-{form}.png'
                im=outputs[str(p)]
                sheet.paste(im,(264*col,752*row+36),im)
                draw.text((264*col+8,752*row+8),f'{sex} / {form}',fill='white' if theme=='dark' else 'black',font=font)
        (PACK/'previews').mkdir(parents=True,exist_ok=True)
        sheet.save(PACK/f'previews/bodies-{theme}.png')
    heads=Image.new('RGB',(528,320),(18,23,32))
    for i,sex in enumerate(['female','male']):
        p=ROOT/f'assets/portraits/{sex}/form-almost-human.png'
        im=outputs.get(str(p)) or Image.open(p).convert('RGBA')
        if sex=='male': im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        heads.paste(im,(264*i,28),im)
    heads.save(PACK/'previews/selector-heads.png')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    recipe=json.loads(RECIPE.read_text(encoding='utf-8'))
    sources={key:Image.open(ROOT/record['path']) for key,record in recipe['sources'].items()}
    for record in recipe['sources'].values():
        assert sha(ROOT/record['path'])==record['sha256'], 'Approved source changed'
    outputs={}; natives={}; manifest={'sources':recipe['sources'],'bodies':[],'heads':[]}
    for entry in recipe['bodies']+[recipe['male_head']]:
        native,mask=cutout(sources[entry['source']],entry)
        assert native.convert('RGB').tobytes() == sources[entry['source']].crop(entry['crop']).convert('RGB').tobytes(), 'Native source RGB changed'
        key=entry['sex']+'/'+entry.get('form','head')
        natives[key]=native
        for kind,im in [('cutouts',native),('masks',mask)]:
            outputs[str(PACK/kind/(key+'.png'))]=im
    for sex in ['female','male']:
        entries=[e for e in recipe['bodies'] if e['sex']==sex]
        limits=[]
        for e in entries:
            bounds=natives[sex+'/'+e['form']].getbbox()
            left=bounds[0]+e['crop'][0]; right=bounds[2]+e['crop'][0]
            top=bounds[1]+e['crop'][1]
            span=e['feet_y']-e['eye'][1]
            limits += [120/(e['feet_x']-left)*span,120/(right-e['feet_x'])*span,682/(e['feet_y']-top)*span]
        target=min(limits)
        for e in entries:
            native=natives[sex+'/'+e['form']]
            im,normalization=body_canvas(native,e,target)
            path=ROOT/f"assets/ui/character-fullbody/{sex}/form-{e['form']}.png"
            outputs[str(path)]=im
            bounds=im.getbbox()
            assert bounds[0]>=11 and bounds[1]>=12 and bounds[2]<=253 and bounds[3]==696,(path,bounds)
            manifest['bodies'].append({'path':path.relative_to(ROOT).as_posix(),'source':e['source'],'size':list(im.size),'alpha_bounds':bounds,**normalization})
    head=head_canvas(natives['male/head'],recipe['male_head'])
    hb=head.getbbox(); assert hb[0]>=4 and hb[1]>=4 and hb[2]<=260 and hb[3]<=260,hb
    hp=ROOT/'assets/portraits/male/form-almost-human.png';outputs[str(hp)]=head
    manifest['heads'].append({'path':hp.relative_to(ROOT).as_posix(),'size':list(head.size),'alpha_bounds':hb,'eye':[115,105],'eye_to_chin':56})
    for path,value in outputs.items():
        p=Path(path)
        if args.check:
            with Image.open(p) as actual:
                assert actual.mode==value.mode and actual.size==value.size and actual.tobytes()==value.tobytes(),str(p)
        else:
            p.parent.mkdir(parents=True,exist_ok=True);value.save(p,optimize=True)
    for record in manifest['bodies']+manifest['heads']:
        record['sha256']=sha(ROOT/record['path'])
    if args.check:
        assert json.loads((PACK/'manifest.json').read_text(encoding='utf-8'))==json.loads(json.dumps(manifest))
        print('CHARACTER SEX ASSET CHECK PASSED: source hashes, deterministic masks, canvases, foot anchors, head alignment')
    else:
        (PACK/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        preview(outputs)
        print('Prepared 10 fullbody figures and 1 missing male selector head; existing female heads/world assets untouched.')


if __name__=='__main__':
    main()
