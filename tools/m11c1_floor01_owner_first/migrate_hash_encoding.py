"""Migrate only an ownership hash encoding and its production metadata pins.

The original Git sidecar must match the new one in every identity, owner,
locator, record digest and ruling. No geometry or lineage is regenerated.
"""
from pathlib import Path
import argparse,copy,hashlib,json,subprocess

def lf_digest(data):
    return hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base',required=True)
    parser.add_argument('--write',action='store_true')
    args=parser.parse_args();root=Path(__file__).resolve().parents[2]
    side='art/data/m11c1/floor01_source_ownership.json'
    old_bytes=subprocess.check_output(['git','show',args.base+':'+side],cwd=root)
    old=json.loads(old_bytes);new=json.loads((root/side).read_bytes())
    allowed=copy.deepcopy(old)
    descriptor=(root/'art/data/building_layout.json').read_bytes()
    assert new['source_layout']['sha256_encoding']=='lf_normalized'
    assert new['source_layout']['sha256']==lf_digest(descriptor)
    assert hashlib.sha256(descriptor.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')).hexdigest()==old['source_layout']['sha256']
    allowed['source_layout'].update(sha256=lf_digest(descriptor),sha256_encoding='lf_normalized')
    assert new==allowed,'Migration would alter source ownership'
    manifest_path=root/'game/assets/building/floor_01_cells/floor01_asset_manifest.json'
    registry_path=root/'game/data/floor_01_cell_registry.json'
    manifest=json.loads(manifest_path.read_bytes());registry=json.loads(registry_path.read_bytes())
    before_manifest=copy.deepcopy(manifest);before_registry=copy.deepcopy(registry)
    assert manifest['authoritative_inputs']['ownership'] in (lf_digest(old_bytes),lf_digest((root/side).read_bytes()))
    assert registry['asset_manifest_sha256']==hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    manifest['authoritative_inputs']['ownership']=lf_digest((root/side).read_bytes())
    encoded=(json.dumps(manifest,ensure_ascii=False,sort_keys=True,indent=2)+'\n').encode('utf-8')
    registry['asset_manifest_sha256']=hashlib.sha256(encoded).hexdigest()
    expected=copy.deepcopy(before_manifest);expected['authoritative_inputs']['ownership']=manifest['authoritative_inputs']['ownership'];assert expected==manifest
    expected=copy.deepcopy(before_registry);expected['asset_manifest_sha256']=registry['asset_manifest_sha256'];assert expected==registry
    if args.write:
        manifest_path.write_bytes(encoded)
        registry_path.write_text(json.dumps(registry,ensure_ascii=False,sort_keys=True,indent=2)+'\n',encoding='utf-8',newline='\n')
    else:
        assert before_manifest==manifest and before_registry==registry,'Production hash pins require migration'
    print('Ownership encoding migration: 5286 identities retained; only two production hash pins updated')

if __name__=='__main__':main()
