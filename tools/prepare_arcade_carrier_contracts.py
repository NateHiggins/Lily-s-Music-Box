"""Compile canonical per-cell native carrier diagnostics; never an installer.

python -B tools/prepare_arcade_carrier_contracts.py [--check]
"""
from __future__ import annotations
import argparse
import copy
import json
import math
import struct
from pathlib import Path
import re
import prepare_arcade_retained_equipment as retained
import prepare_arcade_native_projection as diner
from prepare_arcade_native_projection import require, sha, matrix, mul, label_transform

ROOT = Path(__file__).resolve().parents[1]
PLAN = retained.PLAN
FIXTURE = Path('game/tests/fixtures/arcade_all_native_projection.json')
SEATING = 'game/scripts/building/orison_v2_shop_seating.gd'
PASSAGE = 'game/scripts/building/orison_v2_passage_region.gd'


def owners(root, families):
    seating = (root/SEATING).read_text(encoding='utf-8')
    recipes = {}
    for method, body in re.findall(r'static func (\w+)\([^\n]*\)[^\n]*:\n(.*?)(?=\nstatic func |\n# Immutable|\Z)', seating, re.S):
        match = re.search(r'return mount_records\(cell,layout,"([^"]+)","([^"]+)","([^"]+)","([^"]+)"', body)
        if match:
            sidecar, name, prefix, meta = match.groups()
            require(sidecar not in recipes, 'ambiguous mounting recipe')
            recipes[sidecar] = dict(shared_method=method,name=name,draw_prefix=prefix,part_meta=meta)
    passage = (root/PASSAGE).read_text(encoding='utf-8')
    constants = dict(re.findall(r'const (\w+) := preload\("(res://[^\"]+)"\)', passage))
    calls = re.findall(r'if not (\w+)\.mount_cell\(cell_nodes\[identity\],source_layout([^\n]*)\):', passage)
    result = {}
    for order, (constant, extra) in enumerate(calls):
        wrapper = constants[constant]
        source = root/'game'/wrapper[6:]
        text = source.read_text(encoding='utf-8')
        methods = set(re.findall(r'\.(mount_\w+)\(cell,\s*layout', text))
        if wrapper == 'res://scripts/building/orison_v2_shop_seating.gd':
            methods = {'mount_cell'}
        matches = [(sidecar, recipe) for sidecar,recipe in recipes.items() if recipe['shared_method'] in methods]
        for sidecar, recipe in matches:
            family = Path(sidecar).stem
            if family not in families:
                continue
            require(family not in result, 'ambiguous wrapper ownership: '+family)
            require(extra in ('', ',portrait_atlas_cache'), 'unsupported wrapper arguments: '+family)
            result[family] = dict(recipe, family=family,sidecar=sidecar,wrapper=wrapper,method='mount_cell',
                                  arguments=['cell','original_layout']+(['portrait_atlas_cache'] if extra else []),mount_order=order)
    require(set(result)==set(families), 'missing wrapper ownership: '+str(set(families)-set(result)))
    return result


def game_bindings(root, seeds):
    """Bind wrapper dependency sources too, without flattening their behavior."""
    result = {}
    pending = list(seeds)
    while pending:
        name = pending.pop()
        if name in result:
            continue
        file = diner.resource(root,name)
        require(file.is_file(), 'missing owner dependency: '+name)
        result[name] = dict(kind='lf',sha256=sha(file,True))
        if file.suffix in ('.gd','.gdshader'):
            text = file.read_text(encoding='utf-8')
            calls = re.finditer(r'''\b(?:preload|load)\s*\(\s*(["'])(res://[^"'\r\n]+?\.(?:gd|gdshader))\1\s*\)''',text)
            pending.extend(match.group(2) for match in calls)
    return dict(sorted(result.items()))



def native_aabb_centre(native, part):
    """Read the actual POSITION payload used by Mesh.get_aabb(), in mesh space."""
    primitives = native.doc['meshes'][native.doc['nodes'][native.names[part]]['mesh']]['primitives']
    points = []
    for primitive in primitives:
        accessor = native.doc['accessors'][primitive['attributes']['POSITION']]
        require(accessor['componentType']==5126 and accessor['type']=='VEC3' and not accessor.get('sparse'), 'unsupported auxiliary POSITION')
        view = native.doc['bufferViews'][accessor['bufferView']]
        start = view.get('byteOffset',0)+accessor.get('byteOffset',0)
        for index in range(accessor['count']):
            point = struct.unpack_from('<3f',native.binary,start+index*view.get('byteStride',12))
            require(all(math.isfinite(v) for v in point), 'nonfinite auxiliary POSITION')
            points.append(point)
    require(bool(points), 'empty auxiliary owner mesh')
    return [(min(p[k] for p in points)+max(p[k] for p in points))/2 for k in range(3)]


def globe_auxiliaries(root, cell, ctx):
    if cell['cell']!='shop_otis_son':
        return []
    wrapper = 'res://scripts/building/orison_v2_druggist_carboys.gd'
    receivers = 'res://scripts/lamp/lamp_optical_receivers.gd'
    shader = 'res://shaders/lamp_optical_glass_haze.gdshader'
    for source in (wrapper,receivers,shader):
        require(source in cell['source_bindings'], 'unbound auxiliary owner: '+source)
    wrapper_text = diner.resource(root,wrapper).read_text(encoding='utf-8')
    receiver_text = diner.resource(root,receivers).read_text(encoding='utf-8')
    # These are the actual role recipes, not a generic optical reconstruction.
    for token in ('haze_material.set_shader_parameter("thickness_m",.012)',
                  'const GLOBE_TARGET_X := 15.4',
                  'glow.emission_enabled=true;glow.emission=hue;glow.emission_energy_multiplier=1.4',
                  'lamp.light_color=hue;lamp.light_energy=3.2;lamp.spot_range=5.5;lamp.spot_angle=28.;lamp.spot_attenuation=.8',
                  'lamp.shadow_enabled=false', 'Basis.looking_at(target-centre,Vector3.UP)',
                  'lamp.set_meta("druggist_show_globe",part)'):
        require(token in wrapper_text, 'show globe recipe changed: '+token)
    for token in ('const LAYER := 1 << 17', 'const RECEIVER_META := &"lamp_optical_receiver"',
                  'receiver.mesh = surface.mesh', 'receiver.layers = LAYER',
                  'receiver.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF',
                  'receiver.visible = false', 'surface.add_child(receiver)',
                  'preload("res://shaders/lamp_optical_glass_haze.gdshader")'):
        require(token in receiver_text, 'glass haze recipe changed: '+token)
    family = ctx['families']['druggist_carboys']; native = family['native']
    # This source exports flat mesh nodes; fail rather than guessing a future hierarchy path/order.
    require(all(index not in native.parents for index in native.names.values()), 'nested carboy node paths require explicit renewal')
    scenes = native.doc['scenes'][native.doc.get('scene',0)]['nodes']
    require(scenes==list(range(len(native.doc['nodes']))), 'carboy traversal order changed')
    owners = {r['part_id']:r for r in cell['entries'] if r['model']=='DruggistCarboys'}
    declarations = family['parts']
    result = []; light_index = 0
    identity = [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]
    for part in native.names:
        if part not in owners:
            continue
        owner = owners[part]
        common = dict(model=owner['model'],owner_part_id=part,part_meta=owner['part_meta'],
                      delta_transform=owner['delta_transform'])
        if part.endswith('__glassish_shell'):
            result.append(dict(common,node_path=owner['target_name']+'/LampGlassHaze',kind='glass_haze',
                source_transform=owner['source_transform'],target_transform=owner['target_transform'],
                local_transform=identity,shares_owner_mesh=True,
                properties=dict(layers=1<<17,cast_shadow=0,visible=False),metadata=dict(lamp_optical_receiver=True),
                shader=shader,shader_parameters=dict(thickness_m=.012)))
        record = declarations[(cell['cell'],part)]
        if 'tint' not in record or '__fill' not in part:
            continue
        tint = record['tint'][:3]; require(len(tint)==3 and max(tint)>0, 'invalid show globe tint')
        hue = [v/max(tint) for v in tint]
        centre_local = native_aabb_centre(native,part)
        pose = owner['source_transform']
        centre = [sum(pose[i][k]*centre_local[k] for k in range(3))+pose[i][3] for i in range(3)]
        # Godot Basis.looking_at: -Z points toward target, +Y is the supplied up.
        z = [centre[0]-15.4,centre[1],0.0]
        length = math.sqrt(sum(v*v for v in z)); require(length>0,'degenerate show globe target')
        z = [v/length for v in z]
        x = [z[2],0.0,-z[0]]
        length = math.sqrt(sum(v*v for v in x)); require(length>0,'parallel show globe up')
        x = [v/length for v in x]
        y = [z[1]*x[2]-z[2]*x[1],z[2]*x[0]-z[0]*x[2],z[0]*x[1]-z[1]*x[0]]
        source = matrix([[x[i],y[i],z[i],centre[i]] for i in range(3)]+[[0,0,0,1]],rigid=True)
        result.append(dict(common,node_path='ShowGlobeLight'+str(light_index),kind='show_globe_light',
            source_transform=source,target_transform=mul(owner['delta_transform'],source),source_aabb_centre_local=centre_local,
            properties=dict(light_color=hue,light_energy=3.2,spot_range=5.5,spot_angle=28.0,spot_attenuation=.8,
                shadow_enabled=False),metadata=dict(druggist_show_globe=part),
            owner_material_properties=dict(emission_enabled=True,emission=hue,emission_energy_multiplier=1.4)))
        light_index += 1
    require(light_index==4 and len(result)==8, 'eight exact globe auxiliaries required')
    return result


def validate_contracts(actual, expected):
    """Admission compares the entire generated declaration, not selected counters."""
    require(actual == expected, 'carrier contract differs from current canonical sources (coverage/frame/label/owner binding)')


def build(root=ROOT, document=None):
    doc = copy.deepcopy(document) if document is not None else json.loads((root/PLAN).read_text(encoding='utf-8'))
    ctx = retained.context(root,doc)
    projection = retained.project(doc,ctx)
    require(doc['projection']==projection, 'canonical equipment projection stale')
    ownership = owners(root,ctx['families'])
    canonical_diner = diner.build(root)
    output = dict(schema_version=1,classification='NATIVE_CARRIER_DIAGNOSTIC_NOT_INSTALLATION_OR_DISPOSAL',
                  placement_source=PLAN.as_posix(),placement_sha256_lf=sha(root/PLAN,True),
                  source_bindings=copy.deepcopy(doc['source_bindings']),
                  separate_rebuild_owners=['res://scripts/building/orison_v2_shop_millwork.gd','public_passage_geometry'],
                  receiving_cabinets_enabled=False,cells=[])
    for identity in sorted(ctx['cells']):
        cell_source = 'res://assets/building/floor_01_cells/'+identity+'.gltf'
        cell_file = diner.resource(root,cell_source)
        original = json.loads(cell_file.read_text(encoding='utf-8'))
        bindings = {cell_source:dict(kind='lf',sha256=sha(cell_file,True))}
        if Path(str(cell_file)+'.import').is_file():
            bindings[cell_source+'.import'] = dict(kind='lf',sha256=sha(Path(str(cell_file)+'.import'),True))
        for buffer in original['buffers']:
            uri = buffer['uri']
            require(not Path(uri).is_absolute() and '..' not in Path(uri).parts and ':' not in uri, 'foreign cell buffer')
            res = cell_source.rsplit('/',1)[0]+'/'+uri
            bindings[res] = dict(kind='raw',sha256=sha(diner.resource(root,res)))
        rows = [r for r in projection['native_entries'] if r['cell']==identity]
        rebuilds = [r for r in doc['native_rebuild_parts'] if r['cell']==identity]
        families = {r['family'] for r in rows+rebuilds}
        mounts = sorted((copy.deepcopy(ownership[f]) for f in families),key=lambda r:r['mount_order'])
        bindings.update(game_bindings(root,[m['wrapper'] for m in mounts]+['res://'+SEATING[5:],'res://'+PASSAGE[5:]]))
        # Finishes now also apply to projected passive model identities. Bind
        # the authored recipe data, not only its script/compiled map table.
        finish_profile = 'res://data/orison_v2/owner_finish_profiles.json'
        bindings[finish_profile] = dict(kind='lf',sha256=sha(diner.resource(root,finish_profile),True))
        assets = {}
        for family in sorted(families):
            declaration = ctx['families'][family]['declaration']
            assets['res://'+declaration['asset'][5:]] = declaration['asset_sha256']
            bindings['res://'+declaration['sidecar'][5:]] = dict(kind='lf',sha256=declaration['sidecar_sha256_lf'])
        cell = dict(schema_version=1,cell=identity,placement_source=PLAN.as_posix(),placement_sha256_lf=output['placement_sha256_lf'],
                    fabrication_source='res://data/building_layout.json',fabrication_sha256_lf=sha(root/doc['fabrication'],True),
                    cell_source=cell_source,cell_source_sha256_lf=sha(cell_file,True),source_bindings=bindings,native_assets=assets,
                    mounts=mounts,models=[dict(name=m['name'],part_meta=m['part_meta'],
                        **({'presentation_metadata':['optical_material','show_globe_lights']} if m['family']=='druggist_carboys' else {})) for m in mounts],entries=[],rebuild_entries=[],labels=[])
        for row in rows:
            owner = ownership[row['family']]
            cell['entries'].append(dict(model=owner['name'],part_meta=owner['part_meta'],part_id=row['part'],
                source_transform=row['source_transform'],delta_transform=row['delta_transform'],target_transform=row['target_transform'],
                triangles=row['triangles'],target_name=owner['draw_prefix']+row['part'],group=row['group']))
        for row in rebuilds:
            owner = ownership[row['family']]
            native = ctx['families'][row['family']]['native']
            cell['rebuild_entries'].append(dict(model=owner['name'],part_meta=owner['part_meta'],part_id=row['part'],
                source_transform=row['source_transform'],triangles=native.triangles(row['part']),material_key=row['source_part']['key'],
                source_role=('original_architectural_glazing' if row['family']=='photo_glazing' else row.get('action','source_dependent_architectural_attachment')),reason=row['reason'],source_part=row['source_part'],encoded_source=retained.fingerprint(native,row['part'])))
        if identity == diner.CELL:
            # This producer owns every Diner target and all menu targets. Never rederive them here.
            require([{k:v for k,v in r.items() if k!='group'} for r in cell['entries']]==canonical_diner['entries'], 'Diner authority differs')
            cell['source_bindings'].update(copy.deepcopy(canonical_diner['source_bindings']))
            cell['entries'] = copy.deepcopy(canonical_diner['entries'])
            cell['labels'] = copy.deepcopy(canonical_diner['labels'])
            cell['diner_authority'] = dict(producer='tools/prepare_arcade_native_projection.py',placement_source=canonical_diner['placement_source'],placement_sha256_lf=canonical_diner['placement_sha256_lf'])
        elif identity=='shop_hardware_paint':
            labels = ctx['families']['hardware_stock']['labels'][identity]
            require(len(labels)==1 and labels[0]['id']=='night_service', 'Hardware label identity changed')
            # Source builder's counter branch creates Bell/NightCard/CardStay and this label together.
            source_builder = 'art/blender/scripts/build_hardware_stock.py'
            text = (root/source_builder).read_text(encoding='utf-8')
            require("elif kind=='counter':" in text and "identity+'_NightCard'" in text and "'id':'night_service'" in text, 'Hardware label producer changed')
            output['source_bindings'][source_builder] = dict(kind='lf',sha256=sha(root/source_builder,True))
            group = next(g for g in doc['groups'] if g['cell']==identity and g['id']=='hardware_counter')
            require([a['id'] for a in group['native_assemblies']]==['storm_shop_hardware_paint_counter'], 'Hardware label group changed')
            label = labels[0]; source = label_transform(label); delta = matrix(group['delta_transform'],rigid=True)
            owner = ownership['hardware_stock']
            cell['labels'] = [dict(model=owner['name'],label_id=label['id'],node_name='Words_'+label['id'],text=label['text'],source_label=label,
                source_transform=source,delta_transform=delta,target_transform=mul(delta,source),target_name='Words_'+label['id'],group=group['id'])]
        expected = {(family,part) for family in families for (c,part) in ctx['families'][family]['parts'] if c==identity}
        placed = [(r['family'],r['part']) for r in rows+rebuilds]
        require(len(placed)==len(set(placed)) and set(placed)==expected, 'transfer/rebuild coverage ambiguity')
        expected_labels = sum(len(ctx['families'][f]['labels'].get(identity,[])) for f in families)
        require(len(cell['labels'])==expected_labels, 'label omission')
        cell['auxiliary_entries'] = globe_auxiliaries(root,cell,ctx)
        output['cells'].append(cell)
    counts = projection['counts']
    require((counts['cells'],counts['native_families'],counts['placed_native_parts'],counts['native_rebuild_parts'])==(11,46,1165,84),'unexpected canonical inventory')
    output['counts'] = dict(cells=11,families=46,entries=1165,rebuild_entries=84,labels=4,auxiliary_entries=8)
    for producer in ('tools/prepare_arcade_carrier_contracts.py','tools/prepare_arcade_retained_equipment.py','tools/prepare_arcade_native_projection.py'):
        output['source_bindings'][producer] = dict(kind='lf',sha256=sha(root/producer,True))
    return output


def render(doc):
    return json.dumps(doc,indent=1,allow_nan=False)+'\n'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args(); text=render(build(args.root)); output=args.root/FIXTURE
    if args.check:
        require(output.exists() and output.read_text(encoding='utf-8').replace('\r\n','\n')==text,'carrier contracts stale; rerun producer')
        print('ARCADE ALL NATIVE CONTRACTS OK')
    else:
        output.write_text(text,encoding='utf-8',newline='\n'); print('WROTE '+str(FIXTURE))
    return 0

if __name__=='__main__':
    raise SystemExit(main())
