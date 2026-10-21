"""INERT: contact sheets of completed diagnostic camera records."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parent/'area_final'
if not (ROOT/'areas.json').exists():raise SystemExit('No completed area record yet.')
data=json.loads((ROOT/'areas.json').read_text());records=[r for r in data['records'] if len(r['images'])==4]
out=ROOT/'review_sheets';out.mkdir(exist_ok=True)
for start in range(0,len(records),8):
    batch=records[start:start+8]
    if len(batch)<8 and len(data['records'])<226:break
    target=out/('sheet_%02d.jpg'%(start//8+1))
    if target.exists():continue
    sheet=Image.new('RGB',(1280,len(batch)*205),'#141414');draw=ImageDraw.Draw(sheet);witness=[]
    for row,record in enumerate(batch):
        for col,name in enumerate(record['images']):
            source=ROOT/name;im=Image.open(source).convert('RGB');im.resize((320,180)).load()
            sheet.paste(im.resize((320,180)),(col*320,row*205))
            witness.append({'file':name,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
        draw.text((4,row*205+183),record['id']+'  directions 0 / 1 / 2 / 3',fill='white')
    sheet.save(target,quality=90)
    target.with_suffix('.json').write_bytes((json.dumps({'evidence_class':'INERT','room_ids':[r['id'] for r in batch],'images':witness,'scope':'20-frame-settled diagnostic camera census; fixture stance, no access or human acceptance grant.'},indent=2)+'\n').encode())
    print(target)
print('Completed room records:',len(data['records']),'captured:',len(records),'sheets:',len(list(out.glob('*.jpg'))))
