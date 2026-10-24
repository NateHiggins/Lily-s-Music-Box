import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_closure_source import check_registered_layout
class ConsumedCitySourceTest(unittest.TestCase):
    def setUp(self):
        self.layout=json.loads((ROOT/'art/data/building_layout.json').read_text())
        self.proof=json.loads((ROOT/'art/blender/city_shells_consumed_layout.json').read_text())
        self.registration=json.loads((ROOT/'art/blender/city_shells_registration.json').read_text())
    def test_current_and_editorial_copy_keep_registered_geometry(self):
        check_registered_layout(self.layout,self.proof,self.registration)
        self.layout['editorial_note']='Changed story copy'
        check_registered_layout(self.layout,self.proof,self.registration)
    def test_physical_dimensions_material_or_identity_cannot_reuse_library(self):
        for field in ['rect','h','mat','id']:
            layout=copy.deepcopy(self.layout)
            floor=next(row for row in layout['floors'] if row['id']=='F01')
            row=next(row for row in floor['furniture'] if row['id']==self.proof['records'][0]['id'])
            if field=='rect':row['rect'][0]+=.01
            elif field=='h':row['h']+=.01
            else:row[field]+='_changed'
            with self.subTest(field=field),self.assertRaises(AssertionError):check_registered_layout(layout,self.proof,self.registration)
    def test_projection_cannot_attach_to_a_different_source_or_native(self):
        for field in ['layout_sha256','native_sha256']:
            proof=copy.deepcopy(self.proof);proof[field]='0'*64
            with self.subTest(field=field),self.assertRaises(AssertionError):check_registered_layout(self.layout,proof,self.registration)
if __name__=='__main__':unittest.main()
