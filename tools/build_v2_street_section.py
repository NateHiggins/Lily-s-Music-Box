"""Register the authored street section at the V2 front-door origin.

This writes only the isolated V2 exterior geometry. Existing shop placements,
interaction surfaces and route identities are unchanged.
"""
from pathlib import Path
import ast
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
GEOMETRY = ROOT/'game/data/orison_v2/exterior/exterior_geometry.json'
REGIONS = ROOT/'game/data/orison_v2/exterior/regions.json'
GENERATOR = ROOT/'art/data/gen_layout.py'
LAYOUT = ROOT/'game/data/building_layout.json'
REPORT = ROOT/'game/data/orison_v2/exterior/street_section_source.json'


def readable(value, level=0, compact_records=True):
    """Keep individual authored records compact, as in the existing data file."""
    pad = '  '*level
    if isinstance(value, dict):
        nested = any(isinstance(v, dict) or (isinstance(v, list) and any(isinstance(x, dict) for x in v)) for v in value.values())
        if not nested and compact_records:
            return json.dumps(value, separators=(',', ':'))
        return '{\n'+',\n'.join('  '*(level+1)+json.dumps(k)+': '+readable(v, level+1, compact_records) for k,v in value.items())+'\n'+pad+'}'
    if isinstance(value, list) and any(isinstance(v, dict) for v in value):
        return '[\n'+',\n'.join('  '*(level+1)+readable(v, level+1, compact_records) for v in value)+'\n'+pad+']'
    return json.dumps(value, separators=(',', ':'))


def numeric(node, values):
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return node.value
    if isinstance(node, ast.Name):
        return values[node.id]
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        return -numeric(node.operand, values)
    if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub)):
        a, b = numeric(node.left, values), numeric(node.right, values)
        return a+b if isinstance(node.op, ast.Add) else a-b
    raise ValueError(ast.dump(node))


def build():
    needed = {'WALK_W', 'ROAD_W', 'KERB_N', 'KERB_S', 'WALK_S', 'BLDG_S'}
    values = {}
    for node in ast.parse(GENERATOR.read_text(encoding='utf-8')).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            name = node.targets[0].id
            if name in needed:
                assert name not in values
                values[name] = numeric(node.value, values)
    assert set(values) == needed
    layout = json.loads(LAYOUT.read_text())
    markers = [m for f in layout['floors'] if f['id'] == 'F01' for m in f['markers'] if m['id'] == 'F01_DOOR_06']
    assert len(markers) == 1 and markers[0]['yaw_deg'] == 0
    entry = markers[0]
    assert abs(entry['pos'][0]+entry['w']/2) < 1e-8
    source_threshold_z = -entry['pos'][1]
    north = -values['KERB_N']-source_threshold_z
    south = -values['KERB_S']-source_threshold_z
    gateway = -values['BLDG_S']-source_threshold_z
    assert abs(south-north-values['ROAD_W']) < 1e-8
    data = json.loads(GEOMETRY.read_text())
    templates = [t for t in data['templates'] if t['id'] == 'TEMPLATE_STREET_SEGMENT_V1']
    assert len(templates) == 1
    street = templates[0]
    boxes = {b['id']: b for b in street['boxes']}
    old_curb = boxes['street_curb']['position_m'][2]
    curb_width = boxes['street_curb']['size_m'][2]
    curb_center = north-curb_width/2
    delta = curb_center-old_curb
    boxes['pavement_slab']['size_m'][2] = north
    boxes['pavement_slab']['position_m'][2] = north/2
    boxes['street_lane']['size_m'][2] = south-north
    boxes['street_lane']['position_m'][2] = (north+south)/2
    boxes['street_curb']['position_m'][2] = curb_center
    for name, box in boxes.items():
        if name.startswith(('curb_coping_', 'street_lamp_')):
            box['position_m'][2] += delta
        elif name.startswith('pavement_cross_joint_'):
            box['size_m'][2] = north-0.28
            box['position_m'][2] = north/2
        elif name in ['pavement_wet_west', 'pavement_wet_east']:
            box['position_m'][2] = min(box['position_m'][2], north-box['size_m'][2]/2-0.18)
    for light in street['lights']:
        if light['id'].startswith('street_lamp_pool'):
            light['position_m'][2] += delta
    far_walk = json.loads(json.dumps(boxes['pavement_slab']))
    far_walk.update(id='passage_pavement_slab', position_m=[9.5,-0.08,(south+gateway)/2], size_m=[25,0.16,gateway-south])
    far_curb = json.loads(json.dumps(boxes['street_curb']))
    far_curb.update(id='passage_street_curb', position_m=[9.5,-0.02,south+curb_width/2])
    street['boxes'] = [b for b in street['boxes'] if b['id'] not in ['passage_pavement_slab', 'passage_street_curb']]+[far_walk,far_curb]
    GEOMETRY.write_text(readable(data)+'\n', encoding='utf-8')
    regions = json.loads(REGIONS.read_text())
    template = next(t for t in regions['surface_templates'] if t['id'] == 'TEMPLATE_STREET_SEGMENT_V1')
    pavement = next(s for s in template['surfaces'] if s['id'] == 'pavement')
    assert pavement['u_axis'] == [1,0,0] and pavement['v_axis'] == [0,0,1]
    shift = pavement['point_m'][2]-north/2
    before_placements = {p['id']: pavement['point_m'][2]+p['offset_uvn_m'][1] for p in template['placements'] if p['surface_id'] == 'pavement'}
    pavement['point_m'][2] = north/2
    pavement['size_m'][1] = north
    for placement in template['placements']:
        if placement['surface_id'] == 'pavement':
            placement['offset_uvn_m'][1] += shift
            assert abs(pavement['point_m'][2]+placement['offset_uvn_m'][1]-before_placements[placement['id']]) < 1e-8
    for instance in regions['instances']:
        if instance['owner_instance_id'] == 'STREET_ORISON_01' and instance['owner_surface_id'] == 'pavement':
            instance['offset_uvn_m'][1] += shift
    template['boundary_xz_m'][3] = gateway
    region = next(r for r in regions['regions'] if r['id'] == 'REGION_STREET')
    region['boundary'] = [[-3,0],[22,0],[22,gateway],[-3,gateway]]
    REGIONS.write_text(readable(regions, compact_records=False)+'\n', encoding='utf-8')
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    report = {'schema': 'orison.v2.street-section-source.v1',
        'generator_sha256': sha(GENERATOR), 'layout_sha256': sha(LAYOUT),
        'source_threshold_marker': entry['id'], 'source_threshold_z': source_threshold_z,
        'source_section': values, 'north_kerb_z': north, 'south_kerb_z': south,
        'arcade_building_line_z': gateway, 'road_clear_width_m': south-north,
        'geometry_sha256': sha(GEOMETRY), 'regions_sha256': sha(REGIONS),
        'source_layout_changed': False}
    REPORT.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    build()
