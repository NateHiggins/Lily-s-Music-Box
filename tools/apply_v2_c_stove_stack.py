"""Apply the reviewed stove-stack records while preserving unrelated layout text."""
import json,re
from pathlib import Path
from plan_v2_c_stove_stack import plan,project,LAYOUT

def splice(text,original,updated):
    eol='\r\n' if '\r\n' in text else '\n';decoder=json.JSONDecoder()
    for table in ['anchors','risers','wall_service_openings','masonry_service_openings','riser_openings','slab_openings']:
        match=re.search(r'(?m)^  "'+table+r'":\s*\[',text)
        if not match:raise ValueError('Missing table: '+table)
        start=match.end()-1;current,length=decoder.raw_decode(text[start:]);end=start+length
        if current!=original[table]:raise ValueError('Unexpected table text: '+table)
        block=text[start:end]
        if table=='anchors':
            changed={row['id']:row for row,old in zip(updated[table],original[table]) if row!=old}
            for identity,row in changed.items():
                found=re.search(r'"id"\s*:\s*"'+re.escape(identity)+'"',block)
                left=block.rfind('{',0,found.start());old,size=decoder.raw_decode(block[left:])
                if old['id']!=identity:raise ValueError('Anchor structure changed')
                block=block[:left]+json.dumps(row,separators=(',',':'))+block[left+size:]
        rows=updated[table][len(original[table]):]
        if rows:
            body=block[:-1].rstrip();body+=(',' if current else '')+eol
            body+=(','+eol).join('    '+json.dumps(row,separators=(',',':')) for row in rows)
            block=body+eol+'  ]'
        text=text[:start]+block+text[end:]
    if json.loads(text)!=updated:raise ValueError('Text projection differs from reviewed semantic projection')
    return text

if __name__=='__main__':
    raw=LAYOUT.read_bytes();text=raw.decode('utf8');before=json.loads(raw);after=project(before,plan(before))
    if before==after:print('C stove-stack layout already projected; unchanged.')
    else:LAYOUT.write_bytes(splice(text,before,after).encode('utf8'));print('Projected C stove stack and three furniture positions; unrelated layout text retained.')
