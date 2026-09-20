"""Build a labelled, resized contact sheet from retained production captures."""
import json
from pathlib import Path
import shutil
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'design/astra/evidence/v2_upper_kitchens_01'
folder=OUT/'kitchens_01'
receipt=json.loads((folder/'capture_receipt.json').read_text(encoding='utf-8-sig'))
log=Path(receipt['temp_log'])
shutil.copyfile(log,folder/'engine.log')
shutil.copyfile(Path(str(log)+'.stderr'),folder/'engine.log.stderr')
sheet=Image.new('RGB',(1280,2316),(20,20,22));draw=ImageDraw.Draw(sheet)
for j,unit in enumerate(['5A','5B','5C','6A','6B','6C']):
    for i,state in enumerate(['closed','open']):
        frame=Image.open(folder/(unit+'_'+state+'.png')).convert('RGB')
        sheet.paste(frame.resize((640,360)),(i*640,j*386+26))
        draw.text((i*640+8,j*386+7),unit+' / '+state,fill='white')
sheet.save(OUT/'comparison.png')
print('Contact sheet built; original frames and engine logs retained.')
