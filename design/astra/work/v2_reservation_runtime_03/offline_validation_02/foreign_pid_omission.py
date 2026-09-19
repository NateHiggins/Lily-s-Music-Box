import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(sys.argv[1]).resolve()))
import run,test_runner_contract
original=run.classify_lane
def omitted(*args,**kwargs):
 result=original(*args,**kwargs); result['foreign_processes']=[]; result['lane_contract_exit']=0; return result
run.classify_lane=omitted
suite=unittest.TestSuite([test_runner_contract.RunnerControls('test_foreign_engine_that_disappears_still_blocks_progression')])
result=unittest.TextTestRunner(verbosity=2).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
