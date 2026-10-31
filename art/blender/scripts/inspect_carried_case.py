"""Native/file-contract checks for carried_case; no Godot and no source mutation.

blender -b --python-exit-code 1 -P art/blender/scripts/inspect_carried_case.py
The builder also calls inspect() before its textured CPU reviews.
"""
from pathlib import Path
import sys,json,math,struct
sys.dont_write_bytecode=True
import bpy,bmesh,numpy as np
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
REVIEW=Path('C:/ov/reports/claude30/shops/review')
EXPECTED={'bottle':[1,2],'tin':[1,1],'box':[2,1],'packet':[1,1],'flat':[2,3],'tool':[1,3],
          'roll':[1,1],'jar':[1,1],'card':[1,1],'valve':[1,2],'parcel':[2,2]}
KEYS={'leather_worn','brass_dull','brass','fabric_warm','linen','paper','bakelite_black','milk_glass'}


def geometry(objects,transform=None):
    verts=[];faces=[];transform=transform if transform is not None else Matrix.Identity(4)
    for o in objects:
        base=len(verts);verts.extend(transform@v.co for v in o.data.vertices);faces.extend([[base+i for i in f.vertices] for f in o.data.polygons])
    return verts,faces


def metric(mesh):
    uv=mesh.uv_layers['Metres'];ratios=[]
    for face in mesh.polygons:
        assert len(face.vertices)==3
        p=np.array([mesh.vertices[i].co[:] for i in face.vertices]);q=np.array([uv.data[i].uv[:] for i in face.loop_indices])
        assert np.isfinite(q).all()
        assert abs(np.linalg.det(np.array([q[1]-q[0],q[2]-q[0]])))>1e-12
        for a,b in [(0,1),(1,2),(2,0)]:ratios.append(np.linalg.norm(p[a]-p[b])/np.linalg.norm(q[a]-q[b]))
    assert min(ratios)>=.99 and max(ratios)<=1.01,(mesh.name,min(ratios),max(ratios))
    return min(ratios),max(ratios)


def export_arrays(path):
    raw=path.read_bytes();magic,ver,length=struct.unpack_from('<III',raw);assert magic==0x46546c67 and ver==2 and length==len(raw)
    ln=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+ln]);blob=raw[28+ln:]
    def a(i):
        rec=doc['accessors'][i];view=doc['bufferViews'][rec['bufferView']];dt=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[rec['componentType']]);n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[rec['type']]
        return np.ndarray((rec['count'],n),dtype=dt,buffer=blob,offset=view.get('byteOffset',0)+rec.get('byteOffset',0),strides=(view.get('byteStride',n*dt.itemsize),dt.itemsize)).astype(float)
    return doc,a


def mechanism_checks(draws,hinge):
    groups={}
    for ob in draws:groups.setdefault(ob['assembly'],[]).append(ob)
    fixed={ob.name:BVHTree.FromPolygons(*geometry([ob])) for ob in groups['Tray']}
    def poses(degrees,side):
        a=Vector((0,.280,.208));bo=Vector((0,-.060,.004));b=hinge+Matrix.Rotation(math.radians(degrees-104),4,'X')@(bo-hinge);diff=b-a
        assert diff.length<.4
        c=(a+b)/2+Vector((0,-diff.z,diff.y)).normalized()*math.sqrt(.2**2-diff.length_squared/4)
        def pose(p,q,x):
            direction=Vector((0,q.y-p.y,q.z-p.z)).normalized();mat=Vector((0,0,1)).rotation_difference(direction).to_matrix().to_4x4();mat.translation=(side*x,p.y,p.z);return mat
        return pose(a,c,.286),pose(c,b,.283),a,b,c
    failures=[];attachment_error=0.;endpoint_rows=[]
    for angle in range(105):
        shelfmat=Matrix.Translation(hinge)@Matrix.Rotation(math.radians(angle),4,'X');shelf={ob.name:BVHTree.FromPolygons(*geometry([ob],shelfmat)) for ob in groups['Lid']}
        for side_name,side in [('Port',-1),('Starboard',1)]:
            upper,lower,a,b,c=poses(angle,side);up=BVHTree.FromPolygons(*geometry(groups['Stay_'+side_name+'_Upper'],upper));lo=BVHTree.FromPolygons(*geometry(groups['Stay_'+side_name+'_Lower'],lower))
            endu=upper@Vector((0,0,.2));startl=lower.translation;endl=lower@Vector((0,0,.2));error=max(Vector((0,endu.y-c.y,endu.z-c.z)).length,Vector((0,startl.y-c.y,startl.z-c.z)).length,Vector((0,endl.y-b.y,endl.z-b.z)).length);attachment_error=max(attachment_error,error)
            assert error<2e-7
            pairs=up.overlap(lo)
            if pairs:failures.append({'angle':angle,'side':side_name,'parts':'upper/lower','pairs':len(pairs)})
            for name,tree in {**fixed,**shelf}.items():
                for label,linktree in [('upper',up),('lower',lo)]:
                    pairs=linktree.overlap(tree)
                    if pairs:failures.append({'angle':angle,'side':side_name,'parts':label+'/'+name,'pairs':len(pairs)})
            if angle in [0,52,104]:endpoint_rows.append({'angle':angle,'side':side_name,'upper_matrix_B':[list(row) for row in upper],'lower_matrix_B':[list(row) for row in lower]})
        # Full shelf/frame clearance, not just the four link axes.
        for name,tree in shelf.items():
            for fixedname,fixedtree in fixed.items():
                pairs=tree.overlap(fixedtree)
                if pairs:failures.append({'angle':angle,'parts':name+'/'+fixedname,'pairs':len(pairs)})
    # The kneestop must reject overtravel rather than being decorative relief.
    overtravel=[]
    for side_name,side in [('Port',-1),('Starboard',1)]:
        upper,lower,_,_,_=poses(105,side);pairs=BVHTree.FromPolygons(*geometry(groups['Stay_'+side_name+'_Upper'],upper)).overlap(BVHTree.FromPolygons(*geometry(groups['Stay_'+side_name+'_Lower'],lower)));overtravel.append({'side':side_name,'angle':105,'pairs':len(pairs)})
    result={'samples':105,'opening_degrees':[0,104],'link_length_m':.2,'maximum_attachment_error_m':attachment_error,'failures':failures,'positive_stop_overtravel':overtravel,'endpoint_poses':endpoint_rows}
    REVIEW.mkdir(parents=True,exist_ok=True);(REVIEW/'case_mechanism.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    assert not failures,failures[:8]
    assert all(row['pairs']>0 for row in overtravel),overtravel
    return result


def footprint_ok(low,high,size):
    half=np.array(size)*.025
    return bool(np.all(low[:2]>=-half+.002-1e-7) and np.all(high[:2]<=half-.002+1e-7))


def inspect(draws=None,sources=None,data=None,write=True):
    if draws is None:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/carried_case.blend'))
        draws=[o for o in bpy.data.collections['02_CONTRACT_EXPORT'].objects if o.type=='MESH']
        sources=[o for o in bpy.data.collections['01_EDITABLE_MANUFACTURING_STOCK'].objects if o.type=='MESH']
        data=json.loads((ROOT/'game/data/carried_case.json').read_text(encoding='utf-8'))
    assert set(data)=={'schema_version','asset','cell','grid','hinge','forms','parts'}
    assert data['schema_version']==1 and data['asset']=='res://assets/props/carried_case.glb'
    assert data['cell']==.05 and data['grid']==[10,6]
    assert np.allclose(data['hinge'],[0,0,-.155],atol=1e-8)
    assert {k:v['size'] for k,v in data['forms'].items()}==EXPECTED
    assert all(set(r)=={'name','assembly','key','tile'} for r in data['parts'])
    assert {o.name for o in draws}=={r['name'] for r in data['parts']}
    material_sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
    for rec in data['parts']:
        assert rec['key'] in KEYS and rec['name']==rec['assembly']+'__'+rec['key']
        assert rec['assembly'] in ['Tray','Lid']+['Form_'+x for x in EXPECTED]+['Stay_'+side+'_'+segment for side in ['Port','Starboard'] for segment in ['Upper','Lower']]
        assert rec['tile']==(.14 if rec['key']=='fabric_warm' else material_sets[rec['key']]['meters_per_tile'])
    stock_checks=[]
    for o in sources:
        bm=bmesh.new();bm.from_mesh(o.data);bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
        assert bad==0 and volume>1e-15,(o.name,bad,volume)
        stock_checks.append({'stock':o.name,'role':o.get('construction_role'),'nonmanifold_edges':bad,'volume_m3':volume})
    scale=[metric(o.data) for o in draws]
    form_checks=[];lid=[o for o in draws if o.name.startswith('Lid__')];hinge=Vector((data['hinge'][0],-data['hinge'][2],data['hinge'][1]));lv,lf=geometry(lid,Matrix.Translation(hinge));lid_tree=BVHTree.FromPolygons(*geometry([o for o in draws if o.name.startswith('Tray__')]))
    shelf_rest=Matrix.Rotation(math.radians(-104),4,'X');depth_direction=shelf_rest.to_3x3()@Vector((0,0,1))
    placements=0;minimum_ceiling=1.;failures=[]
    for form,size in EXPECTED.items():
        objects=[o for o in draws if o.name.startswith('Form_'+form+'__')];assert objects,form
        v,f=geometry(objects);arr=np.array(v);low,high=arr.min(0),arr.max(0);half=np.array(size)*.025
        assert footprint_ok(low,high,size),(form,low,high)
        assert low[2]>=-1e-7 and low[2]<.0015 and high[2]<=.0500001,(form,low,high)
        form_checks.append({'form':form,'size':size,'bounds_B':[low.tolist(),high.tolist()],'height_m':float(high[2]),'minimum_cell_margin_m':float(np.min(np.r_[low[:2]+half,half-high[:2]]))})
        for turned in [False,True]:
            w,d=size[::-1] if turned else size;rot=Matrix.Rotation(math.pi/2 if turned else 0,4,'Z')
            for y in range(6-d+1):
                for x in range(10-w+1):
                    centre=Vector((-.25+(x+w/2)*.05,-.15+(y+d/2)*.05,0));points=[shelf_rest@(rot@p+centre-hinge)+hinge for p in v];tree=BVHTree.FromPolygons(points,f);hits=tree.overlap(lid_tree);placements+=1
                    if hits:failures.append({'form':form,'turned':turned,'cell':[x,y],'intersections':len(hits)})
                    start=shelf_rest@(centre+Vector((0,0,float(high[2])))-hinge)+hinge;hit,n,i,dist=lid_tree.ray_cast(start,depth_direction,.3)
                    if hit is not None:minimum_ceiling=min(minimum_ceiling,float(dist))
    assert not failures,failures[:5]
    # Test the player's actual view and a high-wall negative control at all front cells.
    tv,tf=geometry([o for o in draws if o.name.startswith('Tray__')]);sv,sf=geometry([o for o in draws if o.name.startswith('Lid__')],Matrix.Translation(hinge)@Matrix.Rotation(math.radians(104),4,'X'));off=len(tv);tray_tree=BVHTree.FromPolygons(tv+sv,tf+[[i+off for i in f] for f in sf])
    eye=Vector((0,-.46,.62));front=[]
    for i in range(10):
        target=Vector((-.225+i*.05,-.125,.0015));ray=target-eye;hit,n,index,dist=tray_tree.ray_cast(eye,ray.normalized(),ray.length-1e-5)
        front.append({'cell':i,'visible':hit is None})
    assert all(r['visible'] for r in front),front
    # Analytic original85mm wall intersection, bounded to the original front face.
    negative=0
    for i in range(10):
        target=Vector((-.225+i*.05,-.125,.0015));t=(-.162-eye.y)/(target.y-eye.y);p=eye+(target-eye)*t
        negative+=int(-.25<=p.x<=.25 and 0<=p.z<=.085)
    assert negative==10
    card=[o for o in draws if o.name=='Tray__paper'];assert len(card)==1
    cardlocal=np.array([shelf_rest.inverted()@(v.co-hinge) for v in card[0].data.vertices]);assert abs(np.ptp(cardlocal[:,0])-.170)<1e-6 and abs(np.ptp(cardlocal[:,1])-.084)<1e-6
    # All catalogue PBR channels are present in native materials, not just albedo.
    for key in {r['key'] for r in data['parts']}:
        used=[o for o in draws if o['material_key']==key][0].data.materials[0]
        textures={Path(bpy.path.abspath(n.image.filepath)).name for n in used.node_tree.nodes if n.type=='TEX_IMAGE' and n.image}
        assert set(material_sets[key]['files']).issubset(textures),(key,textures)
        assert used.node_tree.nodes['Principled BSDF'].inputs['Normal'].is_linked
    doc,a=export_arrays(ROOT/'game/assets/props/carried_case.glb');triangles=0;export_scale=[]
    assert not doc.get('images') and not doc.get('materials') and not doc.get('cameras') and 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    assert {n['name'] for n in doc['nodes']}=={o.name for o in draws}
    assert all(np.allclose(n.get('translation',[0,0,0]),0) and np.allclose(n.get('scale',[1,1,1]),1) and np.allclose(n.get('rotation',[0,0,0,1]),[0,0,0,1]) for n in doc['nodes'])
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            p=a(primitive['attributes']['POSITION']);q=a(primitive['attributes']['TEXCOORD_0']);ix=a(primitive['indices']).astype(int).reshape(-1,3);triangles+=len(ix);pp=p[ix];qq=q[ix]
            ratios=np.concatenate([np.linalg.norm(pp[:,i]-pp[:,j],axis=1)/np.linalg.norm(qq[:,i]-qq[:,j],axis=1) for i,j in [(0,1),(1,2),(2,0)]])
            assert np.isfinite(ratios).all() and ratios.min()>=.99 and ratios.max()<=1.01
            export_scale.append([float(ratios.min()),float(ratios.max())])
    assert triangles<25000
    sys.path.insert(0,str(Path(__file__).parent));from check_exported_tangents import validate
    tangent=validate(ROOT/'game/assets/props/carried_case.glb')
    # A deliberate oversize item must be refused by the same footprint inequality.
    bad_extent=np.array([.026,.049,.025]);assert not footprint_ok(-bad_extent,bad_extent,[1,2])
    mechanism=mechanism_checks(draws,hinge)
    result={'evidence_class':'INERT','status':'PASS_NATIVE_ONLY','summary':{'triangles':triangles,'partitions':len(draws),'editable_stocks':len(sources),'forms':len(EXPECTED),'closed_lid_placements_checked':placements,'minimum_sampled_closed_ceiling_gap_m':minimum_ceiling,'front_row_cells_visible':10,'mechanism_samples':mechanism['samples'],'maximum_stay_attachment_error_m':mechanism['maximum_attachment_error_m'],'original_high_front_negative_control':negative,'native_metres_per_uv_range':[min(x[0] for x in scale),max(x[1] for x in scale)],'export_metres_per_uv_range':[min(x[0] for x in export_scale),max(x[1] for x in export_scale)],'tangent_minimum_agreement':tangent['minimum_tangent_agreement']},'forms':form_checks,'stocks':stock_checks,'front_row':front,'closed_lid_failures':failures,'runtime':'NOT RUN'}
    if write:
        REVIEW.mkdir(parents=True,exist_ok=True);(REVIEW/'case_inspection.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result

if __name__=='__main__':
    result=inspect();print('CARRIED_CASE_INSPECTION',json.dumps(result['summary']))
