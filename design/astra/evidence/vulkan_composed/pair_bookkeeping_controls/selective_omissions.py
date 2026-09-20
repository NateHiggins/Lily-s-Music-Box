import sys,unittest
from pathlib import Path
import pair_bookkeeping as module
import test_pair_bookkeeping as tests
source=Path(module.__file__).read_text()
mode=sys.argv[1]
if mode=="site_check_omission":
    source=source.replace("if native['invalid_sites']:", "if False: # omit native site rejection only")
    target="test_missing_or_wrong_function_line_or_file_rejected"
elif mode=="restoration_flag_omission":
    source=source.replace("or tx.get('candidate_restored_exactly') is not True", "or False # omit exact restoration flag only\n")
    target="test_missing_or_false_restoration_transaction_rejected"
else: raise ValueError(mode)
namespace=dict(module.__dict__)
exec(compile(source,"<selective_"+mode+">","exec"),namespace)
tests.assess_omission=namespace["assess_omission"]
tests.assess_pair=namespace["assess_pair"]
suite=unittest.TestSuite([tests.PairBookkeepingControls(target)])
result=unittest.TextTestRunner(verbosity=2).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
