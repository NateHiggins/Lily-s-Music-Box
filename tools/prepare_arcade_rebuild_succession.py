"""Bind prepared architectural rebuild roles to explicit native successors.

This is a role map only: no donor disposal, runtime installation or art acceptance.
Only game/tests/fixtures/arcade_rebuild_succession.json is generated.
"""
from __future__ import annotations
import argparse
import ast
import collections
import copy
import json
import math
import re
from types import SimpleNamespace
import hashlib
from pathlib import Path
from prepare_arcade_native_projection import NativeGLB, SourceCell, require, resource, sha, raw_bounds, boundary_match
from prepare_arcade_retained_equipment import fingerprint
import prepare_arcade_door_frames as doors
import prepare_arcade_door_intake as leaves
import prepare_arcade_darkroom_curtain_intake as curtains

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = Path('game/tests/fixtures/arcade_rebuild_succession.json')
FILES = dict(native='game/tests/fixtures/arcade_all_native_projection.json',
             contract='game/tests/fixtures/arcade_plaza_shells_contract.json',
             shell='game/data/orison_v2/arcade_plaza_shells.json',
             frames='game/tests/fixtures/arcade_door_frames.json',
             leaf_proof='game/tests/fixtures/arcade_door_leaf_native.json',
             leaf_runtime='game/data/orison_v2/arcade_door_leaves.json',
             plan='art/data/arcade_plaza/source_plan.json',
             catalog='game/data/runtime_material_sets.json',
             curtain_proof='game/tests/fixtures/arcade_darkroom_curtain_native.json',
             curtain_runtime='game/data/orison_v2/arcade_darkroom_curtain.json')
BUILDER = 'art/blender/scripts/build_arcade_plaza.py'
ORIGINAL_MODELS = {'ShopClerestories': 32, 'ShopJoinery': 44, 'PhotoGlazing': 3}
MODELS = dict(ORIGINAL_MODELS, PhotoRadioFittings=3)
ORIGINAL79_MAPPING_SHA256 = '5241f4500040efff20cd866fdf992c62d76fd3f583651335571a9b236892ea22'
ORIGINAL_LEAF_CATALOG_SHA256_LF = '4af84dc2f77728b46b16aa912b43586eb5e3e9f0a0d41d814be95fd66ab1cb06'
ORIGINAL_LEAF_CATALOG_SCOPE_SHA256 = 'f89ec83de159c8cfa3c3f4e77393fa3eb43397a523550358964376b8bffb19fb'
LEAF_CATALOG_KEYS = ('door_oak','door_brass','glass_drawn_expressive')
WRAPPERS = {'ShopClerestories': 'res://scripts/building/orison_v2_shop_clerestories.gd',
            'ShopJoinery': 'res://scripts/building/orison_v2_shop_joinery.gd',
            'PhotoGlazing': 'res://scripts/building/orison_v2_photo_glazing.gd',
            'PhotoRadioFittings': 'res://scripts/building/orison_v2_photo_radio_fittings.gd'}


def load_inputs(root):
    return {name: json.loads((root/path).read_text(encoding='utf-8')) for name,path in FILES.items()}


def expected_stocks(root, plan):
    """Reuse ONLY two pure stock-name/rectangle functions; never import bpy.

    slab is an observation sink. No mesh, native source, scene or process exists.
    """
    tree = ast.parse((root/BUILDER).read_text(encoding='utf-8'))
    nodes = [n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef) and n.name in ('wall_openings', 'framed_wall')]
    require(len(nodes) == 2, 'unique pure wall opening/stock producers required')
    rows = []
    def slab(name, rect, bottom, top, material, owner):
        rows.append(dict(name=name, owner=owner, material=material, plan_rect_m=rect, bottom_m=bottom, top_m=top))
    env = dict(plan=plan, slab=slab)
    exec(compile(ast.Module(body=nodes, type_ignores=[]), BUILDER, 'exec'), env)
    for shop in plan['shops']:
        cell=shop['id'];x0,y0,x1,y1=shop['rect_m'];t=plan['wall_thickness_m'];front=shop['front']
        require(all(shop['frontage'][key] for key in ('display_source_ids','transom_source_ids','borrowed_light_source_ids')),'missing original optical role: '+cell)
        walls={'west':[x0,y0,x0+t,y1],'east':[x1-t,y0,x1,y1],
               'north':[x0+t,y0,x1-t,y0+t],'south':[x0+t,y1-t,x1-t,y1]}
        centre=shop['entrance_center_m'][1 if front in ('west','east') else 0]
        env['framed_wall'](cell+'_'+front, walls[front], cell, centre, plan['front_frame_clear_m'], env['wall_openings'](plan,shop))
        cut=shop['partition_rect_m'];along_y=cut[3]-cut[1]>cut[2]-cut[0]
        centre=shop.get('stock_opening_center_m',[(cut[0]+cut[2])/2,(cut[1]+cut[3])/2])[1 if along_y else 0]
        env['framed_wall'](cell+'_stock_partition',cut,cell,centre,plan['stock_frame_clear_m'],env['wall_openings'](plan,shop,True))
    require(len({r['name'] for r in rows}) == len(rows), 'duplicate authored successor stock')
    return rows


def native_stock_witness(native, draw, stock, origin):
    """Recover all twelve actual closed-box triangles from the aggregate draw.

    Ten micrometres identifies exported float32 stock coordinates only; this
    is not a collision/contact acceptance tolerance.
    """
    node=native.names[draw['name']];transform=native.transform(node);proxy=SimpleNamespace(doc=native.doc,buffers=[native.binary])
    x0,y0,x1,y1=stock['plan_rect_m'];low=[origin[0]+x0,origin[2]+stock['bottom_m'],-origin[1]+y0];high=[origin[0]+x1,origin[2]+stock['top_m'],-origin[1]+y1];selected=[];residual=0.
    mesh=native.doc['meshes'][native.doc['nodes'][node]['mesh']]
    for pi,primitive in enumerate(mesh['primitives']):
        positions,_=SourceCell.accessor(proxy,primitive['attributes']['POSITION']);raw,_=SourceCell.accessor(proxy,primitive['indices']);indices=[r[0]for r in raw]
        for ti in range(len(indices)//3):
            ids=indices[3*ti:3*ti+3];points=[[sum(transform[i][j]*positions[v][j]for j in range(3))+transform[i][3]for i in range(3)]for v in ids]
            if not boundary_match(points,low,high,1e-5) or not all(min(abs(v[i]-low[i]),abs(v[i]-high[i]))<=1e-5 for v in points for i in range(3)):continue
            residual=max(residual,max(min(abs(v[i]-low[i]),abs(v[i]-high[i]))for v in points for i in range(3)))
            selected.append(dict(node_index=node,primitive_index=pi,canonical_triangle_index=ti,canonical_vertex_indices=ids))
    require(len(selected)==12,'actual closed stock receiver absent/ambiguous: '+stock['name'])
    return dict(asset_frame_transform=transform,expected_asset_low=low,expected_asset_high=high,expected_triangles=12,canonical_faces=selected,maximum_native_corner_identity_residual_m=residual)


def build(root=ROOT, inputs=None):
    root=Path(root);data=load_inputs(root) if inputs is None else copy.deepcopy(inputs);bindings={}
    def bind(name,kind='lf',expected=None):
        path=root/name
        require(path.resolve().is_relative_to(root.resolve()) and path.is_file(),'missing successor/source input: '+name)
        value=sha(path,kind=='lf')
        require(expected is None or value==expected,'source binding changed: '+name)
        row=dict(kind=kind,sha256=value)
        require(name not in bindings or bindings[name]==row,'conflicting source binding')
        bindings[name]=row
        return value
    for name in FILES.values():bind(name)
    for name in ('tools/prepare_arcade_rebuild_succession.py',
                 'tools/prepare_arcade_door_frames.py','tools/prepare_arcade_door_intake.py'):
        bind(name)
    bind(BUILDER)
    native=data['native'];contract=data['contract'];shell=data['shell'];plan=data['plan']
    for name,row in native['source_bindings'].items():bind(name,row['kind'],row['sha256'])
    require(contract['source_plan_sha256_lf']==bind(FILES['plan']),'shell source plan differs')
    require(contract['asset_sha256']==shell['asset_sha256'],'shell native receipt differs')
    shell_asset='game/'+shell['asset'][6:];bind(shell_asset,'raw',shell['asset_sha256']);shell_glb=NativeGLB(root/shell_asset)
    require(data['frames']==doors.build(root),'door frame contract altered/stale')
    require(data['leaf_runtime']==leaves.build(root,data['leaf_proof'],verify_source_bindings=False),'leaf runtime/proof differs')
    leaf_source_drift=[]
    for name,row in data['leaf_proof']['source_bindings'].items():
        actual=bind(name,row['kind'])
        if actual!=row['sha256']:
            require(name=='game/data/runtime_material_sets.json','original leaf producer source changed: '+name)
            leaf_source_drift.append(dict(path=name,kind=row['kind'],original_proof_sha256=row['sha256'],actual_sha256=actual,
                                          scope='Original broad native proof remains drifted; role mapping only, no repin or renewed material/native acceptance.'))
    catalog=data['catalog']['materials']
    require(all(key in catalog for key in LEAF_CATALOG_KEYS),'current leaf material receiver absent')
    require(data['leaf_proof']['source_bindings']['game/data/runtime_material_sets.json']['sha256']==ORIGINAL_LEAF_CATALOG_SHA256_LF,'original leaf catalog provenance changed')
    scoped_catalog={key:catalog[key]for key in LEAF_CATALOG_KEYS}
    scoped_hash=hashlib.sha256(json.dumps(scoped_catalog,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
    require(scoped_hash==ORIGINAL_LEAF_CATALOG_SCOPE_SHA256,'actual three leaf catalog records changed from producer-bound original')
    texture_bindings={}
    for record in scoped_catalog.values():
        for file in record['files']:
            name='game/assets/building/textures/'+file
            require(name in data['leaf_proof']['source_bindings'],'original leaf texture source binding absent')
            old=data['leaf_proof']['source_bindings'][name];require(old['kind']=='raw','original leaf texture raw convention changed')
            bind(name,'raw',old['sha256']);texture_bindings[name]=old
    require(len(texture_bindings)==9,'exact nine original leaf texture bytes required')
    leaf_asset='game/'+data['leaf_runtime']['asset'][6:];bind(leaf_asset,'raw',data['leaf_runtime']['asset_sha256'])
    stocks={r['name']:r for r in contract['closed_stocks']};require(len(stocks)==len(contract['closed_stocks']),'duplicate concrete stock receiver')
    draws={r['name']:r for r in shell['native_parts']};require(len(draws)==len(shell['native_parts']),'duplicate concrete shell draw')
    materials={r['id']:r for r in shell['materials']};require(len(materials)==len(shell['materials']),'duplicate successor material identity')
    fabrication=json.loads((root/'game/data/building_layout.json').read_text(encoding='utf-8'));records={r['id']:r for f in fabrication['floors']if f['id']=='F01'for r in f['furniture']}
    expected=expected_stocks(root,plan)
    # Every relevant concrete stock is required individually; deleting one pane
    # cannot turn into a smaller wildcard mapping with a nonempty remainder.
    for row in expected:
        require(row['name'] in stocks,'missing concrete successor stock: '+row['name'])
        actual=stocks[row['name']]
        require(all(actual[k]==row[k] for k in ('name','owner','material')),'successor owner/material changed: '+row['name'])
        require(max(abs(a-b) for a,b in zip(actual['plan_rect_m']+[actual['bottom_m'],actual['top_m']],row['plan_rect_m']+[row['bottom_m'],row['top_m']]))<=1e-10,'successor stock frame changed: '+row['name'])
    expected_by_name={r['name']:r for r in expected};shops={s['id']:s for s in plan['shops']}
    require(len(shops)==11,'eleven shop owners required')
    frames={(r['cell'],r['frame_kind']):r for r in data['frames']['frames']};require(len(frames)==22,'22 unique door frame owners required')
    leafparts={r['name']:r for r in data['leaf_runtime']['parts']}
    require(data['curtain_runtime']==curtains.build(root,data['curtain_proof']),'darkroom curtain runtime/native proof differs')
    for name,row in data['curtain_proof']['source_bindings'].items():bind(name,row['kind'],row['sha256'])
    curtain=data['curtain_runtime'];curtain_proof=data['curtain_proof']
    bind('game/'+curtain['asset'][6:],'raw',curtain['asset_sha256'])
    bind('game/'+curtain['asset'][6:]+'.import','lf',curtain['import_sha256_lf'])
    for path in ('tools/prepare_arcade_darkroom_curtain_intake.py','game/scripts/building/orison_v2_arcade_shop_door.gd','game/scripts/building/orison_v2_arcade_darkroom_curtain.gd','game/scripts/props/door_prop.gd'):bind(path)
    door_text=(root/'game/scripts/building/orison_v2_arcade_shop_door.gd').read_text(encoding='utf-8')
    selection=re.search(r'door\.set\("curtained", frame\.cell == "([^"]+)" and frame\.frame_kind == "([^"]+)"\)',door_text)
    require(selection is not None and selection.groups()==('shop_photo_supplies','stock_single'),'darkroom selector owner/role changed')
    require('extends DoorProp' in door_text and 'if curtained and identity == "LeftGlass": continue' in door_text and 'res://scripts/building/orison_v2_arcade_darkroom_curtain.gd' in door_text and '_body.add_child(cloth)' in door_text,'darkroom leaf/opaque infill selection seam changed')
    curtain_frame=frames[('shop_photo_supplies','stock_single')]
    require(not curtain_frame['paired'] and curtain_frame['width']==1.0 and curtain_frame['height']==2.3,'darkroom single leaf frame changed')
    selected_frames=[r['id']for r in data['frames']['frames']if r['cell']==selection.group(1) and r['frame_kind']==selection.group(2)]
    require(selected_frames==[curtain_frame['id']],'exact one Photo stock curtain owner required')

    all_rebuilds=[(c['cell'],r['model'],r['part_id'])for c in native['cells']for r in c.get('rebuild_entries',[])];require(len(set(all_rebuilds))==len(all_rebuilds),'duplicate source rebuild ID')
    require(all(model in set(MODELS)|{'CobblerFittings'}for _,model,_ in all_rebuilds),'unknown rebuild source model')
    require(collections.Counter(model for _,model,_ in all_rebuilds)==dict(MODELS,CobblerFittings=2),'exact82 architectural/darkroom cohort plus two excluded sources required')
    mappings=[];seen=set();counts=collections.Counter();cache={};stock_witnesses={}
    for cell_doc in native['cells']:
        cell=cell_doc['cell'];require(cell in shops,'unknown source cell owner')
        for source in cell_doc.get('rebuild_entries',[]):
            model=source['model']
            if model not in MODELS:continue
            identity=source['part_id'];key=(cell,model,identity);require(key not in seen,'duplicate source rebuild ID');seen.add(key);counts[model]+=1
            owners=[m for m in cell_doc['mounts'] if m['name']==model]
            require(len(owners)==1 and owners[0]['wrapper']==WRAPPERS[model],'altered original wrapper owner')
            owner=owners[0];sidecar_name='game/'+owner['sidecar'][6:];wrapper_name='game/'+owner['wrapper'][6:]
            for path in (owner['sidecar'],owner['wrapper']):
                require(path in cell_doc['source_bindings'],'original owner binding missing')
                row=cell_doc['source_bindings'][path];bind('game/'+path[6:],row['kind'],row['sha256'])
            if sidecar_name not in cache:
                sidecar=json.loads((root/sidecar_name).read_text(encoding='utf-8'));asset=sidecar['asset'];require(asset in cell_doc['native_assets'],'source native asset binding missing');bind('game/'+asset[6:],'raw',cell_doc['native_assets'][asset]);cache[sidecar_name]=(sidecar,NativeGLB(resource(root,asset)))
            sidecar,original=cache[sidecar_name];owned=[c for c in sidecar['cells']if c['id']==cell];require(len(owned)==1,'original sidecar owner absent/duplicate');original_cell=owned[0]
            parts=[p for p in original_cell['parts']if p['name']==identity];require(len(parts)==1 and parts[0]==source['source_part'] and parts[0]['key']==source['material_key'],'original material/part identity changed')
            require(identity in original.names and original.transform(original.names[identity])==source['source_transform'],'original native frame changed')
            require(original.triangles(identity)==source['triangles'] and fingerprint(original,identity)==source['encoded_source'],'original native payload changed')
            prefix=cell+'_stock_partition';names=[];frame=None;leaf_names=[];role='';curtain_receiver=False;material_boundary='ROLE_ONLY: source and successor material identities retained separately; no material/art equivalence.'
            masks=original_cell.get('replace',[]);mask_ids=[];suffix=identity.rsplit('__',1)[1]
            if model=='ShopClerestories':
                require('_borrowed_sill__'in identity,'unknown original clerestory identity')
                if suffix=='glassish':
                    names=[n for n in expected_by_name if n.startswith(prefix+'_borrowed_pane_')];mask_ids=[m['id']for m in masks if m['key']=='glassish'];role='borrowed_light_glazing'
                elif suffix=='plaster_stained':
                    names=[n for n in expected_by_name if n.startswith(prefix+'_wall_')];mask_ids=[m['id']for m in masks if m['key']=='plaster_stained'];role='borrowed_light_partition_wall_mass'
                elif suffix=='trim':
                    names=[n for n in expected_by_name if n.startswith(prefix+'_borrowed_')and'_pane_'not in n];mask_ids=[m['id']for m in masks if m['key']=='trim'];role='borrowed_light_frame_and_mullions'
                else:require(False,'unknown clerestory material role')
                require(mask_ids and set(mask_ids).issubset(shops[cell]['frontage']['borrowed_light_source_ids']),'borrowed optical/source lineage absent')
            elif model=='PhotoGlazing':
                base=identity.split('__')[0];front=cell+'_'+shops[cell]['front'];profile=shops[cell]['frontage']
                if base=='storm_sf_photo_supplies_glass1':label='display';sources=profile['display_source_ids']
                elif base=='storm_sf_photo_supplies_transom':label='transom';sources=profile['transom_source_ids']
                elif base=='storm_shop_photo_supplies_borrowed_glass':label='borrowed';sources=profile['borrowed_light_source_ids'];front=prefix
                else:require(False,'unknown Photo glazing source')
                require(base in sources,'explicit Photo optical source successor absent');mask_ids=[base];names=[n for n in expected_by_name if n.startswith(front+'_'+label+'_pane_')];role='photo_'+label+'_glazing'
            elif model=='PhotoRadioFittings':
                require(cell=='shop_photo_supplies' and identity=='storm_shop_photo_supplies_dr_door__'+suffix and suffix in ('fabric_warm','wood_dark','iron_blackened'),'unknown original darkroom source/owner')
                frame=curtain_frame
                if suffix=='fabric_warm':
                    curtain_receiver=True;role='darkroom_original_cloth_to_opaque_moving_infill'
                elif suffix=='wood_dark':
                    leaf_names=['LeftWood'];names=[prefix+'_door_'+part for part in ('left','right','head')];mask_ids=['storm_shop_photo_supplies_dr_door'];role='darkroom_original_wood_to_moving_leaf_and_stock_casing'
                else:
                    leaf_names=['LeftBrass','LeftFixedBrass'];role='darkroom_original_fixed_fingerplate_to_operating_leaf_and_fixed_hardware'
            elif '_boh_door__'in identity:
                frame=frames[(cell,'stock_single')];require(not frame['paired']and frame['width']==1.0,'stock door owner/frame altered')
                if suffix=='brass_dull':leaf_names=['LeftBrass'];mask_ids=[m['id']for m in masks if m['id'].endswith('_boh_knob')];role='stock_door_pull_hardware'
                elif suffix=='iron_blackened':leaf_names=['LeftFixedBrass'];role='stock_door_fixed_hinge_hardware'
                elif suffix=='wood_dark':leaf_names=['LeftWood'];mask_ids=[m['id']for m in masks if m['id'].endswith('_boh_door')];role='stock_door_moving_wood_leaf'
                else:require(False,'unknown backdoor material role')
            elif '_jamb_w__'in identity:
                frame=frames[(cell,'front_pair')];require(frame['paired']and frame['width']==2.0,'front door owner/frame altered');front=cell+'_'+shops[cell]['front'];names=[front+'_door_'+s for s in ('left','right','head')];mask_ids=[m['id']for m in masks if m['id'].endswith(('_jamb_w','_jamb_e','_doorhead'))];require(len(mask_ids)==3,'original front jamb mask incomplete');role='front_operating_pair_frame'
            else:require(False,'unmapped architectural source role: '+identity)
            require(names or leaf_names or curtain_receiver,'no real successor for '+identity)
            receivers=[]
            for name in names:
                require(name in expected_by_name and name in stocks,'unknown/missing concrete successor: '+name);stock=stocks[name];require(stock['owner']==cell,'successor stock belongs to another owner');matches=[r for r in shell['native_parts']if r['owner']==cell and r['material']==stock['material']];require(len(matches)==1,'successor native material draw missing/ambiguous');draw=matches[0]
                require(draw['name']in shell_glb.names and shell_glb.triangles(draw['name'])==draw['triangles'],'actual successor native draw absent/changed')
                if name not in stock_witnesses:stock_witnesses[name]=native_stock_witness(shell_glb,draw,stock,plan['source_origin_blender_m'])
                receivers.append(dict(kind='shell_closed_stock',stock=stock,native_draw=draw,native_stock_witness=stock_witnesses[name],material=materials[stock['material']],asset=shell['asset']))
            for name in leaf_names:
                require(name in leafparts,'missing concrete leaf receiver: '+name);receivers.append(dict(kind='operating_door_draw',door_frame_id=frame['id'],draw=leafparts[name],asset=data['leaf_runtime']['asset']))
            if curtain_receiver:
                receivers.append(dict(kind='darkroom_native_draw',door_frame_id=frame['id'],draw=curtain_proof['parts'][0],stocks=curtain_proof['stocks'],material=curtain_proof['material'],asset=curtain['asset'],
                                      runtime_intake=curtain,selector_class='res://scripts/building/orison_v2_arcade_shop_door.gd',selector_method='from_frame',helper='res://scripts/building/orison_v2_arcade_darkroom_curtain.gd'))
            original_masks=[m for m in masks if m['id']in mask_ids];require(len(original_masks)==len(mask_ids),'unknown original source mask')
            mask_sources=[]
            for mask in masks:
                require(mask['id']in records,'literal original mask source absent')
                record=records[mask['id']];low,high=raw_bounds(record)
                require(mask['key']==record['mat']and max(abs(a-b)for a,b in zip(low+high,mask['low']+mask['high']))<=1e-10,'original mask/source material/frame mismatch')
                mask_sources.append(dict(mask=copy.deepcopy(mask),source_record=copy.deepcopy(record)))
            mappings.append(dict(cell=cell,model=model,source_part_id=identity,source_part=source,original_owner=owner,
                                 original_sidecar=owner['sidecar'],original_wrapper=owner['wrapper'],
                                 original_family_masks=copy.deepcopy(masks),original_mask_source_records=mask_sources,specific_source_masks=original_masks,
                                 source_mask_scope='Literal family masks retained; selected role masks do not authorize wholesale donor retirement.',
                                 native_added_hardware_without_separate_literal_mask=(role=='stock_door_fixed_hinge_hardware'),
                                 role=role,door_frame=frame,successors=receivers,material_boundary=material_boundary))
    require(dict(counts)==MODELS and len(mappings)==82,'exact82 architectural/darkroom cohort required: '+str(dict(counts)))
    original79=[row for row in mappings if row['model']in ORIGINAL_MODELS]
    original79_hash=hashlib.sha256(json.dumps(original79,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()
    require(len(original79)==79 and original79_hash==ORIGINAL79_MAPPING_SHA256,'previous79 role mappings changed')
    for row in mappings:
        if row['model']=='PhotoRadioFittings':
            row['cohort']='ADDED_THREE_DARKROOM_ROLES'
            row['no_separate_literal_mask_for_native_attachment']=not bool(row['specific_source_masks'])
            row['material_boundary']+=' Original fixed fingerplate/cloth are not renamed literal fabrication masks; moving/opaque/hardware roles remain explicit.'
    return dict(schema_version=1,classification='ROLE_SUCCESSION_ONLY_NOT_DISPOSAL_INSTALLATION_RUNTIME_OR_ART_ACCEPTANCE',
                source_bindings=dict(sorted(bindings.items())),counts=dict(sources=82,previous_architectural_sources=79,added_darkroom_sources=3,by_model=dict(counts)),mappings=mappings,
                previous79_mapping_sha256=original79_hash,
                darkroom_selection=dict(owner='shop_photo_supplies',frame_kind='stock_single',door_frame=curtain_frame,selected_frame_ids=selected_frames,removed_draw='LeftGlass',added_draw='LeftDarkroomCurtain',class_source='res://scripts/building/orison_v2_arcade_shop_door.gd',factory_method='from_frame',helper='res://scripts/building/orison_v2_arcade_darkroom_curtain.gd',scope='Role/selection binding only, existing DoorProp owns movement/lock/save; no whole-region light exclusion/art acceptance.'),
                excluded_models=['CobblerFittings'],unmapped=[],
                original_leaf_producer_source_drift=leaf_source_drift,original_leaf_producer_bindings=data['leaf_proof']['source_bindings'],
                current_leaf_catalog_definitions=scoped_catalog,
                leaf_catalog_scope=dict(original_whole_catalog_sha256_lf=ORIGINAL_LEAF_CATALOG_SHA256_LF,original_scope_sha256=ORIGINAL_LEAF_CATALOG_SCOPE_SHA256,actual_scope_sha256=scoped_hash,
                                        original_catalog_revision='32c008163',canonical_projection='sorted-key compact JSON of the entire three material records',texture_bindings=texture_bindings,
                                        scope='Exact three-record and nine-texture reuse only; original broad catalog mismatch retained, no original proof repin.'),
                limits='Explicit stock/draw/frame roles only. All original masks/materials remain intact. Does not admit removal of original donor/source collision, save or optical owners; geometric-role correspondence is not material/art acceptance.')


def render(doc):return json.dumps(doc,indent=1,allow_nan=False)+'\n'


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--root',type=Path,default=ROOT);ap.add_argument('--check',action='store_true');args=ap.parse_args();text=render(build(args.root));target=args.root/FIXTURE
    if args.check:
        require(target.read_text(encoding='utf-8').replace('\r\n','\n')==text,'architectural succession fixture stale');print('ARCADE REBUILD SUCCESSION OK 82 exact source IDs (79 preserved +3 darkroom)')
    else:target.write_text(text,encoding='utf-8',newline='\n');print('WROTE '+str(FIXTURE))
    return 0


if __name__=='__main__':raise SystemExit(main())
