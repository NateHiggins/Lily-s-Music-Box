"""Publication must preserve executed bytes and reject stale or invented proof."""
import gzip
import hashlib
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
import publish_v2_spatial_packet as publisher
import tools.tests.test_spatial_access_evidence as access_tests

class SpatialPublication(unittest.TestCase):
    def setUp(self):
        fixture=access_tests.SpatialAccessEvidence('test_current_proof_and_crlf_normalization');fixture.setUp()
        self.addCleanup(fixture.doCleanups);self.root=fixture.root;self.data=fixture.data
        self.packet=self.root/'tmp/capture';self.packet.mkdir(parents=True)
        self.destination=self.root/'art/renders/orison_v2/played'
        self.archive=self.root/'art/reviews/renewal/previous'
        self.logs={'stdout':b'PLAYED ROUTE: PASS\r\n','stderr':b''}
        self.receipt=self.packet/'original.receipt.json'
        self.run={'schema':'orison.run-receipt.v1','schema_version':1,'evidence_kind':'suite_run',
          'execution':{'completed':True,'exit_code':0,'timed_out':False},
          'source':self.data['source'].copy(),'log':{'fail_count':0,'script_error_count':0,'stale_cache_suspect':False}}
        for key,raw in self.logs.items():
            path=self.packet/('original.'+key);path.write_bytes(raw)
            self.run['log'][key]=str(path);self.run['log'][key+'_sha256']=hashlib.sha256(raw).hexdigest()
        self.write_inputs()
        self.digests=patch.object(publisher,'current_digests',return_value=('b'*64,'c'*64))
        self.digests.start();self.addCleanup(self.digests.stop)

    def write_inputs(self):
        (self.packet/'runtime_contract.json').write_bytes(json.dumps(self.data,indent=1).replace('\n','\r\n').encode())
        self.receipt.write_text(json.dumps(self.run),encoding='utf8')

    def publish(self,**kwargs):
        return publisher.publish(self.packet,self.receipt,self.destination,self.archive,self.root,**kwargs)

    def test_exact_contract_wrapper_and_logs_survive_and_retry(self):
        source=(self.packet/'runtime_contract.json').read_bytes()
        self.assertEqual(self.publish()['rooms'],1)
        self.assertEqual((self.destination/'runtime_contract.json').read_bytes(),source)
        self.assertEqual((self.destination/'suite_run.receipt.json').read_bytes(),self.receipt.read_bytes())
        for key,raw in self.logs.items():self.assertEqual(gzip.decompress((self.destination/f'suite_run.{key}.log.gz').read_bytes()),raw)
        self.assertEqual(self.publish()['result'],'PASS')

    def test_previous_bytes_preserved_and_archive_cannot_be_reused_for_new_proof(self):
        self.destination.mkdir(parents=True);old=b'older captured packet\r\n'
        (self.destination/'runtime_contract.json').write_bytes(old)
        self.publish();self.assertEqual((self.archive/'runtime_contract.json').read_bytes(),old)
        self.data['scope']='a different actual run';self.write_inputs()
        with self.assertRaisesRegex(ValueError,'another publication'):self.publish()
        self.assertEqual((self.archive/'runtime_contract.json').read_bytes(),old)

    def test_changed_helper_cannot_publish(self):
        (self.root/'game/tests/driver.gd').write_text('extends Node\n# altered route\n')
        with self.assertRaisesRegex(ValueError,'stale test'):self.publish()
        self.assertFalse(self.destination.exists())

    def test_unplayed_room_cannot_publish(self):
        self.data['contracts']['room_access']['rooms']['F02_A_BATH']={'actual':[6,3.2,2],'leg':'A'}
        self.write_inputs()
        with self.assertRaisesRegex(ValueError,'played trace'):self.publish()
        self.assertFalse(self.destination.exists())

    def test_failed_wrapper_and_forged_log_hash_cannot_publish(self):
        self.run['execution']['exit_code']=1;self.write_inputs()
        with self.assertRaisesRegex(ValueError,'wrapper did not complete'):self.publish()
        self.run['execution']['exit_code']=0;self.write_inputs()
        (self.packet/'original.stdout').write_bytes(b'changed capture')
        with self.assertRaisesRegex(ValueError,'raw log hash'):self.publish()
        self.assertFalse(self.destination.exists())

    def test_traversal_and_capture_name_refused(self):
        with self.assertRaisesRegex(ValueError,'Capture names'):self.publish(images=['../unrelated.png'])
        with self.assertRaisesRegex(ValueError,'Destination'):publisher.publish(self.packet,self.receipt,self.root.parent/'other',self.archive,self.root)

    def test_preserved_archive_corruption_is_not_overwritten(self):
        self.destination.mkdir(parents=True);(self.destination/'runtime_contract.json').write_bytes(b'old')
        self.publish();(self.archive/'runtime_contract.json').write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError,'archive changed'):self.publish()

    def test_typed_connection_claim_cannot_be_smuggled_through_room_validation(self):
        self.data['contracts']['room_connections']={'executed':True,'status':'PASS'};self.write_inputs()
        with self.assertRaises(ValueError):self.publish()
        self.assertFalse(self.destination.exists())

    def test_region_claim_needs_its_independent_validator(self):
        self.data['contracts']['region_access']={'executed':True,'status':'PASS'};self.write_inputs()
        with self.assertRaises(ValueError):self.publish()
        self.assertFalse(self.destination.exists())

    def test_portable_compressed_logs_remain_byte_verified(self):
        for key,raw in self.logs.items():
            (self.packet/f'suite_run.{key}.log.gz').write_bytes(gzip.compress(raw,mtime=0))
            (self.packet/('original.'+key)).unlink()
        self.assertEqual(self.publish()['result'],'PASS')

    def test_input_drift_is_rejected_without_repinning_the_written_contract(self):
        with patch.object(publisher,'current_digests',side_effect=[('b'*64,'c'*64),('d'*64,'c'*64)]):
            with self.assertRaisesRegex(ValueError,'Inputs changed'):self.publish()
        captured=json.loads((self.destination/'runtime_contract.json').read_bytes())
        self.assertEqual(captured['source']['runtime_inputs_sha256'],'b'*64)

if __name__=='__main__':unittest.main()
