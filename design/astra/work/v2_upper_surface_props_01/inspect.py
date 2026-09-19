import json,shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[4];E=ROOT/'design/astra/evidence/v2_upper_surface_props_01';folder=E/'surfaces_01'
r=json.loads((folder/'capture_receipt.json').read_text(encoding='utf-8-sig'));log=Path(r['temp_log']);shutil.copyfile(log,folder/'engine.log');shutil.copyfile(Path(str(log)+'.stderr'),folder/'engine.log.stderr')
files=sorted(folder.glob('*.png'));sheet=Image.new('RGB',(1280,7*386),(20,20,22));draw=ImageDraw.Draw(sheet)
for i,p in enumerate(files):
    x=i%2*640;y=i//2*386
    sheet.paste(Image.open(p).convert('RGB').resize((640,360)),(x,y+26));draw.text((x+6,y+7),p.stem,fill='white')
sheet.save(E/'comparison.png')
print('Built contact sheet and retained logs.')
