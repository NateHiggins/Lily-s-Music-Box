"""Authored tileable Perlin-Worley optical density; no photographic pixels.

RG8 volume contains Perlin-Worley base and cellular erosion. Every 3D mip is
box-filtered across all three axes. Cirrus is a cheap tileable high cloud mask.
"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/environment/weather'

def perlin(size, cells, seed):
    rng = np.random.default_rng(seed)
    gradients = rng.normal(size=(cells,cells,cells,3)).astype(np.float32)
    gradients /= np.linalg.norm(gradients,axis=-1,keepdims=True)
    coords = np.stack(np.meshgrid(*([np.arange(size,dtype=np.float32)/size*cells]*3),indexing='ij'),-1)
    base = np.floor(coords).astype(int); f = coords-base
    fade = f*f*f*(f*(f*6-15)+10)
    result = np.zeros((size,)*3,np.float32)
    for x in (0,1):
        for y in (0,1):
            for z in (0,1):
                corner = np.array((x,y,z)); g=gradients[tuple(((base+corner)%cells).transpose(3,0,1,2))]
                weight=np.prod(np.where(corner,fade,1-fade),axis=-1)
                result+=np.sum(g*(f-corner),axis=-1)*weight
    return np.clip(result*.8+.5,0,1)

def worley(size,cells,seed):
    rng=np.random.default_rng(seed); points=rng.random((cells,cells,cells,3)).astype(np.float32)
    coords=np.stack(np.meshgrid(*([np.arange(size,dtype=np.float32)/size*cells]*3),indexing='ij'),-1)
    base=np.floor(coords).astype(int); f=coords-base; distance=np.full((size,)*3,10.,np.float32)
    for x in (-1,0,1):
        for y in (-1,0,1):
            for z in (-1,0,1):
                corner=np.array((x,y,z)); feature=points[tuple(((base+corner)%cells).transpose(3,0,1,2))]+corner
                distance=np.minimum(distance,np.sum((feature-f)**2,axis=-1))
    return np.clip(1-np.sqrt(distance)/1.4,0,1)

def build():
    OUT.mkdir(parents=True,exist_ok=True)
    p=perlin(64,4,1928)*.65+perlin(64,8,1929)*.25+perlin(64,16,1930)*.10
    w=worley(64,8,1931)
    volume=np.stack((np.clip(p*.72+w*.28,0,1),w),axis=-1)
    chunks=[]
    while True:
        chunks.append(np.rint(volume*255).astype(np.uint8).tobytes())
        if len(volume)==1:break
        n=len(volume)//2; volume=volume.reshape(n,2,n,2,n,2,2).mean(axis=(1,3,5))
    (OUT/'perlin_worley_64.rg8').write_bytes(b''.join(chunks))
    # Stretch smooth periodic noise into long, broken brush strokes.
    n=np.asarray(Image.fromarray(perlin(64,8,1932)[:,:,0]).resize((256,256),Image.Resampling.BICUBIC))
    u,v=np.meshgrid(np.arange(256)/256,np.arange(256)/256,indexing='ij')
    field=np.zeros_like(n)
    for frequency,weight in [(3,.5),(7,.3),(13,.2)]:
        field+=np.sin(2*np.pi*(u*frequency+v*2)+n*5)*weight
    mask=np.clip((field+n*.7-.15)/.8,0,1)
    Image.fromarray(np.rint(mask*255).astype(np.uint8)).save(OUT/'cirrus.png')
    print('Weather noise:',len(b''.join(chunks)),'bytes; seven 3D levels; cirrus256')

if __name__=='__main__':build()
