"""Export the selectively merged native facade; no external prototype dependency.

The blend retains closed editable construction and reviewed render partitions.
Export only FixedFacade/EntryLeaf. Retired baseline construction remains in Git.
"""
from pathlib import Path
import ast, hashlib, json, sys
import bpy, bmesh, numpy as np

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from check_exported_tangents import validate
from metric_gltf_export import CatalogueMetricUV

def digest(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw if path.suffix in ['.blend','.glb'] else raw.replace(b'\r\n',b'\n')).hexdigest()

class PortalMetricUV(CatalogueMetricUV):
    """Preserve this delivered family's established 1-v chart phase."""
    def gather_mesh_hook(self,mesh,*args):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for p in mesh.primitives:
            q=np.frombuffer(p.attributes['_METRE_UV'].buffer_view.data,dtype='<f4').reshape(-1,3)
            uv=np.column_stack((q[:,0],np.float32(1)-q[:,1])).astype('<f4')
            p.attributes.pop('_METRE_UV');p.attributes.pop('_TANGENT_GUIDE',None)
            p.attributes['TEXCOORD_0'].buffer_view=BinaryData(uv.tobytes(),BufferViewTarget.ARRAY_BUFFER)
            def values(key):return np.frombuffer(p.attributes[key].buffer_view.data,dtype='<f4').reshape(-1,3).astype(float)
            pos=values('POSITION');n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None]
            ids=np.frombuffer(p.indices.buffer_view.data,dtype={5125:'<u4',5123:'<u2',5121:'u1'}[p.indices.component_type]).reshape(-1,3)
            a=uv[ids[:,1]].astype(float)-uv[ids[:,0]];b=uv[ids[:,2]].astype(float)-uv[ids[:,0]]
            det=a[:,0]*b[:,1]-a[:,1]*b[:,0];assert np.all(abs(det)>1e-12)
            du=((pos[ids[:,1]]-pos[ids[:,0]])*b[:,1,None]-(pos[ids[:,2]]-pos[ids[:,0]])*a[:,1,None])/det[:,None]
            dv=((pos[ids[:,2]]-pos[ids[:,0]])*a[:,0,None]-(pos[ids[:,1]]-pos[ids[:,0]])*b[:,0,None])/det[:,None]
            t=np.zeros_like(pos);v=np.zeros_like(pos)
            for c in range(3):np.add.at(t,ids[:,c],du);np.add.at(v,ids[:,c],dv)
            t-=n*np.sum(n*t,axis=1)[:,None]
            for vertex in np.flatnonzero(np.linalg.norm(t,axis=1)<1e-12):
                for face in np.flatnonzero(np.any(ids==vertex,axis=1)):
                    candidate=du[face]-n[vertex]*np.dot(n[vertex],du[face])
                    if np.linalg.norm(candidate)>1e-12:t[vertex]=candidate;break
            t/=np.linalg.norm(t,axis=1)[:,None]
            w=np.where(np.sum(np.cross(n,t)*v,axis=1)<0,-1.,1.)
            p.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,w)).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)

def main():
    native=ROOT/'art/blender/front_facade.blend'
    bpy.ops.wm.open_mainfile(filepath=str(native))
    assert bpy.context.scene.get('portal_revision')=='20261029', 'Use the legacy builder only for the historical baseline.'
    legacy=Path(__file__).with_name('build_media_battery_supply.py')
    tree=ast.parse(legacy.read_text(encoding='utf-8'));namespace={'np':np}
    exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='ExportDerivatives'],type_ignores=[]),str(legacy),'exec'),namespace)
    class MixedDerivatives:
        def gather_mesh_hook(self,mesh,*args):
            marked=[('_METRE_UV' in p.attributes) for p in mesh.primitives]
            assert all(marked) or not any(marked)
            (PortalMetricUV() if all(marked) else namespace['ExportDerivatives']()).gather_mesh_hook(mesh,*args)
    import io_scene_gltf2
    io_scene_gltf2.glTF2ExportUserExtension=MixedDerivatives
    bpy.ops.object.select_all(action='DESELECT')
    roots=[bpy.data.objects[n] for n in ['FixedFacade','EntryLeaf']]
    draws=[o for root in roots for o in root.children if o.type=='MESH']
    assert len(draws)==59
    for o in roots+draws:o.hide_set(False);o.select_set(True)
    asset=ROOT/'game/assets/props/front_facade.glb'
    bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_tangents=True,export_attributes=True,export_materials='NONE',export_animations=False,export_extras=False)
    result=validate(asset);assert result['status']=='PASS',result
    fixture=json.loads((ROOT/'game/tests/fixtures/orison_front_facade.json').read_bytes())
    tiles={p['key']:p['tile'] for p in fixture['parts']}
    fixture['parts']=[{'name':o.name,'key':o['key'],'branch':o['branch'],'triangles':len(o.data.polygons),'tile':tiles[o['key']]} for o in sorted(draws,key=lambda o:o.name)]
    stocks=[]
    for o in bpy.data.collections['ClosedFacadeConstruction'].objects:
        p=np.array([v.co[:] for v in o.data.vertices]);bm=bmesh.new();bm.from_mesh(o.data)
        assert all(e.is_manifold for e in bm.edges),o.name
        volume=bm.calc_volume(signed=True);bm.free();assert volume>0,o.name
        stocks.append({'name':o.name,'key':o['key'],'branch':o['branch'],'volume_m3':volume,'bounds':p.min(axis=0).tolist()+p.max(axis=0).tolist()})
    fixture['stocks']=stocks;fixture['asset_sha256']=digest(asset);fixture['triangles']=result['triangles']
    fixture['native_revision']='20261029';fixture['native_sha256']=digest(native)
    for path in [Path(__file__),Path(__file__).with_name('build_front_facade.py'),legacy,Path(__file__).with_name('metric_gltf_export.py')]:fixture['source_bindings'][path.relative_to(ROOT).as_posix()]=digest(path)
    for rel in ['art/blender/front_facade_inventory.json','game/tests/fixtures/orison_front_facade.json']:(ROOT/rel).write_text(json.dumps(fixture,indent=2)+'\n',newline='\n')
    print('FRONT FACADE EXPORT',json.dumps(result),flush=True)

if __name__=='__main__':main()
