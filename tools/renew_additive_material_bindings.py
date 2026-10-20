"""Renew native construction bindings after a strictly additive material change.

Does not touch runtime contracts. All old material records and other manifest
fields must match, every other construction dependency must still match, and
the exported geometry must match its recorded digest. Archives original records.
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


def renew(root, previous_path, archive):
    root=root.resolve(); archive=archive.resolve()
    previous_raw=previous_path.read_bytes().replace(b'\r\n', b'\n')
    current_raw=(root/MANIFEST).read_bytes().replace(b'\r\n', b'\n')
    added=additions(json.loads(previous_raw),json.loads(current_raw))
    old_hash=digest(previous_raw);new_hash=digest(current_raw)
    records={};assets={}
    for family in FAMILIES:
        for name in (f'art/blender/{family}_construction.json',
                     f'game/tests/fixtures/orison_{family}.json'):
            data=json.loads((root/name).read_text(encoding='utf8'))
            if data['source_bindings'].get(MANIFEST)!=old_hash:
                raise ValueError('Construction does not bind the supplied previous manifest: '+name)
            for reference, expected in data['source_bindings'].items():
                path=(root/reference).resolve()
                if not path.is_relative_to(root):raise ValueError('Escaping dependency: '+reference)
                if reference!=MANIFEST and file_digest(path)!=expected:
                    raise ValueError('Other native source changed: '+reference)
            if 'asset_sha256' in data:
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
    report={'evidence_class':'INERT','scope':'Additive catalogue construction renewal; no runtime acceptance',
            'previous_manifest_sha256':old_hash,'current_manifest_sha256':new_hash,
            'unchanged_materials':len(json.loads(previous_raw)['materials']),
            'added_keys':added,'unchanged_output_hashes':assets,
            'renewed_records':{name:digest(raw) for name,raw in encoded.items()}}
    (archive/'renewal.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8',newline='\n')
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--previous-manifest',type=Path,required=True)
    parser.add_argument('--archive',type=Path,required=True)
    args=parser.parse_args()
    report=renew(args.root,args.previous_manifest,args.archive)
    print(json.dumps({k:report[k] for k in ('unchanged_materials','added_keys','renewed_records')},indent=2))
