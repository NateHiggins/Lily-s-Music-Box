"""Verify stable save frames retain the profiled physical book arrangement."""
from pathlib import Path
import hashlib,json,math,subprocess
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
def old(name):return json.loads(subprocess.check_output(['git','--no-optional-locks','show','e9df01d2:'+name],cwd=ROOT))
def read(name):return json.loads((ROOT/name).read_text(encoding='utf-8'))
def pose(row):
 p=np.eye(4)
 if 'basis' in row:p[:3,:3]=np.array(row['basis']).T
 else:
  c=math.cos(row['yaw']);s=math.sin(row['yaw']);p[:3,:3]=[[c,0,s],[0,1,0],[-s,0,c]]
 p[:3,3]=row['position'];return p
runtime='game/data/orison_v2/reading_nook.json';copies='game/data/orison_v2/nook_readable_books.json'
before_frames={r['id']:r for r in old(runtime)['assemblies']};frames={r['id']:r for r in read(runtime)['assemblies']}
previous={r['id']:r for r in old(copies)['copies']};rows=[]
for row in read(copies)['copies']:
 before=pose(before_frames[row['assembly']])@pose(previous[row['id']])
 if row['assembly']=='nook_pile':before[2,3]-=.85
 after=pose(frames[row['assembly']])@pose(row)
 difference=float(np.max(np.abs(after-before)));assert difference<1e-6,(row['id'],difference)
 rows.append(dict(id=row['id'],maximum_matrix_difference=difference))
owners={name:before_frames[name]==frames[name] for name in ['nook_pile','nook_books','nook_cush1']};assert all(owners.values())
report=dict(evidence_class='INERT',scope='Authoring comparison: physical copy poses match the 850 mm table relocation already played; original logical save frames remain fixed. Not a runtime_contract.',source_base='e9df01d2',copies=rows,unchanged_save_frames=owners,source_sha256={p:hashlib.sha256((ROOT/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [runtime,copies]})
(OUT/'book_world_pose_comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('All',len(rows),'physical copy poses match; all three save frames unchanged')
