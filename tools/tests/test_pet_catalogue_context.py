import copy,importlib.util,json,subprocess,tempfile,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('proposal',HERE.parent/'rebind_additive_material.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
ENTRIES=[{'id': 'PetFur_judge',
  'catalog': {'base_color': [1, 1, 1, 1], 'roughness': 1.0, 'metallic': 0},
  'source_set': None,
  'in_game_catalog': True,
  'texture_status': 'no_maps',
  'import_tier': 'surface'},
 {'id': 'PetFur_Cream',
  'catalog': {'base_color': [1, 1, 1, 1], 'roughness': 1.0, 'metallic': 0},
  'source_set': None,
  'in_game_catalog': True,
  'texture_status': 'no_maps',
  'import_tier': 'surface'},
 {'id': 'PetSkin_Dark',
  'catalog': {'base_color': [1, 1, 1, 1], 'roughness': 1.0, 'metallic': 0},
  'source_set': None,
  'in_game_catalog': True,
  'texture_status': 'no_maps',
  'import_tier': 'surface'},
 {'id': 'PetFur_lafitte',
  'catalog': {'base_color': [1, 1, 1, 1], 'roughness': 1.0, 'metallic': 0},
  'source_set': None,
  'in_game_catalog': True,
  'texture_status': 'no_maps',
  'import_tier': 'surface'},
 {'id': 'PetFur_Shadow',
  'catalog': {'base_color': [1, 1, 1, 1], 'roughness': 1.0, 'metallic': 0},
  'source_set': None,
  'in_game_catalog': True,
  'texture_status': 'no_maps',
  'import_tier': 'surface'},
 {'id': 'PetEye_Olive',
  'catalog': {'base_color': [1, 1, 1, 1], 'roughness': 1.0, 'metallic': 0},
  'source_set': None,
  'in_game_catalog': True,
  'texture_status': 'no_maps',
  'import_tier': 'surface'},
 {'id': 'PetEye_Dark',
  'catalog': {'base_color': [1, 1, 1, 1], 'roughness': 1.0, 'metallic': 0},
  'source_set': None,
  'in_game_catalog': True,
  'texture_status': 'no_maps',
  'import_tier': 'surface'},
 {'id': 'PetSkin_Pink',
  'catalog': {'base_color': [1, 1, 1, 1], 'roughness': 1.0, 'metallic': 0},
  'source_set': None,
  'in_game_catalog': True,
  'texture_status': 'no_maps',
  'import_tier': 'surface'}]

def fixture():
 before={p:b'unchanged\n' for p in m.UNCHANGED_PATHS}
 before['game/data/runtime_material_sets.json']=json.dumps({'materials':{}}).encode()
 for p in m.CATALOGUE_PATHS[:2]:before[p]=json.dumps({'old':{'roughness':.5}}).encode()
 before[m.CATALOGUE_PATHS[2]]=json.dumps({'schema':'schema','about':'old','legacy_order':{'catalog':['old']},'materials':[{'id':'old','catalog':{'roughness':.5}}]}).encode()
 after=copy.deepcopy(before)
 for p in m.CATALOGUE_PATHS[:2]:
  d=json.loads(before[p]);d.update({e['id']:e['catalog'] for e in ENTRIES});after[p]=json.dumps(d).encode()
 d=json.loads(before[m.CATALOGUE_PATHS[2]]);d['about']+=m.PET_ABOUT;d['materials']+=ENTRIES;after[m.CATALOGUE_PATHS[2]]=json.dumps(d).encode()
 return before,after

class CatalogueOnlyTests(unittest.TestCase):
 def test_positive_exact_delta(self):
  a,b=fixture();m.prove_catalogue_only(a,b,m.PET_KEYS,ENTRIES)
 def test_old_recipe_refused(self):
  a,b=fixture();p=m.CATALOGUE_PATHS[0];d=json.loads(b[p]);d['old']['roughness']=.7;b[p]=json.dumps(d).encode()
  with self.assertRaises(AssertionError):m.prove_catalogue_only(a,b,m.PET_KEYS,ENTRIES)
 def test_old_order_refused(self):
  a,b=fixture();p=m.CATALOGUE_PATHS[0];d=json.loads(b[p]);d={'other':{},**d};b[p]=json.dumps(d).encode()
  with self.assertRaises(AssertionError):m.prove_catalogue_only(a,b,m.PET_KEYS,ENTRIES)
 def test_runtime_change_refused(self):
  for p in m.UNCHANGED_PATHS:
   with self.subTest(path=p):
    a,b=fixture();b[p]+=b'changed'
    with self.assertRaises(AssertionError):m.prove_catalogue_only(a,b,m.PET_KEYS,ENTRIES)
 def test_mapped_material_refused(self):
  a,b=fixture();rows=copy.deepcopy(ENTRIES);rows[0]['source_set']='library/pet';
  with self.assertRaises(AssertionError):m.prove_catalogue_only(a,b,m.PET_KEYS,rows)
 def test_wrong_or_missing_named_entries_refused(self):
  a,b=fixture()
  for rows in [ENTRIES[:-1],ENTRIES+[ENTRIES[0]]]:
   with self.assertRaises(AssertionError):m.prove_catalogue_only(a,b,m.PET_KEYS,rows)
 def test_registry_old_entry_edit_refused(self):
  a,b=fixture();p=m.CATALOGUE_PATHS[2];d=json.loads(b[p]);d['materials'][0]['catalog']['roughness']=1;b[p]=json.dumps(d).encode()
  with self.assertRaises(AssertionError):m.prove_catalogue_only(a,b,m.PET_KEYS,ENTRIES)
 def test_real_git_fresh_transitive_and_unchanged_stale(self):self.integration(False)
 def test_unrelated_stale_payload_update_refused(self):self.integration(True)
 def integration(self,alter_stale):
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);a,b=fixture()
   def put(p,raw):
    file=root/p;file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(raw)
   for p,raw in a.items():put(p,raw)
   direct='art/blender/pet_context_construction.json';stale='art/blender/stale_construction.json';dependent='game/tests/fixtures/orison_context.json'
   fresh={'source_bindings':{m.CATALOGUE_PATHS[0]:m.digest(a[m.CATALOGUE_PATHS[0]])},'parts':[{'id':'unchanged'}]};freshraw=(json.dumps(fresh)+'\n').encode();put(direct,freshraw)
   old={'source_bindings':{m.CATALOGUE_PATHS[0]:'historical-stale'},'parts':[{'id':'old'}]};oldraw=json.dumps(old).encode();put(stale,oldraw)
   consumer={'source_bindings':{direct:m.digest(freshraw)},'parts':['retained']};put(dependent,json.dumps(consumer).encode())
   subprocess.run(['git','init','-q',str(root)],check=True)
   subprocess.run(['git','-C',str(root),'add','--',*a,direct,stale,dependent],check=True)
   subprocess.run(['git','-C',str(root),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture'],check=True)
   for p,raw in b.items():put(p,raw)
   if alter_stale:old['parts'][0]['id']='unrelated edit';put(stale,json.dumps(old).encode())
   snapshot={p:(root/p).read_bytes() for p in [direct,stale,dependent]}
   if alter_stale:
    with self.assertRaises(AssertionError):m.catalogue_only(root,'HEAD',m.PET_KEYS,ENTRIES,root/'report.json',preserve=True)
    self.assertFalse((root/'report.json').exists())
   else:
    report=m.catalogue_only(root,'HEAD',m.PET_KEYS,ENTRIES,root/'report.json',preserve=True)
    self.assertEqual({r['path']for r in report['updates']},{direct,dependent});self.assertEqual(len(report['preserved_baseline_drift']),1)
   self.assertEqual(snapshot,{p:(root/p).read_bytes()for p in snapshot})

if __name__=='__main__':unittest.main()
