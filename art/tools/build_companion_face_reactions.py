"""Original 32x12 mechanical face strips and derived review GIFs, no source photos.
Run from the repository root. The game consumes only the structured bit planes.
"""
from pathlib import Path
import json, math
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/data/device/companion_face_reactions.json"
REVIEW = ROOT / "art/reviews/v2_companion_faces_20261025"
W, H = 32, 12

def blank(): return [[0] * W for _ in range(H)]
def dot(p,x,y):
    if 0 <= x < W and 0 <= y < H: p[y][x] = 1

def line(p,x0,y0,x1,y1):
    steps = max(abs(x1-x0),abs(y1-y0),1)
    for i in range(steps+1): dot(p,round(x0+(x1-x0)*i/steps),round(y0+(y1-y0)*i/steps))

def face(blink=False, wink=False, worried=False, yawning=False):
    p=blank()
    for x in (10,20):
        for dx in range(2):
            for y in ([4] if blink or (wink and x==10) else [3,4]): dot(p,x+dx,y)
    if yawning:
        for x,y in [(14,8),(15,7),(16,7),(17,8),(17,9),(16,10),(15,10),(14,9)]:dot(p,x,y)
    elif worried:
        line(p,12,8,19,8);dot(p,11,9);dot(p,20,9)
    else:
        for x,y in [(9,8),(22,8),(10,9),(11,9),(20,9),(21,9)]: dot(p,x,y)
        line(p,12,10,19,10)
    return p

def gear(p,cx,cy,phase):
    for i in range(16):
        a=i*math.tau/16
        r=3.0 if (i+phase)%4==0 else 2.0
        dot(p,round(cx+math.cos(a)*r),round(cy+math.sin(a)*r))
    dot(p,cx,cy)

def thought(phase):
    p=blank();gear(p,11,5,phase);gear(p,20,5,-phase)
    line(p,13,10,18,10)
    return p

def call(phase):
    p=face(worried=phase==2)
    for side in [-1,1]:
        x=15 if side==1 else 16
        if phase>=1:
            for y in range(3,7):dot(p,x+side*11,y)
        if phase>=2:
            line(p,x+side*13,2,x+side*14,3)
            line(p,x+side*14,3,x+side*14,6)
            dot(p,x+side*13,7)
    return p

def bulb(rays):
    p=blank()
    for a in range(24):
        t=a*math.tau/24;dot(p,round(15.5+math.cos(t)*3),round(4+math.sin(t)*3))
    line(p,14,7,14,8);line(p,17,7,17,8);line(p,14,9,17,9);line(p,15,11,16,11)
    line(p,14,4,15,6);line(p,17,4,16,6)
    if rays:
        for x,y in [(10,1),(8,4),(10,8),(21,1),(23,4),(21,8)]:dot(p,x,y)
    return p

def rain(phase):
    p=face(blink=phase==2)
    # Original bowler silhouette; a tiny urban rain pantomime, no copied actor.
    line(p,12,2,19,2);line(p,12,2,12,1);line(p,19,2,19,1);line(p,9,3,22,3)
    for x in (4,7,25,28):
        y=(x+phase*2)%8;dot(p,x,y);dot(p,x,y+1)
    return p

def rows(p): return ["".join("#" if x else "." for x in row) for row in p]
normal=face()
strips={
 "vaudeville_wink":[(normal,400),(face(blink=True),300),(normal,300),(face(wink=True),500),(normal,400)],
 "clockwork_thought":[(normal,350)]+[(thought(i),400) for i in [0,1,2,3,0]]+[(normal,400)],
 "wireless_call":[(normal,350)]+[(call(i),350) for i in [1,2,1,0,1,2,1]]+[(normal,400)],
 "lamp_trim":[(normal,350),(bulb(False),400),(bulb(True),400),(bulb(False),350),(bulb(True),450),(normal,400)],
 "rain_hat":[(normal,350)]+[(rain(i),400) for i in [0,1,2,3]]+[(normal,400)],
 "catnap":[(normal,400),(face(yawning=True),500),(face(blink=True),500),(face(blink=True),500),(normal,400)],
}
REVIEW.mkdir(parents=True,exist_ok=True)
document={"schema_version":1,"width":W,"height":H,"reactions":[]}
report={"evidence_class":"INERT","scope":"Original code-authored bit planes and derived GIF preview; not renderer verification","reactions":[]}
contact=Image.new("RGB",(W*10*3,H*10*2),(28,24,20))
for index,(name,frames) in enumerate(strips.items()):
    changes=[];images=[]
    for n,(p,hold) in enumerate(frames):
        assert len(p)==H and all(len(row)==W for row in p)
        prev=frames[n-1][0] if n else normal
        changes.append(sum(a!=b for ra,rb in zip(prev,p) for a,b in zip(ra,rb)))
        im=Image.new("RGB",(W,H),(28,24,20));im.putdata([(224,208,157) if bit else (28,24,20) for row in p for bit in row]);images.append(im.resize((W*10,H*10),Image.Resampling.NEAREST))
    # Playback waits for actual tiles to settle, so no frame silently outruns hardware.
    document["reactions"].append({"id":name,"cooldown_ms":8000,"frames":[{"hold_ms":ms,"rows":rows(p)} for p,ms in frames]})
    images[0].save(REVIEW/(name+".gif"),save_all=True,append_images=images[1:],duration=[ms for _,ms in frames],loop=0,optimize=False)
    contact.paste(images[min(2,len(images)-1)],((index%3)*W*10,(index//3)*H*10))
    report["reactions"].append({"id":name,"frames":len(frames),"minimum_duration_ms":sum(ms for _,ms in frames),"maximum_transition_tiles":max(changes),"changed_tiles":changes})
OUT.write_text(json.dumps(document,indent=2)+"\n",encoding="utf-8",newline="\n")
contact.save(REVIEW/"contact_sheet.png")
(REVIEW/"generation.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8",newline="\n")
print(json.dumps(report,indent=2))
