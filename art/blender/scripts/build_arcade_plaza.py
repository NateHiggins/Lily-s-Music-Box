"""Author expanded V2 arcade shells without replacing the protected old layout.

Blender --background --python-exit-code 1 --python this.py -- --out NEW_DIRECTORY
The output directory is mandatory and must be empty. No production installation,
rendering, actor placement or gameplay authority is performed by this producer.
"""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import sys

import bpy
import bmesh
from mathutils import Matrix

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'game/project.godot').is_file())
sys.path.insert(0, str(ROOT / 'art/blender/scripts'))
from fabrication_native_batch import material, partition, export


def digest(path):
    data = Path(path).read_bytes()
    if Path(path).suffix not in {'.blend', '.glb', '.png'}:
        data = data.replace(b'\r\n', b'\n')
    return hashlib.sha256(data).hexdigest()


def wall_openings(plan, shop, stock=False):
    """Admit measured window/door profiles in the wall's along/height plane."""
    import math
    r = shop['partition_rect_m'] if stock else shop['rect_m']
    along_y = r[3] - r[1] > r[2] - r[0] if stock else shop['front'] in ('west', 'east')
    lo, hi = (r[1], r[3]) if along_y else (r[0], r[2])
    # North/south shop walls stop at the adjacent side-wall inner faces.
    if not stock and not along_y:
        lo += plan['wall_thickness_m']; hi -= plan['wall_thickness_m']
    centre = shop.get('stock_opening_center_m', [(r[0]+r[2])/2, (r[1]+r[3])/2]) if stock else shop['entrance_center_m']
    middle = centre[1 if along_y else 0]
    width = plan['stock_frame_clear_m'] if stock else plan['front_frame_clear_m']
    openings = [dict(id='door', clear=[middle-width/2, middle+width/2, 0, plan['door_height_m']], frame=plan['frame_stock_m'], glazed=False)]
    if plan.get('frontage_revision') != 1:
        return openings
    profile = shop['frontage']
    frame = plan['window_frame_m']
    assert type(frame) in (int, float) and math.isfinite(frame) and frame > 0
    if not stock:
        a, b = profile['display_clear_interval_m']
        bottom, top = profile['display_bottom_top_m']
        assert profile['display_source_ids']
        openings.append(dict(id='display', clear=[a, b, bottom, top], frame=frame, glazed=True))
    sources = profile['borrowed_light_source_ids'] if stock else profile['transom_source_ids']
    assert sources, ('missing original optical role', shop['id'], stock)
    bottom, top = plan['borrowed_clear_height_m'] if stock else plan['transom_clear_height_m']
    a, b = lo+plan['wall_thickness_m']+frame, hi-plan['wall_thickness_m']-frame
    span = b-a
    maximum = plan['transom_max_pane_width_m']
    assert math.isfinite(maximum) and maximum > frame
    count = math.ceil((span+frame)/(maximum+frame))
    pane = (span-(count-1)*frame)/count
    assert pane > 0 and pane <= maximum
    if stock:
        assert count*pane*(top-bottom)+1e-9 >= profile['original_borrowed_clear_area_m2'], ('lost borrowed-light area', shop['id'])
    openings.append(dict(id='borrowed' if stock else 'transom', clear=[a,b,bottom,top], frame=frame, glazed=True, panes=count))
    outer = []
    for op in openings:
        a,b,z0,z1 = op['clear']; f=op['frame']
        assert all(type(v) in (int,float) and math.isfinite(v) for v in [a,b,z0,z1,f])
        assert b > a and z1 > z0 and z0 >= 0
        bounds = [a-f,b+f,max(0,z0-f),z1+f]
        assert lo-1e-9 <= bounds[0] and bounds[1] <= hi+1e-9 and bounds[3] < plan['wall_height_m'], ('opening outside full wall',shop['id'],op['id'])
        for other in outer:
            assert not (min(bounds[1],other[1])-max(bounds[0],other[0]) > 1e-9 and min(bounds[3],other[3])-max(bounds[2],other[2]) > 1e-9), ('overlapping frames',shop['id'],op['id'])
        outer.append(bounds)
    return openings


def validate_plan(plan, legacy):
    """Check floor coverage and expansion against actual frozen source floors.

    This checks rectangles and declared openings, not equipment or collision fit.
    """
    import math

    def rect(value):
        assert isinstance(value, list) and len(value) == 4
        assert all(type(v) in (int, float) and math.isfinite(v) for v in value)
        assert value[2] > value[0] and value[3] > value[1]
        return value

    def area(value):
        r = rect(value)
        return (r[2] - r[0]) * (r[3] - r[1])

    def inside(a, b):
        return a[0] >= b[0] - 1e-8 and a[1] >= b[1] - 1e-8 and a[2] <= b[2] + 1e-8 and a[3] <= b[3] + 1e-8

    floor = next(f for f in legacy['floors'] if f['id'] == 'F01')
    source = {r['id']: r for r in floor['furniture']}
    expected = {r['id'][6:-6].replace('otis___son', 'otis_son')
                for r in floor['furniture']
                if r['id'].startswith('storm_shop_') and r['id'].endswith('_floor')}
    assert {s['id'] for s in plan['shops']} == expected
    assert len(plan['shops']) == len(expected)
    hall = rect(plan['hall_rect_m'])
    rectangles = [rect(r) for r in plan['public_floor_rects_m']]
    for shop in plan['shops']:
        r = rect(shop['rect_m'])
        assert inside(r, hall), ('shop outside hall', shop['id'])
        name = shop['id'].replace('shop_otis_son', 'shop_otis___son')
        old_sales = area(source['storm_' + name + '_floor']['rect'])
        old_rear = area(source['site_rear_' + name[5:] + '_floor']['rect'])
        assert abs(shop['old_total_floor_m2'] - old_sales - old_rear) < 1e-8
        assert abs(shop['old_rear_floor_m2'] - old_rear) < 1e-8
        t = plan['wall_thickness_m']
        internal = [r[0] + t, r[1] + t, r[2] - t, r[3] - t]
        stock = rect(shop['stock_rect_m'])
        partition_rect = rect(shop['partition_rect_m'])
        assert inside(stock, internal) and inside(partition_rect, internal)
        assert area(stock) + 1e-8 >= old_rear
        assert area(internal) - area(partition_rect) > old_sales + old_rear
        assert shop['retained_rear_function'].strip()
        # Staff/receiving access is measured against actual retained apparatus;
        # a centred aperture is only the default, not a fixed shop constraint.
        opening = shop.get('stock_opening_center_m')
        if opening is not None:
            assert isinstance(opening, list) and len(opening) == 2
            assert all(type(v) in (int, float) and math.isfinite(v) for v in opening)
            along_y = partition_rect[3] - partition_rect[1] > partition_rect[2] - partition_rect[0]
            lo, hi = (partition_rect[1], partition_rect[3]) if along_y else (partition_rect[0], partition_rect[2])
            center, cross = (opening[1], opening[0]) if along_y else (opening[0], opening[1])
            expected_cross = (partition_rect[0] + partition_rect[2]) / 2 if along_y else (partition_rect[1] + partition_rect[3]) / 2
            assert abs(cross - expected_cross) < 1e-8, ('opening off partition', shop['id'])
            margin = plan['stock_frame_clear_m'] / 2 + plan['frame_stock_m']
            assert lo < center - margin < center + margin < hi, ('stock opening/frame outside partition', shop['id'])
        rectangles.append(r)
        if plan.get('frontage_revision') == 1:
            wall_openings(plan, shop)
            wall_openings(plan, shop, True)
    assert all(inside(r, hall) for r in rectangles)
    xs = sorted({v for r in rectangles + [hall] for v in [r[0], r[2]]})
    ys = sorted({v for r in rectangles + [hall] for v in [r[1], r[3]]})
    for x0, x1 in zip(xs, xs[1:]):
        for y0, y1 in zip(ys, ys[1:]):
            if x1 - x0 < 1e-8 or y1 - y0 < 1e-8:
                continue
            x, y = (x0 + x1) / 2, (y0 + y1) / 2
            count = sum(r[0] < x < r[2] and r[1] < y < r[3] for r in rectangles)
            assert count == 1, ('floor gap or overlap', x, y, count)
    return {'status': 'PASS', 'shops': len(expected),
            'scope': 'Source floor area/stock retention and complete disjoint hall-floor rectangle coverage only'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    output = args.out.resolve()
    if output.exists() and any(output.iterdir()):
        raise FileExistsError('Use a new empty output directory: ' + str(output))
    output.mkdir(parents=True, exist_ok=True)
    (output / 'art/blender').mkdir(parents=True)
    (output / 'game/assets/props').mkdir(parents=True)
    plan_path = ROOT / 'art/data/arcade_plaza/source_plan.json'
    plan = json.loads(plan_path.read_text(encoding='utf-8'))
    assert plan['schema_version'] == 1 and plan['classification'] == 'ADAPTATION'
    for name, expected in plan['reference_sources_sha256_lf'].items():
        assert digest(ROOT / name) == expected, ('changed reference source', name)
    assert len(plan['shops']) == 11 and len({s['id'] for s in plan['shops']}) == 11
    floor_proof = validate_plan(plan, json.loads((ROOT / 'art/data/building_layout.json').read_text(encoding='utf-8')))
    roof_path = ROOT / 'art/data/arcade_plaza/roof_plan.json'
    roof_plan = json.loads(roof_path.read_text(encoding='utf-8'))
    from arcade_roof_geometry import stocks as make_roof_stocks
    roof_stocks = make_roof_stocks(plan, roof_plan)
    catalog_path = ROOT / 'game/data/runtime_material_sets.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))['materials']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    scene['evidence_class'] = 'INERT'
    scene['scope'] = plan['native_scope']
    stocks = bpy.data.collections.new('Closed editable arcade stocks')
    draws = bpy.data.collections.new('Metric material partitions')
    scene.collection.children.link(stocks)
    scene.collection.children.link(draws)
    assert not set(plan['materials']) & set(roof_plan['materials'])
    finishes = {**plan['materials'], **roof_plan['materials']}
    mats = {key: material(ROOT, 'ArcadePlaza_' + key, finish, catalog)
            for key, finish in finishes.items()}
    for key, finish in finishes.items():
        if finish.get('optical_role') == 'Glazing':
            # Native preview only; Godot binds the existing registered clear
            # dielectric owner, rather than exporting this preview shader.
            bsdf = mats[key].node_tree.nodes.get('Principled BSDF')
            bsdf.inputs['Transmission Weight'].default_value = 1
            bsdf.inputs['IOR'].default_value = 1.5
    origin = plan['source_origin_blender_m']
    pieces = []
    inventory = []
    areas = []

    def closed_stock(name, plan_vertices, faces, key, owner, role=None, pane_probe=None):
        vertices = [(origin[0]+u, origin[1]-v, origin[2]+h) for u,v,h in plan_vertices]
        rect = [min(v[0] for v in plan_vertices), min(v[1] for v in plan_vertices),
                max(v[0] for v in plan_vertices), max(v[1] for v in plan_vertices)]
        bottom, top = min(v[2] for v in plan_vertices), max(v[2] for v in plan_vertices)
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        volume = bm.calc_volume(signed=True)
        assert volume > 1e-12 and all(e.is_manifold for e in bm.edges), name
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(mats[key])
        obj = bpy.data.objects.new(name, mesh)
        stocks.objects.link(obj)
        pieces.append((obj, key, owner))
        row = {'name': name, 'owner': owner, 'material': key,
               'plan_rect_m': rect, 'bottom_m': bottom, 'top_m': top,
               'closed_volume_m3': volume}
        if role is not None: row['role'] = role
        if pane_probe is not None: row['pane_probe'] = pane_probe
        inventory.append(row)

    def slab(name, rect, bottom, top, key, owner):
        x0,y0,x1,y1 = rect
        assert x1 > x0 and y1 > y0 and top > bottom, name
        vertices = [(x,y,z) for z in [bottom,top] for y in [y0,y1] for x in [x0,x1]]
        closed_stock(name, vertices, [(0,2,3,1),(4,5,7,6),(0,1,5,4),
                                     (2,6,7,3),(0,4,6,2),(1,3,7,5)], key, owner)

    def framed_wall(name, rect, owner, opening_center=None, clear=None, openings=None):
        x0, y0, x1, y1 = rect
        along_y = y1 - y0 > x1 - x0
        lo, hi = (y0, y1) if along_y else (x0, x1)

        def strip(suffix, a, b, z0, z1, key):
            r = [x0, a, x1, b] if along_y else [a, y0, b, y1]
            slab(name + suffix, r, z0, z1, key, owner)

        if opening_center is None and openings is None:
            strip('', lo, hi, 0, plan['wall_height_m'], 'wall')
            return
        if openings is not None:
            # Construct closed wall stocks around the actual clear openings,
            # never an opaque wall hidden behind transparent glass.
            outer = [[o['clear'][0]-o['frame'],o['clear'][1]+o['frame'],max(0,o['clear'][2]-o['frame']),o['clear'][3]+o['frame']] for o in openings]
            xs = sorted({lo,hi} | {v for r in outer for v in r[:2]})
            zs = sorted({0,plan['wall_height_m']} | {v for r in outer for v in r[2:]})
            for i,(a,b) in enumerate(zip(xs,xs[1:])):
                for j,(bottom,top) in enumerate(zip(zs,zs[1:])):
                    if b-a < 1e-8 or top-bottom < 1e-8: continue
                    x,z=(a+b)/2,(bottom+top)/2
                    if any(r[0]<x<r[1] and r[2]<z<r[3] for r in outer): continue
                    strip('_wall_%d_%d'%(i,j),a,b,bottom,top,'wall')
            for op in openings:
                a,b,z0,z1=op['clear']; f=op['frame']; label='_'+op['id']
                strip(label+'_left',a-f,a,z0,z1,'frame')
                strip(label+'_right',b,b+f,z0,z1,'frame')
                strip(label+'_head',a-f,b+f,z1,z1+f,'frame')
                if z0>0: strip(label+'_sill',a-f,b+f,z0-f,z0,'frame')
                if not op['glazed']: continue
                count=op.get('panes',1); pane=(b-a-(count-1)*f)/count
                for index in range(count):
                    start=a+index*(pane+f); end=start+pane
                    middle=(x0+x1)/2 if along_y else (y0+y1)/2
                    thick=plan['glazing_thickness_m']
                    glass=[middle-thick/2,start,middle+thick/2,end] if along_y else [start,middle-thick/2,end,middle+thick/2]
                    slab(name+label+'_pane_%02d'%index,glass,z0,z1,'glazing',owner)
                    if index<count-1: strip(label+'_mullion_%02d'%index,end,end+f,z0,z1,'frame')
            return
        frame = plan['frame_stock_m']
        a, b = opening_center - clear / 2, opening_center + clear / 2
        assert lo < a - frame < b + frame < hi, name
        h = plan['door_height_m']
        strip('_left_wall', lo, a - frame, 0, plan['wall_height_m'], 'wall')
        strip('_right_wall', b + frame, hi, 0, plan['wall_height_m'], 'wall')
        strip('_head_wall', a - frame, b + frame, h + frame,
              plan['wall_height_m'], 'wall')
        strip('_left_jamb', a - frame, a, 0, h, 'frame')
        strip('_right_jamb', b, b + frame, 0, h, 'frame')
        strip('_frame_head', a - frame, b + frame, h, h + frame, 'frame')

    layer = plan['finish_layer_m']
    depth = plan['floor_slab_m']
    slab('HallFoundation', plan['hall_rect_m'], -depth, -layer, 'structure', 'public')
    slab('CourtFoundation', plan['court_rect_m'], -depth, -layer, 'structure', 'public')
    slab('CourtJoinFoundation', plan['court_join_rect_m'], -depth, -layer, 'structure', 'public')
    for i, rect in enumerate(plan['public_floor_rects_m'] +
                             [plan['court_rect_m'], plan['court_join_rect_m']]):
        slab('PublicFloor_%02d' % i, rect, -layer, 0, 'public_floor', 'public')
    for shop in plan['shops']:
        owner = shop['id']
        x0, y0, x1, y1 = shop['rect_m']
        t = plan['wall_thickness_m']
        stock = shop['stock_rect_m']
        stock_area = (stock[2] - stock[0]) * (stock[3] - stock[1])
        cut = shop['partition_rect_m']
        partition_area = (cut[2] - cut[0]) * (cut[3] - cut[1])
        net = (x1 - x0 - 2 * t) * (y1 - y0 - 2 * t) - partition_area
        assert net > shop['old_total_floor_m2']
        assert stock_area + 1e-8 >= shop['old_rear_floor_m2']
        areas.append({'shop': owner, 'old_total_m2': shop['old_total_floor_m2'],
                      'new_net_m2': net, 'reserved_rear_m2': stock_area,
                      'retained_rear_function': shop['retained_rear_function']})
        # Unfinished structural deck; retained trade floor finishes are a later
        # fitted layer, not silently replaced by this construction preview.
        slab(owner + '_deck', shop['rect_m'], -layer, 0, 'structure', owner)
        walls = {'west': [x0, y0, x0 + t, y1], 'east': [x1 - t, y0, x1, y1],
                 'north': [x0 + t, y0, x1 - t, y0 + t],
                 'south': [x0 + t, y1 - t, x1 - t, y1]}
        for side, rect in walls.items():
            center = shop['entrance_center_m'][1 if side in ['west', 'east'] else 0]
            framed_wall(owner + '_' + side, rect, owner,
                        center if side == shop['front'] else None,
                        plan['front_frame_clear_m'],
                        wall_openings(plan, shop) if side == shop['front'] and plan.get('frontage_revision') == 1 else None)
        along_y = cut[3] - cut[1] > cut[2] - cut[0]
        center = (cut[1] + cut[3]) / 2 if along_y else (cut[0] + cut[2]) / 2
        if 'stock_opening_center_m' in shop:
            center = shop['stock_opening_center_m'][1 if along_y else 0]
        framed_wall(owner + '_stock_partition', cut, owner, center,
                    plan['stock_frame_clear_m'],
                    wall_openings(plan, shop, True) if plan.get('frontage_revision') == 1 else None)
    for stock in roof_stocks:
        closed_stock(stock['name'],stock['vertices'],stock['faces'],stock['material'],
                     stock['owner'],stock['role'],stock.get('pane_probe'))
    grouped = collections.defaultdict(list)
    for obj, key, owner in pieces:
        grouped[owner, key].append(obj)
    parts = []
    for (owner, key), objects in sorted(grouped.items()):
        name = 'ArcadePlaza_' + owner + '_' + key
        obj = partition(draws, name, objects, finishes[key], mats[key],
                        Matrix.Identity(4), catalog)
        parts.append({'name': name, 'owner': owner, 'material': key,
                      'triangles': len(obj.data.polygons)})
    stocks.hide_render = True
    stocks.hide_viewport = True
    scene.view_layers[0].update()
    proof = export(output, 'arcade_plaza_shells', draws, material_names_only=True)
    assert proof['status'] == 'PASS'
    assert proof['triangles'] == sum(p['triangles'] for p in parts)
    bindings = [plan_path, roof_path, Path(__file__).resolve(), catalog_path,
                ROOT / 'art/blender/scripts/arcade_roof_geometry.py']
    bindings += [ROOT / 'art/blender/scripts' / name for name in
                 ['fabrication_native_batch.py', 'fabrication_chart_batch.py',
                  'fabrication_uvs.py', 'fabrication_grain.py',
                  'fabrication_normals.py', 'check_exported_tangents.py']]
    bindings += list({ROOT / 'game/assets/building/textures' / name
                      for f in finishes.values() for name in catalog[f['catalog_key']]['files']})
    result = {'evidence_class': 'INERT', 'status': 'NATIVE_EXPORT_PASS_NOT_INSTALLED',
              'scope': plan['native_scope'], 'blender_version': bpy.app.version_string,
              'floor_plan_check': floor_proof,
              'closed_stocks': inventory, 'native_parts': parts, 'shop_areas': areas,
              'tangent_check': proof,
              'source_sha256': {p.relative_to(ROOT).as_posix(): digest(p) for p in bindings},
              'blend_sha256': digest(output / 'art/blender/arcade_plaza_shells.blend'),
              'glb_sha256': digest(output / 'game/assets/props/arcade_plaza_shells.glb'),
              'unresolved': ['retained equipment and trade floor fit', 'actual paired leaves and open passage',
                             'court support/facade/glazing/roof', 'V2 native retirement and actor/frame overlay',
                             'loaded routes/services/save/surface/cost/human acceptance']}
    (output / 'NATIVE_BUILD.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    runtime = {'schema': 'orison.v2.arcade-plaza-shells.v1',
               'asset': 'res://assets/props/arcade_plaza_shells.glb',
               'asset_sha256': result['glb_sha256'],
               'materials': [dict(id=key, **{k:v for k,v in finish.items() if k != 'catalog_purpose'})
                             for key,finish in finishes.items()],
               'native_parts': parts, 'cells': [s['id'] for s in plan['shops']]}
    contract = {'schema': 'orison.v2.arcade-plaza-shell-contract.v1',
               'asset_sha256': result['glb_sha256'],
               'source_plan_sha256_lf': digest(plan_path),
               'closed_stocks': inventory, 'shops': plan['shops'],
               'source_origin_blender_m': origin,
               'front_frame_clear_m': plan['front_frame_clear_m'],
               'stock_frame_clear_m': plan['stock_frame_clear_m'],
               'door_height_m': plan['door_height_m'],
               'optical_material_ids': [key for key,finish in finishes.items() if finish.get('optical_role') == 'Glazing']}
    destination = output / 'game/data/orison_v2/arcade_plaza_shells.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(runtime, indent=2) + '\n', encoding='utf-8')
    destination = output / 'game/tests/fixtures/arcade_plaza_shells_contract.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(contract, indent=2) + '\n', encoding='utf-8')
    print('ARCADE_NATIVE_SHELLS_PASS', len(inventory), 'stocks;', proof['triangles'], 'triangles')


if __name__ == '__main__':
    main()
