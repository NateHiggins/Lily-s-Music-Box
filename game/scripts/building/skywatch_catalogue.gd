@tool
extends RefCounted
## Offline BSC5 parser/baker. Never parse or scan the catalogue per game frame.
## V/50, Hoffleit & Warren (1991), CDS/VizieR; byte offsets from its ReadMe.
const CELLS := 64
const WIDTH := 512
const EPOCH_JD := 2425612.5 # 1929-01-01 00:00 UTC, within the campaign year
const ARCSEC := PI/(180.*3600.)
const FALLBACK_BV := {"O":-.30,"B":-.15,"A":0.,"F":.35,"G":.65,"K":1.15,"M":1.55}

static func parse_catalogue(text: String) -> Dictionary:
	var rows: Array[Dictionary]=[]
	var absent := 0
	var malformed: Array[int]=[]
	var missing_colour := 0
	for line: String in text.split("\n",false):
		if line.length()<160: malformed.append(line.left(4).to_int());continue
		# Fourteen retained non-stellar/removed records have no position.
		if line.substr(75,8).strip_edges().is_empty(): absent+=1;continue
		var fields := [line.substr(75,2),line.substr(77,2),line.substr(79,4),line.substr(84,2),line.substr(86,2),line.substr(88,2),line.substr(102,5)]
		var valid := true
		for value: String in fields:
			if not value.strip_edges().is_valid_float(): valid=false
		if not valid: malformed.append(line.left(4).to_int());continue
		var ra := deg_to_rad(15.*(float(fields[0])+float(fields[1])/60.+float(fields[2])/3600.))
		var dec := deg_to_rad(float(fields[3])+float(fields[4])/60.+float(fields[5])/3600.)
		if line.substr(83,1)=="-":dec=-dec
		if ra<0. or ra>=TAU or absf(dec)>PI*.5:malformed.append(line.left(4).to_int());continue
		var colour := line.substr(109,5).strip_edges()
		var bv := .65
		if colour.is_valid_float():bv=colour.to_float()
		else:
			missing_colour+=1
			var spectral := line.substr(127,20).strip_edges()
			# Historical luminosity prefixes (gK, dF, sgG) precede the class.
			for index in range(spectral.length()):
				var letter := spectral.substr(index,1)
				if FALLBACK_BV.has(letter):bv=float(FALLBACK_BV[letter]);break
		rows.append({"hr":line.left(4).to_int(),"ra":ra,"dec":dec,"magnitude":float(fields[6]),"bv":bv,
			"pm_ra":line.substr(148,6).to_float(),"pm_dec":line.substr(154,6).to_float()})
	return {"rows":rows,"non_stellar":absent,"missing_colour":missing_colour,"malformed":malformed}

static func direction(row: Dictionary,jd: float) -> Vector3:
	var ra := float(row.ra);var dec := float(row.dec)
	var n := Vector3(cos(dec)*cos(ra),cos(dec)*sin(ra),sin(dec))
	var east := Vector3(-sin(ra),cos(ra),0.)
	var north := Vector3(-cos(ra)*sin(dec),-sin(ra)*sin(dec),cos(dec))
	# BSC pmRA is cos(dec)*dRA/dt, already an angular tangent motion.
	var years := (jd-2451545.)/365.25
	return (n+(east*float(row.pm_ra)+north*float(row.pm_dec))*ARCSEC*years).normalized()

static func cube_cell(n: Vector3) -> Vector3i:
	var a := n.abs();var face := 0;var uv := Vector2.ZERO
	if a.x>=a.y and a.x>=a.z:
		face=0 if n.x>=0. else 1
		uv=Vector2(-n.z if n.x>=0. else n.z,n.y)/a.x
	elif a.y>=a.z:
		face=2 if n.y>=0. else 3
		uv=Vector2(n.x,-n.z if n.y>=0. else n.z)/a.y
	else:
		face=4 if n.z>=0. else 5
		uv=Vector2(n.x if n.z>=0. else -n.x,n.y)/a.z
	return Vector3i(clampi(floori((uv.x*.5+.5)*CELLS),0,CELLS-1),clampi(floori((uv.y*.5+.5)*CELLS),0,CELLS-1),face)

static func pack_radec_texture(rows: Array[Dictionary],half_precision := false) -> ImageTexture:
	# Raw global RA/Dec in RGBAH lose up to several arcminutes: visibly wrong
	# at a 0.1-degree field. RGBAF is the authoritative default (about 146 KB).
	# Half precision remains available for diagnostics demonstrating that loss.
	var image := Image.create_empty(WIDTH,ceili(float(rows.size())/WIDTH),false,Image.FORMAT_RGBAH if half_precision else Image.FORMAT_RGBAF)
	for i in range(rows.size()):
		var row: Dictionary=rows[i]
		image.set_pixel(i%WIDTH,i/WIDTH,Color(row.ra,row.dec,row.magnitude,row.bv))
	return ImageTexture.create_from_image(image)

static func bake(rows: Array[Dictionary]) -> Dictionary:
	var buckets: Array=[];buckets.resize(6*CELLS*CELLS)
	for i in range(buckets.size()):buckets[i]=[]
	for row: Dictionary in rows:
		var n := direction(row,EPOCH_JD)
		var cell := cube_cell(n)
		buckets[(cell.z*CELLS+cell.y)*CELLS+cell.x].append({"row":row,"direction":n})
	var headers := Image.create_empty(CELLS,CELLS*6,false,Image.FORMAT_RGBAF)
	var points := Image.create_empty(WIDTH,ceili(float(rows.size())/WIDTH),false,Image.FORMAT_RGBAF)
	var properties := Image.create_empty(WIDTH,points.get_height(),false,Image.FORMAT_RGBAH)
	var offset := 0;var maximum := 0
	for i in range(buckets.size()):
		var bucket: Array=buckets[i]
		maximum=maxi(maximum,bucket.size())
		headers.set_pixel(i%CELLS,i/CELLS,Color(float(offset),float(bucket.size()),0.,0.))
		for entry: Dictionary in bucket:
			var row: Dictionary=entry.row;var n: Vector3=entry.direction
			points.set_pixel(offset%WIDTH,offset/WIDTH,Color(n.x,n.y,n.z,row.magnitude))
			# Photometry/proper-motion tolerates half precision; directions don't.
			properties.set_pixel(offset%WIDTH,offset/WIDTH,Color(row.bv,row.pm_ra,row.pm_dec,float(int(row.hr)%2048)))
			offset+=1
	return {"headers":ImageTexture.create_from_image(headers),"points":ImageTexture.create_from_image(points),"properties":ImageTexture.create_from_image(properties),"count":offset,"max_bucket":maximum,"epoch_jd":EPOCH_JD}
