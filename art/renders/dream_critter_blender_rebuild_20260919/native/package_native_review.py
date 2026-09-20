from pathlib import Path
from PIL import Image, ImageDraw
import hashlib, html, json, shutil, subprocess

repo=Path(r'C:\ov\astra-main-acdb4be')
work=Path(__file__).parent
proof=repo/'art/renders/dream_critter_blender_rebuild_20260919'
run=work/'native_all16_06'
data=json.loads((run/'shots/dream_blender_critters.json').read_text(encoding='utf-8'))
assert len(data['checks'])==486 and data['failures']==0
assert not any(data['logs'].values())
assert (run/'run.log.receipt.json').exists()
out=proof/'native';out.mkdir(exist_ok=True)
captures=out/'captures';captures.mkdir(exist_ok=True)
for src in (run/'shots').iterdir():
    if src.is_file():shutil.copy2(src,captures/src.name)
for number in range(1,7):
    src=work/f'native_all16_{number:02}'
    dst=out/f'attempt_{number:02}';dst.mkdir(exist_ok=True)
    for p in src.iterdir():
        if p.is_file():shutil.copy2(p,dst/p.name)
    diag=src/'shots/dream_blender_critters.json'
    if diag.exists():shutil.copy2(diag,dst/diag.name)
reg=out/'regressions';reg.mkdir(exist_ok=True)
for p in (work/'native_all16_regressions').iterdir():
    if p.is_file():shutil.copy2(p,reg/p.name)
entry_shots=work/'native_all16_04/entry_shots'
if entry_shots.is_dir():
    for p in entry_shots.iterdir():
        if p.is_file():shutil.copy2(p,reg/('final_entry_'+p.name))
names=['Seam Grazer','Crystal Listener','Fold Crab','Tardigrade','Stentor','Lacrymaria','Vorticella','Euplotes','Spirostomum','Heliozoan','Euglena','Volvox','Noctiluca','Bacillaria','Salpingoeca','Mesodinium']
order=[3,6,5,11,4,8,7,10,9,12,13,14,15,0,1,2]
modes={'full_beam':'Lamp','oblique':'Oblique','dark':'Dark','neutral_000':'Geometry 0','neutral_050':'Geometry ½','neutral_100':'Geometry 1','cutaway_050':'Cutaway'}
previews=out/'previews';previews.mkdir(exist_ok=True)
for src in captures.glob('*.png'):
    im=Image.open(src).convert('RGB').crop((380,0,1280,720))
    im.thumbnail((675,540));im.save(previews/(src.stem+'.jpg'),quality=92)
for mode in modes:
    sheet=Image.new('RGB',(1800,1080),'#201a22');draw=ImageDraw.Draw(sheet)
    for i,kind in enumerate(order):
        src=previews/f'species_{kind:02}_{mode}.jpg'
        im=Image.open(src);im.thumbnail((450,244))
        x=(i%4)*450;y=(i//4)*270
        sheet.paste(im,(x+(450-im.width)//2,y+24))
        draw.text((x+10,y+5),names[kind]+' - '+modes[mode].replace('½','half'),fill='white')
    sheet.save(out/(mode+'_contact.jpg'),quality=94)
cards=[]
for kind in order:
    options=[]
    for p in sorted(captures.glob(f'species_{kind:02}_*.png')):
        mode=p.stem.removeprefix(f'species_{kind:02}_')
        title=modes.get(mode,mode.replace('_',' ').title())
        options.append(f'<option value="{mode}"'+(' selected' if mode=='full_beam' else '')+f'>{html.escape(title)}</option>')
    cards.append(f'''<article data-kind="{kind:02}"><h2>{names[kind]}</h2><a class="capture" href="captures/species_{kind:02}_full_beam.png"><img loading="lazy" src="previews/species_{kind:02}_full_beam.jpg" alt="{names[kind]} in the native warehouse"></a><label>View <select>{''.join(options)}</select></label></article>''')
buttons=''.join(f'<button data-mode="{mode}">{title}</button>' for mode,title in modes.items())
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dream warehouse · Native anatomy review</title>
<style>*{box-sizing:border-box}body{margin:0;background:#171219;color:#eee5ed;font:16px/1.5 system-ui,sans-serif}header{padding:28px 4vw;border-bottom:1px solid #735744}h1{font-size:30px;margin:0 0 10px}p{max-width:1050px;margin:8px 0;color:#cbbec8}a{color:#edc488}.status{color:#efc880}nav{display:flex;gap:8px;flex-wrap:wrap;margin-top:18px}button,select{background:#382538;border:1px solid #755b48;color:#f2e8ec;padding:8px 12px;border-radius:5px;cursor:pointer}button:hover{background:#664753}main{padding:25px 4vw;display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:22px}article{background:#241b27;border:1px solid #55404e;border-radius:8px;overflow:hidden}h2{font-size:19px;margin:14px 18px}img{width:100%;aspect-ratio:1.25;object-fit:contain;display:block;background:#201a22}label{display:block;padding:14px 18px}select{margin-left:10px;max-width:75%}</style>
<header><h1>Dream warehouse · Native anatomy review</h1><p class="status">16 specimens · 32 imported models · 486/486 diagnostic checks · 150 native captures</p><p>Research organisms first, followed by the three original critters. Every view is a real Godot capture using the rebuilt Blender geometry. Click a specimen to inspect the complete unmodified screenshot.</p><p>Geometry 0 / ½ / 1 and cutaways are staged review poses. Live controller clocks were observed separately for 18 seconds. Lamp views use nine seconds of the existing voxel-light accumulator; they do not imply uniform saturation. These diagnostics are INERT, not campaign completion or owner art acceptance.</p><p>In game: F1 → GO → Dream ecology. Right-drag to orbit, wheel to zoom. Pause holds CPU clocks; small shader motion continues. Pulse / touch is an explicit debug stimulus.</p><p><a href="../gallery/index.html">Blender source gallery</a> · <a href="captures/dream_blender_critters.json">Native diagnostic</a> · <a href="../../../../design/astra/DREAM_CRITTER_BLENDER_REBUILD_2026-09-19.md">Implementation report</a></p><nav>'''+buttons+'</nav></header><main>'+''.join(cards)+'''</main><script>
function show(card,mode){const stem='species_'+card.dataset.kind+'_'+mode;card.querySelector('img').src='previews/'+stem+'.jpg';card.querySelector('a.capture').href='captures/'+stem+'.png';card.querySelector('select').value=mode;}
document.querySelectorAll('article').forEach(card=>card.querySelector('select').addEventListener('change',event=>show(card,event.target.value)));
document.querySelectorAll('button[data-mode]').forEach(button=>button.addEventListener('click',()=>document.querySelectorAll('article').forEach(card=>show(card,button.dataset.mode))));
</script></html>'''
(out/'index.html').write_text(page,encoding='utf-8',newline='\n')
result={'evidence_class':'INERT','status':'PASS','diagnostic_checks':len(data['checks']),
        'captures':len(list(captures.glob('*.png'))),'frame_sample':data['frame_sample'],
        'scope':'Native debug presentation, not runtime_contract or artistic acceptance',
        'history':['01: valid Euplotes JSON rejected by integer-array equality; corrected exact numeric validation.',
                   '02: 486 checks passed; broad gold and framing reviewed.',
                   '03: 486 checks passed after visual refinements; UI encoding issue found.',
                   '04: 486 checks and 13 entry checks passed after UTF-8 correction.',
                   '05: disabling the alpha depth prepass did not remove the material boundary; reverted.',
                   '06: complete outer envelopes share one material pass; enclosed organs retain opaque depth.'],
        'regressions':{'zoo':147,'entry_final':13,'critters':70,
                       'limitations':'Full-world entry and critter runs emit the already observed resident-route errors; zoo and isolated Blender diagnostic have empty stderr.'}}
(out/'review_summary.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'native':str(out),'captures':result['captures'],'checks':result['diagnostic_checks']},indent=2))
