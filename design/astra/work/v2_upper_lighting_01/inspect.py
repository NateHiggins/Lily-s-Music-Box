"""Make an explicitly resized comparison of retained, unedited game frames."""
import json
from pathlib import Path
import shutil
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[4]
OUT=ROOT/'design/astra/evidence/v2_upper_lighting_01'
rows=['5a_drafting','5b_kitchen','5c_bedroom','6a_workdesk','6c_sitting']
sheet=Image.new('RGB',(1536,1570),(20,20,22))
draw=ImageDraw.Draw(sheet)
metrics=[]
for j,row in enumerate(rows):
    stats={}
    for i,state in enumerate(['off','on','lamp']):
        image=Image.open(OUT/'rooms_02'/(row+'_'+state+'.png')).convert('RGB')
        # Descriptive sRGB luma, not physical lux or a performance measurement.
        values=list(image.resize((128,72)).get_flattened_data())
        stats[state]=sum(.2126*r+.7152*g+.0722*b for r,g,b in values)/len(values)
        sheet.paste(image.resize((512,288)),(i*512,j*314+26))
        draw.text((i*512+8,j*314+7),row+' / '+state,fill='white')
    metrics.append(dict(view=row,mean_srgb_luma_0_255=stats))
sheet.save(OUT/'comparison.png')
(OUT/'image_observations.json').write_bytes((json.dumps(metrics,indent=2)+'\n').encode())
for name in ['rooms_01','rooms_02']:
    folder=OUT/name
    receipt=json.loads((folder/'capture_receipt.json').read_text(encoding='utf-8-sig'))
    log=Path(receipt['temp_log'])
    shutil.copyfile(log,folder/'engine.log')
    shutil.copyfile(Path(str(log)+'.stderr'),folder/'engine.log.stderr')
print('Built comparison sheet; copied both capture runs and their logs.')
