"""Project a freshly built native canopy into V2's surgical mount records."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]


def publish(directory):
    directory = Path(directory)
    plan = json.loads((directory / 'canopy_plan.json').read_text())
    review = json.loads((directory / 'native_review.json').read_text())
    from plan_v2_arcade_canopy import build
    if plan != json.loads(json.dumps(build())):
        raise ValueError('Expired canopy plan')
    for relative, expected in review['source_bindings'].items():
        if hashlib.sha256((ROOT / relative).read_bytes().replace(b'\r\n', b'\n')).hexdigest() != expected:
            raise ValueError('Expired native source: ' + relative)
    asset = directory / 'arcade_canopy.glb'
    if hashlib.sha256(asset.read_bytes()).hexdigest() != review['asset_sha256']:
        raise ValueError('Native export changed')
    catalog = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']
    parts = [dict(name='canopy__glassish', key='glassish', tile=1.6, plain_alpha=True)]
    for key, source_key in [('plaster_stained', 'plaster'), ('iron_blackened', 'iron_blackened'), ('enamel_appliance', 'enamel_appliance')]:
        parts.append(dict(name='canopy__' + key, key=source_key, catalog_key=key,
                          tile=catalog[key]['meters_per_tile'],
                          tint=[.12, .50, .42, 1.] if key == 'enamel_appliance' else [1., 1., 1., 1.]))
    shipping = json.loads((ROOT / 'game/assets/building/orison_v2/passage/passage.gltf').read_text())
    ornaments = []
    for node in shipping['nodes']:
        if not node.get('name', '').startswith('V2_PASSAGE_finish_ceiling_'):
            continue
        mesh = shipping['meshes'][node['mesh']]
        if len(mesh['primitives']) != 1:
            raise ValueError('Legacy decorative draw changed')
        primitive = mesh['primitives'][0]
        accessor = shipping['accessors'][primitive['attributes']['POSITION']]
        triangle_indices = shipping['accessors'][primitive['indices']]['count'] if 'indices' in primitive else accessor['count']
        ornaments.append(dict(name=node['name'], triangles=triangle_indices // 3, low=accessor['min'], high=accessor['max']))
    if len(ornaments) != 3:
        raise ValueError('Legacy decorative partition count changed')
    finishes = []
    for node in shipping['nodes']:
        name = node.get('name', '').removesuffix('-col')
        for key in ['terrazzo', 'terrazzo_dark', 'common_brick']:
            if name.endswith('_' + key):
                finishes.append(dict(name=name, colliding=node['name'].endswith('-col'), source_key=key,
                                     source_metres=4. if key == 'terrazzo' else 1.2,
                                     catalog_key='arcade_brick_bond' if key == 'common_brick' else 'arcade_' + key))
    if len(finishes) != 6 or len({(row['name'], row['colliding']) for row in finishes}) != 6:
        raise ValueError('Retained arcade finish partitions changed')
    data = dict(schema_version=1, asset='res://assets/props/arcade_canopy.glb', tolerance=.00002,
                cells=[dict(id='passage', replace=plan['retire'], parts=parts)],
                optics=dict(role='Glazing', room_class='public',
                            registered_owner='res://scripts/building/orison_v2_architectural_materials.gd',
                            shader='res://shaders/lamp_glass_surface.gdshader', surface_roughness=.06),
                legacy_ornaments=ornaments, retained_finish_draws=finishes)
    shutil.copyfile(asset, ROOT / 'game/assets/props/arcade_canopy.glb')
    (ROOT / 'game/data/orison_v2/arcade_canopy.json').write_text(json.dumps(data, indent=2) + '\n', encoding='utf8', newline='\n')
    print('Projected native roof:', len(plan['retire']), 'source boundaries and three decorative draws; qualified game run pending')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    publish(args.directory)
