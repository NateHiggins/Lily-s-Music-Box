import unittest
import test_pair_artifacts as tests
from pair_bookkeeping import sha
def old_map_validation(folder,result):
    if any(not (folder / p).is_file() or sha((folder / p).read_bytes()) != digest for p,digest in result['artifacts'].items()):
        raise ValueError('artifact changed')
tests.validate_artifacts=old_map_validation
suite=unittest.TestSuite([tests.PairArtifactControls('test_each_consumed_artifact_must_be_named_even_if_file_exists')])
result=unittest.TextTestRunner(verbosity=2).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
