"""Validate inert grade discovery before expensive native reconstruction."""
import hashlib,json
from pathlib import Path
from run_receipt import runtime_inputs_sha256

def validate(plan,root):
    root=Path(root).resolve()
    relative=plan.get('runtime_survey','')
    path=(root/relative).resolve()
    if not relative or not path.is_relative_to(root) or not path.is_file():raise ValueError('Fresh grade runtime survey required')
    digest=hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    if plan.get('bindings',{}).get(relative)!=digest:raise ValueError('Grade survey is not source-bound')
    data=json.loads(path.read_text())
    if data.get('evidence_class')!='INERT' or data.get('failures')!=0:raise ValueError('Failed or misclassified grade discovery')
    if data['source']['runtime_inputs_sha256']!=runtime_inputs_sha256(root):raise ValueError('Grade survey production inputs changed')
    for relative,expected in data['source']['test_dependencies'].items():
        dep=(root/relative).resolve()
        if not dep.is_relative_to(root) or not dep.is_file() or hashlib.sha256(dep.read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=expected:raise ValueError('Grade survey test dependency changed: '+relative)
    return data
