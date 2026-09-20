import sys,unittest
from pathlib import Path
sys.path.insert(0,sys.argv[1])
import assess,test_assess
exec(Path(sys.argv[2]).read_text(),assess.__dict__)
suite=unittest.TestSuite([test_assess.ReservationControls('test_duplicate_anonymous_siblings_cannot_alias')])
result=unittest.TextTestRunner(verbosity=2).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
