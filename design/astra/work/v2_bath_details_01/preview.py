"""Flat-colour projection of generated triangles, not an engine capture."""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT/'design/astra/evidence/v2_bath_details_01'
OUT.mkdir(parents=True, exist_ok=True)
rows = json.loads((ROOT/'game/data/orison_v2/bath_details.json').read_text(encoding='utf-8'))['props'][:3]
im = Image.new('RGB',(1440,850),'#171c23')
draw = ImageDraw.Draw(im)
font = lambda size: ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size)
draw.text((38,26),'V2 / SIX-HOME BATH FITTINGS',font=font(30),fill='#f0e6d8')
draw.text((38,73),'Generated geometry study • flat colours • no Godot or material/lighting proof',font=font(19),fill='#b5c0cc')
palette = {'chrome':(165,182,186),'porcelain_fixture':(218,222,215),'enamel':(215,203,163),'linen':(169,158,132),'paper':(223,213,181)}
eye = [0.38,.23,-.90]
length = math.sqrt(sum(x*x for x in eye)); eye = [x/length for x in eye]
right = [.921,0,.389]
up = [eye[1]*right[2],eye[2]*right[0]-eye[0]*right[2],-eye[1]*right[0]]
# eye x right gives screen up with the chosen camera.
up = [-v for v in up]
dot = lambda a,b: sum(x*y for x,y in zip(a,b))
for column,(row,title,note) in enumerate(zip(rows,
        ['SOAP DISH + BAR','HAND TOWEL + RAIL','CISTERN CLIPS + ROLL'],
        ['Brackets seat on the lavatory back.','Collar follows the tapered pedestal.','Clips rest on the tank lid; flush stays clear.'])):
    left=28+column*472
    draw.rounded_rectangle((left,126,left+444,766),radius=16,fill='#232b34')
    triangles=[]
    for surface in row['surfaces']:
        for i in range(0,len(surface['vertices']),9):
            points=[surface['vertices'][i+j:i+j+3] for j in [0,3,6]]
            n=surface['normals'][i:i+3]
            if dot(n,eye)<0: continue
            projected=[(dot(p,right),dot(p,up)) for p in points]
            shade=.53+.47*max(0,dot(n,eye))
            colour=tuple(int(v*shade) for v in palette[surface['material']])
            triangles.append((sum(dot(p,eye) for p in points)/3,projected,colour))
    points=[p for _,ps,_ in triangles for p in ps]
    low=[min(p[i] for p in points) for i in [0,1]]
    high=[max(p[i] for p in points) for i in [0,1]]
    scale=min(350/(high[0]-low[0]),430/(high[1]-low[1]))
    cx,cy=(high[0]+low[0])/2,(high[1]+low[1])/2
    for _,ps,colour in sorted(triangles,key=lambda t:t[0]):
        draw.polygon([(left+222+(x-cx)*scale,430-(y-cy)*scale) for x,y in ps],fill=colour)
    draw.text((left+20,674),title,font=font(20),fill='#eee6d9')
    draw.text((left+20,711),note,font=font(15),fill='#bdc8d2')
draw.text((38,796),'18 supported assemblies / 6 apartments / existing material library / no added lights or input owners',font=font(20),fill='#c5d0d9')
im.save(OUT/'geometry_study.png')
print(OUT/'geometry_study.png')
