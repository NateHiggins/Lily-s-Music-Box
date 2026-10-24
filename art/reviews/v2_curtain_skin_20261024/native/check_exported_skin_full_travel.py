"""Independent GLB matrix/weight check. No Godot, visual or performance acceptance."""
from pathlib import Path
import json
import math
import struct
import numpy as np

ROOT=Path(__file__).parent
raw=(ROOT/'bath_shower_rig_candidate.glb').read_bytes()
offset=12;document=None;binary=None
while offset<len(raw):
    size,kind=struct.unpack_from('<II',raw,offset);offset+=8
    chunk=raw[offset:offset+size];offset+=size
    if kind==0x4e4f534a:document=json.loads(chunk)
    elif kind==0x004e4942:binary=chunk
DTYPES={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
SIZES={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def accessor(index):
    item=document['accessors'][index];view=document['bufferViews'][item['bufferView']]
    assert 'sparse' not in item
    dtype=np.dtype(DTYPES[item['componentType']]);width=SIZES[item['type']]
    start=view.get('byteOffset',0)+item.get('byteOffset',0)
    result=np.ndarray((item['count'],width),dtype=dtype,buffer=binary,offset=start,
        strides=(view.get('byteStride',dtype.itemsize*width),dtype.itemsize)).copy()
    if item.get('normalized',False) and item['componentType']!=5126:
        result=result.astype(float)/np.iinfo(dtype).max
    return result

def local(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape((4,4),order='F')
    x,y,z,w=node.get('rotation',[0,0,0,1]);m=np.eye(4)
    m[:3,:3]=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
        [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
        [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])@np.diag(node.get('scale',[1,1,1]))
    m[:3,3]=node.get('translation',[0,0,0]);return m

nodes=document['nodes'];parents={j:i for i,n in enumerate(nodes) for j in n.get('children',[])}
globals={}
def global_matrix(index):
    if index not in globals:globals[index]=(global_matrix(parents[index]) if index in parents else np.eye(4))@local(nodes[index])
    return globals[index]

PHYSICAL=1.72+math.pi*.06
def rail(fraction):
    s=max(0,min(1,fraction))*PHYSICAL
    if s<.58:point=(-.34,0,.32-s);axis=(0,0,-1)
    elif s<.58+math.pi*.03:
        a=math.pi+(s-.58)/.06;point=(-.28+.06*math.cos(a),0,-.26+.06*math.sin(a));axis=(-math.sin(a),0,math.cos(a))
    elif s<.58+math.pi*.03+.56:point=(-.28+s-.58-math.pi*.03,0,-.32);axis=(1,0,0)
    elif s<.58+math.pi*.06+.56:
        a=math.pi*1.5+(s-.58-math.pi*.03-.56)/.06;point=(.28+.06*math.cos(a),0,-.26+.06*math.sin(a));axis=(-math.sin(a),0,math.cos(a))
    else:point=(.34,0,-.26+s-.58-math.pi*.06-.56);axis=(0,0,1)
    m=np.eye(4);m[:3,0]=axis;m[:3,1]=(0,1,0);m[:3,2]=np.cross(axis,(0,1,0));m[:3,3]=point
    return m

root_index=next(i for i,n in enumerate(nodes) if n.get('name')=='CurtainDrawn')
root=global_matrix(root_index);inv_root=np.linalg.inv(root)
skin=document['skins'][0];joints=skin['joints']
binds=accessor(skin['inverseBindMatrices']).astype(float).reshape((-1,4,4)).transpose(0,2,1)
rest=np.array([global_matrix(i) for i in joints]);fractions=[];cloth=[]
position_error=[];axis_dots=[]
for index,joint in enumerate(joints):
    name=nodes[joint]['name'];is_cloth=name.startswith('CurtainCloth')
    ordinal=int(name[-3:]);u=ordinal/(96 if is_cloth else 18)
    expected=rail(u);observed=inv_root@rest[index]
    position_error.append(float(np.linalg.norm(observed[:3,3]-expected[:3,3])))
    axis_dots.append(float(np.dot(observed[:3,0]/np.linalg.norm(observed[:3,0]),expected[:3,0])))
    fractions.append(u);cloth.append(is_cloth)
assert len(joints)==116
assert max(position_error)<1e-5,(max(position_error),min(axis_dots))
assert min(axis_dots)>.9999,(max(position_error),min(axis_dots))
bad=rest[0].copy();bad[:3,3]+=root[:3,:3]@np.array([.002,0,0])
wrong_frame_error=float(np.linalg.norm((inv_root@bad)[:3,3]-rail(fractions[0])[:3,3]))
assert wrong_frame_error>1e-5 # A two-millimetre wrong bearing must be refused.
rest_palette=rest@binds
rows=[]
for travel in np.linspace(0,1.78,25):
    poses=[]
    for index,u in enumerate(fractions):
        # Same analytic rotation as the runtime draft, in the authored fixture frame.
        original=inv_root@rest[index];target=rail((travel+u*(1.96-travel))/1.96)
        a=original[:3,0]/np.linalg.norm(original[:3,0]);b=target[:3,0]
        angle=math.atan2(np.dot((0,1,0),np.cross(a,b)),np.dot(a,b));c=math.cos(angle);s=math.sin(angle)
        rotation=np.array([[c,0,s],[0,1,0],[-s,0,c]])
        pose=original.copy();pose[:3,:3]=rotation@original[:3,:3];pose[:3,3]=target[:3,3]
        if cloth[index]:pose[:3,:3]=pose[:3,:3]@np.diag([1,1,1+.8*travel/1.78])
        poses.append(root@pose)
    palette=np.array(poses)@binds
    rigid_error=0.0
    for i,is_cloth in enumerate(cloth):
        if is_cloth:continue
        delta=palette[i]@np.linalg.inv(rest_palette[i]);linear=delta[:3,:3]
        rigid_error=max(rigid_error,float(np.max(np.abs(linear.T@linear-np.eye(3)))))
    assert rigid_error<1e-5,rigid_error
    for node_index,node in enumerate(nodes):
        if node.get('skin')!=0:continue
        for primitive in document['meshes'][node['mesh']]['primitives']:
            attrs=primitive['attributes'];v=accessor(attrs['POSITION']).astype(float)
            weight=accessor(attrs['WEIGHTS_0']).astype(float);joint=accessor(attrs['JOINTS_0']).astype(int)
            assert np.max(np.abs(weight.sum(axis=1)-1))<1e-5
            influences=(weight>1e-8).sum(axis=1);assert influences.max()<=2
            if 'nickel' in node['name']:assert influences.max()==1
            p=np.column_stack((v,np.ones(len(v))));result=np.zeros_like(p)
            for slot in range(4):result+=np.einsum('nij,nj->ni',palette[joint[:,slot]],p)*weight[:,slot,None]
            fixture=(inv_root@result.T).T[:,:3]
            original_fixture=(inv_root@global_matrix(node_index)@p.T).T[:,:3]
            height_error=float(np.max(np.abs(fixture[:,1]-original_fixture[:,1])))
            assert height_error<1e-5,height_error
            assert np.isfinite(fixture).all()
            low=fixture.min(axis=0);high=fixture.max(axis=0)
            assert (low>=np.array([-.41,.14,-.40])-1e-5).all(),low
            assert (high<=np.array([.41,2.08,.42])+1e-5).all(),high
            error=None
            if travel==0:
                expected=(global_matrix(node_index)@p.T).T
                error=float(np.max(np.abs(result-expected)))
                assert error<1e-5,error
            rows.append({'travel':travel,'draw':node['name'],'vertices':len(v),'maximum_weights':int(influences.max()),
                'aabb_min':low.tolist(),'aabb_max':high.tolist(),'rest_identity_max_error':error,
                'vertical_height_max_error':height_error,'rigid_ring_linear_max_error':rigid_error})
            if 'shower_duck' in node['name']:
                ids=accessor(primitive['indices']).reshape(-1).astype(int)
                centers=fixture[ids].reshape((-1,3,3)).mean(axis=1)
                points=np.concatenate((fixture,centers))
                coverage=[]
                for padding,depth in [(.030,.120)]:
                    covered=np.zeros(len(points),dtype=bool)
                    for cell in range(36):
                        a=travel+cell/36*(1.96-travel);b=travel+(cell+1)/36*(1.96-travel)
                        frame=rail((a+b)/2/1.96);frame[1,3]=1.0675
                        local_points=(points-frame[:3,3])@frame[:3,:3]
                        half=np.array([max(.012,(b-a)*PHYSICAL/1.96+padding),1.855,depth])/2
                        covered|=(np.abs(local_points)<=half+1e-5).all(axis=1)
                    coverage.append({'end_padding_m':padding,'depth_m':depth,'points':len(points),
                        'uncovered_vertices_and_face_centers':int((~covered).sum())})
                rows[-1]['cloth_selection_proxy_coverage']=coverage
                assert coverage[0]['uncovered_vertices_and_face_centers']==0,(travel,coverage)
report={'evidence_class':'INERT','scope':'Independent exported GLB rest matrices, skin weights and analytic pose bounds. No Godot, visual, input, save or performance acceptance.',
    'bones':len(joints),'maximum_rest_position_error':max(position_error),'minimum_rest_axis_dot':min(axis_dots),
    'wrong_two_mm_frame_refused':wrong_frame_error>1e-5,'rows':rows,'pass':True}
(ROOT/'exported_skin_full_travel_check.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print(json.dumps({'pass':True,'bones':len(joints),'maximum_rest_position_error':max(position_error),'minimum_rest_axis_dot':min(axis_dots),'pose_draw_checks':len(rows)}))
