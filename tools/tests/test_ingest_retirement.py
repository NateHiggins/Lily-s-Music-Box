"""Full and targeted AI ingestion must not resurrect a retired material plate."""
from pathlib import Path
import contextlib,io,json,sys,tempfile,unittest
from unittest.mock import patch
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'art/tools'))
import ingest_material_sources as ingest

class Retirement(unittest.TestCase):
    def exercise(self,args,mapped='procedural/bakelite'):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'art/textures/ai_sources';source.mkdir(parents=True)
            output=root/'art/textures/ai_materials';output.mkdir()
            gpu=root/'game/assets/building/textures';gpu.mkdir(parents=True)
            recipe=root/'art/textures/procedural/bakelite';recipe.mkdir(parents=True)
            mapping=root/'art/textures/catalog_mapping.json';mapping.write_text(json.dumps({'bakelite':mapped}))
            Image.new('RGB',(64,64),(43,31,24)).save(source/'bakelite.png')
            for name,color in [('albedo',(51,35,26)),('roughness',(66,66,66)),('normal',(128,128,255))]:
                Image.new('RGB',(16,16),color).save(recipe/(name+'.png'))
            with contextlib.ExitStack() as stack:
                for name,value in {'ROOT':str(root),'SRC':str(source),'OUT':str(output),'GODOT_TEX':str(gpu),
                    'MAPPING':str(mapping),'STATE':str(output/'.ingest_state.json'),
                    'GODOT_STAGE':('bakelite',),'GODOT_FAMILY_STAGE':()}.items():stack.enter_context(patch.object(ingest,name,value))
                stack.enter_context(patch.object(sys,'argv',['ingest']+args))
                stack.enter_context(patch.object(ingest.generate_runtime_materials,'generate',return_value=[]))
                write=stack.enter_context(patch.object(ingest,'write_set',side_effect=RuntimeError('AI rebake attempted')))
                stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
                if mapped.startswith('procedural/'):
                    ingest.main();write.assert_not_called()
                    self.assertEqual(json.loads(mapping.read_text())['bakelite'],mapped)
                    for name,suffix in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
                        self.assertEqual((recipe/(name+'.png')).read_bytes(),(gpu/('T_ai_materials_bakelite_'+suffix+'.png')).read_bytes())
                else:
                    with self.assertRaisesRegex(RuntimeError,'AI rebake attempted'):ingest.main()
                    write.assert_called_once()
    def test_full_ingest_keeps_procedural_owner(self):self.exercise(['--full'])
    def test_targeted_slot_keeps_procedural_owner(self):self.exercise(['--slot','bakelite'])
    def test_ai_owned_slot_still_rebuilds(self):self.exercise(['--full'],'ai_materials/bakelite')

if __name__=='__main__':unittest.main()
