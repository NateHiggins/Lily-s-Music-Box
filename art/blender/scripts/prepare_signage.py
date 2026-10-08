"""Retain the measured actor frames; no additional Godot discovery run.

The source census was captured from the unchanged three production scripts.
Builder and runtime preflight bind the source scripts and original mesh counts.
"""
from pathlib import Path
import hashlib,json,argparse
from bodega_services_geometry import dimensions
ROOT=Path(__file__).resolve().parents[3]
def digest(p):return hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
args=argparse.ArgumentParser();args.add_argument('--census',type=Path,default=ROOT/'tmp/v2-improvement/b0-final-01/source-census.json');args=args.parse_args()
census=json.loads(args.census.read_text(encoding='utf-8'))
actors=[a for a in census['actors'] if a['id'] in ['M14','M17','M26']]
assert len(actors)==3
for a in actors:
    a['source_sha256']=digest(ROOT/'game'/a['script'].removeprefix('res://'))
    # Bodega is the sole owner of this script, reached by its original class;
    # its generic exterior node name must never be treated as an identity.
    if a['id']=='M17':a['actor']='FittedBodegaSignage'
dims=dimensions()
frontage=json.loads((ROOT/'art/data/bodega_frontage/source_plan.json').read_text())
plan={'evidence_class':'INERT','classification':'ADAPTATION','source_census_sha256':digest(args.census),'actors':actors,
      'bodega_service':{'sign_offset':[0,2.62,.08],
                        'existing_front_junction':[dims['x'],dims['height'],dims['endpoints']['front'][2]],
                        'ceiling':dims['ceiling']},
      'bodega_service_port':frontage['sign_service_port'],
      'source_finishes':[{'actor':'F01_BAR_SIGNAGE','index':35,'roughness':.93,'color':[.72,.14,.08,1.],'emission':[]},
                         {'actor':'FittedBodegaSignage','index':0,'roughness':.79,'color':[.84,.73,.42,1.],'emission':[1.,.88,.55]}],
      'scope':'Existing sign spans, lettering, light/material state owners and observation bindings. Native housings only.',
      'electrical_scope':'Harukiya internal branches terminate at original fixture sockets and a rear service junction. Bodega branch connects to its existing independent lighting conduit. Orison retains the existing transformer, conduit and wall condulet route.'}
p=ROOT/'art/data/signage/source_plan.json';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(plan,indent=2)+'\n',newline='\n')
print('Three measured signage actors:',[(a['id'],len(a['meshes'])) for a in actors])
