"""INERT exact occupied-cell comparison outside the two authored extensions."""
import json,hashlib,subprocess
from pathlib import Path
import bpy,numpy as np

root=Path('C:/PleaseRemainOnTheLine');out=root/'tmp/v2-service-circulation-20261018/native_passages1'
oldpath=out/'previous_masonry.blend'
oldpath.write_bytes(subprocess.check_output(['git','show','6dc7f5cd:art/blender/exterior_masonry.blend'],cwd=root))
assert oldpath.stat().st_size>10000 # Blender also accepts its compressed container.
def boxes(path):
    bpy.ops.wm.open_mainfile(filepath=str(path));result=[]
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH':continue
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        result.append([min(p.x for p in points),min(p.z for p in points),-max(p.y for p in points),max(p.x for p in points),max(p.z for p in points),-min(p.y for p in points)])
    return np.asarray(result)
old,new=boxes(oldpath),boxes(root/'art/blender/exterior_masonry.blend')
layout=json.loads((root/'game/data/orison_v2_blockout.json').read_text())
levels={r['id']:r['y'] for r in layout['levels']};margin=layout['dimensions']['outer_wall'];slab=layout['dimensions']['slab_thickness']
allowed=[]
for room in layout['spaces']:
    if room['id'] not in ['F01_SERVICE_RISER_BYPASS','F02_SERVICE_RISER_BYPASS']:continue
    a,b,c,d=room['rect'];y=levels[room['level']]
    allowed.append([a-margin,y-slab,b-margin,c+margin,y+layout['dimensions']['floor_to_floor'],d+margin])
allowed=np.asarray(allowed);cells=0;changed=0;outside=0;failures=[]
def occupied(table,points):
    if not len(table):return np.zeros(len(points),dtype=bool)
    return np.any(np.all((points[:,None,:]>table[None,:,:3]-1e-6)&(points[:,None,:]<table[None,:,3:]+1e-6),axis=2),axis=1)
for bounds in np.concatenate((old,new)):
    tables=[]
    for table in [old,new,allowed]:
        mask=np.all(np.minimum(table[:,3:],bounds[3:])-np.maximum(table[:,:3],bounds[:3])>1e-6,axis=1)
        tables.append(table[mask])
    axes=[]
    for axis in range(3):
        cuts=sorted({bounds[axis],bounds[axis+3],*[float(v) for table in tables for v in table[:,[axis,axis+3]].ravel() if bounds[axis]+1e-5<v<bounds[axis+3]-1e-5]})
        axes.append([(a+b)/2 for a,b in zip(cuts,cuts[1:]) if b-a>1e-5])
    points=np.stack(np.meshgrid(*axes,indexing='ij'),axis=-1).reshape(-1,3)
    before,after,permitted=[occupied(table,points) for table in tables]
    changes=before!=after;bad=changes&~permitted
    cells+=len(points);changed+=int(changes.sum());outside+=int(bad.sum())
    if bad.any():failures.extend(points[bad][:5].tolist())
report={'evidence_class':'INERT','method':'Actual old/new orthogonal closed native stocks partitioned at all intersecting stock and allowed extension boundaries. Occupancy must be identical everywhere outside the two source-bounded extension envelopes.','old_stocks':len(old),'new_stocks':len(new),'partition_cells':cells,'changed_cells':changed,'changed_outside_envelopes':outside,'allowed_envelopes':allowed.tolist(),'failures':failures,'old_native_sha256':hashlib.sha256(oldpath.read_bytes()).hexdigest(),'new_native_sha256':hashlib.sha256((root/'art/blender/exterior_masonry.blend').read_bytes()).hexdigest()}
(out/'preservation.json').write_text(json.dumps(report,indent=2)+'\n')
assert not outside,failures[:10]
print('NATIVE MASONRY PRESERVATION PASS',cells,'cells;',changed,'changed inside authored extension envelopes;0 outside')
