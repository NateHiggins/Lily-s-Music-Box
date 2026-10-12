"""Native stock for the eighteen active receivers; gameplay stays Godot-owned.

Authored profile silhouettes/pivots are retained. Cabinet stock is hollow,
speakers have real shells/supports, controls are separate moving stock. Museum
references inform form only; no photographs or lettering are baked into maps.
"""
from pathlib import Path
import ast,collections,hashlib,json,math
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-active-media-20261012';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
materials={k:bpy.data.materials.new(k) for k in ['wood_dark','oak_quartered','bakelite_black','iron_blackened','brass_dull','linen','leather_worn','paper','enamel_appliance','rubber_aged','glassish']}
for m in materials.values():m.use_nodes=True
helper=ROOT/'art/blender/scripts/build_electrical_service.py'
tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'point','cube','cylinder','cut','ring','finish'}],type_ignores=[]),str(helper),'exec'))
stock_finish=finish
def finish(name,objects,key,bevel=.0005):
    obj=stock_finish(name,objects,key,bevel)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return obj
families={};speakers={};parts=[];current=[];prefix=''
def stock(label,objects,key,bevel=.0006,component='Body'):
    obj=finish(prefix+'_'+label,objects,key,bevel)
    obj['component']=component;current.append(obj);return obj
def box(label,size,at,key,bevel=.0006,component='Body'):
    return stock(label,[cube(size,at)],key,bevel,component)
def axial(label,r,h,at,key,axis='z',component='Body',bevel=.0003):
    obj=cylinder(r,h,at)
    if axis=='z':obj.rotation_euler.x=math.pi/2
    elif axis=='x':obj.rotation_euler.y=math.pi/2
    return stock(label,[obj],key,bevel,component)
def band(label,r,inside,h,at,key,axis='z',component='Body'):
    obj=ring(r,inside,h,at)
    if axis=='z':obj.rotation_euler.x=math.pi/2
    elif axis=='x':obj.rotation_euler.y=math.pi/2
    return stock(label,[obj],key,.00015,component)
def wire(label,points,r,key):
    path=[Vector(p) for p in points];n=12;vertices=[]
    for i,p in enumerate(path):
        tangent=(path[min(i+1,len(path)-1)]-path[max(i-1,0)]).normalized()
        axis=Vector((0,1,0)) if abs(tangent.y)<.95 else Vector((0,0,1))
        u=tangent.cross(axis).normalized();v=tangent.cross(u).normalized()
        for j in range(n):vertices.append(point(p+r*(u*math.cos(j*2*math.pi/n)+v*math.sin(j*2*math.pi/n))))
    faces=[tuple(reversed(range(n))),tuple(range((len(path)-1)*n,len(path)*n))]
    for i in range(len(path)-1):
        for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    mesh=bpy.data.meshes.new(label);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(obj)
    return stock(label,[obj],key,0)
def cabinet(w,h,d,key):
    t=.0018 if key=='enamel_appliance' else .004 if key=='bakelite_black' else .006
    box('Bottom',(w,t,d),(0,t/2,0),key)
    box('Top',(w,t,d),(0,h-t/2,0),key,component='Cover')
    for side in [-1,1]:box('Side'+str(side),(t,h-2*t,d),(side*(w-t)/2,h/2,0),key)
    box('Back',(w-2*t,h-2*t,t),(0,h/2,d/2-t/2),key,component='Back')
    box('ControlPanel',(w-2*t,h-2*t,.008),(0,h/2,-d/2-.002),'bakelite_black')
def dial(x,y,z,r,label):
    axial(label+'Scale',r,.002,(x,y,z),'paper')
    band(label+'Bezel',r+.002,r,.003,(x,y,z-.001),'brass_dull')
    for i in range(21):
        angle=math.radians(-135+i*13.5);at=(x+math.sin(angle)*r*.84,y+math.cos(angle)*r*.84,z-.0016)
        tick=box(label+'Tick'+str(i),(.0006,.004 if i%5 else .007,.0004),at,'bakelite_black',0)
        # finish already moves the origin to zero. Rotate the tick around its
        # own centre before baking that transform into the assembled stock.
        center=Vector(point(at));rot=mathutils_rotation(angle)
        for v in tick.data.vertices:v.co=center+rot@(v.co-center)
def mathutils_rotation(angle):
    from mathutils import Matrix
    return Matrix.Rotation(angle,3,'Y')
def knob(x,y,z,label,moving=False):
    axial(label+'Spindle',.005,.035,(x,y,z+.006),'brass_dull')
    component='Tuning' if moving else 'Body'
    grip=axial(label+'Grip',.022,.025,(x,y,z),'bakelite_black',component=component)
    # Radial flutes are geometry, including their UVs after final triangulation.
    for v in grip.data.vertices:
        dx=v.co.x-x;dy=v.co.z-y;r=math.hypot(dx,dy)
        if r>.020:
            scale=1-.00065*(.5+.5*math.cos(math.atan2(dy,dx)*32))/r
            v.co.x=x+dx*scale;v.co.z=y+dy*scale
    box(label+'Index',(.001,.010,.001),(x,y+.009,z-.013),'brass_dull',.0001,component)

specs={'three_dial_battery':(.48,.23,.24,'wood_dark'),'marconiphone_v2':(.45,.24,.28,'wood_dark'),
       'atwater_kent_44':(.55,.19,.27,'enamel_appliance'),'radiola_table':(.58,.33,.25,'wood_dark'),
       'crosley_pup':(.18,.19,.13,'bakelite_black'),'portable_four_valve':(.39,.25,.18,'leather_worn')}
for family,(w,h,d,key) in specs.items():
    prefix=family;current=[]
    cabinet(w,h,d,key)
    if family in ['three_dial_battery','marconiphone_v2']:
        xs=[-.145,0,.145] if family=='three_dial_battery' else [-.12,0,.12]
        for i,x in enumerate(xs):dial(x,.155 if family=='three_dial_battery' else .145,-d/2-.016,.052 if family=='three_dial_battery' else .045,'Dial'+str(i))
        for i,x in enumerate([xs[0],xs[-1]]):knob(x,.075 if family=='three_dial_battery' else .062,-.142 if family=='three_dial_battery' else -.158,'Knob'+str(i),i==0)
        for i,x in enumerate([-.16,.16]):axial('BindingTerminal'+str(i),.009,.018,(x,h+.009,.08),'brass_dull',axis='y')
        if family=='marconiphone_v2':box('ProvenanceTag',(.066,.018,.002),(.07,.015,-.149),'paper',.0001,'Tag')
        for i,x in enumerate([-.13,0,.13]):
            axial('ValveSeat'+str(i),.025,.014,(x,.045,.040),'bakelite_black',axis='y')
            axial('ValveEnvelope'+str(i),.022,.11,(x,.107,.040),'glassish',axis='y')
            axial('ValvePlate'+str(i),.010,.075,(x,.105,.040),'iron_blackened',axis='y')
    elif family=='atwater_kent_44':
        box('DialWindow',(.31,.040,.004),(0,.135,-.148),'paper')
        for i,x in enumerate([-.19,.19,0]):knob(x,.063,-.149,'Knob'+str(i),i==0)
        # Open folded slots, not dark stripes painted on an unbroken lid.
        top=current[1]
        for i in range(9):cut(top,cube((.003,.020,.13),(-.12+i*.03,.187,.025)))
        box('ChassisTray',(.47,.012,.21),(0,.020,0),'iron_blackened')
        for i,x in enumerate([-.15,0,.15]):
            axial('ValveSeat'+str(i),.025,.014,(x,.038,.060),'bakelite_black',axis='y')
            axial('ValveEnvelope'+str(i),.022,.11,(x,.100,.060),'glassish',axis='y')
            axial('ValvePlate'+str(i),.010,.075,(x,.100,.060),'iron_blackened',axis='y')
        for i in range(12):box('TuningGang'+str(i),(.085,.066,.001),(0,.075,-.065+i*.003),'brass_dull',.0001)
    elif family=='radiola_table':
        box('SpeakerCloth',(.50,.19,.003),(0,.215,-.132),'linen')
        for x in [-.252,.250]:box('SpeakerBead'+str(x),(.003,.192,.004),(x,.215,-.135),'brass_dull')
        box('Scale',(.42,.052,.002),(0,.085,-.139),'paper')
        for i,x in enumerate([-.18,.18]):knob(x,.055,-.143,'Knob'+str(i),i==0)
    elif family=='crosley_pup':
        dial(0,.115,-.071,.055,'Dial')
        for i,x in enumerate([-.052,.052]):knob(x,.048,-.077,'Knob'+str(i),i==0)
        axial('ValveBase',.025,.010,(0,.196,0),'bakelite_black',axis='y')
        axial('ValveEnvelope',.023,.075,(0,.235,0),'glassish',axis='y')
        axial('ValvePlate',.011,.045,(0,.235,0),'iron_blackened',axis='y')
        box('InventoryTag',(.032,.010,.001),(0,.014,-.070),'paper',.0001,'Tag')
    elif family=='portable_four_valve':
        box('SpeakerCloth',(.35,.19,.003),(0,.13,-.102),'linen')
        box('Handle',(.20,.025,.025),(0,.285,0),'rubber_aged')
        for x in [-.10,.10]:box('HandleSeat'+str(x),(.025,.065,.025),(x,.265,0),'brass_dull')
        for i,x in enumerate([-.13,.13]):knob(x,.065,-.111,'Knob'+str(i),i==0)
    families[family]=current

for family in ['crystal_set','homebrew_regenerative']:
    prefix=family;current=[]
    if family=='crystal_set':
        box('OakBase',(.34,.055,.23),(0,.0275,0),'oak_quartered')
        cabinet_obj=box('Tuner',(.17,.11,.12),(-.055,.105,0),'bakelite_black')
        dial(-.055,.115,-.066,.043,'Dial')
        for i,x in enumerate([-.145,.115,.155]):axial('BindingPost'+str(i),.013,.045,(x,.09,.07),'brass_dull',axis='y')
        wire('Whisker',[(.095,.075,-.025),(.055,.155,-.025),(.145,.075,-.025)],.002,'brass_dull')
        axial('DetectorCup',.027,.042,(.145,.075,-.025),'brass_dull',axis='y')
    else:
        box('Base',(.50,.045,.29),(0,.0225,0),'wood_dark')
        box('Panel',(.47,.19,.030),(0,.125,-.115),'bakelite_black')
        for i,x in enumerate([-.14,0,.14]):
            dial(x,.145,-.135,.047,'Dial'+str(i))
            axial('ValveBase'+str(i),.031,.025,(x,.065,.055),'bakelite_black',axis='y')
            axial('ValveEnvelope'+str(i),.023,.085,(x,.105,.055),'glassish',axis='y')
            axial('ValvePlate'+str(i),.010,.052,(x,.105,.055),'iron_blackened',axis='y')
        for i,x in enumerate([-.19,.19]):axial('BindingPost'+str(i),.009,.045,(x,.065,.08),'brass_dull',axis='y')
        axial('CoilFormer',.0405,.108,(-.205,.099,0),'wood_dark',axis='y')
        points=[(-.205+.043*math.sin(i*2*math.pi/32),.065+.012*i/32,.043*math.cos(i*2*math.pi/32)) for i in range(7*32+1)]
        wire('Coil',points,.0025,'brass_dull')
    families[family]=current

prefix='headphones';current=[]
for i,x in enumerate([.17,.255]):
    axial('Earcup'+str(i),.031,.018,(x,.03,0),'bakelite_black',axis='y')
    band('Cushion'+str(i),.028,.018,.006,(x,.022,0),'rubber_aged',axis='y')
wire('Headband',[(.22+.055*math.cos(t*math.pi/24),.035,-.010-.082*math.sin(t*math.pi/24)) for t in range(25)],.004,'rubber_aged')
wire('ClothLead',[(.17,.02,.01),(.12,.01,.075),(.03,.01,.075),(-.04,.05,.075)],.0025,'linen')
speakers[prefix]=current

def shell(label,profile,at,key):
    n=64;vertices=[]
    for radius,z in profile:
        for i in range(n):vertices.append(point((at[0]+radius*math.cos(i*2*math.pi/n),at[1]+radius*math.sin(i*2*math.pi/n),at[2]+z)))
    faces=[]
    for j in range(len(profile)):
        following=(j+1)%len(profile)
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,following*n+(i+1)%n,following*n+i))
    mesh=bpy.data.meshes.new(label);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(obj)
    return stock(label,[obj],key,0)
for speaker in ['cone','horn']:
    prefix=speaker;current=[];x=-.38 if speaker=='cone' else .37
    box('Foot',(.13,.016,.15),(x,.008,.015),'iron_blackened')
    axial('Pedestal',.009,.17,(x,.10,.06),'iron_blackened',axis='y')
    axial('Drive',.028,.05,(x,.20,.06),'iron_blackened')
    if speaker=='cone':
        shell('PaperCone',[(.020,.035),(.138,-.040),(.1365,-.040),(.0185,.035)],(x,.20,0),'bakelite_black')
        band('Rim',.145,.138,.009,(x,.20,-.040),'iron_blackened')
        axial('CentreCap',.020,.006,(x,.20,.034),'brass_dull')
        vertices=[];faces=[];nx=8;ny=6
        for layer in range(2):
            for j in range(ny+1):
                for i in range(nx+1):
                    dx=-.020+.040*i/nx;dy=.066+.040*j/ny
                    z=.035-(math.hypot(dx,dy)-.0185)*.075/.118-.0002-layer*.0008
                    vertices.append(point((x+dx,.20+dy,z)))
        count=(nx+1)*(ny+1)
        for layer in range(2):
            for j in range(ny):
                for i in range(nx):
                    a=layer*count+j*(nx+1)+i
                    face=(a,a+1,a+nx+2,a+nx+1);faces.append(face if layer else tuple(reversed(face)))
        boundary=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
        for a,b in zip(boundary,boundary[1:]+boundary[:1]):faces.append((a,b,b+count,a+count))
        mesh=bpy.data.meshes.new('FittedRepairPatch');mesh.from_pydata(vertices,[],faces);mesh.update()
        patch=bpy.data.objects.new('FittedRepairPatch',mesh);bpy.context.collection.objects.link(patch)
        stock('FittedRepairPatch',[patch],'linen',0,'Repair')
    else:
        shell('Horn',[(.026,.070),(.045,.035),(.075,-.025),(.160,-.115),(.157,-.115),(.072,-.025),(.042,.035),(.023,.070)],(x,.22,0),'brass_dull')
        band('RolledLip',.160,.157,.006,(x,.22,-.115),'brass_dull')
    speakers[prefix]=current

# Partition by material and mechanical component; each stock remains editable
# in Blender, while fixed runtime draw calls are shared by all instances.
def partition(group,objects):
    buckets=collections.defaultdict(list)
    for obj in objects:buckets[(obj.data.materials[0].name,obj['component'])].append(obj)
    result=[]
    for (key,component),items in buckets.items():
        obj=finish(group+'_'+component+'_'+key,items,key,0)
        result.append({'name':obj.name,'component':component,'material':key})
    return result
family_rows={key:partition('Receiver_'+key,objects) for key,objects in families.items()}
speaker_rows={key:partition('Speaker_'+key,objects) for key,objects in speakers.items()}
for obj in [o for o in bpy.context.scene.objects if o.type=='MESH']:
    layer=obj.data.uv_layers.active
    for face in obj.data.polygons:
        p=[obj.data.vertices[i].co for i in face.vertices];normal=(p[1]-p[0]).cross(p[2]-p[0]).normalized()
        axis=max(range(3),key=lambda i:abs(normal[i]));a,b=[(1,2),(0,2),(0,1)][axis]
        for loop in face.loop_indices:
            q=obj.data.vertices[obj.data.loops[loop].vertex_index].co
            layer.data[loop].uv=(q[a],q[b])
    bm=bmesh.new();bm.from_mesh(obj.data);closed=all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    bad=sum(abs((Vector(layer.data[f.loop_indices[1]].uv)-Vector(layer.data[f.loop_indices[0]].uv)).cross(Vector(layer.data[f.loop_indices[2]].uv)-Vector(layer.data[f.loop_indices[0]].uv)))<=1e-12 for f in obj.data.polygons)
    assert closed and volume>0 and bad==0,(obj.name,closed,volume,bad)
    parts.append({'name':obj.name,'closed':closed,'volume':volume,'triangles':len(obj.data.polygons),'collapsed_uv':bad})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/active_household_radios.blend'))
asset=ROOT/'game/assets/props/active_household_radios.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_apply=True,export_tangents=True,export_lights=False,export_cameras=False)
data={'schema_version':1,'asset':'res://assets/props/active_household_radios.glb','families':[{'id':key,'parts':rows} for key,rows in family_rows.items()],'speakers':[{'id':key,'parts':rows} for key,rows in speaker_rows.items()]}
(ROOT/'game/data/orison_v2/active_household_radios.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'radio-construction.json').write_text(json.dumps({'evidence_class':'INERT','asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'parts':parts,'scope':'Native stock only. Installed contacts, original controls/audio and composed render proof remain required.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('ACTIVE RECEIVERS:',len(families),'families;',len(speakers),'speaker kits;',len(parts),'material/component draws')
