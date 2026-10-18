"""Bind physical play evidence to authored meshes without invalidating it for UVs.

Triangle positions, morph positions, node frames, material slot identities and
import parameters matter. Optical maps, normals and UVs have their own surface
qualification. Unsupported animated/compressed stock is conservatively hashed
in full. No generated glTF is modified and no Godot process is started.
"""
from pathlib import Path
import argparse, base64, hashlib, json, struct, subprocess
from urllib.parse import unquote, urlparse
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DTYPES = {5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
WIDTHS = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT2':4,'MAT3':9,'MAT4':16}

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()

def load_document(path):
    raw=path.read_bytes(); binary=None
    if path.suffix=='.glb':
        if struct.unpack_from('<4sII',raw)!= (b'glTF',2,len(raw)):
            raise ValueError('unsupported GLB header')
        offset=12; document=None
        while offset<len(raw):
            size,kind=struct.unpack_from('<II',raw,offset);offset+=8
            chunk=raw[offset:offset+size];offset+=size
            if kind==0x4e4f534a:document=json.loads(chunk)
            elif kind==0x004e4942:binary=chunk
        if document is None:raise ValueError('missing GLB document')
    else:document=json.loads(raw)
    buffers=[]
    for row in document.get('buffers',[]):
        uri=row.get('uri')
        if uri is None:
            if binary is None:raise ValueError('missing binary buffer')
            buffers.append(binary)
        elif uri.startswith('data:'):
            header,payload=uri.split(',',1)
            if not header.endswith(';base64'):raise ValueError('non-base64 data URI')
            buffers.append(base64.b64decode(payload,validate=True))
        else:
            if urlparse(uri).scheme:raise ValueError('remote physical buffer is not reproducible')
            local=(path.parent/unquote(uri)).resolve()
            buffers.append(local.read_bytes())
    return document,buffers,raw

def geometry(path):
    document,buffers,raw=load_document(path)
    def fallback():return {'method':'conservative','sha256':sha(raw+b''.join(buffers))}
    if document.get('skins') or document.get('animations') or document.get('extensionsRequired'):
        return fallback()
    def accessor(index):
        spec=document['accessors'][index]
        if 'sparse' in spec or spec.get('normalized'):raise ValueError('unsupported physical accessor')
        view=document['bufferViews'][spec['bufferView']]
        if view.get('extensions'):raise ValueError('compressed view')
        dtype=np.dtype(DTYPES[spec['componentType']]);width=WIDTHS[spec['type']]
        values=np.ndarray((spec['count'],width),dtype=dtype,buffer=buffers[view.get('buffer',0)],
            offset=view.get('byteOffset',0)+spec.get('byteOffset',0),
            strides=(view.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
        if not np.all(np.isfinite(values)):raise ValueError('nonfinite physical accessor')
        return values
    def positions(index,indices):
        values=accessor(index)[indices].astype('<f8');values[values==0]=0
        return sha(values.tobytes())
    try:
        meshes=[]
        for mesh in document.get('meshes',[]):
            rows=[]
            for primitive in mesh['primitives']:
                if primitive.get('extensions'):return fallback()
                attributes=primitive['attributes'];position=attributes['POSITION']
                indices=accessor(primitive['indices']).ravel() if 'indices' in primitive else np.arange(len(accessor(position)))
                rows.append({'mode':primitive.get('mode',4),'material':primitive.get('material'),
                    'positions':positions(position,indices),'count':len(indices),
                    'morphs':[positions(target['POSITION'],indices) if 'POSITION' in target else None
                              for target in primitive.get('targets',[])]})
            meshes.append({'primitives':rows,'weights':mesh.get('weights'),
                           'target_names':mesh.get('extras',{}).get('targetNames')})
        # Include all node metadata because runtime factories can consume it.
        # Mesh datablock names are incidental; semantic node names are not.
        value={'meshes':meshes,'nodes':document.get('nodes',[]),
               'scenes':document.get('scenes',[]),'scene':document.get('scene'),
               'materials':[r.get('name','') for r in document.get('materials',[])]}
        return {'method':'physical','sha256':sha(encoded(value))}
    except (ValueError,KeyError,IndexError,TypeError):return fallback()

def snapshot(root=ROOT):
    root=Path(root).resolve()
    try:
        names=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z','--','game/assets'],cwd=root,stderr=subprocess.DEVNULL).decode().split('\0')
        paths=[root/name for name in set(names) if name]
    except subprocess.CalledProcessError:paths=list((root/'game/assets').rglob('*'))
    rows=[]
    for path in sorted(paths):
        if not path.is_file() or path.suffix not in {'.glb','.gltf','.obj','.mesh','.tscn','.tres'}:continue
        result=geometry(path) if path.suffix in {'.glb','.gltf'} else {'method':'conservative','sha256':sha(path.read_bytes().replace(b'\r\n',b'\n'))}
        imported=Path(str(path)+'.import')
        params=imported.read_text().split('[params]',1)[-1].replace('\r\n','\n').strip() if imported.is_file() else ''
        rows.append([path.relative_to(root).as_posix(),result,sha(params.encode())])
    value={'schema':'orison.physical-inputs.v1','tool_sha256':sha(Path(__file__).read_bytes().replace(b'\r\n',b'\n')),'assets':rows}
    return {**value,'sha256':sha(encoded(value))}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--json',action='store_true')
    args=parser.parse_args();result=snapshot(args.root)
    print(json.dumps(result,indent=2) if args.json else result['sha256'])

if __name__=='__main__':main()
