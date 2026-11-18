"""Revalidate the canonical all-shop equipment/disposition declarations.

No private studies are read. With --check, the embedded derived projection must
match current pinned public inputs exactly; otherwise write only that section.
This is source preparation, never an installer or physical acceptance test.
"""
from __future__ import annotations
import argparse
import collections
import hashlib
import itertools
import json
import math
from pathlib import Path
import struct
from prepare_arcade_native_projection import NativeGLB, matrix, mul, raw_bounds, require, sha

ROOT = Path(__file__).resolve().parents[1]
PLAN = Path('art/data/arcade_plaza/retained_equipment_placements.json')
SHARED_IDS = {'storm_sf_'+name+'_stall'+str(index) for name,index in [('funeral_parlour',0),('keys_cut',0),('news_cigars',1),('otis___son',0),('pawnbroker',0),('photo_supplies',1),('radio_service',0),('shoe_rebuilding',0)]}
ACTIONS = {
 'active_native_replacement','structural_shell_joinery_finish_rebuild',
 'retained_raw_stock_needing_native_rebuild_placement','unresolved','explicit_retired_cabinet_or_stool',
 'RETIRED_EXACT_ACTIVE_NATIVE_MASK','REBUILD_NEW_SHELL_OR_FRONTAGE',
 'KEEP_ORIGINAL_SOURCE_STOCK_RIGID_CANDIDATE','REBUILD_GLAZING_WITH_EXPLICIT_SOURCE_OPTICAL_OWNERSHIP',
 'RETIRED_DISABLED_ARCADE_CABINET','RETIRED_EXACT_NATIVE_REPLACEMENT_BOUNDARY',
 'REBUILD_GLAZING_WITH_EXPLICIT_OLD_OWNER_GUARDS','REBUILD_HEADER_FOR_NEW_CLEARANCE',
 'REBUILD_GLAZING_WITH_EXPLICIT_SOURCE_OPTICAL_GUARDS','RETIRED_EXPLICIT_SEATING_PROGRAMME_REMOVAL',
 'UNRESOLVED_SEMANTIC_MARKER_OVERLAY'}

def path(root, name):
    require(isinstance(name,str) and not Path(name).is_absolute() and '..' not in Path(name).parts, 'repository-relative source required')
    result = (root/name).resolve()
    require(result.is_relative_to(root.resolve()), 'source escapes repository')
    return result

def normalized_record_hash(collection, record):
    payload = dict(schema='orison.floor01.source-record',schema_version=1,floor_id='F01',collection=collection,record=record)
    return hashlib.sha256(json.dumps(payload,sort_keys=True,ensure_ascii=False,separators=(',',':'),allow_nan=False).encode()).hexdigest()

def fingerprint(native, name):
    result = []
    for primitive in native.doc['meshes'][native.doc['nodes'][native.names[name]]['mesh']]['primitives']:
        bindings = {}
        for key, index in dict(primitive['attributes'],INDICES=primitive['indices']).items():
            a = native.doc['accessors'][index]
            require(not a.get('sparse'), 'sparse native fingerprint unsupported')
            v = native.doc['bufferViews'][a['bufferView']]
            width = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
            size = width*{5126:4,5125:4,5123:2,5122:2,5121:1,5120:1}[a['componentType']]
            offset = v.get('byteOffset',0)+a.get('byteOffset',0)
            stride = v.get('byteStride',size)
            encoded = b''.join(native.binary[offset+i*stride:offset+i*stride+size] for i in range(a['count']))
            bindings[key] = dict(component_type=a['componentType'],type=a['type'],count=a['count'],normalized=a.get('normalized',False),sha256=hashlib.sha256(encoded).hexdigest())
        material = native.doc.get('materials',[])[primitive['material']] if 'material' in primitive else None
        result.append(dict(attributes=bindings,material=material,mode=primitive.get('mode',4)))
    return result

def context(root, doc):
    for key in ('plaza_plan','fabrication','ownership','diner_plan'):
        require(doc[key] in doc['source_bindings'] and doc['source_bindings'][doc[key]]['kind']=='lf', 'unbound primary source')
    for source, binding in doc['source_bindings'].items():
        require(binding['kind'] in ('lf','raw'), 'unknown source binding kind')
        require(sha(path(root,source),binding['kind']=='lf')==binding['sha256'], 'source binding changed: '+source)
    plaza = json.loads(path(root,doc['plaza_plan']).read_text(encoding='utf-8'))
    fabrication = json.loads(path(root,doc['fabrication']).read_text(encoding='utf-8'))
    floor = next(f for f in fabrication['floors'] if f['id']=='F01')
    records = {}
    for collection in ('furniture','markers'):
        for record in floor[collection]:
            key = (collection,record['id'])
            require(key not in records, 'duplicate fabrication source identity')
            records[key] = record
    owner = json.loads(path(root,doc['ownership']).read_text(encoding='utf-8'))
    ownership = {(r['collection'],r['source_id']):r for r in owner['records']}
    require(len(ownership)==len(owner['records']), 'duplicate ownership source identity')
    cells = {s['id'] for s in plaza['shops']}
    families = {}
    for family in doc['families']:
        name = family['name']
        require(name not in families, 'duplicate native family')
        require(sha(path(root,family['asset']))==family['asset_sha256'], 'native payload changed: '+name)
        require(sha(path(root,family['sidecar']),True)==family['sidecar_sha256_lf'], 'native sidecar changed: '+name)
        data = json.loads(path(root,family['sidecar']).read_text(encoding='utf-8'))
        require(data['asset']=='res://'+family['asset'].removeprefix('game/'), 'family asset reference changed')
        parts, masks, labels = {}, {}, {}
        for cell in data['cells']:
            if cell['id'] not in cells:
                continue
            for part in cell['parts']:
                key = (cell['id'],part['name'])
                require(key not in parts, 'duplicate sidecar part')
                parts[key] = part
            masks[cell['id']] = cell.get('replace',[])
            labels[cell['id']] = cell.get('labels',[])
        families[name] = dict(declaration=family,native=NativeGLB(path(root,family['asset'])),parts=parts,masks=masks,labels=labels)
    diner = json.loads(path(root,doc['diner_plan']).read_text(encoding='utf-8'))
    return dict(cells=cells,records=records,ownership=ownership,families=families,diner=diner)

def diner_groups(diner):
    models = {m['name']:Path(m['asset']).stem for m in diner['models']}
    out = []
    for g in diner['groups']:
        out.append(dict(id=g['name'],cell='shop_luncheonette',delta_transform=g['delta_transform'],native_assemblies=[dict(id=a['id'],family=models[a['model']],parts=[dict(id=p['part_id'],target_transform=p['target_transform']) for p in a['parts']]) for a in g['assemblies']],raw_stocks=[]))
    for identity in sorted({r['group'] for r in diner['raw_stocks']}):
        rows = [r for r in diner['raw_stocks'] if r['group']==identity]
        require(all(r['delta_transform']==rows[0]['delta_transform'] for r in rows), 'Diner raw group changed internally')
        out.append(dict(id=identity,cell='shop_luncheonette',delta_transform=rows[0]['delta_transform'],native_assemblies=[],raw_stocks=[dict(id=r['id'],source_record=r['source_record'],source_low=r['source_low'],source_high=r['source_high'],target_low=r['target_low'],target_high=r['target_high']) for r in rows]))
    return out

def validate_dispositions(doc, ctx):
    expected = {key for key,row in ctx['ownership'].items() if row['owner_cell'] in {'CELL_'+c.upper() for c in ctx['cells']}}
    seen, counts = set(), collections.Counter()
    for row in doc['source_dispositions']:
        key = (row['collection'],row['id'])
        require(key not in seen, 'duplicate source disposition')
        seen.add(key)
        require(key in ctx['records'] and key in ctx['ownership'], 'foreign source disposition')
        require(row['cell'] in ctx['cells'], 'foreign disposition target cell')
        require(row['source_record']==ctx['records'][key], 'literal source disposition changed: '+row['id'])
        require(row['record_sha256']==normalized_record_hash(row['collection'],row['source_record']), 'source record hash changed')
        require(row['owner_cell']==ctx['ownership'][key]['owner_cell'], 'source owner changed')
        require(row['record_sha256']==ctx['ownership'][key]['source_record_sha256'], 'ownership manifest hash mismatch')
        require(row['action'] in ACTIONS, 'unknown disposition action')
        shared = row['owner_cell'] not in {'CELL_'+c.upper() for c in ctx['cells']}
        require(row['affected_shared_source']==shared, 'shared source custody misclassified')
        if shared:
            require(row['action'].startswith('REBUILD_'), 'shared source cannot be retired')
        for mask in row['native_masks']:
            require(mask['family'] in ctx['families'], 'foreign source mask family')
            require(mask['record'] in ctx['families'][mask['family']]['masks'].get(row['cell'],[]), 'exact native replacement boundary changed')
        counts[row['action']] += 1
    require(expected<=seen, 'missing owned source dispositions')
    require({tuple(k) for k in doc['affected_shared_source_ids']}=={('furniture',identity) for identity in SHARED_IDS}, 'explicit shared frontage inventory changed')
    require(seen-expected=={tuple(k) for k in doc['affected_shared_source_ids']}, 'shared source inventory changed')
    return counts

def projected_bounds(delta, low, high):
    ps = [[sum(delta[i][j]*p[j] for j in range(3))+delta[i][3] for i in range(3)] for p in itertools.product(*zip(low,high))]
    return [min(p[i] for p in ps) for i in range(3)], [max(p[i] for p in ps) for i in range(3)]

def project(doc, ctx):
    require(set(doc['cells'])==ctx['cells'] and len(doc['cells'])==len(ctx['cells'])==11, 'eleven exact cells required')
    dispositions = validate_dispositions(doc,ctx)
    lane_ids = set()
    for lane in doc['selected_lane_reservations']:
        key = (lane['cell'],lane['id'])
        require(lane['cell'] in ctx['cells'] and key not in lane_ids, 'duplicate or foreign lane reservation')
        lane_ids.add(key)
        r = lane['rect_shop_uv']
        require(isinstance(r,list) and len(r)==4 and all(type(v) in (int,float) and math.isfinite(v) for v in r) and r[2]>r[0] and r[3]>r[1], 'invalid lane reservation')
    require(all(g['cell']!='shop_luncheonette' for g in doc['groups']), 'Diner declarations must come from canonical Diner plan')
    groups = doc['groups']+diner_groups(ctx['diner'])
    seen_groups, seen_native, seen_assemblies, seen_raw = set(), set(), set(), set()
    native_entries, raw_entries = [], []
    all_dispositions = {(r['collection'],r['id']):r for r in doc['source_dispositions']}
    for group in groups:
        key = (group['cell'],group['id'])
        require(key not in seen_groups and group['cell'] in ctx['cells'], 'duplicate or foreign placement group')
        seen_groups.add(key)
        require(bool(group['native_assemblies'] or group['raw_stocks']), 'empty placement group')
        delta = matrix(group['delta_transform'],rigid=True)
        for assembly in group['native_assemblies']:
            require(assembly['id'] not in seen_assemblies, 'duplicate native assembly')
            seen_assemblies.add(assembly['id'])
            require(bool(assembly['parts']), 'empty native assembly')
            require(assembly['family'] in ctx['families'], 'foreign native family')
            family = ctx['families'][assembly['family']]
            for part in assembly['parts']:
                identity = (group['cell'],assembly['family'],part['id'])
                require(identity not in seen_native, 'duplicate placed native part')
                seen_native.add(identity)
                source_key = (group['cell'],part['id'])
                require(source_key in family['parts'], 'foreign native part')
                native = family['native']
                require(part['id'] in native.names and part['id'].startswith(assembly['id']+'__'), 'wrong native assembly identity')
                source = native.transform(native.names[part['id']])
                target = matrix(part['target_transform'])
                computed = mul(delta,source)
                require(max(abs(target[i][j]-computed[i][j]) for i in range(4) for j in range(4))<=1e-10, 'native target differs from delta * current source')
                if 'source_transform' in part:
                    require(part['source_transform']==source, 'native source frame changed')
                cache = family.setdefault('fingerprints',{})
                if part['id'] not in cache:
                    cache[part['id']] = fingerprint(native,part['id'])
                actual_fingerprint = cache[part['id']]
                counts = family.setdefault('triangle_counts',{})
                if part['id'] not in counts:
                    counts[part['id']] = native.triangles(part['id'])
                if 'encoded_source' in part:
                    require(part['encoded_source']==actual_fingerprint, 'encoded native attributes changed')
                native_entries.append(dict(cell=group['cell'],group=group['id'],assembly=assembly['id'],family=assembly['family'],part=part['id'],material_record=family['parts'][source_key],source_transform=source,delta_transform=delta,target_transform=target,triangles=counts[part['id']],encoded_source=actual_fingerprint))
        for stock in group['raw_stocks']:
            require(stock['id'] not in seen_raw, 'duplicate retained raw stock')
            seen_raw.add(stock['id'])
            key = ('furniture',stock['id'])
            require(key in all_dispositions and stock['source_record']==ctx['records'][key], 'raw stock record changed')
            require(all_dispositions[key]['action'] in ('retained_raw_stock_needing_native_rebuild_placement','KEEP_ORIGINAL_SOURCE_STOCK_RIGID_CANDIDATE'), 'raw stock has wrong disposition')
            low,high = raw_bounds(stock['source_record'])
            require(stock['source_low']==low and stock['source_high']==high, 'false retained raw bounds')
            for bound in (stock['target_low'],stock['target_high']):
                require(isinstance(bound,list) and len(bound)==3 and all(type(x) in (int,float) and math.isfinite(x) for x in bound), 'nonfinite raw target bounds')
            target_low,target_high = projected_bounds(delta,low,high)
            require(max(abs(a-b) for a,b in zip(target_low+target_high,stock['target_low']+stock['target_high']))<=1e-10, 'raw target bounds differ from rigid source')
            raw_entries.append(dict(cell=group['cell'],group=group['id'],id=stock['id'],source_record_sha256=normalized_record_hash('furniture',stock['source_record']),source_low=low,source_high=high,delta_transform=delta,target_low=stock['target_low'],target_high=stock['target_high']))
    expected_raw = {r['id'] for r in doc['source_dispositions'] if r['action'] in ('retained_raw_stock_needing_native_rebuild_placement','KEEP_ORIGINAL_SOURCE_STOCK_RIGID_CANDIDATE')}
    require(seen_raw==expected_raw, 'retained raw stock inventory incomplete')
    rebuild_seen = set()
    for row in doc['native_rebuild_parts']:
        key = (row['cell'],row['family'],row['part'])
        require(key not in rebuild_seen and key not in seen_native, 'duplicate or placed rebuild part')
        rebuild_seen.add(key)
        require(row['family'] in ctx['families'], 'foreign rebuild family')
        family = ctx['families'][row['family']]
        require((row['cell'],row['part']) in family['parts'], 'foreign native rebuild part')
        require(row['source_part']==family['parts'][(row['cell'],row['part'])], 'native rebuild material record changed')
        require(row['source_transform']==family['native'].transform(family['native'].names[row['part']]), 'native rebuild source frame changed')
    expected = {(cell,name,part) for name,f in ctx['families'].items() for cell,part in f['parts']}
    require(seen_native | rebuild_seen==expected, 'native parts missing disposition')
    expected_labels = {(cell,name,label['id']) for name,f in ctx['families'].items() for cell,labels in f['labels'].items() for label in labels}
    seen_labels = set()
    for row in doc['label_dispositions']:
        key = (row['cell'],row['family'],row['id'])
        require(key not in seen_labels and key in expected_labels, 'duplicate or foreign label disposition')
        seen_labels.add(key)
        actual = next(l for l in ctx['families'][row['family']]['labels'][row['cell']] if l['id']==row['id'])
        require(row['source_label']==actual, 'source label text/resources changed')
        expected_action = 'CANONICAL_DINER_PROJECTION' if row['cell']=='shop_luncheonette' and row['family']=='diner_overhead' else 'UNRESOLVED_LABEL_OWNER_PROJECTION'
        require(row['action']==expected_action, 'unknown or false resolved label disposition')
    require(seen_labels==expected_labels, 'labels missing disposition')
    return dict(status='SOURCE_PLACEMENT_AND_DISPOSITION_ONLY',counts=dict(cells=11,groups=len(groups),native_assemblies=len(seen_assemblies),placed_native_parts=len(seen_native),native_rebuild_parts=len(rebuild_seen),retained_raw_stocks=len(seen_raw),source_dispositions=len(doc['source_dispositions']),affected_shared_sources=len(doc['affected_shared_source_ids']),native_families=len(ctx['families']),labels=len(seen_labels),selected_lane_reservations=len(lane_ids)),source_disposition_counts=dict(sorted(dispositions.items())),native_entries=native_entries,raw_entries=raw_entries)

def render(doc):return json.dumps(doc,indent=1,allow_nan=False)+'\n'

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root',type=Path,default=ROOT)
    ap.add_argument('--check',action='store_true')
    args=ap.parse_args()
    target=args.root/PLAN
    doc=json.loads(target.read_text(encoding='utf-8'))
    require(doc.get('schema_version')==1, 'unknown placement schema')
    derived=project(doc,context(args.root,doc))
    if args.check:
        require(doc.get('projection')==derived, 'retained equipment projection stale')
        require(target.read_text(encoding='utf-8').replace('\r\n','\n')==render(doc), 'canonical placement serialization stale')
        print('ARCADE RETAINED EQUIPMENT OK '+json.dumps(derived['counts'],sort_keys=True))
    else:
        doc['projection']=derived
        target.write_text(render(doc),encoding='utf-8',newline='\n')
        print('WROTE '+str(PLAN)+' '+json.dumps(derived['counts'],sort_keys=True))
    return 0

if __name__=='__main__':raise SystemExit(main())
