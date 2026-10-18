"""Publish source-fitted clock stock; only composed testing can qualify it."""
from pathlib import Path
import argparse,hashlib,json,shutil,struct
from plan_v2_arcade_clock import ROOT,build
def publish(directory):
    directory=Path(directory);plan=json.loads((directory/'plan.json').read_text());proof=json.loads((directory/'native_review.json').read_text())
    if plan!=build():raise ValueError('Clock source plan is stale')
    if proof.get('status')!='PASS' or not all(c['ok'] for c in proof.get('checks',[])) or len(proof['checks'])<351:raise ValueError('Native clock proof incomplete')
    if proof.get('saved_hand_reference')!='12:00':raise ValueError('Editable native and GLB must retain the same zero-angle hand reference')
    for relative,expected in proof['source_bindings_lf'].items():
        if hashlib.sha256((ROOT/relative).read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=expected:raise ValueError('Expired clock source: '+relative)
    for filename,expected in proof['mapped_source_sha256'].items():
        if hashlib.sha256((ROOT/'game/assets/building/textures'/filename).read_bytes()).hexdigest()!=expected:raise ValueError('Expired clock finish: '+filename)
    asset=directory/'arcade_clock.glb';native=ROOT/'art/blender/arcade_clock.blend'
    if hashlib.sha256(asset.read_bytes()).hexdigest()!=proof['asset_sha256'] or hashlib.sha256(native.read_bytes()).hexdigest()!=proof.get('published_native_sha256'):raise ValueError('Native clock publication differs')
    raw=asset.read_bytes();length,kind=struct.unpack_from('<II',raw,12);doc=json.loads(raw[20:20+length]);names={n['name'] for n in doc['nodes'] if 'mesh' in n}
    catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials'];parts=[]
    expected={'clock_fixed__radiator_service_brass':'radiator_service_brass','clock_fixed__radiator_service_brass_turned_rims':'radiator_service_brass','clock_fixed__iron_blackened':'iron_blackened','clock_fixed__washer_enamel':'washer_enamel'}
    for face in plan['faces']:
        for hand in ['hour','minute']:expected[face['id']+'_'+hand+'_hand']='iron_blackened'
    expected['clock_fixed__milk_glass']='milk_glass'
    if names!=set(expected):raise ValueError('Clock export nodes differ: '+str(names^set(expected)))
    for name,key in expected.items():
        row=dict(name=name,key=key,tile=catalog[key]['meters_per_tile'])
        if key!='milk_glass':row['catalog_key']=key
        parts.append(row)
    data=dict(schema_version=1,asset='res://assets/props/arcade_clock.glb',tolerance=.00002,
              cells=[dict(id='passage',replace=plan['retire'],parts=parts)],origin=plan['origin'],
              faces=[{key:row[key] for key in ['id','normal','u','v','center']} for row in plan['faces']],
              presentation=dict(time_owner='CampaignClock.minute_of_day',update_interval_s=.2,letter_depth_m=.0075,numeral_radius_m=.161,font_size=48,pixel_size_m=.0005),
              optics=dict(role='Glazing',room_class='public',registered_owner='res://scripts/building/orison_v2_architectural_materials.gd',shader='res://shaders/lamp_glass_surface.gdshader',surface_roughness=.06,normal_strength=.035,glass_part='clock_fixed__milk_glass'))
    shutil.copyfile(asset,ROOT/'game/assets/props/arcade_clock.glb')
    (ROOT/'game/data/orison_v2/arcade_clock.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
    print('Published native clock at five exact source boundaries; composed verification pending')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);publish(p.parse_args().directory)
