"""Exact oriented triangle/owner comparison; material review only, INERT."""
from pathlib import Path
import collections, hashlib, json, sys, subprocess, tempfile
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
BASE='64acefdf'
TEMP=tempfile.TemporaryDirectory()
BEFORE=Path(TEMP.name)
sys.path.insert(0,str(ROOT/'tools'))
from v2_physical_inputs import load_document, DTYPES, WIDTHS

def geometry(path):
 document,buffers,raw=load_document(path)
 def accessor(index):
  spec=document['accessors'][index];view=document['bufferViews'][spec['bufferView']]
  dtype=np.dtype(DTYPES[spec['componentType']]);width=WIDTHS[spec['type']]
  return np.ndarray((spec['count'],width),dtype=dtype,buffer=buffers[view.get('buffer',0)],offset=view.get('byteOffset',0)+spec.get('byteOffset',0),strides=(view.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
 groups={};frames={}
 for node in document['nodes']:
  if 'mesh' not in node:continue
  owner=node['name'].split('__')[0]
  frames.setdefault(owner,set()).add(json.dumps({k:v for k,v in node.items() if k not in ['name','mesh','extras']},sort_keys=True))
  counter=groups.setdefault(owner,collections.Counter())
  for primitive in document['meshes'][node['mesh']]['primitives']:
   assert primitive.get('mode',4)==4
   points=accessor(primitive['attributes']['POSITION'])
   indices=accessor(primitive['indices']).ravel()
   triangles=points[indices].reshape(-1,3,3).astype('<f4');triangles[triangles==0]=0
   structured=triangles.view([('x','<f4'),('y','<f4'),('z','<f4')]).reshape(-1,3)
   first=np.argsort(structured,axis=1,order=['x','y','z'])[:,0]
   canonical=np.ascontiguousarray(triangles[np.arange(len(triangles))[:,None],(first[:,None]+np.arange(3))%3])
   counter.update(row.tobytes() for row in canonical)
 return groups,frames

rows=[]
for family in ['surface_stock','domestic_storage','domestic_objects','reading_nook']:
 relative='game/assets/props/'+family+'.glb'
 old=BEFORE/(family+'.glb');old.write_bytes(subprocess.check_output(['git','show',BASE+':'+relative],cwd=ROOT));new=ROOT/relative
 old_groups,old_frames=geometry(old);groups,frames=geometry(new)
 old_data=json.loads(subprocess.check_output(['git','show',BASE+':game/data/orison_v2/'+family+'.json'],cwd=ROOT))
 data=json.loads((ROOT/'game/data/orison_v2'/(family+'.json')).read_text())
 def owners(value):
  return {k:([{x:y for x,y in row.items() if x!='parts'} for row in v] if k=='assemblies' else v) for k,v in value.items() if k not in ['local_materials','optics']}
 passed=groups==old_groups and frames==old_frames and owners(data)==owners(old_data)
 rows.append(dict(family=family,exact_oriented_triangles_and_assembly_owners=groups==old_groups,node_frames_by_assembly=frames==old_frames,other_runtime_fields=owners(data)==owners(old_data),triangles=sum(sum(v.values()) for v in groups.values()),before_sha256=hashlib.sha256(old.read_bytes()).hexdigest(),after_sha256=hashlib.sha256(new.read_bytes()).hexdigest(),passed=passed))
 print(family,'PASS' if passed else 'FAIL',rows[-1]['triangles'],flush=True)
report=dict(evidence_class='INERT',scope='Exact float32 oriented triangles grouped by retained assembly owner, source node frames, placement/instance records; no gameplay or visual acceptance.',families=rows)
(ROOT/'art/reviews/v2_binding_stock_20261020/native_comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8',newline='\n')
assert all(row['passed'] for row in rows)
