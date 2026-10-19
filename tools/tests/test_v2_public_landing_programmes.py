"""Actual retained floor owners, holes and immutable projection boundaries."""
import copy
import json
from pathlib import Path
import sys
import unittest
from types import SimpleNamespace

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_v2_public_landings import project
from v2_space_footprints import programme_errors,contains,rectangles
from audit_orison_v2_completeness import V2Model,Ledger


class PublicLandingProgrammes(unittest.TestCase):
    def setUp(self):
        self.layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
        self.source=json.loads((ROOT/'art/data/orison_v2/public_landings_source.json').read_text(encoding='utf-8'))

    def test_source_projection_is_current_idempotent_and_keeps_all_other_owners(self):
        before=copy.deepcopy(self.layout)
        after=project(before,self.source)
        self.assertEqual(before,self.layout)
        self.assertEqual(after,self.layout)
        self.assertEqual(project(after,self.source),after)
        owned={r['id'] for r in self.source['programmes']}
        for table in before:
            if table not in ['spaces','platforms']:self.assertEqual(before[table],after[table],table)
        repair_ids={r['id'] for r in self.source['platform_repairs']}
        self.assertEqual([r for r in before['platforms'] if r['id'] not in repair_ids],
                         [r for r in after['platforms'] if r['id'] not in repair_ids])
        self.assertEqual([r for r in before['spaces'] if r['id'] not in owned],
                         [r for r in after['spaces'] if r['id'] not in owned])

    def test_all_six_programmes_reuse_real_native_floor_landmark_and_vertical_owners(self):
        model=V2Model(self.layout)
        for record in self.source['programmes']:
            space=model.spaces[record['id']]
            self.assertEqual(programme_errors(self.layout,space),[])
            self.assertEqual(model.space_status(space)[0],'PROGRAMMED')
            self.assertTrue(contains(self.layout,space,3.4,2.75))
            self.assertFalse(contains(self.layout,space,0,-1.5))

    def test_missing_foreign_or_invented_owners_never_fall_back_to_a_rectangle(self):
        for defect in ['missing','duplicate','foreign','empty','core','landmark','envelope']:
            layout=copy.deepcopy(self.layout)
            s=next(r for r in layout['spaces'] if r['id']=='F02_LANDING')
            if defect=='missing':del s['floor_platforms']
            if defect=='duplicate':s['floor_platforms'][0]=s['floor_platforms'][1]
            if defect=='foreign':s['floor_platforms'][0]='F03_PUBLIC_LANDING_S'
            if defect=='empty':s['floor_platforms']=[]
            if defect=='core':s['landing_core']='F03_PUBLIC_CORE'
            if defect=='landmark':s['programme_anchors']=['F03_PUBLIC_LANDING_PIECE']
            if defect=='envelope':s['rect'][0]-=.1
            with self.subTest(defect=defect):
                self.assertTrue(programme_errors(layout,s))
                self.assertEqual(rectangles(layout,s),[])
                self.assertEqual(V2Model(layout).space_status(s)[0],'SHELL_ONLY')

    def test_a_bare_open_shell_keeps_its_existing_status(self):
        space={'id':'TEST','level':'F02','rect':[0,0,1,1],'class':'public','purpose':'landing','open_shell':True}
        self.assertEqual(V2Model(self.layout).space_status(space)[0],'SHELL_ONLY')

    def test_ground_repair_links_old_platforms_without_filling_the_shaft(self):
        repair=next(r for r in self.layout['platforms'] if r['id']=='F01_PUBLIC_LANDING_E')
        self.assertEqual(repair['rect'],[4.5,-1.9,5.4,1.65])
        for other in self.layout['platforms']:
            if other['id']==repair['id'] or other['level']!='F01':continue
            a=repair['rect'];b=other['rect']
            self.assertEqual(max(0,min(a[2],b[2])-max(a[0],b[0]))*max(0,min(a[3],b[3])-max(a[1],b[1])),0)
        self.assertGreater(repair['rect'][0],1.2)

    def test_authoring_cannot_move_or_substitute_a_core_or_landmark(self):
        for key,value in [('core','F03_PUBLIC_CORE'),('landmark_anchor','F03_PUBLIC_LANDING_PIECE')]:
            source=copy.deepcopy(self.source);source['programmes'][1][key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):project(self.layout,source)

    def test_repair_cannot_expand_into_the_stair_or_shaft(self):
        for rect in [[0,-1.9,5.4,1.65],[4.4,-1.9,5.4,1.65],[4.5,-2,5.4,1.65]]:
            source=copy.deepcopy(self.source);source['platform_repairs'][0]['rect']=rect
            with self.subTest(rect=rect),self.assertRaises(ValueError):project(self.layout,source)

    def test_independent_room_and_platform_edits_survive_projection(self):
        layout=copy.deepcopy(self.layout)
        room=next(r for r in layout['spaces'] if r['id']=='F02_A_BATH')
        room['purpose']='independent retained bathroom work'
        platform=next(r for r in layout['platforms'] if r['id']=='B1_PUBLIC_LANDING_E')
        platform['rect'][0]+=.01
        after=project(layout,self.source)
        self.assertEqual(next(r for r in after['spaces'] if r['id']==room['id']),room)
        self.assertEqual(next(r for r in after['platforms'] if r['id']==platform['id']),platform)

    def circulation(self,tiers):
        ledger=Ledger.__new__(Ledger)
        ledger.model=V2Model(self.layout);ledger.requirements=[]
        ledger.evidence=SimpleNamespace(tier_for=lambda identity:(None,[]))
        ledger.space_attained=lambda identity:(tiers.get(identity,'PROGRAMMED'),[],'')
        ledger._dim_circulation()
        return {r['id']:r for r in ledger.requirements}

    def test_service_landing_proof_never_promotes_public_landing_or_public_core(self):
        rows=self.circulation({'F05_SERVICE_CORE':'SPATIALLY_PROVEN','F06_SERVICE_CORE':'SPATIALLY_PROVEN'})
        for floor in ['F05','F06']:
            self.assertEqual(rows['circ.'+floor+'.service_core']['status'],'SPATIALLY_PROVEN')
            for role in ['public_landing','public_core']:
                self.assertEqual(rows['circ.'+floor+'.'+role]['status'],'PROGRAMMED')

    def test_valid_public_platform_programme_still_proves_its_core_circulation(self):
        tiers={floor+'_LANDING':'SPATIALLY_PROVEN' for floor in [f'F{i:02d}' for i in range(1,7)]}
        rows=self.circulation(tiers)
        for floor in [f'F{i:02d}' for i in range(1,7)]:
            for role in ['public_landing','public_core']:
                self.assertEqual(rows['circ.'+floor+'.'+role]['status'],'SPATIALLY_PROVEN')

    def test_private_room_purpose_words_cannot_replace_circulation_roles(self):
        self.layout['spaces'].append({'id':'F05_PRIVATE_WORDS','level':'F05','class':'private','rect':[0,0,1,1],'purpose':'passenger lift primary stair service lift service stair landing decision'})
        rows=self.circulation({'F05_PRIVATE_WORDS':'SPATIALLY_PROVEN'})
        for role in ['public_landing','public_core','service_core']:
            self.assertEqual(rows['circ.F05.'+role]['status'],'PROGRAMMED')


if __name__=='__main__':unittest.main()
