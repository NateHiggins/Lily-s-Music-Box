"""INERT independent read of actual rebuilt masonry and retained pipe clearance."""
import json,math,sys,hashlib
from pathlib import Path
import bpy,bmesh

root=Path('C:/PleaseRemainOnTheLine')
out=root/'tmp/v2-service-circulation-20261018/native_passages1'
out.mkdir(exist_ok=True)
layout=json.loads((root/'game/data/orison_v2_blockout.json').read_text())
levels={r['id']:r['y'] for r in layout['levels']}
bpy.ops.wm.open_mainfile(filepath=str(root/'art/blender/exterior_masonry.blend'))
boxes=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,obj.name
    bm.free()
    points=[obj.matrix_world@v.co for v in obj.data.vertices]
    boxes.append((obj.name,[min(p.x for p in points),min(p.z for p in points),-max(p.y for p in points),max(p.x for p in points),max(p.z for p in points),-min(p.y for p in points)]))
routes={'F01':[(8.9,1.5),(7.7,1.5),(7.7,-.2),(8.9,-.2)],'F02':[(8.9,1.45),(7.7,1.45),(7.7,-.7),(8.9,-.7)]}
failures=[];samples=0
for floor,route in routes.items():
    y=levels[floor]
    for a,b in zip(route,route[1:]):
        count=math.ceil(math.dist(a,b)/.025)
        for i in range(count+1):
            t=i/count;x,z=[u+(v-u)*t for u,v in zip(a,b)];samples+=1
            for name,box in boxes:
                if box[4]<=y+.025 or box[1]>=y+1.85:continue
                dx=max(box[0]-x,0,x-box[3]);dz=max(box[2]-z,0,z-box[5])
                if math.hypot(dx,dz)<.335-1e-6:failures.append({'floor':floor,'point':[x,y,z],'masonry':name})
# Actual native hole, not just the declared port bounds: the fitted old pipe
# remains clear across the complete new outer leaf.
source=json.loads((root/'art/data/orison_v2/heating_refit_authoring.json').read_text())
route=next(r for r in source['routes']['branches'] if r['id']=='F03_C_RADIATOR_01')
a,b=route['points_local_godot'][1:3]
port=next(p for p in layout['masonry_service_openings'] if p['id']=='F02_SERVICE_BYPASS_HEAT_OUTER_PORT')['bounds']
for i in range(101):
    z=port[2]+(port[5]-port[2])*i/100
    p=[a[j]+(b[j]-a[j])*(z-a[2])/(b[2]-a[2]) for j in range(3)]
    for name,box in boxes:
        distance=math.sqrt(sum(max(box[j]-p[j],0,p[j]-box[j+3])**2 for j in range(3)))
        if distance<.04-1e-6:failures.append({'pipe':p,'masonry':name,'distance':distance})
report={'evidence_class':'INERT','scope':'Reopened actual closed masonry stock; sampled full standing-disc envelope and retained 40mm-radius pipe clearance, not played proof.','stocks':len(boxes),'standing_samples':samples,'pipe_samples':101,'failures':failures,'native_sha256':hashlib.sha256((root/'art/blender/exterior_masonry.blend').read_bytes()).hexdigest()}
(out/'inspection.json').write_text(json.dumps(report,indent=2)+'\n')
assert not failures,failures[:10]
print('NATIVE SERVICE PASSAGES PASS',samples,'standing samples;101 retained pipe samples;',len(boxes),'closed stocks')
