"""Fixed roof lighting supply: bored cross, supported bridge and lamp drops.

Existing circuit owners remain. Original riser cap is superseded at its exact
datum, never left inside the new branch. All exported stock has metre UVs.
"""
from pathlib import Path
import ast,json,math,hashlib,sys
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-roof-supply-20261012';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
materials={}
for key in ['iron_neutral','galvanized_roof','brass_dull']:
    m=bpy.data.materials.new(key);m.use_nodes=True;materials[key]=m
path=ROOT/'art/blender/scripts/build_electrical_service.py'
tree=ast.parse(path.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'point','cube','cylinder','cut','ring','finish','screw'}],type_ignores=[]),str(path),'exec'))
ORIGIN=Vector((9.39,21.9,1.0));segments=[];supports=[]
def local(p):return Vector(p)-ORIGIN
def union(o,c):
    bpy.context.view_layer.objects.active=o
    mod=o.modifiers.new('Joined casting','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=c
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(c,do_unlink=True);return o
def along_x(o):o.rotation_euler.y=math.pi/2;return o
cross=union(cylinder(.0225,.11),along_x(cylinder(.0225,.24)))
cut(cross,cylinder(.0185,.14));cut(cross,along_x(cylinder(.0185,.28)))
finish('RoofFeedCross',[cross],'iron_neutral',.0002)
finish('RoofUpperCap',[cylinder(.026,.008,(0,.059,0))],'iron_neutral',.0002)
def span(name,a,b,radius=.0225):
    a=Vector(a);b=Vector(b);length=(b-a).length
    o=ring(radius,radius-.004,length,local((a+b)/2))
    direction=Vector((b.x-a.x,-(b.z-a.z),b.y-a.y)).normalized()
    o.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
    finish(name,[o],'galvanized_roof',.00015)
    segments.append({'name':name,'a':list(a),'b':list(b),'radius':radius})
span('RiserExtension',[9.39,21.4,1],[9.39,21.845,1])
# The bridge crosses above the walked deck, supported by a fixed steel angle.
span('PublicBridge',[9.27,21.9,1],[5.20,21.9,1])
span('ServiceWallEntry',[9.51,21.9,1],[9.72,21.9,1])
# Indoor conduits follow the ceiling and enter the existing native canopies.
routes={'Public':[[5.20,21.9,1],[.2,21.9,1],[.2,21.9,-.4],[.2,22.2,-.4]],
        'Service':[[9.72,21.9,1],[11.9,21.9,1],[11.9,21.9,2.3],[11.9,22.2,2.3]]}
for room,points in routes.items():
    for i,(a,b) in enumerate(zip(points,points[1:])):span(room+'Conduit'+str(i),a,b)
    # Hollow box fittings enclose the square route changes rather than
    # counterfeit closed pipe intersections. Side entries are actual bores.
    for i,p in enumerate(points[1:-1]):
        q=local(p);shell=cube((.09,.07,.09),q)
        cut(shell,cube((.068,.09,.068),q))
        for direction in [Vector(points[i])-Vector(p),Vector(points[i+2])-Vector(p)]:
            cutter=cylinder(.024,.14,q);d=Vector((direction.x,-direction.z,direction.y)).normalized();cutter.rotation_euler=d.to_track_quat('Z','Y').to_euler();cut(shell,cutter)
        finish(room+'ElbowBox'+str(i),[shell],'iron_neutral',.0003)
        finish(room+'ElbowCover'+str(i),[cube((.086,.004,.086),q+Vector((0,.037,0)))],'iron_neutral',.0003)
    for i,(a,b) in enumerate(zip(points,points[1:])):
        a=Vector(a);b=Vector(b)
        if abs(a.y-b.y)>.001:continue
        length=(b-a).length
        for j in range(max(1,math.ceil(length/.65))):
            at=a.lerp(b,(j+.5)/max(1,math.ceil(length/.65)));q=local(at)
            seat=cube((.06,.006,.06),q+Vector((0,.297,0)))
            rod=cylinder(.0035,.272,q+Vector((0,.161,0)))
            strap=ring(.027,.0225,.020,q)
            direction=Vector((b.x-a.x,-(b.z-a.z),b.y-a.y)).normalized();strap.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
            finish(room+'CeilingStay'+str(i)+'_'+str(j),[seat,rod,strap],'iron_neutral',.0002)
            supports.append({'name':room+'CeilingStay'+str(i)+'_'+str(j),'seat':[at.x,22.2,at.z],'owner':room})
# A rolled angle carries the external conduit; end brackets bear on the walls.
# Extrude the rolled L section directly: Boolean coplanar faces on the thin
# flange produced zero-area triangles despite a closed positive shell.
profile=[(-.0025,-.0275),(.0025,-.0275),(.0025,.0225),(.0525,.0225),(.0525,.0275),(-.0025,.0275)]
vertices=[point(local([7.45+x,22.04+y,1+z])) for x in [-1.95,1.95] for y,z in profile]
faces=[tuple(reversed(range(6))),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
mesh=bpy.data.meshes.new('RolledAngle');mesh.from_pydata(vertices,[],faces);mesh.update()
beam=bpy.data.objects.new('RolledAngle',mesh);bpy.context.collection.objects.link(beam)
finish('BridgeCarrier',[beam],'iron_neutral',.0003)
for i in range(6):
    q=local([5.6+i*.72,21.9,1])
    strap=along_x(ring(.027,.0225,.020,q))
    rod=cylinder(.0035,.113,q+Vector((0,.0835,0)))
    finish('BridgeHanger'+str(i),[strap,rod],'iron_neutral',.0002)
    supports.append({'name':'BridgeHanger'+str(i),'seat':[5.6+i*.72,22.04,1],'owner':'BridgeCarrier'})
for name,x,normal in [('Public',5.476,1),('Service',9.424,-1)]:
    q=local([x,22.0,1]);plate=cube((.012,.18,.12),q);shelf=cube((.13,.012,.12),q+Vector((normal*.06,.036,0)))
    finish(name+'BridgeBracket',[union(plate,shelf)],'iron_neutral',.0003)
    supports.append({'name':name+'BridgeBracket','seat':[x-normal*.006,22.0,1],'owner':name+' bulkhead wall face'})
    for z in [-.035,.035]:
        bolt=along_x(cylinder(.005,.024,q+Vector((normal*.008,-.05,z))))
        finish(name+'BracketBolt'+str(z),[bolt],'brass_dull',.0002)
# Broad weather collars cover the rectangular service bores at both faces.
for name,x in [('PublicOuter',5.474),('PublicInner',5.326),('ServiceOuter',9.426),('ServiceInner',9.574)]:
    q=local([x,21.9,1]);collar=along_x(ring(.063,.024,.008,q));finish(name+'WeatherCollar',[collar],'iron_neutral',.0003)
rows=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    # Triangle normals after Boolean/bevel conversion can differ from inherited
    # polygon normals. Chart the actual triangle plane, not stale ngon metadata.
    uv_layer=obj.data.uv_layers.active
    for face in obj.data.polygons:
        points=[obj.data.vertices[i].co for i in face.vertices]
        normal=(points[1]-points[0]).cross(points[2]-points[0])
        axis=max(range(3),key=lambda i:abs(normal[i]));a,b=[(1,2),(0,2),(0,1)][axis]
        for loop in face.loop_indices:
            point=obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv_layer.data[loop].uv=(point[a],point[b])
    bm=bmesh.new();bm.from_mesh(obj.data);volume=bm.calc_volume(signed=True);closed=all(e.is_manifold for e in bm.edges);bm.free()
    bad=0
    for face in obj.data.polygons:
        uv=[Vector(obj.data.uv_layers.active.data[i].uv) for i in face.loop_indices]
        if abs((uv[1]-uv[0]).cross(uv[2]-uv[0]))<1e-13:bad+=1
    assert closed and volume>0 and bad==0,(obj.name,closed,volume,bad)
    rows.append({'name':obj.name,'triangles':len(obj.data.polygons),'volume':volume,'degenerate_uv':bad})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/roof_lighting_supply.blend'))
asset=ROOT/'game/assets/props/roof_lighting_supply.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_apply=True,export_tangents=True,export_lights=False,export_cameras=False)
data={'schema_version':1,'asset':'res://assets/props/roof_lighting_supply.glb','asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'origin':list(ORIGIN),'superseded_cap':[9.39,21.404,1]}
(ROOT/'game/data/orison_v2/roof_lighting_supply.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'construction.json').write_text(json.dumps({'evidence_class':'INERT','parts':rows,'segments':segments,'supports':supports,'origin':list(ORIGIN),'scope':'Closed positive native stock/metre charts. Installed bore, support, collision and appearance proof remain required.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('ROOF SUPPLY:',len(rows),'parts; lowest bridge21.8775 = 2.6775m above deck')
