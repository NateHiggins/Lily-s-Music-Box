"""Retain final engine logs and build labelled resized capture comparisons."""
import json,shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[4];E=ROOT/'design/astra/evidence/v2_upper_radios_01';run=E/'radios_04'
r=json.loads((run/'capture_receipt.json').read_text(encoding='utf-8-sig'))
for ext in ['', '.stderr']:shutil.copyfile(r['temp_log']+ext,E/('capture_clean.log'+ext))
for page,units in enumerate([['5A','5B','5C'],['6A','6B','6C']]):
 sheet=Image.new('RGB',(1280,1170),(24,24,24));draw=ImageDraw.Draw(sheet)
 for y,unit in enumerate(units):
  for x,mode in enumerate(['room','lamp']):
   im=Image.open(run/('DomesticRadio_'+unit+'_'+mode+'.png'));assert im.size==(1280,720)
   sheet.paste(im.resize((640,360)),(x*640,y*390+30));draw.text((x*640+10,y*390+8),unit+' / '+mode,fill='white')
 sheet.save(E/('clean_comparison_'+str(page)+'.png'))
