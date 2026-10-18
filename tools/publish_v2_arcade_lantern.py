"""Publish reviewed native lantern stock through existing source retirement."""
from pathlib import Path
import argparse,hashlib,json,shutil
from plan_v2_arcade_lantern import ROOT,build


def publish(directory):
    directory=Path(directory)
    plan=json.loads((directory/'plan.json').read_text())
    proof=json.loads((directory/'native_review.json').read_text())
    if plan!=build():raise ValueError('Expired source fitting')
    if proof.get('status')!='PASS' or len(proof.get('geometry_checks',[]))!=8 or not all(r['ok'] for r in proof['geometry_checks']):
        raise ValueError('Native geometry/export checks are incomplete')
    for relative,expected in proof['source_bindings_lf'].items():
        raw=(ROOT/relative).read_bytes()
        if Path(relative).suffix!='.blend':raw=raw.replace(b'\r\n',b'\n')
        if hashlib.sha256(raw).hexdigest()!=expected:raise ValueError('Expired native source: '+relative)
    asset=directory/'arcade_lantern.glb'
    if hashlib.sha256(asset.read_bytes()).hexdigest()!=proof['asset_sha256']:raise ValueError('Native export changed')
    native=ROOT/'art/blender/arcade_lantern.blend'
    if hashlib.sha256(native.read_bytes()).hexdigest()!=proof.get('published_native_sha256'):raise ValueError('Editable native publication changed')
    record=dict(schema_version=1,asset='res://assets/props/arcade_lantern.glb',tolerance=.00002,
                cells=[dict(id='passage',replace=plan['retire'],parts=[dict(name='lantern_roof__cast_iron',key='cast_iron',catalog_key='iron_blackened',tile=.4)])])
    shutil.copyfile(asset,ROOT/'game/assets/props/arcade_lantern.glb')
    (ROOT/'game/data/orison_v2/arcade_lantern.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8',newline='\n')
    print('Published native lantern; three source slabs only; composed verification pending')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path)
    publish(parser.parse_args().directory)
