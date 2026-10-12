"""Source-owned AC media leads; original appliance power owners are retained."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def read(name):return json.loads((ROOT/name).read_text(encoding='utf-8'))
profiles={r['unit']:r for r in read('game/data/domestic_radios.json')['profiles']}
radios=read('game/data/orison_v2/domestic_radios.json')['receivers']
projectors=read('game/data/orison_v2/domestic_projectors.json')['projectors']
records=[]
depths={'atwater_kent_44':.27,'radiola_table':.25}
for row in radios+projectors:
    projector=row in projectors
    family='projector' if projector else profiles[row['unit']]['family']
    if not projector and family not in depths:continue
    position=row['position'];x=position[0]+.030;y=position[1]+.085;z=position[2]+(.150 if projector else depths[family]/2+.003)
    # Put the receptacle inside the four table legs. The lead passes around
    # the rear edge, returns below the top and falls beside the centre bay.
    edge=.263 if projector else .243
    outlet=[.030,0,.040]
    records.append({'id':row['id'],'unit':row['unit'],'support':row['support'],'family':family,
        'entry':[x,y,z],'outlet':outlet,'path':[[x,y,z],[x,y,z+.025],[x,y,edge],[x,.765,edge],[x,.680,edge],[x,.665,.200],[x,.610,.200],[x,.110,.200],[.030,.090,.040],[.030,.043,.040]],
        'floor_owner':row['unit']})
assert len(records)==10
target=ROOT/'art/data/media_ac_supply';target.mkdir(parents=True,exist_ok=True)
(target/'source_plan.json').write_text(json.dumps({'evidence_class':'INERT','classification':'ADAPTATION','schema_version':1,
 'intent':'New visual floor receptacles and supported cloth leads for seven AC receivers and three projectors. Original switches, circuits, placement, audio and decoder owners remain. Battery/aerial installations are separate unfinished work.',
 'cord_radius':.0033,'installations':records},indent=2)+'\n',encoding='utf-8',newline='\n')
print('Ten authored AC installations; original appliance manifests unchanged')
