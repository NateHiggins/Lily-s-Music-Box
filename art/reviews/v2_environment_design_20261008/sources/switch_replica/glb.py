import json, struct, sys
import numpy as np
def load(path):
    b=open(path,'rb').read()
    magic,ver,length=struct.unpack('<III',b[:12])
    off=12; js=None; binc=None
    while off<length:
        cl,ct=struct.unpack('<II',b[off:off+8]); chunk=b[off+8:off+8+cl]
        if ct==0x4E4F534A: js=json.loads(chunk)
        else: binc=chunk
        off+=8+cl
    return js,binc
CT={5126:('f',4),5123:('H',2),5125:('I',4),5121:('B',1),5122:('h',2)}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def acc(js,binc,i):
    a=js['accessors'][i]; bv=js['bufferViews'][a['bufferView']]
    fmt,sz=CT[a['componentType']]; n=NC[a['type']]
    start=bv.get('byteOffset',0)+a.get('byteOffset',0)
    stride=bv.get('byteStride',sz*n)
    out=[]
    for k in range(a['count']):
        o=start+k*stride
        out.append(struct.unpack('<'+fmt*n,binc[o:o+sz*n]))
    return np.array(out)
def quat_mat(q):
    x,y,z,w=q
    return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
def node_mat(n):
    if 'matrix' in n: return np.array(n['matrix']).reshape(4,4).T
    M=np.eye(4)
    R=quat_mat(n.get('rotation',[0,0,0,1])); S=np.diag(n.get('scale',[1,1,1]))
    M[:3,:3]=R@S; M[:3,3]=n.get('translation',[0,0,0]); return M
def walk(js):
    res=[]
    sc=js['scenes'][js.get('scene',0)]
    def rec(i,P,path):
        n=js['nodes'][i]; M=P@node_mat(n); p=path+'/'+n.get('name',str(i))
        res.append((i,p,M,n))
        for c in n.get('children',[]): rec(c,M,p)
    for r in sc['nodes']: rec(r,np.eye(4),'')
    return res
