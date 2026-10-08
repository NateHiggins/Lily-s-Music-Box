"""Build the owner review PDF and offline image/notes companion from dossier.json."""
from pathlib import Path
import json,html,io,hashlib
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor,Color,white
from reportlab.lib.utils import ImageReader
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
HERE=Path(__file__).parent;DATA=json.loads((HERE/'dossier.json').read_text(encoding='utf-8'))
OUT=ROOT/'output/pdf/V2_remaining_geometry_texture_dossier.pdf';OUT.parent.mkdir(parents=True,exist_ok=True)
pdfmetrics.registerFont(TTFont('Review','C:/Windows/Fonts/segoeui.ttf'))
pdfmetrics.registerFont(TTFont('ReviewBold','C:/Windows/Fonts/segoeuib.ttf'))
W,H=864,648;M=34;INK=HexColor('#172d38');MUTED=HexColor('#52666d');TEAL=HexColor('#086b74');GOLD=HexColor('#a26123');LINE=HexColor('#d1dce0')
C=canvas.Canvas(str(OUT),pagesize=(W,H));C.setTitle('V2 - Remaining geometry and texture review');C.setAuthor('Orison development / owner review');C.setSubject('Current model images and visual-condition notes, 8 October 2026')
image_cache={};qa=[]
def para(text,x,top,width,size=10,color=INK,bold=False,leading=None):
 style=ParagraphStyle('body',fontName='ReviewBold' if bold else 'Review',fontSize=size,leading=leading or size*1.35,textColor=color)
 p=Paragraph(text,style);_,height=p.wrap(width,1000);p.drawOn(C,x,top-height);return height
def image(path,x,y,w,h):
 path=HERE/path
 if str(path) not in image_cache:
  im=Image.open(path).convert('RGB');b=io.BytesIO();im.save(b,format='JPEG',quality=94,subsampling=0);b.seek(0);image_cache[str(path)]=(ImageReader(b),im.size)
 reader,(iw,ih)=image_cache[str(path)];scale=min(w/iw,h/ih);dw,dh=iw*scale,ih*scale
 C.drawImage(reader,x+(w-dw)/2,y+(h-dh)/2,dw,dh)
def header(label):
 C.setFillColor(TEAL);C.rect(0,H-9,W,9,fill=1,stroke=0)
 C.setFont('ReviewBold',9);C.drawString(M,H-30,'ORISON / V2 VISUAL REVIEW')
 C.setFillColor(MUTED);C.setFont('Review',9);C.drawRightString(W-M,H-30,label)
def footer(page):
 C.setStrokeColor(LINE);C.line(M,27,W-M,27);C.setFillColor(MUTED);C.setFont('Review',8)
 C.drawString(M,14,'08 OCT 2026  /  Current-model dossier  /  Art direction remains open')
 C.drawRightString(W-M,14,str(page))

header('OWNER NOTES EDITION')
para('Remaining geometry<br/>and texture work',M,H-62,650,33,bold=True,leading=39)
para('40 review sets  /  84 selected images  /  stable IDs for your notes',M,H-155,760,13,color=TEAL)
cover=[('G01',1),('G09',0),('T07',0),('A01',1)]
for i,(identity,index) in enumerate(cover):
 row=next(x for x in DATA['sets'] if x['id']==identity);im=row['images'][index];x=M+i*201
 image(im['file'],x,237,190,210);para(identity+'  '+row['title'],x,229,190,9,bold=True)
para('Use this dossier to say what should change, what should stay, and which sets matter most. Each item page includes a description, observed visual condition, suggested review topics, and a fillable notes box.',M,163,785,11)
para('The refrigerator and stove batches are finished and pushed. V2 as a whole is still in progress. These are images of existing models, not proposed redesigns. Native studies and production-light views are labeled separately.',M,104,785,10,color=MUTED)
footer(1);C.showPage()

header('INDEX')
para('Find a review set',M,H-58,700,27,bold=True)
para('Return notes by ID, for example: G09 - piano keys, body proportions, pedals, timber finish.',M,H-96,795,11,color=MUTED)
groups=[('G','Geometry and detail'),('T','Fabricated families / finishes'),('A','Architecture and room balance')]
for col,(prefix,title) in enumerate(groups):
 x=M+col*270;para(title,x,H-140,250,12,bold=True,color=TEAL)
 rows=[r for r in DATA['sets'] if r['id'].startswith(prefix)]
 for i,row in enumerate(rows):
  top=H-170-i*23;page=3+DATA['sets'].index(row)
  para(row['id'],x,top,30,9,bold=True)
  para(row['title'],x+36,top,194,8.8,leading=10)
  C.setFillColor(MUTED);C.setFont('Review',8);C.drawRightString(x+252,top-9,str(page))
  C.linkAbsolute(row['title'],row['id'],Rect=(x,top-20,x+255,top+2),thickness=0)
footer(2);C.showPage()

for page,row in enumerate(DATA['sets'],3):
 C.bookmarkPage(row['id']);C.addOutlineEntry(row['id']+'  '+row['title'],row['id'],0,False)
 header(row['category'].upper())
 para(row['id'],M,H-59,52,22,bold=True,color=TEAL)
 title_h=para(row['title'],M+64,H-58,W-2*M-64,23,bold=True,leading=27)
 assert title_h<=54,(row['id'],'title too tall')
 what_h=para(row['what'],M,H-97,W-2*M,10.4,leading=14)
 assert what_h<=44,(row['id'],'description too tall')
 n=len(row['images']);gap=14;panel_w=(W-2*M-gap*(n-1))/n
 for i,im in enumerate(row['images']):
  x=M+i*(panel_w+gap);image(im['file'],x,269,panel_w,230)
  cap_h=para(im['caption'],x,259,panel_w,8.1,color=MUTED,leading=10.4)
  assert cap_h<=33,(row['id'],'caption too tall')
 C.setStrokeColor(LINE);C.line(M,218,W-M,218)
 para('VISUAL CONDITION',M,204,475,9,bold=True,color=TEAL)
 cond_h=para(row['condition'],M,188,490,10.1,leading=13.4)
 para('REVIEW TOPICS',M+518,204,265,9,bold=True,color=TEAL)
 prompt_h=para(row['prompt'],M+518,188,275,10.1,leading=13.4)
 assert cond_h<=81 and prompt_h<=81,(row['id'],cond_h,prompt_h)
 para('YOUR NOTES  /  Keep, change, priority',M,93,700,9,bold=True,color=TEAL)
 C.acroForm.textfield(name=row['id']+'_notes',tooltip=row['id']+' - '+row['title'],x=M,y=39,width=W-2*M,height=37,fontName='Helvetica',fontSize=10,textColor=INK,borderColor=LINE,fillColor=HexColor('#f4f8fa'),borderWidth=.6,fieldFlags='multiline',forceBorder=True,maxlen=5000)
 qa.append({'id':row['id'],'page':page,'images':n,'condition_height':cond_h,'prompt_height':prompt_h})
 footer(page);C.showPage()

page=len(DATA['sets'])+3
header('SCOPE AND IMAGE SOURCES')
para('How to read these images',M,H-60,740,27,bold=True)
paragraphs=[
 ('Current model / neutral light','Captured from the loaded production world on 8 October. Visible mesh and material resources were copied into an isolated review scene. Original text was retained. Lighting, background and camera are review settings; the images do not represent the room light. The additive halo was omitted from isolated light-fixture views.'),
 ('Current production light','Captured on 8 October in the actual composed V2 world using the existing practical lighting and player lamp. These views reveal warm color shifts, contrast and surrounding materials. They are stationary review views, not route or gameplay acceptance.'),
 ('Native family review','Reused images from the latest family review packets shown in the source manifest, generally 5-8 October. They show the fabricated native model under its review lighting. They are not concept images. Native cabinet-only views may omit separately owned household contents.'),
 ('Saved Blender materials','Fresh renders of the current saved native file, with its existing materials, captured on 8 October. They are shape/component studies: runtime catalogue or optical material treatment may differ. Facade trim, membrane and lift paneling are components, not the whole surrounding installation.'),
 ('Coverage and limits','These 40 sets are representative art-direction groups, not a photograph of every variant or all 200 semantic spaces. The family index accompanies the dossier. Service capacity, live-machine behavior, routes, runtime contracts and the completeness ledger remain separate work. The accepted carried service set and Dream/zoo assets are outside this redesign pass.'),
 ('Return notes','Write into the PDF notes fields, use the offline HTML companion, or reply with item IDs. State what to keep, what to change, desired material character and priority. The companion can export all entered notes as a text file. No model changes are proposed as accepted by this dossier.')]
top=H-112
for title,body in paragraphs:
 para(title,M,top,210,11,bold=True,color=TEAL)
 used=para(body,M+220,top,W-2*M-220,10.3,leading=14);top-=max(used,23)+19
assert top>40,top
footer(page);C.showPage()
C.save()

# Verify the canonical AcroForm and each widget, not just their appearances.
reader=PdfReader(OUT);fields=reader.get_fields();expected={r['id']+'_notes' for r in DATA['sets']}
assert set(fields)==expected,(len(fields),len(expected))
widgets=[]
for p in reader.pages:
 for a in p.get('/Annots',[]):
  a=a.get_object()
  if a.get('/Subtype')=='/Widget':
   assert a.get('/T') in expected and a.get('/V','')==''
   assert a.get('/AP') and a['/AP'].get('/N')
   widgets.append(a['/T'])
assert len(widgets)==len(expected) and len(set(widgets))==len(expected)
for id in expected:assert fields[id].get('/V','')==''
assert len(reader.pages)==len(DATA['sets'])+3
(HERE/'pdf_validation.json').write_text(json.dumps({'evidence_class':'INERT','pdf':OUT.relative_to(ROOT).as_posix(),'pages':len(reader.pages),'fillable_notes':len(fields),'unique_widgets':len(widgets),'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'layout_checks':qa},indent=2)+'\n')

# Offline companion: full-size pictures and exportable owner notes.
esc=html.escape
cards=[]
for row in DATA['sets']:
 figs=''.join(f'<figure><a href="{esc(im["file"])}" target="_blank"><img loading="lazy" src="{esc(im["file"])}" alt="{esc(im["caption"])}"></a><figcaption>{esc(im["caption"])}</figcaption></figure>' for im in row['images'])
 cards.append(f'<article id="{row["id"]}" data-search="{esc((row["id"]+" "+row["title"]+" "+row["category"]).lower())}"><div class="eyebrow">{esc(row["category"])}</div><h2><span>{row["id"]}</span> {esc(row["title"])}</h2><p>{esc(row["what"])}</p><div class="images">{figs}</div><div class="copy"><div><h3>Visual condition</h3><p>{esc(row["condition"])}</p></div><div><h3>Review topics</h3><p>{esc(row["prompt"])}</p></div></div><label for="{row["id"]}_notes">Your notes - keep, change, priority</label><textarea id="{row["id"]}_notes" data-id="{row["id"]}" rows="5"></textarea><small>Source references: {esc(row["references"] or "See dossier.json for image paths and hashes.")}</small></article>')
nav=''.join(f'<a href="#{r["id"]}">{r["id"]} {esc(r["title"])}</a>' for r in DATA['sets'])
document='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>V2 geometry and texture review</title><style>
*{box-sizing:border-box}body{margin:0;background:#eaf0f2;color:#172d38;font:16px/1.5 Segoe UI,Arial,sans-serif}header{background:#102f3a;color:white;padding:36px max(25px,calc((100vw - 1200px)/2));}header h1{font-size:36px;margin:0 0 8px}header p{max-width:950px}main{max-width:1240px;margin:auto;padding:24px}nav{display:grid;grid-template-columns:repeat(3,1fr);gap:4px 20px;padding:16px 0}nav a{color:#0a6873;font-size:13px}article{scroll-margin-top:90px;background:white;padding:28px;margin:30px 0;border-radius:12px;box-shadow:0 2px 12px #1733420c}.eyebrow{color:#5d747d;text-transform:uppercase;font-size:12px;letter-spacing:.1em}h2{margin:7px 0 12px;font-size:27px}h2 span{color:#067381;margin-right:10px}h3{color:#067381;font-size:14px;text-transform:uppercase;letter-spacing:.05em;margin:0}.images{display:flex;gap:16px;align-items:start;margin:24px 0}figure{margin:0;flex:1;min-width:0}img{width:100%;height:350px;object-fit:contain;background:#eef1f2}figcaption{font-size:12px;color:#5d747d;margin-top:6px}.copy{display:grid;grid-template-columns:2fr 1fr;gap:28px}.copy p{margin-top:7px}label{font-weight:600;display:block;margin-top:18px}textarea{font:15px/1.5 Segoe UI,Arial;width:100%;border:1px solid #aabfc8;border-radius:6px;padding:12px;margin-top:6px}small{display:block;color:#657c86;margin-top:10px}.toolbar{position:sticky;top:0;z-index:10;background:#f7fafbed;padding:12px 24px;display:flex;gap:16px;border-bottom:1px solid #cad8dc}.toolbar input{font:inherit;padding:8px;border:1px solid #aabfc8;border-radius:6px;flex:1}.toolbar button{background:#086b74;color:white;border:0;border-radius:6px;padding:8px 22px;font:inherit;cursor:pointer}.note{padding:16px;background:#dcebee;border-radius:8px;font-size:14px}.hidden{display:none}@media(max-width:800px){.images{display:block}figure{margin-bottom:16px}.copy{grid-template-columns:1fr}nav{grid-template-columns:1fr}img{height:auto}.toolbar{padding:10px}.toolbar button{padding:8px}article{padding:18px}}
</style><header><h1>V2 geometry and texture review</h1><p>40 review sets / 84 selected images / 8 October 2026</p><p>Current model condition, ready for your notes. Click an image for its full resolution. Model geometry has not been changed for this dossier.</p></header><div class="toolbar"><input id="search" type="search" placeholder="Find an ID, model or category" aria-label="Find review set"><button id="export">Export notes</button></div><main><div class="note">Notes are stored locally in this browser where supported. Export them before closing. Neutral studio, native study, and production lighting are labeled separately. Saved Blender material studies are component views; runtime materials may differ. This is a representative art-direction dossier, not acceptance of every V2 space or variant.</div><nav>'''+nav+'</nav>'+''.join(cards)+r'''</main><script>
const key='orison-v2-review-20261008';let saved={};try{saved=JSON.parse(localStorage.getItem(key)||'{}')}catch(e){}document.querySelectorAll('textarea').forEach(el=>{el.value=saved[el.dataset.id]||'';el.addEventListener('input',()=>{saved[el.dataset.id]=el.value;try{localStorage.setItem(key,JSON.stringify(saved))}catch(e){}})});document.getElementById('search').addEventListener('input',e=>{let q=e.target.value.toLowerCase();document.querySelectorAll('article').forEach(a=>a.classList.toggle('hidden',!a.dataset.search.includes(q)))});document.getElementById('export').addEventListener('click',()=>{let text='V2 OWNER REVIEW NOTES - 2026-10-08\n\n';document.querySelectorAll('article').forEach(a=>{let note=a.querySelector('textarea').value.trim();if(note)text+=a.querySelector('h2').textContent+'\n'+note+'\n\n'});const u=URL.createObjectURL(new Blob([text],{type:'text/plain'}));const a=document.createElement('a');a.href=u;a.download='V2_owner_review_notes.txt';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)});
</script></html>'''
(HERE/'dossier.html').write_text(document,encoding='utf-8',newline='\n')
(HERE/'notes_template.txt').write_text('V2 OWNER REVIEW NOTES - 2026-10-08\n\n'+''.join(f'{r["id"]} - {r["title"]}\nKeep:\nChange:\nMaterial / wear:\nPriority:\n\n' for r in DATA['sets']),encoding='utf-8',newline='\n')
print(json.dumps({'pdf':str(OUT),'pages':len(reader.pages),'fillable_notes':len(fields),'size_mb':round(OUT.stat().st_size/1024**2,2),'html':str(HERE/'dossier.html')}))
