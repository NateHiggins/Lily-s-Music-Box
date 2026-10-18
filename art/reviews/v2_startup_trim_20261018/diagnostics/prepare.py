from pathlib import Path
import json
r=Path('C:/PleaseRemainOnTheLine'); b=r/'tmp/v2-retirement-20261018';b.mkdir(exist_ok=True)
s=(r/'game/scripts/building/orison_v2_shop_seating.gd').read_text()
f=s[s.index('static func _without_boxes'):]
(b/'legacy_function.txt').write_text(f,encoding='utf8',newline='\n')
prefix='extends RefCounted\n'
(r/'game/tests/_v2_retirement_legacy.gd').write_text(prefix+f,encoding='utf8',newline='\n')
c=f.replace('var selected_surfaces: Array=[]','''var selected_surfaces: Array=[]
	var prepared: Array[Dictionary]=[]
	for box: Dictionary in boxes:
		var low:=_v(box.low);var high:=_v(box.high)
		prepared.append({"id":str(box.id),"low":low,"high":high})
	var normal_basis:=draw.basis.inverse().transposed()''')
c=c.replace('var retained:=PackedInt32Array()','''var positions:=PackedVector3Array();positions.resize(vertices.size())
		var transformed_normals:=PackedVector3Array();transformed_normals.resize(normals.size())
		for index in vertices.size():
			positions[index]=draw.transform*vertices[index]
			transformed_normals[index]=normal_basis*normals[index]
		var retained:=PackedInt32Array()''')
c=c.replace('p.append(draw.transform*vertices[index]);n+=draw.basis.inverse().transposed()*normals[index]','p.append(positions[index]);n+=transformed_normals[index]')
c=c.replace('''			for box: Dictionary in boxes:
				var low:=_v(box.low);var high:=_v(box.high);var within:=true
				for point: Vector3 in p:
					for axis in 3:
						if point[axis]<low[axis]-tolerance or point[axis]>high[axis]+tolerance:within=false
				if not within:continue''','''			var minimum:=p[0].min(p[1]).min(p[2]);var maximum:=p[0].max(p[1]).max(p[2])
			for box: Dictionary in prepared:
				var low: Vector3=box.low;var high: Vector3=box.high
				if minimum.x<low.x-tolerance or minimum.y<low.y-tolerance or minimum.z<low.z-tolerance or maximum.x>high.x+tolerance or maximum.y>high.y+tolerance or maximum.z>high.z+tolerance:continue''')
assert c!=f and 'for box: Dictionary in prepared:' in c
(b/'candidate_function.txt').write_text(c,encoding='utf8',newline='\n')
(r/'game/tests/_v2_retirement_candidate.gd').write_text(prefix+c,encoding='utf8',newline='\n')
cases=[]
for p in sorted((r/'game/data/orison_v2').glob('*.json')):
 d=json.loads(p.read_text())
 if isinstance(d,dict) and d.get('schema_version')==1 and 'asset' in d and 'tolerance' in d:
  for row in d.get('cells',[]):
   if row.get('replace'):cases.append({'data':p.relative_to(r/'game').as_posix(),'cell':row['id']})
(b/'cases.json').write_text(json.dumps(cases,indent=2)+'\n');print(len(cases),'actual replacement programmes; production unchanged')
