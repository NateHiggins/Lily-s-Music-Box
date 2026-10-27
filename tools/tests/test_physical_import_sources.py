"""A local cache must not make an incomplete checkout look reproducible."""
from pathlib import Path
import subprocess,sys,tempfile,unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from check_physical_import_sources import evaluate

class PhysicalImportSourcesTests(unittest.TestCase):
    def setup_repo(self,folder):
        root=Path(folder);subprocess.run(['git','init','--quiet',str(root)],check=True)
        (root/'.gitattributes').write_text('*.import -text\n*.glb -text\n',encoding='utf8')
        asset=root/'game/assets/props/test.glb';asset.parent.mkdir(parents=True);asset.write_bytes(b'fixture source')
        metadata=Path(str(asset)+'.import')
        metadata.write_text('[remap]\nimporter="scene"\ntype="PackedScene"\n[deps]\nsource_file="res://assets/props/test.glb"\n[params]\nnodes/root_scale=1.0\n',encoding='utf8')
        subprocess.run(['git','add','--','.gitattributes','game/assets/props/test.glb','game/assets/props/test.glb.import'],cwd=root,check=True,capture_output=True)
        return root,metadata
    def test_tracked_source_without_an_import_cache_is_portable(self):
        with tempfile.TemporaryDirectory() as folder:
            root,_=self.setup_repo(folder);result=evaluate(root)
            self.assertEqual(result['referenced'],1);self.assertEqual(result['missing'],[]);self.assertEqual(result['wrong'],[])
    def test_local_only_settings_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root,_=self.setup_repo(folder)
            subprocess.run(['git','rm','--cached','--','game/assets/props/test.glb.import'],cwd=root,check=True,capture_output=True)
            self.assertTrue(any('untracked' in row for row in evaluate(root)['wrong']))
    def test_absent_settings_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root,path=self.setup_repo(folder);path.unlink()
            self.assertEqual(evaluate(root)['missing'],['game/assets/props/test.glb.import'])
    def test_a_copied_import_cannot_point_at_another_mesh(self):
        with tempfile.TemporaryDirectory() as folder:
            root,path=self.setup_repo(folder);path.write_text(path.read_text().replace('props/test.glb','props/other.glb'),encoding='utf8')
            self.assertTrue(any('source binding differs' in row for row in evaluate(root)['wrong']))
    def test_line_ending_policy_is_explicit(self):
        with tempfile.TemporaryDirectory() as folder:
            root,_=self.setup_repo(folder);(root/'.gitattributes').write_text('',encoding='utf8')
            self.assertTrue(any('requires -text' in row for row in evaluate(root)['wrong']))

    def test_model_bytes_need_protection_even_when_import_settings_are_safe(self):
        with tempfile.TemporaryDirectory() as folder:
            root,_=self.setup_repo(folder);(root/'.gitattributes').write_text('*.import -text\n',encoding='utf8')
            self.assertEqual(evaluate(root)['wrong'],['game/assets/props/test.glb: hash-bound physical source requires -text'])

    def test_large_inventory_does_not_use_a_windows_sized_argument_list(self):
        with tempfile.TemporaryDirectory() as folder:
            root,template=self.setup_repo(folder)
            paths=[]
            for index in range(200):
                name=f"game/assets/props/{index:03d}_"+'long physical source '*4+'.glb'
                asset=root/name
                asset.write_bytes(b'fixture source')
                metadata=Path(str(asset)+'.import')
                metadata.write_text(template.read_text().replace('game/assets/','').replace(
                    'props/test.glb',name.removeprefix('game/assets/')),encoding='utf8')
                paths.extend([name,name+'.import'])
            for begin in range(0,len(paths),32):
                subprocess.run(['git','add','--',*paths[begin:begin+32]],cwd=root,check=True,capture_output=True)
            result=evaluate(root)
            self.assertEqual(result['referenced'],201)
            self.assertEqual(result['missing'],[])
            self.assertEqual(result['wrong'],[])

if __name__=='__main__':unittest.main()
