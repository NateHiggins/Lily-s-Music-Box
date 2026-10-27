"""Renew five scoped native families after additive or unused material changes.

Does not touch runtime contracts. Additive mode preserves all old materials;
named replacements must be absent from each scoped construction record.
All other dependencies and exported output hashes must match. Archives originals.
"""
import argparse, copy, gzip, hashlib, json
from pathlib import Path

MANIFEST = 'game/data/runtime_material_sets.json'
FAMILIES = ('city_closure', 'city_elevations', 'city_ground_apron',
            'city_horizon', 'street_paving_details')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def file_digest(path):
    raw = path.read_bytes()
    if path.suffix in {'.json', '.py', '.gd'}:
        raw = raw.replace(b'\r\n', b'\n')
    return digest(raw)


def additions(previous, current):
    old = previous['materials']; new = current['materials']
    if {k:v for k,v in previous.items() if k!='materials'} != {k:v for k,v in current.items() if k!='materials'}:
        raise ValueError('Non-material manifest fields changed')
    if any(new.get(key)!=value for key,value in old.items()):
        raise ValueError('Existing material changed or disappeared; rebuild its native family')
    added = sorted(set(new)-set(old))
    if not added:
        raise ValueError('No additive material change')
    return added


def unused_replacements(previous, current, keys):
    """A named replacement may affect no stock in the five scoped families."""
    if not keys or any(not isinstance(key,str) or not key for key in keys) or len(keys)!=len(set(keys)):
        raise ValueError('Supply distinct replaced material keys')
    old=previous['materials'];new=current['materials']
    if set(old)!=set(new) or {k:v for k,v in previous.items() if k!='materials'}!={k:v for k,v in current.items() if k!='materials'}:
        raise ValueError('Replacement must preserve all other manifest structure')
    changed={key for key in old if old[key]!=new[key]}
    if changed!=set(keys):raise ValueError('Replacement list does not exactly match changed records')
    return sorted(changed)


def renew(root, previous_path, archive, replaced_keys=(), families=FAMILIES):
    root=root.resolve(); archive=archive.resolve()
    previous_raw=previous_path.read_bytes().replace(b'\r\n', b'\n')
    current_raw=(root/MANIFEST).read_bytes().replace(b'\r\n', b'\n')
    previous=json.loads(previous_raw);current=json.loads(current_raw)
    replaced=unused_replacements(previous,current,replaced_keys) if replaced_keys else []
    added=[] if replaced else additions(previous,current)
    old_hash=digest(previous_raw);new_hash=digest(current_raw)
    records={};assets={}
    if not families or any(f not in (*FAMILIES,'house_switchboard','readable_library') for f in families):
        raise ValueError('Unknown or empty scoped family selection')
    for family in families:
        names=(f'art/blender/{family}_construction.json',) if family in ('house_switchboard','readable_library') else (
            f'art/blender/{family}_construction.json',f'game/tests/fixtures/orison_{family}.json')
        for name in names:
            data=json.loads((root/name).read_text(encoding='utf8'))
            # These five families enumerate their actual finishes/part keys in
            # construction. Refuse the entire record, including bound map paths,
            # if it mentions any replaced substance. A consuming family must
            # rebuild through its owning Blender producer instead.
            if any(key in json.dumps(data) for key in replaced):
                raise ValueError('Scoped native family consumes a replaced material: '+name)
            if data['source_bindings'].get(MANIFEST)!=old_hash:
                raise ValueError('Construction does not bind the supplied previous manifest: '+name)
            for reference, expected in data['source_bindings'].items():
                path=(root/reference).resolve()
                if not path.is_relative_to(root):raise ValueError('Escaping dependency: '+reference)
                if reference!=MANIFEST and file_digest(path)!=expected:
                    raise ValueError('Other native source changed: '+reference)
            if family=='house_switchboard':
                outputs={'game/assets/props/house_switchboard.glb':data['export']['sha256']}
            elif family=='readable_library':
                outputs=data['outputs']
            elif 'asset_sha256' in data:
                asset_family='city_shells' if family=='city_closure' else family
                outputs={f'game/assets/props/{asset_family}.glb':data['asset_sha256']}
            else:
                outputs={}
                for entry in data['assets'].values():
                    outputs[entry['asset']]=entry['sha256']
                    outputs[entry['native']]=entry['native_sha256']
            for reference, expected in outputs.items():
                path=(root/reference).resolve()
                if not path.is_relative_to(root) or file_digest(path)!=expected:
                    raise ValueError('Native output changed: '+reference)
                assets[reference]=expected
            records[name]=data
    encoded={}
    def encode(name, stack=()):
        if name in encoded:return encoded[name]
        if name in stack:raise ValueError('Cyclic construction bindings')
        data=copy.deepcopy(records[name])
        for reference in data['source_bindings']:
            if reference==MANIFEST:data['source_bindings'][reference]=new_hash
            elif reference in records:
                data['source_bindings'][reference]=digest(encode(reference,stack+(name,)))
        encoded[name]=(json.dumps(data,indent=2)+'\n').encode()
        return encoded[name]
    for name in records:encode(name)
    # Validate everything before the first write. Recheck immediately before
    # publishing, so an interrupted renewal never silently becomes new proof.
    originals={name:(root/name).read_bytes() for name in records}
    archive.mkdir(parents=True,exist_ok=False)
    (archive/'previous_runtime_material_sets.json').write_bytes(previous_raw)
    for name,raw in originals.items():
        target=archive/(name+'.gz');target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(gzip.compress(raw,mtime=0))
    for name,raw in originals.items():
        if (root/name).read_bytes()!=raw:raise ValueError('Concurrent construction change: '+name)
    for name,raw in encoded.items():(root/name).write_bytes(raw)
    report={'evidence_class':'INERT','scope':'Unused replacement construction renewal; no runtime acceptance' if replaced else 'Additive catalogue construction renewal; no runtime acceptance',
            'previous_manifest_sha256':old_hash,'current_manifest_sha256':new_hash,
            'unchanged_materials':len(previous['materials'])-len(replaced),
            'added_keys':added,'replaced_unused_keys':replaced,'unchanged_output_hashes':assets,
            'renewed_records':{name:digest(raw) for name,raw in encoded.items()}}
    (archive/'renewal.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8',newline='\n')
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--previous-manifest',type=Path,required=True)
    parser.add_argument('--archive',type=Path,required=True)
    parser.add_argument('--unused-replacement',action='append',default=[],help='Exact changed key, absent from every scoped native construction record; repeat per key')
    parser.add_argument('--family',choices=[*FAMILIES,'house_switchboard','readable_library'],action='append',help='Explicit known family; defaults to the five city families')
    args=parser.parse_args()
    report=renew(args.root,args.previous_manifest,args.archive,args.unused_replacement,args.family or FAMILIES)
    print(json.dumps({k:report[k] for k in ('unchanged_materials','added_keys','renewed_records')},indent=2))
