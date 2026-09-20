"""Plan drawing from authored room/wall records; not a game capture."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import build

ROOT=build.ROOT;OUT=ROOT/'design/astra/evidence/v2_upper_floors_01';OUT.mkdir(parents=True,exist_ok=True)
layout=json.loads((ROOT/build.LAYOUT).read_text(encoding='utf-8'))
program=json.loads((ROOT/build.PROGRAM).read_text(encoding='utf-8'))
wall=build.module('design/astra/work/v2_apartment_walls_batch_01/build.py','plan_walls')
im=Image.new('RGB',(1660,1080),'#17202a');draw=ImageDraw.Draw(im)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',n)
draw.text((38,24),'V2 / FLOORS FIVE AND SIX',font=font(32),fill='#efe7d8')
draw.text((38,72),'Authored rooms and circulation • source plan • furnishing, lighting and runtime proof pending',font=font(20),fill='#c1cbd5')
colours={'A':'#b6c5b1','B':'#acbed0','C':'#caba9f','D':'#a5786c'}
scale=23
for column,level in enumerate(['F05','F06']):
    left=35+column*820
    def point(p):return (left+380+p[0]*scale,465+p[1]*scale)
    def rect(r):return (*point(r[:2]),*point(r[2:]))
    draw.rounded_rectangle((left,125,left+790,1015),radius=15,fill='#25313c')
    draw.text((left+24,143),level+' / '+('NADIA, CAL, IRIS' if column==0 else 'SACHA, JONAH, MAE'),font=font(21),fill='#f0e8d8')
    for room in layout['spaces']:
        if room['level']!=level:continue
        fill=colours[room['unit'][-1]] if room.get('unit') else '#8f9da6'
        draw.rectangle(rect(room['rect']),fill=fill)
    for stair in layout['stairs']:
        if stair['to']!=level:continue
        x,z=stair['origin'];w,g=stair['width'],stair['gap'];run=stair['tread']*stair['risers_per_flight']
        for dx in [0,w+g]:
            draw.rectangle(rect([x+dx,z,x+dx+w,z+run]),fill='#697b88')
            for i in range(11):
                a=point([x+dx,z+i*stair['tread']]);b=point([x+dx+w,z+i*stair['tread']]);draw.line([a,b],fill='#c3ced4',width=1)
    for edge in wall.owned(layout):
        if edge['level']!=level:continue
        holes=[(h['start'],h['end']) for h in wall.apertures(layout,edge) if h['sill']==0]
        for a,b in wall.subtract(edge['start'],edge['end'],holes):
            points=[[a,edge['fixed']],[b,edge['fixed']]] if edge['axis']=='x' else [[edge['fixed'],a],[edge['fixed'],b]]
            draw.line([point(p) for p in points],fill='#202b32',width=4)
    for window in layout['windows']:
        if window['level']!=level:continue
        x,z=window['center'];w=window['width']/2
        pts=[[x-w,z],[x+w,z]] if window['axis']=='x' else [[x,z-w],[x,z+w]]
        draw.line([point(p) for p in pts],fill='#56c7d3',width=4)
    for door in layout['doors']:
        if door['level']!=level:continue
        at=point(door['center']);spec=program['doors'][door['id']]
        draw.ellipse((at[0]-4,at[1]-4,at[0]+4,at[1]+4),fill='#742e20' if spec['leaf_state']=='locked' else '#f5e4b5')
    for room in layout['spaces']:
        if room['level']!=level:continue
        r=room['rect'];at=point([(r[0]+r[2])/2,(r[1]+r[3])/2])
        suffix=room['id'].replace(level+'_','')
        title=suffix.replace('PRIVATE_HALL','hall').replace('VESTIBULE','entry').replace('PUBLIC_CORE','lift / stair').replace('SERVICE_CORE','service stair').replace('SERVICE_CROSSING','crossing').replace('SERVICE_HALL_SOUTH','service').replace('SERVICE_HALL','service').replace('WEST_HALL','hall').replace('EAST_HALL','hall')
        title=title.replace('RESTRICTED','sealed' if column==0 else 'storage').replace('_','\n')
        if room.get('unit') and suffix.endswith('MAIN'):
            person=next(p for p in program['programs'] if p['unit']==room['unit'])['resident'].replace('_',' ').title()
            title=room['unit']+'\n'+person+'\nliving / meals'
        if r[2]-r[0]<1.6:title='hall'
        bbox=draw.multiline_textbbox((0,0),title,font=font(12),align='center',spacing=1)
        draw.multiline_text((at[0]-(bbox[2]-bbox[0])/2,at[1]-(bbox[3]-bbox[1])/2),title,font=font(12),fill='#132029',align='center',spacing=1)
    draw.text((left+25,812),'21 occupied rooms + one restricted unit',font=font(20),fill='#e5ddcf')
    draw.text((left+25,853),'Primary and service stairs continue from floor four.',font=font(17),fill='#c0cbd4')
    draw.text((left+25,885),'Pale dots: operable doors. Red dot: locked threshold.',font=font(17),fill='#c0cbd4')
    draw.text((left+25,938),'Room connections checked with a 0.38 m body radius.',font=font(17),fill='#c0cbd4')
draw.text((38,1036),'58 new spaces / 30 doors / 24 windows / 4 stair connections • V2 remains incomplete; Godot not run',font=font(19),fill='#c7d1da')
im.save(OUT/'floor_plans.png')
print(OUT/'floor_plans.png')
