"""Native UV surface for the retained radiator casting; no new dimensions."""
from pathlib import Path
import ast,hashlib,json,math,re,sys
import bpy
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from repair_surface_uvs import repair_scene
source=ROOT/'game/scripts/props/radiator_prop.gd';text=source.read_text()
def constant(name):
    return float(re.search(r'const '+name+r'\s*:?=\s*([\d.]+)',text).group(1))
height=constant('BODY_TOP')-constant('BODY_BOTTOM')
profile=re.search(r'var rings := (\[.*?\n\t\])',text,re.S).group(1)
rings=ast.literal_eval(profile.replace('BODY_TOP - BODY_BOTTOM',str(height)))
sides=int(re.search(r'var sides := (\d+)',text).group(1))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
vertices=[];normals=[];faces=[]
for y,rx,rz in rings:
    for side in range(sides):
        theta=math.tau*side/sides;vertices.append((math.cos(theta)*rx,-math.sin(theta)*rz,y))
        n=(math.cos(theta)/rx,-math.sin(theta)/rz,0);length=math.sqrt(sum(v*v for v in n));normals.append(tuple(v/length for v in n))
bottom=len(vertices);vertices.append((0,0,0));normals.append((0,0,-1))
top=len(vertices);vertices.append((0,0,height));normals.append((0,0,1))
for ring in range(len(rings)-1):
    for side in range(sides):
        next_side=(side+1)%sides;a=ring*sides+side;b=(ring+1)*sides+side;c=(ring+1)*sides+next_side;d=ring*sides+next_side
        faces.extend([(a,b,c),(a,c,d)])
for side in range(sides):
    next_side=(side+1)%sides;faces.extend([(bottom,side,next_side),(top,(len(rings)-1)*sides+next_side,(len(rings)-1)*sides+side)])
mesh=bpy.data.meshes.new('CastSection');mesh.from_pydata(vertices,[],faces);mesh.update()
obj=bpy.data.objects.new('CastSection',mesh);bpy.context.collection.objects.link(obj)
mesh.normals_split_custom_set([normals[loop.vertex_index] for loop in mesh.loops])
repair_scene()
native=ROOT/'art/blender/radiator_section.blend';asset=ROOT/'game/assets/props/radiator_section.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native))
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_yup=True,export_tangents=True,export_materials='NONE')
fixture={'evidence_class':'INERT','interpretation':'UV-only adaptation of original radiator casting; all input dimensions read from the retained source profile.','asset':asset.relative_to(ROOT).as_posix(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'profile':rings,'sides':sides,'triangles':len(faces),'native':native.relative_to(ROOT).as_posix()}
(ROOT/'game/tests/fixtures/orison_radiator_section.json').write_text(json.dumps(fixture,indent=2)+'\n',newline='\n')
