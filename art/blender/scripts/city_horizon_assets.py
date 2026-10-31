"""Whole-building city block exports through the shared strict native pipeline."""
import collections,hashlib,re
from types import SimpleNamespace

def block_id(part):
    identity,key=part.split('__')
    assert key and re.fullmatch(r'HORIZON_(?:(?:NEAR|FAR)_\d+_\d+|STREET_END_\d+)_P\d+(?:R\d+)?',identity),part
    return '_'.join(identity.split('_')[:4])

def group_parts(names,expected_buildings):
    groups=collections.defaultdict(list);seen=set();owners={}
    for name in names:
        assert name not in seen,name
        identity=name.split('__')[0];group=block_id(name)
        assert identity in expected_buildings,identity
        assert owners.setdefault(identity,group)==group
        groups[group].append(name);seen.add(name)
    assert set(owners)==set(expected_buildings),(set(expected_buildings)-set(owners),set(owners)-set(expected_buildings))
    return {k:sorted(v) for k,v in sorted(groups.items())}

def manifest_paths(source):
    """Validate the exact registered shard roster before policy/discovery uses it."""
    assert source['schema']==2 and source['frame']=='ORISON_V2_BUILDING_FRAME'
    profiles=[r['id'] for r in source['buildings']];assert profiles and len(profiles)==len(set(profiles))
    paths=[];levels=[]
    for role,entries in [('base',source['assets']),('body_lod',source['body_lod']['assets'])]:
        names=[];owners={}
        for entry in entries:
            group=group_parts(entry['parts'],set(entry['buildings']))
            assert len(group)==1 and entry['block'] in group
            assert len(entry['buildings'])==len(set(entry['buildings']))
            suffix=entry['block'].removeprefix('HORIZON_').lower()+('_lod1' if role=='body_lod' else '')
            assert entry['asset']=='res://assets/props/city_horizon_'+suffix+'.glb'
            for identity in entry['buildings']:
                assert identity in profiles and identity not in owners;owners[identity]=entry['asset']
            names.extend(entry['parts']);paths.append(entry['asset'])
        assert len(names)==len(set(names)) and names
        levels.append((set(names),owners))
    assert set(levels[0][1])==set(profiles)
    lower=source['body_lod'];assert float(lower['error_m'])>0.
    assert len(lower['parts'])==len(set(lower['parts'])) and set(lower['parts'])==levels[1][0]
    for identity in levels[1][1]:
        assert {n for n in levels[0][0] if n.split('__')[0]==identity}=={n for n in levels[1][0] if n.split('__')[0]==identity}
    assert len(paths)==len(set(paths))
    return paths

def export_blocks(root,family,draws,expected_buildings):
    # Called after native geometry/UV/stock/contact controls. No mesh mutation.
    import bpy
    from fabrication_native_batch import export
    from city_ground_apron_geometry import exported_bounds
    by_name={draw.name:draw for draw in draws};assert len(by_name)==len(draws)
    groups=group_parts([draw.name for draw in draws],expected_buildings)
    result={}
    for block,names in groups.items():
        suffix=block.removeprefix('HORIZON_').lower()+('_lod1' if family=='lod1' else '')
        asset_name='city_horizon_'+suffix
        proof=export(root,asset_name,SimpleNamespace(objects=[by_name[n] for n in names]),staged_output=True,save_native=False)
        asset=root/'game/assets/props'/(asset_name+'.glb');raw=asset.read_bytes()
        assert len(raw)<95*1024*1024
        result[asset_name]=dict(role='body_lod' if family=='lod1' else 'base',block=block,buildings=sorted({n.split('__')[0] for n in names}),asset=asset.relative_to(root).as_posix(),sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw),bounds=exported_bounds(raw),export_check=proof,parts=[dict(name=n,key=n.split('__')[-1],triangles=len(by_name[n].data.polygons)) for n in names])
    native=root/'art/blender'/('city_horizon_'+family+'.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
    assert native.stat().st_size<95*1024*1024
    digest=hashlib.sha256(native.read_bytes()).hexdigest()
    for record in result.values():record.update(native=native.relative_to(root).as_posix(),native_sha256=digest)
    return result
