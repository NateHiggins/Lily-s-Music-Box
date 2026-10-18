"""Isometric mirrored wood charts; original albedo pixels remain untouched.

Triangles are split at catalogue tile boundaries. Reflected chart neighbours
share the same clamped image edge. Normals are interpolated before the split,
and the exported tangent sign follows each chart's actual handedness.
"""
import itertools
import numpy as np

def clip(polygon,axis,value,greater):
    result=[]
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        da=a[3+axis]-value;db=b[3+axis]-value
        inside_a=da>=-1e-12 if greater else da<=1e-12
        inside_b=db>=-1e-12 if greater else db<=1e-12
        if inside_a:result.append(a)
        if inside_a!=inside_b:
            point=a+(b-a)*(da/(da-db));point[3+axis]=value;result.append(point)
    return result

def mirrored_triangles(points,uvs,normals,guides,tile=1.):
    output=[];charts=[];frames=[];tangents=[];signs=[]
    for points_row,uv_row,normals_row,guide in zip(points,uvs,normals,guides):
        low=np.floor(uv_row.min(axis=0)/tile+1e-10).astype(int)
        high=np.floor(uv_row.max(axis=0)/tile-1e-10).astype(int)
        high=np.maximum(high,low)
        original=[np.concatenate((p,uv,n)) for p,uv,n in zip(points_row,uv_row,normals_row)]
        for i,j in itertools.product(range(low[0],high[0]+1),range(low[1],high[1]+1)):
            polygon=original
            for axis,index in [(0,i),(1,j)]:
                polygon=clip(polygon,axis,index*tile,True)
                if not polygon:break
                polygon=clip(polygon,axis,(index+1)*tile,False)
                if not polygon:break
            if len(polygon)<3:continue
            for k in range(1,len(polygon)-1):
                tri=np.array([polygon[0],polygon[k],polygon[k+1]])
                area=np.linalg.norm(np.cross(tri[1,:3]-tri[0,:3],tri[2,:3]-tri[0,:3]))
                if area<1e-14:continue
                # Blender/glTF store positions as float32. Clipping a bevel
                # exactly beside a chart boundary can leave a sub-ULP sliver
                # whose distinct double vertices become identical on export.
                # Reject that unrepresentable triangle here, before constructing
                # the mesh; retain the exported tangent check unchanged.
                stored=tri[:,:3].astype(np.float32).astype(float)
                if np.linalg.norm(np.cross(stored[1]-stored[0],stored[2]-stored[0]))==0:continue
                uv=tri[:,3:5]-np.array([i,j])*tile
                if i%2:uv[:,0]=tile-uv[:,0]
                if j%2:uv[:,1]=tile-uv[:,1]
                n=tri[:,5:8];n/=np.linalg.norm(n,axis=1)[:,None]
                output.append(tri[:,:3]);charts.append(np.clip(uv,0,tile));frames.append(n)
                tangents.append(np.repeat((guide*(-1 if i%2 else 1))[None],3,axis=0))
                signs.append(-1. if (i+j)%2==0 else 1.)
    return tuple(np.array(value) for value in [output,charts,frames,tangents,signs])
