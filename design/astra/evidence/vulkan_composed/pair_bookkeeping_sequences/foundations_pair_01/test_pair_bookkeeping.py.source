"""Pure parser/receipt controls; dummy captures are not visual/runtime evidence."""
import copy
import unittest

from pair_bookkeeping import (BUILDING_ROOT, CONTRACT, SOFT_HEADER, UNPAIR_HEADER,
                              assess_omission, assess_pair, native_sites, sha)
import test_gate
from variant_case import LIVE, select_variant


class PairBookkeepingControls(unittest.TestCase):
    def setUp(self):
        self.fx = test_gate.GateControls()
        self.fx.setUp()
        self.candidate = LIVE.read_bytes()
        self.selected = select_variant(self.candidate, 'omission')
        self.probe = self.fx.root_omission()
        self.probe['checks'] = [{'label': label, 'passed': True}
                                for label in ['actual shell retired', 'actual selected world retired']]
        self.stdout = self.fx.stdout + '[VULKAN COMPOSED PHASE] separate_world_case_explicitly_excluded\n'
        self.stderr = (UNPAIR_HEADER + '\n   at: instance_set_scenario (servers/rendering/renderer_scene_cull.cpp:844)\n'
                       + SOFT_HEADER + '\n   at: _instance_unpair (servers/rendering/renderer_scene_cull.cpp:348)\n')
        self.result = self.make_result('omission', self.probe, self.stderr, self.selected)
        self.new_probe = copy.deepcopy(self.probe)
        self.new_probe['variant'] = 'candidate'
        self.restored = self.make_result('candidate', self.new_probe, '', self.candidate)
        self.restored['started_at_utc'] = '2026-09-05T01:01:00+00:00'

    def tearDown(self):
        self.fx.tearDown()

    def make_result(self, variant, probe, stderr, source):
        files = {BUILDING_ROOT: sha(source), 'game/tests/fixture.gd': 'same-fixture'}
        return {'root': 'v1', 'variant': variant, 'execution_scope': 'root_retirement',
                'actual_engine_exit': 0, 'source_unchanged': True,
                'before': {'files': files}, 'after': {'files': files.copy()},
                'started_at_utc': '2026-09-05T01:00:00+00:00',
                'engines_before': ['synthetic-launcher', 'synthetic-engine'],
                'engines_after': ['synthetic-launcher', 'synthetic-engine'],
                'wrapper_inputs': {'synthetic-parser': 'same'},
                'gate': self.fx.gate(stderr, probe=probe, stdout=self.stdout)}

    def omission(self, **changes):
        args = {'result': self.result, 'stdout': self.stdout, 'stderr': self.stderr,
                'probe': self.probe, 'candidate': self.candidate, 'selected': self.selected,
                'declared_contract': CONTRACT, 'source_review_bound': True}
        args.update(changes)
        return assess_omission(**args)

    def transaction(self, variant):
        return {'root': 'v1', 'variant': variant, 'execution_scope': 'root_retirement',
                'candidate_sha256': sha(self.candidate),
                'selected_sha256': sha(self.selected if variant == 'omission' else self.candidate),
                'restored_sha256': sha(self.candidate), 'candidate_restored_exactly': True}

    def pair(self, **changes):
        args = {'omission_assessment': self.omission(), 'omission': self.result,
                'restored': self.restored, 'restored_probe': self.new_probe,
                'omission_transaction': self.transaction('omission'),
                'restored_transaction': self.transaction('candidate'),
                'candidate': self.candidate, 'selected': self.selected,
                'preparation_unchanged': True}
        args.update(changes)
        return assess_pair(**args)

    def test_per_run_observation_is_provisional_and_strict_unpair_stays_false(self):
        result = self.omission()
        self.assertTrue(result['pair_bookkeeping_omission_evidence_complete'])
        self.assertFalse(result['expected_pair_bookkeeping_red_observed'])
        self.assertFalse(self.result['gate']['expected_unpair_red_observed'])
        self.assertEqual(self.result['gate']['diagnostic_gate_exit'], 1)

    def test_completed_matched_pair_remains_diagnostic_red(self):
        result = self.pair()
        self.assertTrue(result['expected_pair_bookkeeping_red_observed'], result['reasons'])
        self.assertEqual(result['diagnostic_gate_exit'], 1)
        self.assertFalse(result['candidate_clearance'])

    def test_unpair_base_site_also_supported(self):
        stderr = self.stderr.replace('instance_set_scenario (servers/rendering/renderer_scene_cull.cpp:844)',
                                     'instance_set_base (servers/rendering/renderer_scene_cull.cpp:616)')
        self.assertTrue(self.omission(stderr=stderr)['pair_bookkeeping_omission_evidence_complete'])

    def test_missing_or_wrong_function_line_or_file_rejected(self):
        for old, new in [(':348)', ':349)'), ('_instance_unpair', '_other_function'),
                         ('renderer_scene_cull.cpp:348', 'other.cpp:348'),
                         ('   at: _instance_unpair (servers/rendering/renderer_scene_cull.cpp:348)', '')]:
            with self.subTest(new=new):
                self.assertFalse(self.omission(stderr=self.stderr.replace(old, new))['pair_bookkeeping_omission_evidence_complete'])

    def test_one_unexpected_site_among_valid_sites_rejected(self):
        stderr = self.stderr + SOFT_HEADER + '\n   at: _instance_unpair (servers/rendering/renderer_scene_cull.cpp:349)\n'
        result = self.make_result('omission', self.probe, stderr, self.selected)
        self.assertFalse(self.omission(result=result, stderr=stderr)['pair_bookkeeping_omission_evidence_complete'])

    def test_exact_header_required_not_spaced_variant(self):
        stderr = self.stderr.replace('softshadow_count==0', 'softshadow_count == 0')
        result = self.make_result('omission', self.probe, stderr, self.selected)
        self.assertFalse(self.omission(result=result, stderr=stderr)['pair_bookkeeping_omission_evidence_complete'])

    def test_both_signatures_required(self):
        for header in [SOFT_HEADER, UNPAIR_HEADER]:
            stderr = '\n'.join(line for line in self.stderr.splitlines() if line != header)
            result = self.make_result('omission', self.probe, stderr, self.selected)
            self.assertFalse(self.omission(result=result, stderr=stderr)['pair_bookkeeping_omission_evidence_complete'])

    def test_no_implicit_opt_in_or_unbound_source(self):
        self.assertFalse(self.omission(declared_contract='unpair_only')['pair_bookkeeping_omission_evidence_complete'])
        self.assertFalse(self.omission(source_review_bound=False)['pair_bookkeeping_omission_evidence_complete'])

    def test_raw_other_root_or_extra_source_edit_rejected(self):
        for key, value in [('variant', 'raw'), ('root', 'v2')]:
            result = dict(self.result, **{key: value})
            self.assertFalse(self.omission(result=result)['pair_bookkeeping_omission_evidence_complete'])
        self.assertFalse(self.omission(selected=self.selected + b'\n# unrelated') ['pair_bookkeeping_omission_evidence_complete'])
        self.assertFalse(self.omission(selected=self.selected.replace(b'cursor is SubViewport', b'cursor is Node'))['pair_bookkeeping_omission_evidence_complete'])

    def test_av_timeout_or_nonzero_never_validates(self):
        for code in [3221225477, 1, 124, -1]:
            result = dict(self.result, actual_engine_exit=code)
            self.assertFalse(self.omission(result=result)['pair_bookkeeping_omission_evidence_complete'])

    def test_incomplete_probe_capture_or_actual_retirement_rejected(self):
        self.assertFalse(self.omission(probe=None)['pair_bookkeeping_omission_evidence_complete'])
        probe = copy.deepcopy(self.probe)
        probe['captures'].pop()
        result = self.make_result('omission', probe, self.stderr, self.selected)
        self.assertFalse(self.omission(result=result, probe=probe)['pair_bookkeeping_omission_evidence_complete'])
        probe = copy.deepcopy(self.probe)
        probe['checks'].pop()
        result = self.make_result('omission', probe, self.stderr, self.selected)
        self.assertFalse(self.omission(result=result, probe=probe)['pair_bookkeeping_omission_evidence_complete'])

    def test_unrelated_error_retention_and_indented_error_rejected(self):
        for extra in ['ERROR: No wall-safe resident route on F04',
                      'WARNING: ObjectDB instances leaked at exit', '  ERROR: unexpected native fault']:
            stderr = self.stderr + extra + '\n'
            result = self.make_result('omission', self.probe, stderr, self.selected)
            self.assertFalse(self.omission(result=result, stderr=stderr)['pair_bookkeeping_omission_evidence_complete'])

    def test_source_or_engine_drift_rejected(self):
        self.assertFalse(self.omission(result=dict(self.result, source_unchanged=False))['pair_bookkeeping_omission_evidence_complete'])
        result = copy.deepcopy(self.result)
        result['gate'] = self.fx.gate(self.stderr, probe=self.probe, stdout=self.stdout, engine_bound=False)
        self.assertFalse(self.omission(result=result)['pair_bookkeeping_omission_evidence_complete'])

    def test_full_scope_cannot_claim_excluded_separate_world(self):
        probe = copy.deepcopy(self.probe)
        probe['execution_scope'] = 'full'
        result = self.make_result('omission', probe, self.stderr, self.selected)
        result['execution_scope'] = 'full'
        self.assertFalse(self.omission(result=result, probe=probe)['pair_bookkeeping_omission_evidence_complete'])

    def test_missing_or_false_restoration_transaction_rejected(self):
        self.assertFalse(self.pair(omission_transaction={})['expected_pair_bookkeeping_red_observed'])
        tx = self.transaction('candidate')
        tx['candidate_restored_exactly'] = False
        self.assertFalse(self.pair(restored_transaction=tx)['expected_pair_bookkeeping_red_observed'])

    def test_restored_native_failure_or_missing_probe_rejected(self):
        restored = self.make_result('candidate', self.new_probe, self.stderr, self.candidate)
        self.assertFalse(self.pair(restored=restored)['expected_pair_bookkeeping_red_observed'])
        self.assertFalse(self.pair(restored_probe=None)['expected_pair_bookkeeping_red_observed'])

    def test_restored_unknown_failure_engine_or_scope_change_rejected(self):
        for key, value in [('actual_engine_exit', 1), ('source_unchanged', False), ('execution_scope', 'full')]:
            self.assertFalse(self.pair(restored=dict(self.restored, **{key: value}))['expected_pair_bookkeeping_red_observed'])

    def test_cross_run_source_asset_and_engine_change_rejected(self):
        for key in ['before', 'after']:
            restored = copy.deepcopy(self.restored)
            restored[key]['files']['game/assets/extra.bin'] = 'changed'
            self.assertFalse(self.pair(restored=restored)['expected_pair_bookkeeping_red_observed'])
        restored = dict(self.restored, engines_after=['changed', 'engine'])
        self.assertFalse(self.pair(restored=restored)['expected_pair_bookkeeping_red_observed'])

    def test_wrapper_drift_or_wrong_order_rejected(self):
        self.assertFalse(self.pair(preparation_unchanged=False)['expected_pair_bookkeeping_red_observed'])
        restored = dict(self.restored, wrapper_inputs={'different': 'gate'})
        self.assertFalse(self.pair(restored=restored)['expected_pair_bookkeeping_red_observed'])
        restored = dict(self.restored, started_at_utc=self.result['started_at_utc'])
        self.assertFalse(self.pair(restored=restored)['expected_pair_bookkeeping_red_observed'])


if __name__ == '__main__':
    unittest.main()
