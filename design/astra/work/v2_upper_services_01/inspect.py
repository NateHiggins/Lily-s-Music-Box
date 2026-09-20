import json, shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[4];OUT=ROOT/'design/astra/evidence/v2_upper_services_01';folder=OUT/'services_01'
r=json.loads((folder/'capture_receipt.json').read_text(encoding='utf-8-sig'));log=Path(r['temp_log'])
shutil.copyfile(log,folder/'engine.log');shutil.copyfile(Path(str(log)+'.stderr'),folder/'engine.log.stderr')
for category,patterns in [('baths',['mirror_closed','mirror_open','sink_details','toilet_roll']),('heating',['radiator_installed']),('toasters',['toaster_installed'])]:
    rows=[]
    for unit in ['5A','5B','5C','6A','6B','6C']:
        names=[unit+'_'+s for s in patterns if (folder/(unit+'_'+s+'.png')).exists()]
        if names:rows.append(names)
    width=400;h=251;sheet=Image.new('RGB',(width*len(patterns),h*len(rows)),(20,20,22));draw=ImageDraw.Draw(sheet)
    for j,names in enumerate(rows):
        for i,name in enumerate(names):
            frame=Image.open(folder/(name+'.png')).convert('RGB')
            sheet.paste(frame.resize((400,225)),(i*width,j*h+26));draw.text((i*width+6,j*h+7),name,fill='white')
    sheet.save(OUT/(category+'.png'))
print('Built all category sheets and retained engine logs.')
