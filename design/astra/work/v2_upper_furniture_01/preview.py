"""Source furniture plan, not a material render or engine screenshot."""
from PIL import Image,ImageDraw,ImageFont
import build

ROOT=build.ROOT;OUT=ROOT/'design/astra/evidence/v2_upper_furniture_01';OUT.mkdir(parents=True,exist_ok=True)
layout=build.load(build.LAYOUT);proof=build.load('design/astra/work/v2_upper_furniture_01/checks.json')
program=build.load('game/data/orison_v2/upper_floor_programs.json')
walls=build.module('design/astra/work/v2_apartment_walls_batch_01/build.py','furniture_plan_walls')
geo=build.module('design/astra/work/v2_apartment_doors_batch_01/check.py','furniture_plan_doors')
im=Image.new('RGB',(1780,1100),'#18252e');d=ImageDraw.Draw(im)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',n)
d.text((32,20),'V2 / UPPER HOMES / FURNITURE CATEGORY PASS',font=font(31),fill='#f1e6d4')
d.text((32,68),'50 additions across six homes: eight bedroom suites, six dining groups, authored work and living furniture.',font=font(20),fill='#c2d0d7')
colour={'bed':'#8aada4','nightstand':'#b99b77','wardrobe':'#977a5b','chair':'#c19b6b','table_round':'#ddbd86','table_rect':'#ddbd86','shelf':'#ad9476','desk':'#bca48a','sofa':'#8eabb6','coffee':'#86b8c1'}
labels={'bed':'bed','nightstand':'','wardrobe':'W','chair':'','table_round':'table','table_rect':'table','shelf':'shelf','desk':'desk','sofa':'sofa','coffee':'glass'}
for col,level in enumerate(['F05','F06']):
    left=25+col*885
    d.rounded_rectangle((left,115,left+850,976),14,fill='#273945')
    d.text((left+24,130),level+' / '+('NADIA - CAL - IRIS' if col==0 else 'SACHA - JONAH - MAE'),font=font(23),fill='#f3e7d4')
    scale=29
    def p(xz):return (left+46+(xz[0]+16)*scale,195+(xz[1]+12.5)*scale)
    def rect(r):return (*p(r[:2]),*p(r[2:]))
    rooms=[r for r in layout['spaces'] if r['level']==level and r.get('unit') in [level[-1]+c for c in 'ABC']]
    room_ids={r['id'] for r in rooms}
    for room in rooms:
        d.rectangle(rect(room['rect']),fill={'A':'#d9ddd3','B':'#cdd9df','C':'#ded7c5'}[room['unit'][-1]])
    for edge in walls.owned(layout):
        if edge['level']!=level:continue
        # Only boundaries adjacent to the three occupied apartment programs.
        if not any(edge['owner']==r['id'] for r in rooms):continue
        holes=[(h['start'],h['end']) for h in walls.apertures(layout,edge) if h['sill']==0]
        for a,b in walls.subtract(edge['start'],edge['end'],holes):
            pts=[[a,edge['fixed']],[b,edge['fixed']]] if edge['axis']=='x' else [[edge['fixed'],a],[edge['fixed'],b]]
            d.line([p(q) for q in pts],fill='#4b5d60',width=3)
    for fixture in proof['footprints']:
        if fixture['level']!=level or fixture['kind']=='counter':continue
        r=fixture['rect'];kind=fixture['kind']
        d.rectangle(rect(r),fill=colour.get(kind,'#97b5c2'),outline='#4b5d60',width=1)
        label=labels.get(kind,'')
        if fixture['id']=='5A_plantable':label='plans'
        if label:d.text(p([(r[0]+r[2])/2,(r[1]+r[3])/2]),label,font=font(10),fill='#203139',anchor='mm')
    for door in layout['doors']:
        if door['level']!=level or not any(r in room_ids for r in door.get('connects',[])):continue
        spec=program['doors'][door['id']];off=geo.rotate([0,spec['mount_offset']],door['yaw'])
        poly=[[q[i]+off[i] for i in [0,1]] for q in geo.leaf_polygon(door,spec['swing_out'],100)]
        d.polygon([p(q) for q in poly],fill='#975d41')
    for unit,point in [(level[-1]+'A',[-14.4,-3.0]),(level[-1]+'B',[-14.4,2.3]),(level[-1]+'C',[-3.2,7.2])]:
        d.text(p(point),unit,font=font(22),fill='#42565e',anchor='mm')
    d.text((left+30,933),'Wardrobe leaves and all room/fixture approaches checked in plan.',font=font(16),fill='#c8d5db')
d.text((32,1000),'8 beds + 8 bedside pieces + 8 wardrobes / 6 dining groups / 8 additional work and living pieces',font=font(21),fill='#e5dfce')
d.text((32,1044),'Flat source colours only. Lighting, materials, real interaction and performance remain unverified; Godot not run.',font=font(18),fill='#bfced5')
im.save(OUT/'furniture_plans.png')
print(OUT/'furniture_plans.png')
