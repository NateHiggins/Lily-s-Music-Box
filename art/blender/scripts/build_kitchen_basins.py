"""Closed cast sink shells, rolled rims, draining boards and removable plugs."""
from pathlib import Path
import ast, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_uvs import chart_for_triangle
from check_exported_tangents import validate
OUT=ROOT/'tmp/v2-kitchen-castings-20261012';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
# Reuse the established solid constructors without executing the faucet build.
source=Path(__file__).with_name('build_kitchen_faucet.py')
tree=ast.parse(source.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),str(source),'exec'))
enamel=mat('porcelain_fixture',(.9,.88,.82),0,.23)
nickel=mat('faucet_nickel',(.72,.71,.67),.92,.24)
rubber=mat('rubber_aged',(.055,.05,.045),0,.65)

def perimeter(hx,hz,r):
    return [(cx+r*math.cos(a),cz+r*math.sin(a))
            for cx,cz,base in [(hx-r,hz-r,0),(-hx+r,hz-r,90),(-hx+r,-hz+r,180),(hx-r,-hz+r,270)]
            for a in np.radians(np.linspace(base,base+90,17))]

def stock(name,verts,faces,material,parent,bevel=0):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([p(v) for v in verts],[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(obj,name,material,parent,bevel)

def basin(parent,w,d,top):
    # Walk the entire section: drain mouth, coved interior, rolled rim,
    # bearing underside, tapered outer casting and open drain underside.
    hx,hz=w/2,d/2
    profile=[(-.064,-.064,.04,-.130),(-.050,-.050,.045,-.124),
             (-.043,-.043,.047,-.112),(-.029,-.029,.04,-.025),
             (-.026,-.026,.035,-.005),(-.020,-.020,.03,.008),
             (0,0,.025,.0125),(.014,.014,.025,.008),
             (.0175,.0175,.025,.002),(.0175,.0175,.025,-.006),
             (.0125,.0125,.025,-.0125),(-.006,-.006,.022,-.0125),
             (-.020,-.020,.035,-.033),(-.029,-.029,.048,-.120),
             (-.044,-.044,.048,-.146),(-.060,-.060,.045,-.150)]
    angles=[math.atan2(z,x) for x,z in perimeter(hx-.064,hz-.064,.04)]
    rings=[[(.029*math.cos(a),top-.133,.01+.029*math.sin(a)) for a in angles]]
    rings += [[(x,top+y,z) for x,z in perimeter(hx+dx,hz+dz,r)] for dx,dz,r,y in profile]
    rings += [[(.029*math.cos(a),top-.150,.01+.029*math.sin(a)) for a in angles]]
    n=len(angles);verts=[v for ring in rings for v in ring];faces=[]
    for row in range(len(rings)):
        nxt=(row+1)%len(rings)
        faces.extend((row*n+i,row*n+(i+1)%n,nxt*n+(i+1)%n,nxt*n+i) for i in range(n))
    shell=stock('ContinuousCasting',verts,faces,enamel,parent)
    tube('DrainFerrule',[(0,top-.154,.01),(0,top-.128,.01)],.031,.025,nickel,parent)
    # A real strainer bridge leaves the bore visible around it.
    box('DrainBridge',(0,top-.137,.01),(.005,.003,.049),nickel,parent)
    bpy.ops.mesh.primitive_cube_add(size=1,location=p((0,top+.075,d*.5-.004)))
    o=bpy.context.object;o.dimensions=(w+.03,.035,.16)
    finish(o,'IntegralSplash',enamel,parent,.006)
    return shell

def board(parent,w,d,top):
    left=w*.5;right=left+.42;front=-d/2;back=d/2
    verts=[(x,y,z) for y in [top-.016,top+.009] for z in [front,back] for x in [left,right]]
    verts=[(x,(top+.004+.008*(x-left)/.42) if i>=4 else y,z) for i,(x,y,z) in enumerate(verts)]
    stock('SlopingDrainboard',verts,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],enamel,parent,.002)
    for i in range(7):
        z=(i-3)*(d-.075)/6
        # Rounded longitudinal crests discharge toward the bowl, rather
        # than the old transverse square bars that trapped water.
        bpy.ops.mesh.primitive_cube_add(size=1,location=p((left+.218,top+.012,z)))
        o=bpy.context.object;o.dimensions=(.365,.011,.010)
        o.rotation_euler.y=-math.atan2(.008,.42)
        finish(o,'DrainFlute',enamel,parent,.0045)

shells=[]
for name,compact,draining in [('Standard',False,True),('Compact',True,True),('Countertop',True,False)]:
    parent=group(name);w=.50 if compact else .61;d=.38 if compact else .46;top=.9175 if compact else .9
    shells.append((basin(parent,w,d,top),w,d,top))
    if draining:board(parent,w,d,top)
    plug=group('Plug'+name);plug.parent=parent
    cylinder('RubberPlug',(0,0,0),.033,.010,rubber,plug)
    cylinder('PlugButton',(0,.006,0),.010,.004,nickel,plug)
    # Rounded, closed thin water disc. Runtime applies its existing water
    # material and controls its position/scale; this is only its footprint.
    ring=perimeter((w-.095)/2,(d-.095)/2,.035);n=len(ring)
    verts=[(x,y,z) for y in [-.001,.001] for x,z in ring]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    stock('Water'+name,verts,faces,enamel,parent)

bpy.context.view_layer.update()
contacts=[]
for shell,w,d,top in shells:
    # These rays check the untriangulated casting itself, not its AABB.
    bm=bmesh.new();bm.from_mesh(shell.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(shell.data);bm.free()
    hit= shell.ray_cast(p((0,top+.04,.01)),p((0,-1,0)),distance=.3)[0]
    assert not hit,'Casting caps its drain'
    for x in [-w/2-.01,w/2+.01]:
        hit,at,normal,index=shell.ray_cast(p((x,top-.04,0)),p((0,1,0)),distance=.1)
        assert hit and abs(at.z-(top-.0125))<1e-5,(shell.name,at[:])
    contacts.append({'shell':shell.name,'open_drain':True,'rim_underside_m':top-.0125})

native=[]
# Use the same checked UV/normal/export pipeline as the accepted faucet.
loop=next(n for n in tree.body if isinstance(n,ast.For) and isinstance(n.target,ast.Name) and n.target.id=='obj')
# Porcelain uses its catalogue's 0.4 m scale; metal and rubber retain 0.18 m.
code=ast.unparse(loop).replace('chart_for_triangle(points, np.zeros(3), 0.18)',"chart_for_triangle(points, np.zeros(3), .4 if obj.data.materials[0].name=='porcelain_fixture' else .18)")
exec(compile(code,str(source),'exec'))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/kitchen_basins.blend'),compress=True)
exporter=Path(__file__).with_name('build_media_battery_supply.py');et=ast.parse(exporter.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in et.body if isinstance(n,ast.ClassDef) and n.name=='ExportDerivatives'],type_ignores=[]),str(exporter),'exec'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportDerivatives
asset=ROOT/'game/assets/props/kitchen_basins.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_tangents=True,export_lights=False,export_cameras=False)
proof={'evidence_class':'INERT','native':native,'contacts':contacts,'export':validate(asset),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest()}
(OUT/'construction.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8',newline='\n')
print('KITCHEN CASTINGS:',len(native),'closed stocks',proof['export'])
