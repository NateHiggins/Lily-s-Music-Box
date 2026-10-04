"""Source-fitted Harukiya split pipe collars; all original pipe authority retained."""
from pathlib import Path
import collections, hashlib, json, math, os, sys
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan_path=root/'art/data/bar_pipe_supports/source_plan.json';plan=json.loads(plan_path.read_text())
assert plan['classification']=='ADAPTATION'
out=root
for folder in ['art/blender','game/assets/props','game/data/orison_v2','game/tests/fixtures']:(out/folder).mkdir(parents=True,exist_ok=True)
def digest(path):
    data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
def godot(value):return [value[0],value[2],-value[1]]
sys.path.insert(0,str(root/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
layout=json.loads((root/'art/data/building_layout.json').read_text());floor=next(x for x in layout['floors'] if x['id']==plan['source_floor'])
rows={r['id']:r for r in floor['furniture']};pipes=[rows[k] for k in plan['pipe_ids']]
sets=json.loads((root/'game/data/runtime_material_sets.json').read_text())['materials']
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.gltf(filepath=str(root/'game/assets/building/floor_01_cells/shop_bar.gltf'))
context=bpy.data.collections.new('ReadOnlyRetainedContext');bpy.context.scene.collection.children.link(context)
vertices=[];faces=[];owners=[]
for obj in list(bpy.context.scene.objects):
    for c in list(obj.users_collection):c.objects.unlink(obj)
    context.objects.link(obj)
    if obj.type!='MESH':continue
    if not any(key in obj.name for key in ['retail_bar_soot','retail_bar_common_brick','retail_bar_plaster_stained']):continue
    offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    for face in obj.data.polygons:faces.append(tuple(offset+i for i in face.vertices));owners.append(obj.name)
tree=BVHTree.FromPolygons(vertices,faces,all_triangles=False)
construction=bpy.data.collections.new('FittedFixtureConstruction');bpy.context.scene.collection.children.link(construction)
materials={}
for key in plan['runtime_keys']:
    material=bpy.data.materials.new(key);material.use_nodes=True;spec=sets[key];node=material.node_tree.nodes['Principled BSDF']
    node.inputs['Metallic'].default_value=spec['metallic'];coord=material.node_tree.nodes.new('ShaderNodeTexCoord')
    scale=material.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];material.node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
    for i,target in enumerate(['Base Color','Roughness','Normal']):
        image=bpy.data.images.load(str(root/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
        tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
        if i:image.colorspace_settings.name='Non-Color'
        material.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
        if i==2:
            normal=material.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35
            material.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);material.node_tree.links.new(normal.outputs[0],node.inputs[target])
        else:material.node_tree.links.new(tex.outputs['Color'],node.inputs[target])
    materials[key]=material
stocks=[];groups=collections.defaultdict(list);contacts=[];stock_checks=[]
def finish(obj,name,key,group):
    obj.name=name
    for c in list(obj.users_collection):c.objects.unlink(obj)
    construction.objects.link(obj);obj.data.materials.append(materials[key]);obj['assembly']=group;obj['key']=key
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
    stock_checks.append({'name':name,'assembly':group,'key':key,'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'volume_m3':bm.calc_volume(signed=True)})
    bm.to_mesh(obj.data);bm.free();stocks.append(obj);groups[(group,key)].append(obj);return obj
def cylinder(name,a,b,r,key,group):
    a,b=Vector(a),Vector(b);direction=b-a;assert direction.length>.0001
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=r,depth=direction.length,location=(a+b)*.5)
    obj=bpy.context.object;obj.rotation_euler=direction.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return finish(obj,name,key,group)
def plate(name,center,normal,width,height,depth,key,group):
    normal=Vector(normal).normalized();bpy.ops.mesh.primitive_cube_add(size=1,location=center)
    obj=bpy.context.object;obj.dimensions=(width,height,depth);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.rotation_euler=normal.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    mod=obj.modifiers.new('Worked arris','BEVEL');mod.width=.0006;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj,name,key,group)
def fit(identity,start,direction,flex=False):
    start=Vector(start);direction=Vector(direction).normalized()
    hit,normal,index,distance=tree.ray_cast(start+direction*.002,direction,5.)
    assert hit is not None,(identity,'missing original bearing')
    span=(hit-start).dot(direction);assert span>.01,(identity,span)
    assert normal.dot(direction)<-.99,(identity,normal,direction)
    cylinder(identity+'_Stem',start+direction*.012,hit-direction*.004,plan['flex_radius_m'] if flex else plan['stem_radius_m'],'rubber_aged' if flex else 'iron_blackened',identity)
    cylinder(identity+'_LowerCollar',start,start+direction*.018,.012,'brass_dull',identity)
    cylinder(identity+'_UpperCollar',hit-direction*.016,hit-direction*.004,.016,'iron_blackened',identity)
    plate(identity+'_BearingPlate',hit-direction*plan['bearing_plate_thickness_m']*.5,direction,plan['bearing_plate_m'],plan['bearing_plate_m'],plan['bearing_plate_thickness_m'],'iron_blackened',identity)
    seed=Vector((1,0,0)) if abs(direction.z)>.9 else Vector((0,0,1));other=direction.cross(seed)
    for i in range(4):
        angle=math.pi*.25+i*math.pi*.5;at=hit+seed*.037*math.cos(angle)+other*.037*math.sin(angle)
        cylinder(identity+'_Fixing'+str(i),at-direction*.007,at-direction*.004,.003,'brass_dull',identity)
    contacts.append({'id':identity,'fixture_endpoint':list(start),'bearing':list(hit),'direction':list(direction),'gap':span,'owner':owners[index]})
# Profiles come from the actual source rings, including their stored float precision.
def native_profile(row):
    center=Vector(row['p0']);found={};owner=None
    for obj in context.objects:
        if obj.type!='MESH':continue
        for vertex in obj.data.vertices:
            delta=obj.matrix_world@vertex.co-center
            if abs(delta.x)<.00001 and abs(Vector((delta.y,delta.z)).length-row['r'])<.00001:
                found[(round(delta.y,7),round(delta.z,7))]=True;owner=obj.name
    result=[Vector(p) for p in sorted(found,key=lambda p:math.atan2(p[1],p[0]))]
    assert len(result)==10,(row['id'],result)
    return result,owner

def offset_profile(points,thickness):
    result=[]
    for i,at in enumerate(points):
        before=(at-points[i-1]).normalized();after=(points[(i+1)%len(points)]-at).normalized()
        n0=Vector((before.y,-before.x));n1=Vector((after.y,-after.x));bisector=(n0+n1).normalized()
        result.append(at+bisector*(thickness/bisector.dot(n0)))
    return result

def arc(points,sign,cut):
    result=[]
    for a,b in zip(points,points[1:]+points[:1]):
        if sign*a.y>=cut:result.append(a.copy())
        if (sign*a.y>=cut)!=(sign*b.y>=cut):result.append(a+(b-a)*((sign*cut-a.y)/(b.y-a.y)))
    return sorted(result,key=lambda p:math.atan2(sign*p.y,p.x))

def band(name,at,inner,outer,sign,group):
    inside=arc(inner,sign,plan['split_clearance_m']);outside=arc(outer,sign,plan['split_clearance_m']);contour=outside+list(reversed(inside));count=len(contour)
    vertices=[Vector((at.x+x,at.y+p.x,at.z+p.y)) for x in [-plan['band_width_m']*.5,plan['band_width_m']*.5] for p in contour]
    faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]
    for i in range(count):j=(i+1)%count;faces.append((i,j,count+j,count+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);return finish(obj,name,'iron_blackened',group)

def washer(name,at,outer,inner,height,sides,key,group,hex_outer=False):
    vertices=[Vector((at.x+(r*math.cos(math.pi/6)/math.cos((i*math.tau/sides)%(math.pi/3)-math.pi/6) if hex_outer and r==outer else r)*math.cos(i*math.tau/sides),at.y+(r*math.cos(math.pi/6)/math.cos((i*math.tau/sides)%(math.pi/3)-math.pi/6) if hex_outer and r==outer else r)*math.sin(i*math.tau/sides),at.z+z)) for r in [outer,inner] for z in [-height*.5,height*.5] for i in range(sides)]
    faces=[]
    for i in range(sides):
        j=(i+1)%sides;faces.extend([(i,j,sides+j,sides+i),(2*sides+i,3*sides+i,3*sides+j,2*sides+j),(i,2*sides+i,2*sides+j,j),(sides+i,sides+j,3*sides+j,3*sides+i)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);return finish(obj,name,key,group)
def bored_ear(name,center,bolt_at,group):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center);obj=bpy.context.object;obj.dimensions=(plan['band_width_m'],plan['ear_outer_offset_m']-plan['ear_inner_offset_m'],plan['ear_thickness_m']);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel=obj.modifiers.new('Worked arris','BEVEL');bevel.width=.0004;bevel.segments=1;bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.0027,depth=.012,location=(bolt_at.x,bolt_at.y,center.z));tool=bpy.context.object
    bpy.context.view_layer.objects.active=obj;cut=obj.modifiers.new('Clear bolt bore','BOOLEAN');cut.operation='DIFFERENCE';cut.solver='EXACT';cut.object=tool;bpy.ops.object.modifier_apply(modifier=cut.name);bpy.data.objects.remove(tool,do_unlink=True)
    return finish(obj,name,'iron_blackened',group)

def solid_pin(name,at,radius,low,high,sides,key,group):
    vertices=[Vector((at.x+radius*math.cos(i*math.tau/sides),at.y+radius*math.sin(i*math.tau/sides),at.z+z)) for z in [low,high] for i in range(sides)]
    faces=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
    for i in range(sides):j=(i+1)%sides;faces.append((i,j,sides+j,sides+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);return finish(obj,name,key,group)

profiles=[];pipe_contacts=[]
for row in pipes:
    inner,owner=native_profile(row);outer=offset_profile(inner,plan['band_thickness_m']);profiles.append({'original':row,'native_profile_yz':[list(p) for p in inner],'pipe_owner':owner})
    for station,x in enumerate(plan.get('station_overrides',{}).get(row['id'],plan['stations_x'])):
        assert row['p0'][0]+.1<x<row['p1'][0]-.1
        group=row['id']+'_Hanger'+str(station);at=Vector((x,row['p0'][1],row['p0'][2]));band(group+'_UpperBand',at,inner,outer,1,group);band(group+'_LowerBand',at,inner,outer,-1,group)
        for side in [-1,1]:
            bolt_at=at+Vector((0,side*plan['bolt_offset_m'],0))
            for sign in [-1,1]:
                center=at+Vector((0,side*(plan['ear_inner_offset_m']+plan['ear_outer_offset_m'])*.5,sign*(plan['split_clearance_m']+plan['ear_thickness_m']*.5)))
                bored_ear(group+'_Ear'+str(side)+'_'+str(sign),center,bolt_at,group)
                washer(group+'_Washer'+str(side)+'_'+str(sign),bolt_at+Vector((0,0,sign*.00425)),.009,.0027,.0015,24,'iron_blackened',group)
            solid_pin(group+'_BoltShank'+str(side),bolt_at,.0025,-.009,.006,24,'brass_dull',group)
            solid_pin(group+'_HexHead'+str(side),bolt_at,.007,.005,.008,6,'brass_dull',group)
            # The closed static nut has a nominal bore matching the shaft;
            # sub-millimetre helical thread relief is intentionally unresolved.
            washer(group+'_HexNut'+str(side),bolt_at-Vector((0,0,.0065)),.007,.0025,.003,24,'brass_dull',group,True)
        rod_foot=at+Vector((0,0,max(p.y for p in outer)));fit(group,rod_foot,(0,0,1));contacts[-1]['pipe_id']=row['id'];contacts[-1]['center']=[at.x,at.z,-at.y]
        for i,(a,b) in enumerate(zip(inner,inner[1:]+inner[:1])):
            midpoint=(a+b)*.5;delta=b-a;normal=Vector((0,delta.y,-delta.x)).normalized()
            for dx in [-.008,0,.008]:pipe_contacts.append({'assembly':group,'owner':owner,'point':[at.x+dx,at.z+midpoint.y,-(at.y+midpoint.x)],'normal':[normal.x,normal.z,-normal.y]})
parts=[];inventory=[];fallbacks=0;total_triangles=0
for (group,key),objects in sorted(groups.items()):
    vertices=[];triangles=[]
    for obj in objects:
        obj.data.calc_loop_triangles();offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        triangles.extend(tuple(offset+i for i in tri.vertices) for tri in obj.data.loop_triangles)
    origin=Vector(tuple(round(sum(v[i] for v in vertices)/len(vertices),3) for i in range(3)))
    mesh=bpy.data.meshes.new(group+'__'+key);mesh.from_pydata([v-origin for v in vertices],[],triangles);mesh.update()
    uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
    for face in mesh.polygons:
        points=[mesh.vertices[mesh.loops[i].vertex_index].co for i in face.loop_indices]
        n,u,values,fallback=chart_for_triangle(points,origin,sets[key]['meters_per_tile']);fallbacks+=fallback
        for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
    obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;mesh.materials.append(materials[key]);parts.append(obj)
    total_triangles+=len(triangles);inventory.append({'name':mesh.name,'assembly':group,'key':key,'tile':sets[key]['meters_per_tile'],'triangles':len(triangles)})
construction.hide_render=True
# Imported context is a read-only fitting instrument, never duplicated in the shipped native.
for obj in list(context.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.data.collections.remove(context)
# Discard orphaned imported meshes/materials/images; the editable stocks keep
# their own two catalogue materials and real external shipping maps.
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
native=out/'art/blender/bar_pipe_supports.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.export_scene.gltf(filepath=str(out/'game/assets/props/bar_pipe_supports.glb'),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
runtime={'schema_version':1,'asset':'res://assets/props/bar_pipe_supports.glb','parts':[{k:row[k] for k in ['name','key','tile']} for row in inventory]}
(out/'game/data/orison_v2/bar_pipe_supports.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,root/'art/data/building_layout.json',Path(__file__),root/'art/blender/scripts/fabrication_uvs.py',root/'art/data/material_catalog.json',root/'game/data/runtime_material_sets.json',root/'game/assets/building/floor_01_cells/shop_bar.gltf',root/'game/assets/building/floor_01_cells/shop_bar.bin',root/'game/assets/building/floor_01_cells/shop_bar.gltf.import',root/'game/assets/props/bar_fixture_mounts.glb',root/'game/assets/props/bar_pipe_supports.glb.import']
for key in plan['runtime_keys']:bindings.extend(root/'game/assets/building/textures'/name for name in sets[key]['files'])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_pipes':pipes,'profiles':profiles,'pipe_contacts':pipe_contacts,'closed_stocks':stock_checks,'parts':inventory,'triangles':total_triangles,'contacts':[{**row,'fixture_endpoint':godot(row['fixture_endpoint']),'bearing':godot(row['bearing']),'direction':godot(row['direction'])} for row in contacts],'runtime':runtime,'precision_chart_fallbacks':fallbacks,'native_sha256':digest(native),'asset_sha256':digest(out/'game/assets/props/bar_pipe_supports.glb'),'source_bindings':{path.relative_to(root).as_posix():digest(path) for path in bindings},'open_work':plan['open_work']}
for path in ['art/blender/bar_pipe_supports_construction.json','game/tests/fixtures/orison_bar_pipe_supports.json']:(out/path).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('PIPE SUPPORT PROTOTYPE:',len(stocks),'closed stocks;',len(contacts),'supports;',len(parts),'partitions;',total_triangles,'triangles;',len(pipe_contacts),'pipe-bearing samples')
