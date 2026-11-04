"""Pinned source inputs for replaying the legacy F01 finishes, not V2 art.

Recover existing Git blobs instead of duplicating textures or changing current
material owners. All geometry, shading construction and equivalence checks stay
with the original generator/exporter. Missing history fails without fetching.
"""
from pathlib import Path, PurePosixPath
import hashlib
import json
import math
import re
import subprocess

SCHEMA = 'orison.floor01.legacy-material-context.v1'
BOOKS = frozenset('book_'+c for c in ('brown','burgundy','green','navy','ochre','teal'))
ROUGH = frozenset(('concrete_b','slab_b','stair_b'))
DEFAULT_REL = Path('art/data/m11c1/floor01_material_context.json')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def binding(path):
    path = Path(path).resolve()
    return {'path':str(path), 'sha256':digest(path.read_bytes())}


def reader_binding():
    return binding(Path(__file__))


def read_context(path, root):
    """Validate the exact historical tree membership and every source byte."""
    path,root = Path(path).resolve(),Path(root).resolve()
    doc = json.loads(path.read_text(encoding='utf-8'))
    if doc.get('schema') != SCHEMA or set(doc.get('materials',{})) != BOOKS|ROUGH:
        raise ValueError('F01 material context schema or nine-material vocabulary drifted')
    if doc.get('wall_cache_policy')!='TRACKED_COMPATIBILITY_INPUTS_IGNORE_UNTRACKED_BAKE_CACHE':
        raise ValueError('Legacy wall input authority is not explicit')
    if not re.fullmatch('[0-9a-f]{40}',doc.get('source_commit','')):
        raise ValueError('F01 material context requires an exact historical commit')
    if not re.fullmatch('[0-9a-f]{64}',doc.get('compatible_floor01_sha256','')):
        raise ValueError('F01 material context lacks its comparison target hash')
    expected=set()
    for key,recipe in doc['materials'].items():
        channels=recipe.get('channels',{})
        if key in BOOKS:
            source_set='library/furniture/'+key
            if recipe.get('mode')!='set' or recipe.get('source_set')!=source_set or set(channels)!={'albedo','roughness','normal'}:
                raise ValueError('Invalid legacy book material recipe: '+key)
            if recipe.get('metadata')!='art/textures/'+source_set+'/asset.json':
                raise ValueError('Legacy book metadata path drifted: '+key)
            expected.add(recipe['metadata'])
        else:
            source_set='ai_materials/'+key
            if recipe.get('mode')!='roughness' or set(channels)!={'roughness'}:
                raise ValueError('Invalid legacy mineral recipe: '+key)
        for channel,source in channels.items():
            if source!='art/textures/'+source_set+'/'+channel+'.png':
                raise ValueError('Material input leaves its declared source set: '+key)
            expected.add(source)
    if set(doc.get('files',{}))!=expected or len(expected)!=27:
        raise ValueError('Material context must bind exactly its 27 consumed source files')
    for source,row in doc['files'].items():
        p=PurePosixPath(source)
        if p.is_absolute() or '..' in p.parts or '\\' in source or not re.fullmatch('[0-9a-f]{40}',row.get('git_blob','')) or not re.fullmatch('[0-9a-f]{64}',row.get('sha256','')):
            raise ValueError('Invalid historical source path or digest')
    tree=subprocess.check_output(['git','ls-tree','-r','-z',doc['source_commit'],'--',*sorted(expected)],cwd=root)
    entries={}
    for row in tree.split(b'\0'):
        if row:
            header,name=row.split(b'\t',1);mode,kind,oid=header.decode().split()
            if mode!='100644' or kind!='blob':raise ValueError('Historical source is not a regular blob')
            entries[name.decode()]=oid
    if entries!={p:r['git_blob'] for p,r in doc['files'].items()}:
        raise ValueError('Material source blobs do not belong to the declared historical tree')
    sources=sorted(expected)
    packed=subprocess.check_output(['git','cat-file','--batch'],input=''.join(doc['files'][p]['git_blob']+'\n' for p in sources).encode(),cwd=root)
    offset=0;raws={}
    for source in sources:
        end=packed.index(b'\n',offset);header=packed[offset:end].split()
        if len(header)!=3 or header[1]!=b'blob':raise ValueError('Historical material blob is unavailable')
        size=int(header[2]);offset=end+1;raw=packed[offset:offset+size];offset+=size+1
        if digest(raw)!=doc['files'][source]['sha256']:raise ValueError('Historical material bytes changed: '+source)
        raws[source]=raw
    return doc,raws


def ignored_wall_cache(path, root):
    """Only an ignored, untracked bake cache can yield to the pinned context."""
    path,root=Path(path).resolve(),Path(root).resolve()
    if not path.is_relative_to(root/'art/textures/wall_finishes'):
        return False
    relative=path.relative_to(root).as_posix()
    if subprocess.check_output(['git','ls-files','--',relative],cwd=root).strip():
        return False
    return subprocess.run(['git','check-ignore','-q','--',relative],cwd=root).returncode==0


def apply_context(path, root, output, generator):
    doc,raws=read_context(path,root)
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=False)
    rows=[];used_images=set()
    for source,raw in raws.items():
        # Metadata is consumed from its verified blob in memory, not emitted
        # as another JSON artifact among the transaction's generated receipts.
        target=output/source if source.endswith('.png') else None
        if target is not None:
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
            used_images.add(str(target))
        rows.append({'source':source,'staged_path':str(target) if target else None,'sha256':digest(raw)})
    for key,recipe in doc['materials'].items():
        if key in BOOKS:
            meta=json.loads(raws[recipe['metadata']]);mpt=float(meta.get('meters_per_tile',2.0))
            if not math.isfinite(mpt) or mpt<=0:raise ValueError('Invalid legacy material metre scale')
            spec={'mpt':mpt,'slug':recipe['source_set'].replace('/','_')}
        else:
            spec=dict(generator['tex_set'](key))
        spec.update({channel:str(output/source) for channel,source in recipe['channels'].items()})
        generator['_tex_cache'][key]=spec
    return {'binding':binding(path),'reader':reader_binding(),'files':rows},used_images


def validate_receipt(receipt, manifest, root, candidate_root):
    doc,raws=read_context(manifest,root)
    if receipt.get('binding')!=binding(manifest) or receipt.get('reader')!=reader_binding():
        raise ValueError('Material context receipt input binding drifted')
    expected={p:digest(raw) for p,raw in raws.items()};seen={}
    base=(Path(candidate_root)/'material_context').resolve()
    for row in receipt.get('files',[]):
        source=row.get('source')
        if source in seen or source not in expected or row.get('sha256')!=expected[source]:
            raise ValueError('Invalid or duplicate material context source')
        if not source.endswith('.png'):
            if row.get('staged_path') is not None:raise ValueError('Context metadata must be consumed in memory')
            seen[source]=None
            continue
        target=Path(row.get('staged_path','')).resolve()
        if target!=base/source or not target.is_relative_to(base):
            raise ValueError('Invalid or duplicate staged material context source')
        if row.get('sha256')!=expected[source] or digest(target.read_bytes())!=expected[source]:
            raise ValueError('Staged historical material source drifted')
        seen[source]=str(target)
    if set(seen)!=set(expected):raise ValueError('Historical material receipt is incomplete')
    if set(receipt.get('used_images',[]))!={seen[p] for p in seen if p.endswith('.png')}:
        raise ValueError('Historical material context did not feed every declared image to the generator')
    return doc
