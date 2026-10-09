"""Source-fitted street joints, coping, passage panels and finite damp patches."""
import hashlib,json,math,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def digest(p):
    raw=(ROOT/p).read_bytes()
    return hashlib.sha256(raw if Path(p).suffix in ['.blend','.glb','.png'] else raw.replace(b'\r\n',b'\n')).hexdigest()
plan=read('art/data/v2_import_resume_20261008/resume.json')['next_batch']
source=read(plan['source']);street=next(t for t in source['templates'] if t['id']==plan['template_id'])
rows={r['id']:r for r in street['boxes']}
for group in plan['records'].values():
    for r in group:assert rows[r['id']]==r
paving=read('game/tests/fixtures/orison_front_pavement_construction.json')
review=read('game/tests/fixtures/orison_front_pavement_review.json')
assert review['original_fixture_sha256']==digest('game/tests/fixtures/orison_front_pavement_construction.json')
door_z=review['blockout_projection']['door']['center'][1]
catalog=read('game/data/runtime_material_sets.json')['materials']
finishes={
 'joint':{'catalog_key':'concrete','tint':[.43,.42,.39,1],'normal':.12,'roughness':1.,'pigment':1.},
 'coping':{'catalog_key':'concrete','tint':[.92,.90,.84,1],'normal':.17,'roughness':.93,'pigment':1.},
 'panel':{'catalog_key':'concrete','tint':[1,1,1,1],'normal':.24,'roughness':1.,'pigment':1.},
 'damp':{'catalog_key':'concrete','tint':[.73,.76,.73,1],'normal':.12,'roughness':.32,'pigment':1.}}
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True;closed.hide_viewport=True
exports=bpy.data.collections.new('Exports');bpy.context.scene.collection.children.link(exports)
mats={k:material(ROOT,k,v,catalog) for k,v in finishes.items()}
wet=mats['damp'];n=wet.node_tree.nodes;l=wet.node_tree.links
color=n.new('ShaderNodeVertexColor');color.layer_name='Color'
mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=.72;l.new(color.outputs['Alpha'],mul.inputs[0]);l.new(mul.outputs[0],n['Principled BSDF'].inputs['Alpha'])
wet.surface_render_method='DITHERED'
stocks=[];records=[];contacts=[]
def solid(name,vertices,faces):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
    bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(name,mesh);closed.objects.link(obj);stocks.append(obj);return obj
def box(name,c,size,bevel=0):
    bm=bmesh.new();bmesh.ops.create_cube(bm,size=1)
    for v in bm.verts:v.co=Vector((c[0]+v.co.x*size[0],-c[2]-v.co.y*size[2],c[1]+v.co.z*size[1]))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
    if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=2,affect='EDGES')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.verts.ensure_lookup_table();bm.verts.index_update()
    obj=solid(name,[v.co[:] for v in bm.verts],[tuple(v.index for v in f.verts) for f in bm.faces]);bm.free();return obj
def emit(row,kind,objects):
    name=row['id'];obj=partition(exports,name,objects,finishes[kind],mats[kind],Matrix.Identity(4),catalog)
    # Local vertices keep metric charts accurate, while the node carries source placement.
    center=Vector((row['position_m'][0],-row['position_m'][2],0))
    for v in obj.data.vertices:v.co-=center
    obj.location=center
    points=[v.co+center for v in obj.data.vertices]
    record={'id':name,'kind':kind,'source':row,'stocks':len(objects),'triangles':len(obj.data.polygons),
        'bounds':[min(p.x for p in points),min(p.z for p in points),-max(p.y for p in points),max(p.x for p in points),max(p.z for p in points),-min(p.y for p in points)]}
    records.append(record);return obj
def supported(x,z):
    x,z=-x,door_z-z;a,b,c,d=paving['envelope']
    return a<x<c and b<z<d and not any(m['bounds'][0]<x<m['bounds'][2] and m['bounds'][1]<z<m['bounds'][3] for m in paving['masks'])
width=.007
cross=[r['position_m'][0] for r in plan['records']['pavement_joints'] if 'cross' in r['id']]
for row in plan['records']['pavement_joints']:
    x,y,z=row['position_m'];sx,sy,sz=row['size_m'];along=0 if sx>sz else 2
    center=x if along==0 else z;length=sx if along==0 else sz;lo,hi=center-length/2,center+length/2
    stations={lo,hi}
    for m in paving['masks']:
        values=m['bounds'][::2] if along==0 else m['bounds'][1::2]
        stations.update(-v if along==0 else door_z-v for v in values)
    if along==0:stations.update(v+d for v in cross for d in [-width/2,width/2])
    cuts=sorted(v for v in stations if lo<=v<=hi);pieces=[]
    for a,b in zip(cuts,cuts[1:]):
        if b-a<.0001:continue
        middle=(a+b)/2;px=middle if along==0 else x;pz=z if along==0 else middle
        if along==0 and any(abs(middle-v)<width/2-1e-7 for v in cross):continue
        if not all(supported(px+dx,pz+dz) for dx,dz in [(-width/2,0),(width/2,0),(0,-width/2),(0,width/2)]):continue
        pieces.append(box(row['id']+'_strip', [px,-.001,pz],[b-a,.0028,width] if along==0 else [width,.0028,b-a]))
        contacts.append({'id':row['id'],'point':[px,0,pz],'owner':'front_pavement'})
    assert pieces,row['id'];emit(row,'joint',pieces)
caps=plan['records']['curb_coping']
for i,row in enumerate(caps):
    x,y,z=row['position_m'];sx,sy,sz=row['size_m']
    lo=x-sx/2 if i==0 else (caps[i-1]['position_m'][0]+x)/2+.002
    hi=x+sx/2 if i==len(caps)-1 else (x+caps[i+1]['position_m'][0])/2-.002
    curb=rows['street_curb'];hi=min(hi,curb['position_m'][0]+curb['size_m'][0]/2)
    pieces=[]
    for j in range(4):
        a=lo+(hi-lo)*j/4+(.002 if j else 0);b=lo+(hi-lo)*(j+1)/4-(.002 if j<3 else 0)
        pieces.append(box(row['id']+f'_{j}',[(a+b)/2,.13625,z],[b-a,.0325,sz],.0012))
        contacts.extend({'id':row['id'],'point':[v,.12,z],'owner':'street_curb'} for v in [a+.04,(a+b)/2,b-.04])
    emit(row,'coping',pieces)
for row in plan['records']['passage_paving']:
    x,y,z=row['position_m'];sx,sy,sz=row['size_m'];nx=math.ceil(sx/1.5);nz=math.ceil(sz/1.5);pieces=[]
    for ix in range(nx):
        for iz in range(nz):
            x0=x-sx/2+sx*ix/nx;x1=x-sx/2+sx*(ix+1)/nx;z0=z-sz/2+sz*iz/nz;z1=z-sz/2+sz*(iz+1)/nz
            a=x0+(.0015 if ix else 0);b=x1-(.0015 if ix<nx-1 else 0);c=z0+(.0015 if iz else 0);d=z1-(.0015 if iz<nz-1 else 0)
            pieces.append(box(row['id']+f'_{ix}_{iz}',[(a+b)/2,-.004,(c+d)/2],[b-a,.008,d-c],.0008))
            contacts.append({'id':row['id'],'point':[(a+b)/2,0,(c+d)/2],'owner':row['id']})
    emit(row,'panel',pieces)
for index,row in enumerate(plan['records']['wet_surface_patches']):
    x,y,z=row['position_m'];sx,sy,sz=row['size_m'];count=96;verts=[]
    curb=rows['street_curb'];inner=curb['position_m'][2]-curb['size_m'][2]/2
    sz=min(sz,2*(inner-z-.012));assert sz>0
    def radius(a):return .88+.055*math.sin(a*5+index)+.035*math.cos(a*9+.8*index)+.025*math.sin(a*13)
    for height,scale in [(.0012,.70),(.0012,1.),(.0002,1.)]:
        for i in range(count):
            a=i*math.tau/count;r=radius(a)*scale;verts.append((x+sx*.5*r*math.cos(a),-z-sz*.5*r*math.sin(a),height))
    faces=[tuple(reversed(range(count))),tuple(range(2*count,3*count))]
    for ring in range(2):faces.extend((ring*count+i,ring*count+(i+1)%count,(ring+1)*count+(i+1)%count,(ring+1)*count+i) for i in range(count))
    obj=emit(row,'damp',[solid(row['id']+'_film',verts,faces)])
    colors=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    for i,v in enumerate(obj.data.vertices):
        px,pz=v.co.x/(sx*.5),-v.co.y/(sz*.5);a=math.atan2(pz,px);r=math.hypot(px,pz)/radius(a)
        fade=max(0,min(1,(1-r)/.3));fade=fade*fade*(3-2*fade)
        colors.data[i].color=(1,1,1,fade)
    obj.data.color_attributes.active_color=colors
result=export(ROOT,'street_paving_details',exports)
source_paths=[plan['source'],'game/data/runtime_material_sets.json','game/tests/fixtures/orison_front_pavement_construction.json','game/tests/fixtures/orison_front_pavement_review.json','art/blender/scripts/build_street_paving_details.py','art/blender/scripts/fabrication_native_batch.py']
report={'schema':'orison.street-paving-details.v1','evidence_class':'INERT','source_bindings':{p:digest(p) for p in source_paths},
    'asset_sha256':digest('game/assets/props/street_paving_details.glb'),'runtime':{'asset':'res://assets/props/street_paving_details.glb'},
    'parts':records,'contacts':contacts,'finishes':finishes,'triangles':result['triangles'],'stocks':len(stocks),
    'adaptations':['7mm seams clipped to fitted paving, seated at +0.4mm; original 35mm proxy removed visually.',
        'Coping lower face seats on original +0.12m curb. Internal 70mm proxy gaps become 4mm stone joints. The east 640mm unsupported source overhang is clipped to the retained curb end.',
        'Passage panels have 3mm joints and 0.8mm arrises within original floor extents. Original full floor collision remains.',
        'Finite irregular damp films use vertex edge fade within original patch envelopes. No liquid/service simulation.'],
    'preservation':'Only 20 original environment draws hidden. Collision, route guides, lights and source records remain original.'}
for p in ['art/blender/street_paving_details_construction.json','game/tests/fixtures/orison_street_paving_details.json']:
    (ROOT/p).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('STREET DETAIL:',len(records),'parts',len(stocks),'closed stocks',result)

runtime={'schema_version':1,'source_geometry_sha256':digest(plan['source']),'finishes':finishes,'parts':[{'id':r['id'],'kind':r['kind']} for r in records]}
(ROOT/'game/data/orison_v2/street_paving_details.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
