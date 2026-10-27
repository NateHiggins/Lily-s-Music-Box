"""Authored tileable Perlin-Worley optical density; no photographic pixels.

RG8 volume contains Perlin-Worley base and cellular erosion. Every 3D mip is
box-filtered across all three axes. Cirrus is a cheap tileable high cloud mask.
"""
from pathlib import Path
import numpy as np
from PIL import Image
import argparse
import json

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

def mip_bytes(volume):
    chunks=[]
    while True:
        chunks.append(np.rint(np.clip(volume,0,1)*255).astype(np.uint8).tobytes())
        if len(volume)==1:break
        n=len(volume)//2
        volume=volume.reshape(n,2,n,2,n,2,volume.shape[-1]).mean(axis=(1,3,5))
    return b''.join(chunks)

def build_fluid(output):
    """Offline curl of a periodic vector potential; one runtime flow lookup.

    Central derivatives commute on this periodic grid. A single global scale
    preserves that discrete identity; per-voxel normalization would not.
    Quantization/interpolation and finite coordinate warps are approximations,
    not a mass-conserving cloud simulation. Axes are image Z,Y,X.
    """
    output.mkdir(parents=True,exist_ok=True)
    potential=np.stack([perlin(32,3,1940+i)*.75+perlin(32,6,1950+i)*.25
                        for i in range(3)],axis=-1)
    def derivative(a,axis):return (np.roll(a,-1,axis)-np.roll(a,1,axis))*.5
    curl=np.stack((derivative(potential[...,2],1)-derivative(potential[...,1],0),
                   derivative(potential[...,0],0)-derivative(potential[...,2],2),
                   derivative(potential[...,1],2)-derivative(potential[...,0],1)),axis=-1)
    curl/=max(float(np.max(np.abs(curl))),1e-8)
    divergence=derivative(curl[...,0],2)+derivative(curl[...,1],1)+derivative(curl[...,2],0)
    assert np.max(np.abs(divergence))<1e-5
    flow=mip_bytes(curl*.5+.5)
    p=perlin(128,4,1928)*.65+perlin(128,8,1929)*.25+perlin(128,16,1930)*.10
    base=mip_bytes(np.clip(p*.72+worley(128,8,1931)*.28,0,1)[...,None])
    (output/'perlin_worley_128.r8').write_bytes(base)
    (output/'cloud_curl_32.rgb8').write_bytes(flow)
    result={'base_bytes':len(base),'flow_bytes':len(flow),
            'unquantized_discrete_divergence_max':float(np.max(np.abs(divergence))),
            'method':'periodic central-difference curl of three seeded scalar potentials; full 3D mip chains'}
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fluid-output',type=Path,help='Bake new base/flow stock only; preserve legacy assets')
    args=parser.parse_args()
    if args.fluid_output:build_fluid(args.fluid_output)
    else:build()
