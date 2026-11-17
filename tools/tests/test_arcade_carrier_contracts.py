"""CPU-only carrier compiler coverage and source-custody refusal controls."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest import mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import prepare_arcade_carrier_contracts as compiler


class CarrierContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document=json.loads((compiler.ROOT/compiler.PLAN).read_text(encoding='utf-8'))
        cls.expected=compiler.build()

    def reject_contract(self, mutate):
        candidate=copy.deepcopy(self.expected)
        mutate(candidate)
        with self.assertRaisesRegex(ValueError,'carrier contract differs'):
            compiler.validate_contracts(candidate,self.expected)

    def reject_document(self, mutate, message):
        candidate=copy.deepcopy(self.document)
        mutate(candidate)
        with self.assertRaisesRegex(ValueError,message):
            compiler.build(document=candidate)

    def test_complete_current_fixture_reproducible(self):
        self.assertEqual((compiler.ROOT/compiler.FIXTURE).read_text(encoding='utf-8'),compiler.render(self.expected))
        self.assertEqual(self.expected['counts'],dict(cells=11,families=46,entries=1165,rebuild_entries=84,labels=4,auxiliary_entries=8))
        self.assertEqual(sum(len(c['entries']) for c in self.expected['cells']),1165)
        self.assertEqual(sum(len(c['rebuild_entries']) for c in self.expected['cells']),84)

    def test_each_part_exactly_once_between_dispositions(self):
        for c in self.expected['cells']:
            keys=[(r['model'],r['part_id']) for r in c['entries']+c['rebuild_entries']]
            self.assertEqual(len(keys),len(set(keys)))
            self.assertTrue(all(r['triangles']>0 for r in c['entries']+c['rebuild_entries']))

    def test_diner_target_authority(self):
        current=compiler.diner.build()
        actual=next(c for c in self.expected['cells'] if c['cell']==compiler.diner.CELL)
        self.assertEqual(actual['entries'],current['entries'])
        self.assertEqual(actual['labels'],current['labels'])

    def test_hardware_card_uses_complete_counter_once(self):
        c=next(c for c in self.expected['cells'] if c['cell']=='shop_hardware_paint')
        label=c['labels'][0]
        group=next(g for g in self.document['groups'] if g['id']=='hardware_counter')
        self.assertEqual(label['group'],group['id'])
        self.assertEqual(label['delta_transform'],group['delta_transform'])
        self.assertEqual(label['target_transform'],compiler.mul(label['delta_transform'],label['source_transform']))
        self.assertEqual(label['source_label']['text'],'NIGHT SERVICE\nRING BELL STOP')
        self.assertEqual(label['source_label']['font_size'],40)

    def test_missing_transfer_refused(self):
        self.reject_contract(lambda d:d['cells'][0]['entries'].pop())

    def test_duplicate_rebuild_transfer_refused(self):
        self.reject_contract(lambda d:d['cells'][0]['entries'].append(copy.deepcopy(d['cells'][0]['rebuild_entries'][0])))

    def test_label_omission_refused(self):
        self.reject_contract(lambda d:next(c for c in d['cells'] if c['labels'])['labels'].clear())

    def test_label_double_transform_refused(self):
        def mutate(d):
            label=next(c for c in d['cells'] if c['labels'])['labels'][0]
            label['target_transform']=compiler.mul(label['delta_transform'],label['target_transform'])
        self.reject_contract(mutate)

    def test_owner_binding_change_refused(self):
        self.reject_contract(lambda d:d['cells'][0]['source_bindings']['res://'+compiler.SEATING[5:]].update(sha256='0'*64))

    def test_changed_fabrication_refused(self):
        source=self.document['fabrication']
        self.reject_document(lambda d:d['source_bindings'][source].update(sha256='0'*64),'source binding changed')

    def test_changed_native_payload_pin_refused(self):
        self.reject_document(lambda d:d['families'][0].update(asset_sha256='0'*64),'native payload changed')

    def test_changed_source_frame_refused(self):
        self.reject_document(lambda d:d['groups'][0]['native_assemblies'][0]['parts'][0]['source_transform'][0].__setitem__(3,999),'source.*transform|source.*frame')

    def test_missing_rebuild_refused(self):
        self.reject_document(lambda d:d['native_rebuild_parts'].pop(),'unplaced native|coverage|native part')

    def test_duplicate_rebuild_refused(self):
        self.reject_document(lambda d:d['native_rebuild_parts'].append(copy.deepcopy(d['native_rebuild_parts'][0])),'duplicate')

    def test_ambiguous_owner_recipe_refused(self):
        original=Path.read_text
        def changed(path,*args,**kwargs):
            text=original(path,*args,**kwargs)
            if path==compiler.ROOT/compiler.SEATING:
                text+='\nstatic func ambiguous(cell: Node3D, layout: Dictionary) -> bool:\n\treturn mount_records(cell,layout,"res://data/orison_v2/shop_seating.json","Other","wrong_","wrong")\n'
            return text
        with mock.patch.object(Path,'read_text',changed):
            with self.assertRaisesRegex(ValueError,'ambiguous mounting recipe'):
                compiler.owners(compiler.ROOT,{f['name'] for f in self.document['families']})


    def test_exact_eight_auxiliaries_and_owner_frames(self):
        cells=[c for c in self.expected['cells'] if c['auxiliary_entries']]
        self.assertEqual([c['cell'] for c in cells],['shop_otis_son'])
        cell=cells[0]; rows=cell['auxiliary_entries']
        self.assertEqual(len(rows),8)
        self.assertEqual(len({(r['model'],r['node_path']) for r in rows}),8)
        owners={r['part_id']:r for r in cell['entries'] if r['model']=='DruggistCarboys'}
        self.assertEqual([r['node_path'] for r in rows if r['kind']=='show_globe_light'],['ShowGlobeLight'+str(i) for i in range(4)])
        for r in rows:
            owner=owners[r['owner_part_id']]
            self.assertEqual(r['part_meta'],owner['part_meta'])
            self.assertEqual(r['delta_transform'],owner['delta_transform'])
            self.assertEqual(r['target_transform'],compiler.mul(r['delta_transform'],r['source_transform']))
            if r['kind']=='glass_haze':
                self.assertEqual(r['source_transform'],owner['source_transform'])
                self.assertTrue(r['shares_owner_mesh'])
                self.assertEqual(r['shader_parameters'],{'thickness_m':.012})
                self.assertEqual(r['metadata'],{'lamp_optical_receiver':True})
                self.assertIn(r['shader'],cell['source_bindings'])
            else:
                self.assertEqual(r['metadata'],{'druggist_show_globe':r['owner_part_id']})
                self.assertEqual(r['properties']['light_energy'],3.2)
                self.assertEqual(r['owner_material_properties']['emission_energy_multiplier'],1.4)
                self.assertAlmostEqual(max(r['properties']['light_color']),1.)
                # Looking-at -Z intersects original floor at actual authored X=15.4.
                pose=r['source_transform']; t=pose[1][3]/pose[1][2]
                self.assertGreater(t,0)
                self.assertAlmostEqual(pose[0][3]-t*pose[0][2],15.4)

    def mutate_auxiliary(self,mutate):
        def change(d):
            c=next(c for c in d['cells'] if c['auxiliary_entries'])
            mutate(c['auxiliary_entries'])
        self.reject_contract(change)

    def test_missing_auxiliary_refused(self):
        self.mutate_auxiliary(lambda rows:rows.pop())

    def test_duplicate_auxiliary_refused(self):
        self.mutate_auxiliary(lambda rows:rows.append(copy.deepcopy(rows[0])))

    def test_wrong_auxiliary_owner_refused(self):
        self.mutate_auxiliary(lambda rows:rows[0].update(owner_part_id='foreign_part'))

    def test_auxiliary_double_target_refused(self):
        self.mutate_auxiliary(lambda rows:rows[0].update(target_transform=compiler.mul(rows[0]['delta_transform'],rows[0]['target_transform'])))

    def test_auxiliary_changed_property_refused(self):
        self.mutate_auxiliary(lambda rows:next(r for r in rows if r['kind']=='show_globe_light')['properties'].update(light_energy=9))

    def test_auxiliary_haze_reparent_refused(self):
        self.mutate_auxiliary(lambda rows:next(r for r in rows if r['kind']=='glass_haze').update(node_path='LampGlassHaze'))

    def test_auxiliary_changed_owner_recipe_refused(self):
        original=Path.read_text
        def changed(path,*args,**kwargs):
            text=original(path,*args,**kwargs)
            if path.name=='orison_v2_druggist_carboys.gd':
                text=text.replace('lamp.light_energy=3.2','lamp.light_energy=9')
            return text
        with mock.patch.object(Path,'read_text',changed):
            with self.assertRaisesRegex(ValueError,'show globe recipe changed'):
                compiler.build()


    def test_wrapper_order_and_context_preserved(self):
        c=next(c for c in self.expected['cells'] if c['cell']=='shop_photo_supplies')
        portrait=next(m for m in c['mounts'] if m['name']=='PhotoPortraits')
        self.assertEqual(portrait['arguments'],['cell','original_layout','portrait_atlas_cache'])
        for c in self.expected['cells']:
            self.assertEqual([m['mount_order'] for m in c['mounts']],sorted(m['mount_order'] for m in c['mounts']))
        self.assertFalse(self.expected['receiving_cabinets_enabled'])


if __name__=='__main__':
    unittest.main()
