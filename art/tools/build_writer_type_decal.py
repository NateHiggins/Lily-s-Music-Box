"""Font-authored reverse type: raised-metal normal/coverage atlas, not AI text.

Owner explicitly requested reversed letter decals on physical writer type.
The overlay retains the registered steel finish; this is its relief mask.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter,ImageOps

ROOT=Path(__file__).resolve().parents[2]
CHARS='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,:!?+-*/=()'
CELL=128

def generate():
    assert len(CHARS)==48 and len(set(CHARS))==48
    atlas=Image.new('L',(CELL*8,CELL*6))
    font=ImageFont.truetype(str(ROOT/'game/assets/fonts/courier_prime/CourierPrime-Bold.ttf'),96)
    for index,char in enumerate(CHARS):
        tile=Image.new('L',(CELL,CELL));draw=ImageDraw.Draw(tile)
        bounds=draw.textbbox((0,0),char,font=font)
        draw.text(((CELL-bounds[2]+bounds[0])/2-bounds[0],(CELL-bounds[3]+bounds[1])/2-bounds[1]),char,font=font,fill=255)
        atlas.paste(ImageOps.mirror(tile),(index%8*CELL,index//8*CELL))
    height=np.array(atlas.filter(ImageFilter.GaussianBlur(.9)),dtype=float)/255
    # 60 micrometre raised type on 3.6 x 3.8mm seats; normals are linear data.
    dx=np.gradient(height,axis=1)*.00006/(.0036/CELL)
    dy=-np.gradient(height,axis=0)*.00006/(.0038/CELL)
    normals=np.stack((-dx,-dy,np.ones_like(dx)),axis=-1)
    normals/=np.linalg.norm(normals,axis=-1,keepdims=True)
    rgba=np.concatenate((normals*.5+.5,height[...,None]),axis=-1)
    directory=ROOT/'game/assets/device/writer_type';directory.mkdir(parents=True,exist_ok=True)
    Image.fromarray(np.rint(rgba*255).astype('uint8')).save(directory/'reversed_type_emboss.png')
    source=ROOT/'art/reviews/v2_handheld_20261023/hot_type';source.mkdir(exist_ok=True)
    atlas.save(source/'reversed_type_coverage.png')
    (source/'atlas.json').write_text(json.dumps(dict(evidence_class='INERT',characters=CHARS,columns=8,rows=6,
        cell_pixels=CELL,seat_metres=[.0036,.0038],relief_metres=.00006,horizontally_reversed=True),indent=2)+'\n')
    print('Reverse type decal:',len(CHARS),'glyphs;',atlas.size)

if __name__=='__main__':generate()
