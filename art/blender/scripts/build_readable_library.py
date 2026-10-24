"""Native readable bindings, fitted cases, bookends and original ink diagrams.

All lettering is runtime Label3D. Source drawings contain no text or numbers.
The existing library owns book identity; these stocks own only manufactured form.
"""
from pathlib import Path
import hashlib,json,math,sys,colorsys
import bpy,bmesh,numpy as np
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition
from fabrication_chart_batch import triangle_charts
from fabrication_book_export import export_books
from book_flex_math import ANGLES,KEYS,spine_profile,spine_point,page_point,trim_point,cover_point,left_translation,wrapper_point,cover_contact_point

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
source=bpy.data.collections.new('ClosedSourceStock');bpy.context.scene.collection.children.link(source)
draws=bpy.data.collections.new('AuthoredMetrePartitions');bpy.context.scene.collection.children.link(draws)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
library=json.loads((ROOT/'game/data/library.json').read_text())
spreads=json.loads((ROOT/'game/data/orison_v2/book_spreads.json').read_text())
artwork=json.loads((ROOT/'art/illustrations/book_plates/provenance.json').read_text())['plates']
page_designs=json.loads((ROOT/'art/illustrations/book_plates/page_designs.json').read_text())
editorial=json.loads((ROOT/'art/data/readable_library/editorial.json').read_text())
assert {b['id'] for b in library['books']}==set(spreads['spreads'])
keys=['ceramic','book_brown','book_burgundy','book_green','book_navy','book_ochre','book_teal','paper',
      'linen','soot','oak_work_surface','wood_dark','site_softwood','fire_hardware_steel',
      'brass_dull','washer_rubber','glass_drawn_expressive']
finishes={key:dict(catalog_key=key,normal=1. if key.startswith('book_') or key in ['fire_hardware_steel','glass_drawn_expressive','site_softwood'] else .35,
                  roughness=1.,pigment=1.,tint=[1.,1.,1.,1.]) for key in keys}
finishes['paper']['normal']=.08
finishes['soot']['normal']=0.
finishes['soot']['roughness']=.95
finishes['soot']['tint']=[.10,.08,.055,1.]
materials={k:material(ROOT,k,f,catalog) for k,f in finishes.items()}
glass=materials['glass_drawn_expressive']
glass.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.055
glass.node_tree.nodes['Principled BSDF'].inputs['Transmission Weight'].default_value=.9
glass.surface_render_method='DITHERED'
parts={};stocks=[];exports=[];deformers={}

def b(point):return (point[0],-point[2],point[1])

def cube(size,at):
    bpy.ops.mesh.primitive_cube_add(size=1,location=b(at));o=bpy.context.object
    o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return o

def finish(name,objects,key,role,bevel=.0005,collision=True):
    # Texture axes were inspected: both oak and walnut run along V, salvaged
    # softwood along U. Each separately manufactured board keeps its own phase.
    wood_axes={'oak_work_surface':1,'wood_dark':1,'site_softwood':0}
    frames=[]
    for index,obj in enumerate(objects):
        obj.name='Source_'+name+'_'+str(index)
        bpy.context.view_layer.objects.active=obj
        if bevel:
            modifier=obj.modifiers.new('Worked edges','BEVEL');modifier.width=bevel;modifier.segments=3
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-9)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        volume=bm.calc_volume(signed=True)
        assert all(e.is_manifold for e in bm.edges) and volume>1e-14,(name,volume)
        bm.to_mesh(obj.data);bm.free()
        for col in list(obj.users_collection):col.objects.unlink(obj)
        source.objects.link(obj);obj.hide_render=True
        stocks.append(dict(part=name,volume_m3=volume,closed=True))
        points=np.asarray([v.co[:] for v in obj.data.vertices])
        rotation=np.eye(3)
        if key in wood_axes:
            _,_,basis=np.linalg.svd(points-points.mean(axis=0),full_matrices=False)
            length=basis[0]
            if length[np.argmax(np.abs(length))]<0:length=-length
            lateral=np.cross(np.eye(3)[np.argmin(np.abs(length))],length);lateral/=np.linalg.norm(lateral)
            rotation=np.stack((lateral,np.cross(length,lateral),length))
        frames.extend([rotation]*len(points))
    draw=partition(draws,name,objects,finishes[key],materials[key],Matrix.Identity(4),catalog)
    assert draw.name==name,('native stock name was shadowed',name,draw.name)
    if key in wood_axes:
        mesh=draw.data;coords=np.asarray([v.co[:] for v in mesh.vertices]);tri=np.asarray([l.vertex_index for l in mesh.loops]).reshape(-1,3)
        rotations=np.stack([frames[i] for i in tri[:,0]])
        _,us,charts,_=triangle_charts(coords[tri],np.zeros(3),1.,rotations,np.full(len(tri),wood_axes[key]==0))
        phase=int(hashlib.sha256(name.encode()).hexdigest()[:8],16)
        charts+=np.asarray([(phase%257)*.013,((phase//257)%251)*.017])
        mesh.uv_layers.active.data.foreach_set('uv',charts.astype(np.float32).ravel())
        guide=np.repeat(us[:,[0,2,1]],3,axis=0);guide[:,2]*=-1
        mesh.attributes['_tangent_guide'].data.foreach_set('vector',guide.astype(np.float32).ravel())
    exports.append(draw)
    parts[name]=dict(material=key,role=role,collision=collision)
    return name

def box(name,size,at,key,role,bevel=.0005,collision=True):
    return finish(name,[cube(size,at)],key,role,bevel,collision)

def wire(name,points,radius,key,role):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=radius
    curve.bevel_resolution=2;curve.use_fill_caps=True
    spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
    for v,p in zip(spline.points,points):v.co=(*b(p),1.)
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.convert(target='MESH')
    return finish(name,[bpy.context.object],key,role,0.,False)

def ink(name,a,c,width=.00034):
    # A thin printed film; no invented relief in its normal map. Paper supplies
    # the underlying fibre response. These rectangles are native closed stock.
    p=Vector(a);q=Vector(c);axis=(q-p).normalized();side=Vector((-axis.y,axis.x))*width*.5
    vertices=[]
    for z in [-.000012,.000012]:
        for xy in [p+side,p-side,q-side,q+side]:vertices.append(b((xy.x,xy.y,z)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return obj

def ring_stock(name,rings,key,role):
    vertices=[b(point) for ring in rings for point in ring];faces=[]
    for index in range(len(rings)-1):
        for edge in range(4):faces.append((index*4+edge,index*4+(edge+1)%4,(index+1)*4+(edge+1)%4,(index+1)*4+edge))
    faces.extend([(3,2,1,0),tuple((len(rings)-1)*4+i for i in range(4))])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(name,[obj],key,role,0.,True)

def morphs(name,functions):
    draw=draws.objects[name];draw.shape_key_add(name='Basis',from_mix=False)
    neutral=[tuple(vertex.co) for vertex in draw.data.vertices]
    for key,deform in zip(KEYS,functions):
        target=draw.shape_key_add(name=key,from_mix=False);target.value=0.
        for vertex,point in zip(target.data,neutral):
            x,z,minus_y=point
            vertex.co=b(deform((x,minus_y,-z)))
    deformers[name]=functions

def binding(identity,width,height,thickness,key,cover,kind):
    seam=.00002
    style='paperback' if kind=='sewn paper cover' else ('pamphlet' if 'pamphlet' in kind else 'hardback')
    record=dict(width=width,height=height,thickness=thickness,material=key,parts=[],binding=kind,
                right_page_z=-seam+.00004,left_page_z=seam-.00004,
                opening_angles=list(ANGLES),opening_keys=list(KEYS),opening_style=style)
    profiles=[spine_profile(thickness,a,style) for a in ANGLES[1:]]
    for side,lo,hi in [('right',-thickness*.5,-seam),('left',seam,thickness*.5)]:
        board_z=lo+cover*.5 if side=='right' else hi-cover*.5
        if style=='hardback':
            name=box(identity+'__'+side+'_board',(width,height,cover),(width*.5,height*.5,board_z),key,side,min(.00035,cover*.20))
        else:
            rings=[[(x,0,board_z-cover*.5),(x,height,board_z-cover*.5),(x,height,board_z+cover*.5),(x,0,board_z+cover*.5)] for x in np.linspace(0,width,33)]
            name=ring_stock(identity+'__'+side+'_board',rings,key,side)
            morphs(name,[lambda p,a=a,pr=pr,w=width,t=thickness,s=side,st=style:cover_contact_point(p,w,t,st,a,pr,s) for a,pr in zip(ANGLES[1:],profiles)])
            parts[name]['render_surface']=False
        record['parts'].append(name)
        page_low,page_high=(lo+cover,hi) if side=='right' else (lo,hi-cover)
        assert page_high>page_low,(identity,side,page_low,page_high)
        rings=[[(x,.0035,page_low),(x,height-.0035,page_low),(x,height-.0035,page_high),(x,.0035,page_high)] for x in np.linspace(.004,width-.003,33)]
        name=ring_stock(identity+'__'+side+'_leaves',rings,'paper',side)
        morphs(name,[lambda p,a=a,w=width,low=page_low,high=page_high,s=side,t=thickness,st=style:page_point(p,w,low,high,s,a,t,st) for a in ANGLES[1:]])
        record['parts'].append(name)
        if style=='hardback' and key in ['book_brown','book_burgundy'] and thickness>.01:
            z=board_z+(-1 if side=='right' else 1)*(cover*.5+.00006)
            pieces=[cube((.00045,height-.020,.00012),(x,height*.5,z)) for x in [.010,width-.010]]
            pieces += [cube((width-.020,.00045,.00012),(width*.5,y,z)) for y in [.010,height-.010]]
            record['parts'].append(finish(identity+'__'+side+'_tooling',pieces,key,side,.00002,False))
    wall=min(.0012,cover*.85) if style=='hardback' else cover
    rings=[[(-wall,0,z),(0,0,z),(0,height,z),(-wall,height,z)] for z in np.linspace(-thickness*.5,thickness*.5,25)]
    name=ring_stock(identity+'__spine',rings,key,'fixed')
    record['spine_frames']=[]
    for profile in [spine_profile(thickness,0.,style)]+profiles:
        start,chord,normal,bow=profile;length=math.hypot(*chord)
        frame=Matrix(((-normal[0],0.,chord[0]/length),(0.,1.,0.),(-normal[1],0.,chord[1]/length)))
        q=frame.to_quaternion()
        record['spine_frames'].append([start[0]+chord[0]*.5+normal[0]*bow,0.,start[1]+chord[1]*.5+normal[1]*bow,q.x,q.y,q.z,q.w])
    functions=[lambda p,t=thickness,profile=profile:spine_point(p,t,profile) for profile in profiles]
    morphs(name,functions);record['parts'].append(name)
    if style!='hardback':
        parts[name]['render_surface']=False
        rings=[]
        for u in np.linspace(0.,1.,33):
            outer=(width*(1-u)-cover*u,-thickness*.5);inner=(width*(1-u),-thickness*.5+cover)
            rings.append([(outer[0],0,outer[1]),(inner[0],0,inner[1]),(inner[0],height,inner[1]),(outer[0],height,outer[1])])
        for u in np.linspace(0.,1.,25)[1:]:
            outer=(-cover,-thickness*.5+thickness*u);inner=(0,-thickness*.5+cover+(thickness-2*cover)*u)
            rings.append([(outer[0],0,outer[1]),(inner[0],0,inner[1]),(inner[0],height,inner[1]),(outer[0],height,outer[1])])
        for u in np.linspace(0.,1.,33)[1:]:
            outer=(width*u-cover*(1-u),thickness*.5);inner=(width*u,thickness*.5-cover)
            rings.append([(outer[0],0,outer[1]),(inner[0],0,inner[1]),(inner[0],height,inner[1]),(outer[0],height,outer[1])])
        wrapper=ring_stock(identity+'__continuous_wrap',rings,key,'fixed')
        parts[wrapper]['collision']=False
        morphs(wrapper,[lambda p,a=a,pr=pr,w=width,t=thickness,st=style:wrapper_point(p,w,t,st,a,pr) for a,pr in zip(ANGLES[1:],profiles)])
        record['parts'].append(wrapper)
    trim_functions=[lambda p,profile=profile:trim_point(p,profile) for profile in profiles]
    if identity=='onefinger':
        for i,y in enumerate([height*.22,height*.5,height*.78]):
            name=wire(identity+'__lace'+str(i),[(-.002,y,-thickness*.45),(.003,y,-thickness*.45),(.004,y,thickness*.45),(-.002,y,thickness*.45),(-.004,y,0)],.0004,'book_navy','fixed')
            morphs(name,trim_functions);record['parts'].append(name)
    elif style=='hardback':
        for i,y in enumerate([.004,height-.004]):
            name=wire(identity+'__headband'+str(i),[(.001,y,-thickness*.35),(.001,y,thickness*.35)],min(.00055,thickness*.18),'linen','fixed')
            morphs(name,trim_functions);record['parts'].append(name)
    return record

books={};opening_checks=[]
palette=['book_burgundy','book_ochre','book_green','book_teal','book_navy','book_brown']
for entry in library['books']:
    identity=entry['id'];edition=editorial['books'][identity];format=editorial['formats'][edition['format']]
    thickness=edition['page_count']*.5*format['leaf_m']+2*format['cover_m']
    record=binding(identity,format['width_m'],format['height_m'],thickness,edition['material'],format['cover_m'], 'lace pamphlet' if identity=='onefinger' else format['binding'])
    if record['opening_style']!='hardback':
        # A pigmented paper finish uses the registered paper PBR triplet;
        # it does not borrow the embossed cloth/leather cover normal.
        hue={'book_burgundy':350,'book_brown':25,'book_ochre':50,'book_green':110,'book_teal':180,'book_navy':225,'paper':45}[edition['material']]
        tint=list(colorsys.hsv_to_rgb(hue/360.,.50,.72))+[1.]
        finish_spec=dict(finishes['paper']);finish_spec['tint']=tint
        stock_material=material(ROOT,'paper',finish_spec,catalog)
        for part in record['parts']:
            if part.endswith(('_board','__spine','__continuous_wrap')):
                parts[part]['material']='paper';parts[part]['tint']=tint
                mesh=draws.objects[part].data;mesh.materials.clear();mesh.materials.append(stock_material)
    record.update(format=edition['format'],layout=edition['layout'],publisher=edition['publisher'],page_count=edition['page_count'],subtitle=edition['subtitle'])
    style=record['opening_style'];w=record['width'];h=record['height'];t=record['thickness'];seam=.00002
    right=Vector(page_point((.004,h*.5,-seam),w,-t*.5+format['cover_m'],-seam,'right',math.pi,t,style))
    left=Vector(page_point((.004,h*.5,seam),w,seam,t*.5-format['cover_m'],'left',math.pi,t,style))
    left=Matrix.Rotation(-math.pi,3,'Y')@left+Vector(left_translation(t,math.pi,style))
    assert (left-right).length<1e-7,(identity,'sewn gutter disconnected',(left-right).length)
    components=0
    if style!='hardback':
        mesh=draws.objects[identity+'__continuous_wrap'].data
        adjacency={v.index:set() for v in mesh.vertices}
        for edge in mesh.edges:
            a,c=edge.vertices;adjacency[a].add(c);adjacency[c].add(a)
        unseen=set(adjacency)
        while unseen:
            pending=[unseen.pop()];components+=1
            while pending:
                for index in adjacency[pending.pop()]&unseen:unseen.remove(index);pending.append(index)
        assert components==1,(identity,'paper cover is not one connected piece',components)
    opening_checks.append(dict(book=identity,style=style,sewn_gutter_gap_m=(left-right).length,rigid_boards=style=='hardback',continuous_wrap_components=components))
    books[identity]=record

cases={}
for style,width,height,depth,tops in [('plain',.72,1.30,.28,[.060,.465,.875]),
                                     ('repaired',.68,1.22,.25,[.0935,.4435,.8335]),
                                     ('sectional',.78,1.34,.30,[.153,.543,.933])]:
    case_parts=[];key='oak_work_surface' if style=='plain' else 'wood_dark'
    def add(label,size,at,finish_key=key,bevel=.001):
        case_parts.append(box(style+'__'+label,size,at,finish_key,'case',bevel))
    side=.034 if style!='repaired' else .027
    add('Back',(width-side,height-.030,.012),(0,(height-.030)*.5,-depth*.5))
    for index,x in enumerate([-width*.5,width*.5]):add('Side'+str(index),(side,height-.030,depth),(x,(height-.030)*.5,0))
    for index,top in enumerate(tops):add('Shelf'+str(index),(width+.012,.027,depth),(0,top-.0135,0),'site_softwood' if style=='repaired' and index==1 else key)
    add('Top',(width+.04,.030,depth),(0,height-.015,0))
    for index,x in enumerate([-.27,.27]):add('Foot'+str(index),(.08,tops[0]-.027,.20),(x,(tops[0]-.027)*.5,-.01))
    # Separate wood cap moulding catches a small grazing highlight.
    add('CapMoulding',(width-side,.012,.018),(0,height-.036,depth*.5-.009),key,.002)
    if style=='repaired':
        for i,x in enumerate([-.24,.23]):
            case_parts.append(box('repaired__RepairStrap'+str(i),(.022,.16,.018),(x,.47,.137),'brass_dull','case',.001))
    if style=='sectional':add('Plinth',(width+.08,.10,depth+.04),(0,.05,0),key,.002)
    for index,(x,y) in enumerate([(x,y) for x in [-width*.5+.003,width*.5-.003] for y in tops]):
        case_parts.append(box(style+'__ShelfPin'+str(index),(.006,.006,.018),(x,y-.016,depth*.25),'brass_dull','case',.001))
    doors=[]
    if style=='sectional':
        for tier,top in enumerate(tops):
            names=[];w=width-.07;h=.32;rail=.030;cy=top+.170
            pivot=[0,top+.330,depth*.5+.012]
            for side,x in enumerate([-w*.5+.007,w*.5-.007]):
                case_parts.append(box('sectional__PocketTrack%d_%d'%(tier,side),(.012,.003,.288),(x,pivot[1]+.012,.016),'fire_hardware_steel','case',.0004))
                names.append(wire('sectional_sash%d__Roller%d'%(tier,side),[(x-.003,pivot[1]+.0065,pivot[2]),(x+.003,pivot[1]+.0065,pivot[2])],.004,'fire_hardware_steel','carriage'))
            for i,y in enumerate([cy-h*.5+rail*.5,cy+h*.5-rail*.5]):
                names.append(box('sectional_sash%d__Rail%d'%(tier,i),(w,rail,.012),(0,y,depth*.5+.012),key,'door',.001))
            for i,x in enumerate([-w*.5+rail*.5,w*.5-rail*.5]):
                names.append(box('sectional_sash%d__Stile%d'%(tier,i),(rail,h-2*rail,.012),(x,cy,depth*.5+.012),key,'door',.001))
            names.append(box('sectional_sash%d__Glass'%tier,(w-2*rail,h-2*rail,.004),(0,cy,depth*.5+.017),'glass_drawn_expressive','door',.0003))
            names.append(wire('sectional_sash%d__Pull'%tier,[(-.025,cy-h*.5+.012,depth*.5+.015),(-.02,cy-h*.5+.012,depth*.5+.019),(.02,cy-h*.5+.012,depth*.5+.019),(.025,cy-h*.5+.012,depth*.5+.015)],.002,'brass_dull','door'))
            doors.append(dict(parts=names,pivot=pivot,angle_limit=math.pi*.5,inset_limit=.30))
    cases[style]=dict(parts=case_parts,shelf_tops=tops,width=width,depth=depth,height=height,doors=doors)

bookends={}
for style,key in [('pressed','fire_hardware_steel'),('brass','brass_dull')]:
    end_parts=[]
    def endbox(label,size,at,bevel=.0005):
        end_parts.append(box('bookend_'+style+'__'+label,size,at,key,'end',bevel))
    endbox('Foot',(.075,.0014,.10),(.034,.0007,0),.00035)
    # Open hand grip is assembled from real independent stock, keeping its
    # aperture and the inside of the L clear in the collision decomposition.
    for i,z in enumerate([-.034,.034]):endbox('Upright'+str(i),(.002,.105,.018),(0,.053,z),.0007)
    if style=='pressed':
        endbox('TopFace',(.0014,.018,.086),(0,.111,0),.0003)
        endbox('FoldedLip',(.0014,.014,.086),(.0076,.113,0),.0003)
        endbox('TopReturn',(.009,.0014,.086),(.0038,.1193,0),.0003)
    else:endbox('TopReturn',(.009,.018,.086),(.002,.111,0),.002)
    endbox('LowerWeb',(.002,.040,.068),(0,.021,0),.0005)
    endbox('FloorReturn',(.07,.005,.0014 if style=='pressed' else .005),(.033,.003,.0493 if style=='pressed' else .047),.0003 if style=='pressed' else .0005)
    end_parts.append(box('bookend_'+style+'__Felt',(.068,.001,.086),(.034,-.0005,0),'linen','end',.00025))
    mass=sum(row['volume_m3']*(200. if parts[row['part']]['material']=='linen' else (7800. if style=='pressed' else 8500.)) for row in stocks if row['part'] in end_parts)
    bookends[style]=dict(parts=end_parts,width=.075,height=.12,depth=.10,support_y=-.001,mass_kg=mass)

# Original small line plates. No downloaded or projected reference images.
illustrations={}
def plate(kind,paths):
    objects=[]
    for path in paths:
        for a,c in zip(path,path[1:]):
            if (Vector(a)-Vector(c)).length>.0001:objects.append(ink(kind,a,c))
    name=finish('plate__'+kind,objects,'soot','print',0.,False)
    coordinates=np.asarray([v.co[:] for v in draws.objects[name].data.vertices])
    illustrations[kind]=dict(part=name,width=float(np.ptp(coordinates[:,0])),height=float(np.ptp(coordinates[:,2])))

decorations={}
def lathe(name,profile,key):
    count=32;vertices=[b((r*math.cos(a),y,r*math.sin(a))) for r,y in profile for a in np.linspace(0,2*math.pi,count,endpoint=False)]
    faces=[]
    for level in range(len(profile)-1):
        for i in range(count):faces.append((level*count+i,level*count+(i+1)%count,(level+1)*count+(i+1)%count,(level+1)*count+i))
    vertices.extend([b((0,profile[0][1],0)),b((0,profile[-1][1],0))])
    for i in range(count):
        faces.append((len(vertices)-2,(i+1)%count,i));faces.append((len(vertices)-1,(len(profile)-1)*count+i,(len(profile)-1)*count+(i+1)%count))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(name,[obj],key,'fixed',0.,True)

# A hollow stoneware cup; the runtime keeps its closed wall sections instead
# of filling the mouth with a whole-object convex hull.
name=lathe('decor__cup',[(.027,0),(.032,.075),(.028,.075),(.024,.006)],'ceramic')
decorations['cup']={'parts':[name], 'open_vessel':True}
name=box('decor__letter_packet',(.09,.018,.065),(0,.009,0),'paper','fixed',.0003)
band=box('decor__packet_band',(.012,.0185,.0655),(0,.009,0),'linen','fixed',.0002)
decorations['letters']={'parts':[name,band], 'open_vessel':False}
name=lathe('decor__inkwell',[(.025,0),(.026,.028),(.012,.040),(.012,.046)],'glass_drawn_expressive')
cap=lathe('decor__inkwell_cap',[(.014,.046),(.014,.050)],'fire_hardware_steel')
decorations['inkwell']={'parts':[name,cap], 'open_vessel':False}
# An unfinished model hull, a solid workshop keepsake rather than a live boat.
hull=ring_stock('decor__model_hull',[[(-w*.5,y,-d*.5),(w*.5,y,-d*.5),(w*.5,y,d*.5),(-w*.5,y,d*.5)] for w,d,y in [(.06,.022,.012),(.11,.040,.024),(.085,.033,.040)]],'wood_dark','fixed')
keel=box('decor__model_stand',(.055,.012,.045),(0,.006,0),'site_softwood','fixed',.001)
decorations['model_boat']={'parts':[hull,keel], 'open_vessel':False}

def engraved_plate(kind,spec):
    path=ROOT/'game'/spec['image'].removeprefix('res://')
    image=bpy.data.images.load(str(path),check_existing=True)
    width=.102;height=width*image.size[1]/image.size[0]
    image.filepath=bpy.path.relpath(str(path),start=str(ROOT/'art/blender'))
    rings=[[(x,-height*.5,-.00004),(x,height*.5,-.00004),(x,height*.5,.00004),(x,-height*.5,.00004)] for x in np.linspace(-width*.5,width*.5,25)]
    name=ring_stock('plate__'+kind,rings,'paper','print')
    parts[name]['collision']=False
    draw=draws.objects[name];mesh=draw.data
    uv=mesh.uv_layers.new(name='Artwork')
    for loop in mesh.loops:
        p=mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv=((p.x+width*.5)/width,(p.z+height*.5)/height)
    mesh.uv_layers.active_index=0;mesh.uv_layers[0].active_render=True
    paper=materials['paper'].copy();paper.name='PrintedPaper_'+kind
    nodes=paper.node_tree.nodes;links=paper.node_tree.links
    principled=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    coordinate=nodes.new('ShaderNodeUVMap');coordinate.uv_map='Artwork'
    tex=nodes.new('ShaderNodeTexImage');tex.image=image;links.new(coordinate.outputs['UV'],tex.inputs['Vector'])
    blend=nodes.new('ShaderNodeMixRGB');blend.blend_type='MULTIPLY'
    if principled.inputs['Base Color'].links: links.new(principled.inputs['Base Color'].links[0].from_socket,blend.inputs[1])
    else: blend.inputs[1].default_value=principled.inputs['Base Color'].default_value
    links.new(tex.outputs['Alpha'],blend.inputs[0]);links.new(tex.outputs['Color'],blend.inputs[2]);links.new(blend.outputs[0],principled.inputs['Base Color'])
    mesh.materials.clear();mesh.materials.append(paper)
    illustrations[kind]=dict(part=name,width=width,height=height,image=spec['image'])

def rectangle(x,y,w,h):return [(x,y),(x+w,y),(x+w,y+h),(x,y+h),(x,y)]
def circle(x,y,r):return [(x+math.cos(a)*r,y+math.sin(a)*r) for a in np.linspace(0,2*math.pi,33)]
for kind in sorted({v[side]['illustration'] for v in spreads['spreads'].values() for side in ['left','right'] if 'illustration' in v[side]}):
    if kind in artwork:
        engraved_plate(kind,artwork[kind]);continue
    paths=[]
    if kind in ['roof_plan','street_plan','pattern']:
        paths=[rectangle(-.05,-.018,.10,.036)]
        if kind=='street_plan':
            paths += [[(x,-.022),(x,.022)] for x in [-.027,0,.027]]
            paths += [[(-.053,y),(.053,y)] for y in [-.008,.008]]
        elif kind=='roof_plan':
            paths += [rectangle(-.043,-.011,.036,.022),rectangle(.007,-.011,.036,.022)]
            paths += [circle(x,.0,.0028) for x in [-.035,-.021,-.007,.007,.021,.035]]
            paths += [rectangle(.017,-.024,.007,.005)]
        else:paths += [[(-.033,-.018),(-.02,.018),(.02,.018),(.033,-.018)],[(0,-.018),(0,.018)]]
    elif kind in ['circuit','keyboard','timetable']:
        paths=[rectangle(-.05,-.018,.10,.036)]
        if kind=='circuit':
            paths += [[(-.05,0),(-.022,0),(-.012,.012),(.012,-.012),(.022,0),(.05,0)],circle(-.027,0,.005),circle(.027,0,.005)]
        elif kind=='keyboard':
            paths += [[(x,-.018),(x,.018)] for x in np.linspace(-.05,.05,9)[1:-1]]
            paths += [rectangle(x,.002,.005,.016) for x in [-.04,-.027,-.001,.012,.026]]
        else:paths += [[(x,-.018),(x,.018)] for x in [-.025,0,.025]]+[[(-.05,y),(.05,y)] for y in [-.009,0,.009]]
    elif kind in ['seedling','pressed_flower','bird_window']:
        if kind=='bird_window':paths=[rectangle(-.045,-.02,.09,.04),circle(0,.004,.006),[(-.01,-.003),(0,.01),(.016,.008),(.023,0),(.003,-.003),(-.01,-.003)]]
        else:
            paths=[[(-.015,-.021),(-.009,-.008),(0,.004),(.004,.019)], [(-.009,-.008),(-.03,.0),(-.023,.007),(-.009,-.008)],[(0,.004),(.023,.009),(.025,.002),(0,.004)]]
            if kind=='pressed_flower':paths += [circle(.004+math.cos(a)*.006,.019+math.sin(a)*.006,.004) for a in np.linspace(0,2*math.pi,6)[:-1]]
    elif kind in ['lift_section','elevation','door']:
        paths=[rectangle(-.032,-.02,.064,.04)]
        if kind=='door':paths += [rectangle(-.026,-.016,.052,.032),circle(.018,-.002,.002)]
        elif kind=='lift_section':paths += [rectangle(-.014,-.014,.028,.018),[(-.024,.02),(-.024,-.02)],[(.024,.02),(.024,-.02)]]
        else:paths += [rectangle(x,y,.012,.010) for x in [-.024,-.006,.012] for y in [-.013,.004]]
    elif kind=='envelope':paths=[rectangle(-.045,-.018,.09,.036),[(-.045,.018),(0,-.006),(.045,.018)],[(-.045,-.018),(-.01,.001)],[(.045,-.018),(.01,.001)]]
    elif kind=='contact_frames':paths=[rectangle(x,-.017,.027,.034) for x in [-.049,-.014,.021]]
    elif kind=='knot':
        paths=[[(math.sin(t)*.045,math.sin(2*t)*.015) for t in np.linspace(0,2*math.pi,81)], [(-.05,-.019),(-.029,-.009)],[(.029,.009),(.05,.019)]]
    elif kind=='billiards':paths=[rectangle(-.048,-.018,.096,.036),circle(-.02,-.005,.003),circle(.012,.007,.003),circle(.038,.024,.003)]
    elif kind=='dartboard':
        paths=[circle(0,0,r) for r in [.0015,.0035,.021,.023,.036,.039]]
        paths += [[(.0035*math.cos(a),.0035*math.sin(a)),(.039*math.cos(a),.039*math.sin(a))] for a in np.linspace(0,2*math.pi,21)[:-1]+math.pi/20]
    else:raise ValueError(kind)
    plate(kind,paths)

source.hide_render=True
type_rule=ring_stock('type__running_rule',[[(x,-.00006,-.000012),(x,.00006,-.000012),(x,.00006,.000012),(x,-.00006,.000012)] for x in np.linspace(-.051,.051,25)],'soot','print')
parts[type_rule]['collision']=False
proof=export_books(ROOT,'readable_library',draws,deformers)
proof['asset']='game/assets/props/readable_library.glb'
data=dict(schema_version=1,asset='res://assets/props/readable_library.glb',books=books,cases=cases,
          bookends=bookends,illustrations=illustrations,decorations=decorations,parts=parts,finishes=finishes,
          page_designs=page_designs,typography=dict(running_rule=type_rule),
          formats={k:{field:v[field] for field in ['width_m','height_m','cover_m','leaf_m','binding']} for k,v in editorial['formats'].items()},
          publishers={k:{field:v[field] for field in ['name','place']} for k,v in editorial['publishers'].items()},
          publication_layouts={k:{field:v[field] for field in ['body_em_m','margin_fraction','columns','plate_fraction']} for k,v in editorial['layouts'].items()},
          material_intent={'soot':'Printed ink film: intentionally flat; paper supplies the grain.',
                           'paper':'Restrained fibre normal; lettering and illustrations are independent of relief.'})
(ROOT/'game/data/orison_v2/readable_library.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
bindings=[Path(__file__),ROOT/'game/data/library.json',ROOT/'game/data/orison_v2/book_spreads.json',ROOT/'game/data/runtime_material_sets.json']
bindings += [ROOT/'art/illustrations/book_plates/provenance.json']+[ROOT/'game'/v['image'].removeprefix('res://') for v in artwork.values()]
bindings += [ROOT/'art/illustrations/book_plates/page_designs.json']
bindings += [ROOT/'art/data/readable_library/editorial.json']
bindings += [ROOT/'art/blender/scripts'/p for p in ['book_flex_math.py','fabrication_book_export.py']]
bindings += [ROOT/'art/blender/scripts'/p for p in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
bindings += [ROOT/'game/assets/building/textures'/f for key in keys for f in catalog[key]['files']]
report=dict(evidence_class='INERT',scope='Native stock construction, authored UV/tangents and physical size only. No runtime, save, narrative or human acceptance.',
            parts=parts,closed_stocks=stocks,opening_checks=opening_checks,export=proof,source_bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n') if p.suffix in ['.json','.py'] else p.read_bytes()).hexdigest() for p in bindings})
report['outputs']={path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in ['game/assets/props/readable_library.glb','art/blender/readable_library.blend','game/data/orison_v2/readable_library.json']}
(ROOT/'art/blender/readable_library_construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8',newline='\n')
print('READABLE LIBRARY:',len(books),'books;',len(cases),'cases;',len(bookends),'bookends;',len(illustrations),'original plates;',len(parts),'parts')
