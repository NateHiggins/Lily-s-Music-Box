"""Native retrofit dispatch apron. No lettering or independent lift simulation."""
from pathlib import Path
import hashlib,json,math,sys
import bpy,bmesh
from mathutils import Matrix,Vector
R=Path(__file__).resolve().parents[3];sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
catalog=json.loads((R/'game/data/runtime_material_sets.json').read_text())['materials']
collection=bpy.data.collections.new('Dispatch stocks');bpy.context.scene.collection.children.link(collection)
raw=[];parts=[];stocks=[]
layout=json.loads((R/'game/data/orison_v2_blockout.json').read_text())
served={row['level'] for row in layout['lift_landings'] if row['shaft']=='PASSENGER_LIFT_SHAFT'}|{'B1'}
assert 1<len(served)<=8
centers=[[(i-(len(served)-1)*.5)*.028,-.344,.053] for i in range(len(served))]

def solid(name,points,faces,edge=0):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([C@Vector(p) for p in points],[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    if edge:
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Worked edge','BEVEL');mod.width=edge;mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    raw.append(obj);return obj

def box(name,lo,hi,edge=.00015):
    return solid(name,[(x,y,z) for z in [lo[2],hi[2]] for y in [lo[1],hi[1]] for x in [lo[0],hi[0]]],[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],edge)

def tube(name,r,inside,z0,z1,at=(0,0,0),edge=.00008):
    n=48;rings=[(z0,r),(z1,r)]+([(z1,inside),(z0,inside)] if inside else [])
    points=[(at[0]+rad*math.cos(i*math.tau/n),at[1]+rad*math.sin(i*math.tau/n),at[2]+z) for z,rad in rings for i in range(n)]
    faces=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(rings)-1) for i in range(n)]
    if inside:faces += [(3*n+i,3*n+(i+1)%n,(i+1)%n,i) for i in range(n)]
    else:faces += [tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    return solid(name,points,faces,edge)

def wire(name,points,radius):
    controls=[Vector(p) for p in points];path=[controls[0]]
    for i,p in enumerate(controls[1:-1],1):
        before=p-controls[i-1];after=controls[i+1]-p
        reach=min(.004,before.length*.3,after.length*.3)
        a=p-before.normalized()*reach;b=p+after.normalized()*reach
        path.extend((1-t)**2*a+2*(1-t)*t*p+t*t*b for t in [j/8 for j in range(9)])
    path.append(controls[-1]);verts=[];n=8;u=None
    for i,p in enumerate(path):
        tangent=(path[min(i+1,len(path)-1)]-path[max(0,i-1)]).normalized()
        if u is None:u=tangent.cross(Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((1,0,0))).normalized()
        else:u=(u-tangent*u.dot(tangent)).normalized()
        v=tangent.cross(u)
        verts.extend(p+radius*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n)) for j in range(n))
    faces=[tuple(reversed(range(n)))]+[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(path)-1) for j in range(n)]+[tuple((len(path)-1)*n+j for j in range(n))]
    return solid(name,verts,faces)

def finish(name,key):
    global raw
    for obj in raw:
        bm=bmesh.new();bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,obj.name
        stocks.append({'name':obj.name,'part':name,'volume_m3':bm.calc_volume(signed=True)});bm.free()
    normal=1. if key in ['bakelite','radiator_service_brass'] else .08 if key=='faucet_nickel' else .18
    roughness=.82 if key=='faucet_nickel' else 1.
    spec={'catalog_key':key,'normal':normal,'roughness':roughness,'pigment':1.,'tint':[1,1,1]}
    if name not in ['ReturnSpring','DispatchLeads']:spec['planar_axes']=[[1,0,0],[0,1,0],[0,0,1]]
    mat=material(R,key,spec,catalog);obj=partition(collection,name,raw,spec,mat,Matrix.Identity(4),catalog)
    # Whole tile shifts retain appearance without magnifying tiny UV offsets.
    tile=catalog[key]['meters_per_tile'];uv=obj.data.uv_layers.active.data
    for face in obj.data.polygons:
        mean=sum((uv[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
        offset=Vector((round(mean.x/tile)*tile,round(mean.y/tile)*tile))
        for i in face.loop_indices:uv[i].uv-=offset
    for item in raw:bpy.data.objects.remove(item,do_unlink=True)
    raw=[];parts.append({'name':name,'key':key,'normal_scale':normal,'roughness':roughness});return obj

plate=box('Pierced dispatch apron',(-.12,-.362,.048),(.12,-.326,.052),.0003)
for at in centers:
    cutter=tube('Actual guide bore',.0041,0,.045,.055,(at[0],at[1],0),0)
    bpy.context.view_layer.objects.active=plate
    mod=plate.modifiers.new('Through guide port','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);raw.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
for x in [-.112,.112]:
    box('Case attachment ear',(x-.004,-.343,.028),(x+.004,-.298,.049))
    screw=tube('Attachment screw',.002,0,.049,.051,(x,-.304,0))
    cutter=box('Driver recess', (x-.0023,-.3042,.0505),(x+.0023,-.3038,.0515),0)
    bpy.context.view_layer.objects.active=screw
    mod=screw.modifiers.new('Real screwdriver slot','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);raw.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
finish('Apron','radiator_service_brass')
for at in centers:
    tube('Porcelain guide',.004,.003,-.006,.006,at)
    tube('Guide flange',.006,.003,.004,.006,at)
finish('Guides','porcelain_fixture')
box('Common contact bus',(-.111,-.350,.027),(.111,-.338,.029))
finish('ContactBus','faucet_nickel')
for x in [-.112,.112]:tube('Isolating bus standoff',.003,0,.029,.048,(x,-.344,0))
for at in centers:tube('Insulating spring seat',.0054,.003,-.0234,-.0224,at)
for at in centers:box('Binding post porcelain', (at[0]-.006,-.252,.042),(at[0]+.006,-.240,.048))
finish('BusInsulators','porcelain_fixture')

lead_paths=[]
for i,at in enumerate(centers):
    x=at[0];side=-1 if i<=len(centers)//2 else 1
    lane=i if side<0 else len(centers)-1-i;bx=side*(.119+lane*.0018)
    tube('Isolated spring terminal eye',.0051,.0035,-.0224,-.0222,at,edge=.00003)
    post=tube('Binding screw',.0017,0,.048,.051,(x,-.246,0))
    cutter=box('Binding driver slot',(x-.002,-.2462,.0505),(x+.002,-.2458,.0515),0)
    bpy.context.view_layer.objects.active=post
    cut=post.modifiers.new('Slotted binding head','BOOLEAN');cut.operation='DIFFERENCE';cut.solver='EXACT';cut.object=cutter
    bpy.ops.object.modifier_apply(modifier=cut.name);raw.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
    start=(x+.005,-.344,.0307);jacket=(x+.007,-.336,.036);end=(x,-.246,.058)
    wire('Bare terminal tail',[start,jacket],.00055)
    wire('Bare binding tail',[end,(x,-.246,.051)],.00055)
    lead_paths.append([jacket,(bx,-.336,.036),(bx,-.319,.036),(bx,-.313,.054),(bx,-.258+lane*.0015,.054),end])
wire('Common bus solder tail',[(-.108,-.344,.029),(-.110,-.337,.036)],.00055)
wire('Common silvered contact tail',[(-.044,-.282,.0435),(-.035,-.282,.045)],.00055)
lead_paths.append([(-.110,-.337,.036),(-.1285,-.334,.036),(-.1285,-.319,.036),(-.1285,-.313,.054),(-.1285,-.282,.054),(-.056,-.282,.0435),(-.044,-.282,.0435)])
finish('Terminals','faucet_nickel')
for path in lead_paths:wire('Dressed insulated lead',path,.0009)
finish('DispatchLeads','rubber_aged')
tube('Stem',.0028,0,-.020,.010)
tube('Spring retainer',.0045,0,-.0105,-.0095)
finish('ButtonStem','faucet_nickel')
tube('Bakelite finger cap',.007,0,.010,.014,edge=.00035)
finish('ButtonCap','bakelite')
# Closed wire stock, fixed at its lower end; runtime compresses axial travel.
path=[Vector((.0043*math.cos(i*math.tau/20),.0043*math.sin(i*math.tau/20),.012*i/100)) for i in range(101)]
points=[];sides=8
for i,p in enumerate(path):
    t=(path[min(i+1,100)]-path[max(0,i-1)]).normalized();u=t.cross(Vector((0,0,1))).normalized();v=t.cross(u)
    points += [p+.0004*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides)) for j in range(sides)]
faces=[tuple(reversed(range(sides)))]+[(i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j) for i in range(100) for j in range(sides)]+[tuple(100*sides+j for j in range(sides))]
solid('Return spring',points,faces);spring=finish('ReturnSpring','faucet_nickel')
# Vary pitch, retaining wire thickness and both bearing ends. Scaling the
# whole mesh would lift its lower wire from the ceramic seat as it compressed.
spring.shape_key_add(name='Basis');pressed=spring.shape_key_add(name='Pressed')
for i,point in enumerate(pressed.data):point.co += C@Vector((0,0,-.004*(i//sides)/100))
report=export(R,'annunciator_dispatch',collection)
data={'schema_version':1,'asset':'res://assets/props/annunciator_dispatch.glb','travel':.004,'make':.004,'return_speed':.018,'centers':centers,'parts':parts}
(R/'game/data/orison_v2/annunciator_dispatch.json').write_text(json.dumps(data,indent=2)+'\n',newline='\n')
report.update(evidence_class='INERT',scope='Native dispatch apron, guides, stems, springs and real through bores; not gameplay or room acceptance.',stocks=stocks,projection=data,source_lf_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest())
out=R/'tmp/v2-annunciator-dispatch-20261017';out.mkdir(parents=True,exist_ok=True)
(out/'native.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('DISPATCH NATIVE',len(parts),'parts',len(stocks),'closed stocks',flush=True)
