"""Source footprint/door drawing, not a game or material capture."""
import math
from PIL import Image,ImageDraw,ImageFont
import build

ROOT=build.ROOT
OUT=ROOT/'design/astra/evidence/v2_upper_fixtures_01'
OUT.mkdir(parents=True,exist_ok=True)
layout=build.load(build.LAYOUT);program=build.load(build.PROGRAM)
receipt=build.load('design/astra/work/v2_upper_fixtures_01/checks.json')
geo=build.module('design/astra/work/v2_apartment_doors_batch_01/check.py','fixture_preview_geo')
im=Image.new('RGB',(1530,1160),'#17232b');draw=ImageDraw.Draw(im)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',n)
draw.text((32,22),'V2 / SIX UPPER HOMES / KITCHENS + BATHROOMS',font=font(29),fill='#eee7d9')
draw.text((32,68),'Source clearance study. Identical room geometry on floors five and six; authored appliance variants retained.',font=font(18),fill='#b8c7cd')
colours={'toilet':'#e3decc','sink':'#71bcc1','shower':'#5999b0','stove':'#c8966a','fridge':'#acb989'}
labels={'toilet':'WC','shower':'SH','stove':'ST','fridge':'FR','sink':'SK'}
for col,letter in enumerate('ABC'):
    left=25+col*505
    for row,suffix in enumerate(['BATH','KITCHEN']):
        top=115+row*475;panel=[left,top,left+480,top+450]
        draw.rounded_rectangle(panel,14,fill='#253641')
        draw.text((left+18,top+12),'5'+letter+' / 6'+letter+'   '+suffix,font=font(22),fill='#f0e6d7')
        room=next(r for r in layout['spaces'] if r['id']=='F05_'+letter+'_'+suffix);r=room['rect']
        scale=min(365/(r[2]-r[0]+.6),320/(r[3]-r[1]+.6))
        mid=[(r[0]+r[2])/2,(r[1]+r[3])/2]
        def point(p):return (left+240+(p[0]-mid[0])*scale,top+239+(p[1]-mid[1])*scale)
        def rect(r):return (*point(r[:2]),*point(r[2:]))
        draw.rectangle(rect(r),fill='#d5d4c4',outline='#9ca68e',width=2)
        for fixture in receipt['footprints']:
            if fixture['room']!=room['id'] or fixture['kind']=='counter':continue
            box=fixture['rect'];draw.rectangle(rect(box),fill=colours[fixture['kind']],outline='#34434a',width=2)
            center=point([(box[0]+box[2])/2,(box[1]+box[3])/2]);label=labels[fixture['kind']]
            draw.text(center,label,font=font(16),anchor='mm',fill='#14242d')
            target=next(t for t in receipt['targets'] if t['id']==fixture['id']);at=point(target['point'])
            draw.line([center,at],fill='#455a56',width=1)
            radius=.38*scale
            draw.ellipse((at[0]-radius,at[1]-radius,at[0]+radius,at[1]+radius),outline='#687a62',width=1)
            draw.ellipse((at[0]-3,at[1]-3,at[0]+3,at[1]+3),fill='#233c33')
        for door in layout['doors']:
            if door['level']!='F05':continue
            x,z=door['center']
            if not (r[0]-.01<=x<=r[2]+.01 and r[1]-.01<=z<=r[3]+.01):continue
            w=door['width']/2
            dx,dz=geo.rotate([w,0],door['yaw'])
            opening=[[x-dx,z-dz],[x+dx,z+dz]]
            draw.line([point(p) for p in opening],fill='#e9bd7c',width=5)
            spec=program['doors'][door['id']];offset=geo.rotate([0,spec['mount_offset']],door['yaw'])
            poly=[[p[i]+offset[i] for i in [0,1]] for p in geo.leaf_polygon(door,spec['swing_out'],100)]
            if all(r[0]<=p[0]<=r[2] and r[1]<=p[1]<=r[3] for p in poly):
                draw.polygon([point(p) for p in poly],fill='#714738')
        draw.text((left+18,top+418),f'{r[2]-r[0]:.2f} m x {r[3]-r[1]:.2f} m   /   open door and 0.38 m stance radius',font=font(15),fill='#c0cbd0')
draw.text((32,1082),'WC toilet   SH shower   SK sink   ST gas stove   FR fridge / icebox',font=font(20),fill='#e4e0d2')
draw.text((32,1120),'Geometry estimates only. Godot, material appearance, real targeting and performance checks remain pending.',font=font(18),fill='#bac9d0')
im.save(OUT/'fixture_plans.png')
print(OUT/'fixture_plans.png')
