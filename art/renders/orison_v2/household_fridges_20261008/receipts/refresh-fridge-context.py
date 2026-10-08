"""Narrow INERT provenance proof for this batch's three refrigerator placements.

Run from the repository root. Existing asset/recipe/evidence content is preserved;
only dependency hashes advance after exact JSON and asset comparisons succeed.
"""
from pathlib import Path
import hashlib,json,subprocess,sys
r=Path.cwd();base='db2187c48ca8f6aab8109ad0fc203e55386b3097'
ids={'F01_1A_FRIDGE_01','F03_3D_FRIDGE_01','F04_4D_FRIDGE_01'}
def digest(data):return hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()
def old_bytes(path):return subprocess.check_output(['git','show',base+':'+path])
paths=['art/data/orison_v2/completion_interiors_source.json','game/data/orison_v2_blockout.json'];hashes={};changes=[]
for path in paths:
 before=old_bytes(path);after=(r/path).read_bytes();old=json.loads(before);new=json.loads(after)
 old_rows=old['records']['anchors'] if 'records' in old else old['anchors'];new_rows=new['records']['anchors'] if 'records' in new else new['anchors']
 assert len(old_rows)==len(new_rows)
 found=[]
 for left,right in zip(old_rows,new_rows):
  if left==right:continue
  assert left['id']==right['id'] and left['id'] in ids,(path,left,right)
  assert {k:v for k,v in left.items() if k not in ['position','yaw']}=={k:v for k,v in right.items() if k not in ['position','yaw']}
  assert left['position']==[-10.82,0,-8.8] and right['position']==[-8.62,0,-8.5]
  assert left['yaw']==-1.5707963267948966 and right['yaw']==1.5707963267948966
  found.append(left['id']);changes.append({'source':path,'before':left.copy(),'after':right.copy()});right.clear();right.update(left)
 assert set(found)==ids and new==old,(path,'unrelated source modification')
 hashes[path]=(digest(before),digest(after))
documents={};original={};pending=[];updates=[];serialized={};active=set()
for folder,pattern in [('game/tests/fixtures','orison_*.json'),('art/blender','*_construction.json')]:
 for p in sorted((r/folder).glob(pattern)):
  data=json.loads(p.read_text(encoding='utf-8'))
  if isinstance(data,dict) and data.get('source_bindings'):
   path=p.relative_to(r).as_posix();documents[path]=data;original[path]=p.read_bytes()
def resolve(path):
 if path in serialized:return serialized[path]
 assert path not in active;active.add(path);data=documents[path];changed=[]
 for literal,expected in data['source_bindings'].items():
  rel=literal.replace('\\','/');new_hash=None;allowed=set()
  if rel in hashes:
   old_hash,new_hash=hashes[rel];allowed.add(old_hash)
  elif rel in documents:
   updated=resolve(rel);new_hash=digest(updated)
   assert {k:v for k,v in json.loads(original[rel]).items() if k!='source_bindings'}=={k:v for k,v in json.loads(updated).items() if k!='source_bindings'}
   allowed.add(digest(original[rel]))
  if new_hash is None or expected==new_hash:continue
  assert expected in allowed,('unrelated drift',path,literal)
  data['source_bindings'][literal]=new_hash;changed.append(literal)
 if changed:
  asset=data.get('runtime',{}).get('asset')
  if asset and data.get('asset_sha256'):
   disk=r/'game'/asset.removeprefix('res://');assert hashlib.sha256(disk.read_bytes()).hexdigest()==data['asset_sha256'],(path,'asset changed')
  # Any family that owns a moved actor must be freshly inspected, never
  # certified by this provenance-only path. The new fridge family is fresh.
  owned={row.get('id') for row in data.get('runtime',{}).get('instances',[])}
  assert not owned&ids or 'household_fridges' in path,(path,'moved actor requires fresh QA')
  encoded=(json.dumps(data,indent=2)+'\n').encode();pending.append((r/path,encoded));updates.append({'path':path,'before':digest(original[path]),'after':digest(encoded),'bindings_only':changed,'asset_sha256_unchanged':data.get('asset_sha256')})
 else:encoded=original[path]
 serialized[path]=encoded;active.remove(path);return encoded
for path in documents:resolve(path)
if '--apply' in sys.argv:
 for p,encoded in pending:p.write_bytes(encoded)
report={'evidence_class':'INERT','base':base,'applied':'--apply' in sys.argv,'exact_source_changes':changes,'updates':updates,'scope':'Exactly three V2 refrigerator positions/yaws; every other source record is identical. Existing geometry and evidence unchanged. Fresh refrigerator context checks independently cover all surrounding native furniture and relocated stove service envelopes. Existing visual acceptance is not renewed.'}
(r/'tmp/v2-finish-review/fridges-context-reuse.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print(len(updates),'provenance-only documents; applied=',report['applied'])
