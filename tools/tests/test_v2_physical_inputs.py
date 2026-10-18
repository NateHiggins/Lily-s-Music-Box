"""Physical proof survives optical edits, never changed geometry or import policy."""
from pathlib import Path
import json, os, struct, sys, tempfile, unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import v2_physical_inputs as p
import audit_orison_v2_completeness as audit

def fixture(path,positions=None,normals=None,uv=None,indices=None,morph=None,node=None):
    points=positions or [(0,0,0),(1,0,0),(0,1,0)]
    document={'asset':{'version':'2.0'},'nodes':[node or {'name':'OperablePart','mesh':0}],
              'scenes':[{'nodes':[0]}],'scene':0,'bufferViews':[],'accessors':[],
              'materials':[{'name':'iron'}]}
    binary=bytearray()
    def add(values,width,component=5126):
        offset=len(binary);flat=[v for row in values for v in row]
        binary.extend(struct.pack('<'+('f' if component==5126 else 'I')*len(flat),*flat))
        document['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(binary)-offset})
        index=len(document['accessors'])
        document['accessors'].append({'bufferView':index,'componentType':component,'count':len(values),'type':{1:'SCALAR',2:'VEC2',3:'VEC3'}[width]})
        return index
    attrs={'POSITION':add(points,3),'NORMAL':add(normals or [(0,0,1)]*len(points),3),'TEXCOORD_0':add(uv or [(0,0)]*len(points),2)}
    primitive={'attributes':attrs,'material':0}
    if indices is not None:primitive['indices']=add([(i,) for i in indices],1,5125)
    if morph is not None:primitive['targets']=[{'POSITION':add(morph,3)}]
    document['meshes']=[{'primitives':[primitive]}];document['buffers']=[{'byteLength':len(binary)}]
    text=json.dumps(document,separators=(',',':')).encode();text+=b' '*((-len(text))%4)
    binary+=b'\0'*((-len(binary))%4)
    path.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(text)+len(binary))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(binary),0x004e4942)+binary)

class PhysicalInputTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.path=self.root/'game/assets/part.glb';self.path.parent.mkdir(parents=True);fixture(self.path)
    def digest(self):return p.snapshot(self.root)['sha256']
    def test_normals_and_uvs_do_not_invalidate_play(self):
        before=self.digest();fixture(self.path,normals=[(0,1,0)]*3,uv=[(1,1)]*3)
        self.assertEqual(before,self.digest())
    def test_binary_mesh_bytes_are_never_line_normalized(self):
        binary=self.path.with_suffix('.mesh');binary.write_bytes(b'prefix\r\nsuffix');before=self.digest()
        binary.write_bytes(b'prefix\nsuffix');self.assertNotEqual(before,self.digest())
    def test_same_size_position_edit_with_restored_mtime_invalidates(self):
        before=self.digest();stamp=self.path.stat();size=stamp.st_size
        fixture(self.path,positions=[(0,0,0),(2,0,0),(0,1,0)]);os.utime(self.path,ns=(stamp.st_atime_ns,stamp.st_mtime_ns))
        self.assertEqual(size,self.path.stat().st_size);self.assertNotEqual(before,self.digest())
    def test_reindexing_preserves_identical_oriented_triangles(self):
        before=self.digest();fixture(self.path,positions=[(0,1,0),(0,0,0),(1,0,0)],indices=[1,2,0])
        self.assertEqual(before,self.digest())
    def test_reversed_winding_invalidates(self):
        before=self.digest();fixture(self.path,indices=[0,2,1]);self.assertNotEqual(before,self.digest())
    def test_morph_position_invalidates(self):
        fixture(self.path,morph=[(0,0,0)]*3);before=self.digest()
        fixture(self.path,morph=[(0,.001,0)]*3);self.assertNotEqual(before,self.digest())
    def test_node_pose_invalidates(self):
        before=self.digest();fixture(self.path,node={'name':'OperablePart','mesh':0,'translation':[0,1,0]})
        self.assertNotEqual(before,self.digest())
    def test_import_params_matter_but_cache_uid_does_not(self):
        imported=Path(str(self.path)+'.import');imported.write_text('[remap]\nuid="one"\n[params]\nmeshes/force_disable_compression=true\n')
        before=self.digest();imported.write_text(imported.read_text().replace('"one"','"two"'));self.assertEqual(before,self.digest())
        imported.write_text(imported.read_text().replace('=true','=false'));self.assertNotEqual(before,self.digest())

    def receipt(self):
        source=self.root/'game/tests/physical.gd';source.parent.mkdir(parents=True,exist_ok=True);source.write_text('# fixture\n')
        return {'schema_version':2,'evidence_kind':'runtime_contract','production_runtime':True,'selector':'v2',
            'execution':{'completed':True,'exit_code':0,'timed_out':False},
            'source':{'test_path':'game/tests/physical.gd','test_sha256':audit.sha256_file(source),
                      'repository_head':'1'*40,'runtime_inputs_sha256':audit.runtime_inputs_sha256(self.root),
                      'physical_inputs_sha256':self.digest()},
            'contracts':{name:{'executed':True,'status':'PASS',**extra} for name,extra in [
                ('production_composition',{'identities':['physical']}),('save_reconstruction',{}),
                ('premature_action_denial',{}),('physical_service_round',{}),
                ('teardown',{'measurement_scope':'runtime_owned','retained_nodes':0,'retained_resources':0,'retained_playbacks':0})]}}

    def test_ledger_refuses_receipt_after_mesh_changes(self):
        receipt=self.receipt();self.assertEqual(audit.runtime_receipt_errors(receipt,self.root),[])
        fixture(self.path,positions=[(0,0,0),(2,0,0),(0,1,0)])
        self.assertIn('physical-input SHA-256 is missing or stale',audit.runtime_receipt_errors(receipt,self.root))

    def test_ledger_refuses_unexecuted_physical_round(self):
        receipt=self.receipt();receipt['contracts']['physical_service_round']['executed']=False
        self.assertIn('physical_service_round: executed PASS required',audit.runtime_receipt_errors(receipt,self.root))

    def test_physical_domain_rechecked_before_ledger_publication(self):
        snapshot=audit._InputDigests(self.root);snapshot.get('physical')
        fixture(self.path,positions=[(0,0,0),(2,0,0),(0,1,0)])
        with self.assertRaisesRegex(audit.AuditError,'physical inputs changed'):snapshot.verify_unchanged()

if __name__=='__main__':unittest.main()
