"""Fit the missing fixed shop frame and upper lights to actual retained panes.

ExteriorCell keeps its doorway, three original panes, facade and simulation.
Closed construction is subtracted around their actual volumes; the installed
skin omits paired contacts, with metre UVs and fixed triangle collision.
"""
from pathlib import Path
import collections, hashlib, json, math
import bpy, bmesh, numpy as np
from mathutils import Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan_path=ROOT/'art/data/bodega_frontage/source_plan.json'
geometry_path=ROOT/'game/data/orison_v2/exterior/exterior_geometry.json'
regions_path=ROOT/'game/data/orison_v2/exterior/regions.json'
door_path=ROOT/'game/scripts/props/door_prop.gd'
plan=json.loads(plan_path.read_text());geometry=json.loads(geometry_path.read_text())
template=next(t for t in geometry['templates'] if t['id']=='TEMPLATE_BODEGA_CELL_V1')
rows={r['id']:r for r in template['boxes']}
door=next(r for r in template['doors'] if r['surface_id']=='threshold')
assert door['width_m']==.95 and door['height_m']==2.1 and not door['swing_out']
assert plan['classification']=='ADAPTATION'
door_source=door_path.read_text()
assert 'Vector3(0.13, height - 0.02, 0.055)' in door_source
assert 'for y in [0.065, 0.78, height - 0.065]:' in door_source

def bounds(row):
    assert row['yaw_degrees']==0
    p=row['position_m'];s=row['size_m']
    return [round(p[i]-s[i]/2,12) for i in range(3)]+[round(p[i]+s[i]/2,12) for i in range(3)]

retained_ids=['facade_left_pier','facade_right_pier','facade_head','left_bulkhead',
              'right_bulkhead','left_store_glass','right_store_glass','front_transom','threshold_sill']
retained=[{'owner':key,'bounds':bounds(rows[key])} for key in retained_ids]
head=bounds(rows['facade_head']);transom=bounds(rows['front_transom'])
left=bounds(rows['left_store_glass']);right=bounds(rows['right_store_glass'])
outer=[bounds(rows['facade_left_pier'])[3],bounds(rows['facade_right_pier'])[0]]
old_jambs=[bounds(rows['left_window_bar']),bounds(rows['right_window_bar'])]
inner=door['width_m']/2+plan['jamb_leaf_clearance']
outer_jamb=max(abs(old_jambs[0][0]),abs(old_jambs[1][3]))
frame_low=bounds(rows['threshold_sill'])[4]
back=plan['frame_back'];front=plan['frame_front'];top=head[1]
glass_front=left[5]
assert abs(glass_front-right[5])<1e-8 and abs(glass_front-transom[5])<1e-8
pieces=[]

def add(identity,x0,x1,y0,y1,z0,z1,key='wood',grain=1):
    if min(x1-x0,y1-y0,z1-z0)>1e-8:
        pieces.append({'id':identity,'bounds':[round(v,12) for v in [x0,y0,z0,x1,y1,z1]],'key':key,'grain_axis':grain})

for side in [-1,1]:
    lo,hi=(-outer_jamb,-inner) if side<0 else (inner,outer_jamb)
    add('DoorJamb'+str(side),lo,hi,frame_low,top-plan['upper_header'],back,front)
add('DoorTransomRail',-inner,inner,door['height_m'],transom[1],back,front,grain=0)
add('DoorTransomHead',-inner,inner,transom[4],top-plan['upper_header'],back,front,grain=0)
add('ContinuousHeader',outer[0],outer[1],top-plan['upper_header'],top,back,front,grain=0)
new_glass=[]
for side,pane in [(-1,left),(1,right)]:
    lo,hi=(outer[0],-outer_jamb) if side<0 else (outer_jamb,outer[1])
    base=pane[4];rail=base+plan['lower_upperlight_rail'];upper=top-plan['upper_header']
    add('UpperlightRail'+str(side),lo,hi,base,rail,back,front,grain=0)
    new={'id':'Upperlight'+str(side),'bounds':[lo,rail,glass_front-plan['new_glass_thickness'],hi,upper,glass_front]}
    new_glass.append(new)
    add(new['id'],lo,hi,rail,upper,new['bounds'][2],glass_front,'glass')
    for identity,a,b,c,d in [('RetainedDisplay',lo,hi,pane[1],pane[4]),('Upperlight',lo,hi,rail,upper)]:
        bead=plan['bead_width'];depth=plan['bead_depth']
        for face,z0,z1 in [('Front',glass_front,glass_front+depth),
                            ('Back',pane[2]-depth,pane[2]) if identity=='RetainedDisplay'
                            else ('Back',new['bounds'][2]-depth,new['bounds'][2])]:
            add(identity+face+'Left'+str(side),a,a+bead,c,d,z0,z1)
            add(identity+face+'Right'+str(side),b-bead,b,c,d,z0,z1)
            add(identity+face+'Bottom'+str(side),a+bead,b-bead,c,c+bead,z0,z1,grain=0)
            add(identity+face+'Top'+str(side),a+bead,b-bead,d-bead,d,z0,z1,grain=0)

def subtract(box,mask):
    lo=[max(box[i],mask[i]) for i in range(3)];hi=[min(box[i+3],mask[i+3]) for i in range(3)]
    if any(hi[i]<=lo[i]+1e-9 for i in range(3)):return [box]
    a,b,c,d,e,f=box;x,y,z,u,v,w=lo+hi
    return [r for r in [[a,b,c,x,e,f],[u,b,c,d,e,f],[x,b,c,u,y,f],[x,v,c,u,e,f],[x,y,c,u,v,z],[x,y,w,u,v,f]]
            if all(r[i+3]-r[i]>1e-9 for i in range(3))]

source_pieces=pieces;pieces=[]
for row in source_pieces:
    clipped=[row['bounds']]
    for mask in retained:
        clipped=[piece for box in clipped for piece in subtract(box,mask['bounds'])]
    pieces.extend({**row,'id':row['id']+'__'+str(index),'bounds':box} for index,box in enumerate(clipped))
for index,a in enumerate(pieces):
    for b in pieces[index+1:]:
        assert not all(min(a['bounds'][i+3],b['bounds'][i+3])-max(a['bounds'][i],b['bounds'][i])>1e-9 for i in range(3)),(a['id'],b['id'])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
materials={}
mat=bpy.data.materials.new(plan['wood_key']);mat.use_nodes=True
node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Roughness'].default_value=.5
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
spec=sets[plan['wood_key']]
uv=bpy.data.materials[mat.name].node_tree.nodes.new('ShaderNodeTexCoord')
scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/(spec['meters_per_tile']*plan['wood_scale_multiplier'])
mat.node_tree.links.new(uv.outputs['UV'],scale.inputs[0])
for index,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
    image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
    image.filepath=bpy.path.relpath(image.filepath,start=str(ROOT/'art/blender'))
    if index:image.colorspace_settings.name='Non-Color'
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
    mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
    if index==0:
        tint=mat.node_tree.nodes.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1;tint.inputs[2].default_value=plan['wood_tint']
        mat.node_tree.links.new(tex.outputs['Color'],tint.inputs[1]);mat.node_tree.links.new(tint.outputs[0],node.inputs[target])
    elif index==1:
        factor=mat.node_tree.nodes.new('ShaderNodeMath');factor.operation='MULTIPLY';factor.inputs[1].default_value=spec['roughness_multiplier']
        mat.node_tree.links.new(tex.outputs['Color'],factor.inputs[0]);mat.node_tree.links.new(factor.outputs[0],node.inputs[target])
    else:
        normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35
        mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
materials['wood']=mat
glass=bpy.data.materials.new('glass');glass.use_nodes=True
gn=glass.node_tree.nodes['Principled BSDF'];gn.inputs['Base Color'].default_value=(.9,.95,.92,1);gn.inputs['Transmission Weight'].default_value=1.;gn.inputs['Roughness'].default_value=.06;gn.inputs['IOR'].default_value=1.5
materials['glass']=glass

def inside(p,box):return all(box[i]-1e-10<p[i]<box[i+3]+1e-10 for i in range(3))
def to_blender(p):return (p[0],-p[2],p[1])
def face_uv(p,normal,grain):
    n=Vector(normal);seed=Vector([1 if i==grain else 0 for i in range(3)])
    if abs(n.dot(seed))>.9:seed=Vector((0,0,1)) if grain!=2 else Vector((1,0,0))
    # The retained quartered-oak map runs longitudinally along texture V.
    # Carry that direction along each stile, rail and panel, at metre scale.
    v=(seed-n*seed.dot(n)).normalized();u=v.cross(n)
    return (Vector(p).dot(u),Vector(p).dot(v))

face_normals=[]
def make_mesh(name,polygons,key,collection,origin,grains,closed_source=False):
    vertices=[];faces=[];normals=[]
    for polygon in polygons:
        first=len(vertices);vertices.extend(tuple(to_blender(p)[i]-origin[i] for i in range(3)) for p in polygon)
        faces.append(tuple(range(first,first+len(polygon))))
        p=[Vector(v) for v in polygon];normals.append((p[1]-p[0]).cross(p[2]-p[0]).normalized())
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh)
    if closed_source:
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-9)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>1e-12
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);obj.location=origin;mesh.materials.append(materials[key])
    chart=mesh.uv_layers.new(name='Metres');chart.active_render=True
    for index,face in enumerate(mesh.polygons):
        # The mesh normals are outward; derive the Godot-frame chart directly.
        n=face.normal;normal=Vector((n.x,n.z,-n.y))
        for loop in face.loop_indices:
            b=Vector(origin)+mesh.vertices[mesh.loops[loop].vertex_index].co;p=(b.x,b.z,-b.y)
            chart.data[loop].uv=face_uv(p,normal,grains[index])
    return obj

# Each native counterpart remains individually closed and positive.
for row in pieces:
    box=row['bounds'];a,b,c,d,e,f=box
    verts=[(x,y,z) for x in [a,d] for y in [b,e] for z in [c,f]]
    faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    origin=tuple(round(v,3) for v in to_blender([(a+d)/2,(b+e)/2,(c+f)/2]))
    obj=make_mesh(row['id'],[[verts[i] for i in face] for face in faces],row['key'],closed,origin,[row['grain_axis']]*6,True);obj.hide_render=True

# Exact planar boundary cells. Splitting only at authored faces prevents
# partial contact faces from being wrongly discarded by a centroid shortcut.
axes=[sorted({row['bounds'][j] for row in pieces+retained for j in [i,i+3]}) for i in range(3)]
groups=collections.defaultdict(list);omitted=0
for row in pieces:
    box=row['bounds']
    for axis in range(3):
        rest=[i for i in range(3) if i!=axis]
        us=[v for v in axes[rest[0]] if box[rest[0]]-1e-9<=v<=box[rest[0]+3]+1e-9]
        vs=[v for v in axes[rest[1]] if box[rest[1]]-1e-9<=v<=box[rest[1]+3]+1e-9]
        for sign in [-1,1]:
            at=box[axis+(3 if sign>0 else 0)]
            for u0,u1 in zip(us,us[1:]):
                for v0,v1 in zip(vs,vs[1:]):
                    p=[0.,0.,0.];p[axis]=at+sign*1e-7;p[rest[0]]=(u0+u1)/2;p[rest[1]]=(v0+v1)/2
                    if any(inside(p,other['bounds']) for other in pieces if other is not row) or any(inside(p,other['bounds']) for other in retained):omitted+=1;continue
                    corners=[]
                    for u,v in [(u0,v0),(u1,v0),(u1,v1),(u0,v1)]:
                        q=[0.,0.,0.];q[axis]=at;q[rest[0]]=u;q[rest[1]]=v;corners.append(q)
                    normal=(Vector(corners[1])-Vector(corners[0])).cross(Vector(corners[2])-Vector(corners[0]))
                    if normal[axis]*sign<0:corners.reverse()
                    groups[row['key']].append((corners,row['grain_axis']))
draws=[];inventory=[];triangles=0
for key,faces in sorted(groups.items()):
    polygons=[p for p,grain in faces];points=[p for polygon in polygons for p in polygon]
    origin=tuple(round(v,3) for v in to_blender([sum(p[i] for p in points)/len(points) for i in range(3)]))
    obj=make_mesh('Frontage__'+materials[key].name,polygons,key,bpy.context.scene.collection,origin,[grain for p,grain in faces])
    obj.data.calc_loop_triangles();count=len(obj.data.loop_triangles);triangles+=count;draws.append(obj)
    inventory.append({'name':obj.name,'key':materials[key].name,'triangles':count})
# The original storefront carcass left this lower field empty. This closed,
# raised timber panel fits between its actual stiles and rails, inside the
# existing leaf's physical envelope. Its rigid parent receives the original
# hinge pose at runtime; no second moving body or interaction is exported.
panel=[plan['leaf_stile'],plan['leaf_bottom_rail'],-plan['leaf_panel_thickness']/2,
       door['width_m']-plan['leaf_stile'],plan['leaf_lock_rail_center']-plan['leaf_lock_rail']/2,plan['leaf_panel_thickness']/2]
panel_polygons=[]
def ring(inset,z):
    a,b,c,d,e,f=panel
    return [[a+inset,b+inset,z],[d-inset,b+inset,z],[d-inset,e-inset,z],[a+inset,e-inset,z]]
for face in [-1,1]:
    rings=[ring(0,face*panel[5]),ring(plan['leaf_panel_rim'],face*panel[5]),
           ring(plan['leaf_panel_rim']+plan['leaf_panel_bevel'],face*(panel[5]+plan['leaf_panel_raise']))]
    for first,second in zip(rings,rings[1:]):
        for i in range(4):panel_polygons.append([first[i],first[(i+1)%4],second[(i+1)%4],second[i]])
    panel_polygons.append(rings[-1])
for i in range(4):
    lo=ring(0,panel[2]);hi=ring(0,panel[5]);panel_polygons.append([lo[i],lo[(i+1)%4],hi[(i+1)%4],hi[i]])
origin=tuple(round(v,3) for v in to_blender([door['width_m']/2,(panel[1]+panel[4])/2,0]))
native_panel=make_mesh('ClosedLeafPanel',panel_polygons,'wood',closed,origin,[1]*len(panel_polygons),True);native_panel.hide_render=True
leaf_parent=bpy.data.objects.new('LeafInfill',None);bpy.context.scene.collection.objects.link(leaf_parent)
leaf_parent.location=to_blender([-door['width_m']/2,0,door['offset_uvn_m'][2]])
leaf_draw=bpy.data.objects.new('LeafPanel__'+plan['wood_key'],native_panel.data.copy());bpy.context.scene.collection.objects.link(leaf_draw)
leaf_draw.location=origin;leaf_draw.parent=leaf_parent;draws.append(leaf_draw)
leaf_draw.data.calc_loop_triangles();leaf_triangles=len(leaf_draw.data.loop_triangles);triangles+=leaf_triangles
inventory.append({'name':leaf_draw.name,'key':plan['wood_key'],'triangles':leaf_triangles,'owner':'original_hinged_leaf'})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bodega_frontage.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
leaf_parent.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=ROOT/'game/assets/props/bodega_frontage.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True)
manifest={'evidence_class':'INERT','classification':'ADAPTATION','parts':inventory,'triangles':triangles,
          'closed_native_pieces':len(pieces)+1,
          'closed_pieces':pieces,'retained':retained,'new_glass':new_glass,'omitted_contact_cells':omitted,
          'door_clear_width':inner*2,'door_clear_height':door['height_m'],
          'leaf_panel_bounds':panel,'leaf_panel_triangles':leaf_triangles,'leaf_panel_raise':plan['leaf_panel_raise'],
          'wood_key':plan['wood_key'],'wood_tint':plan['wood_tint'],'wood_scale_multiplier':plan['wood_scale_multiplier'],
          'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),
          'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [plan_path,geometry_path,regions_path,door_path]},
          'open_work':plan['open_work']}
for path in ['art/blender/bodega_frontage_construction.json','game/tests/fixtures/orison_bodega_frontage.json']:
    (ROOT/path).write_text(json.dumps(manifest,indent=2)+'\n',newline='\n')
print('BODEGA FRONTAGE',len(pieces),'closed pieces;',len(draws),'draws;',triangles,'triangles;',omitted,'omitted contact cells')
