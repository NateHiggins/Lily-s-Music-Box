extends RefCounted
## Candidate numerical seed only. The host retains full material, physical
## bend, native world/self sweep and original fitting collision vetoes.
var rig: RefCounted
var radii:=PackedFloat64Array()
var kernels: Dictionary={}
var last_join:=-1
var attempts:=0
var failures:=0
var last_error:=""
var last_usec:=0
var tip_direction:=Vector3.ZERO

func configure(owner_rig: RefCounted,minimum_radii: PackedFloat64Array) -> bool:
	if rig!=null or owner_rig==null or minimum_radii.size()!=owner_rig.rest.size():return false
	rig=owner_rig;radii=minimum_radii.duplicate();return true

func _ensure_kernel(join: int,before: PackedVector3Array) -> bool:
	if kernels.has(join):return true
	var prepared_kernel:=preload("res://scripts/props/hose_mass_constraints.gd").new()
	if not prepared_kernel.configure(rig.strand.lengths.slice(0,join),before.slice(0,join+1),radii.slice(0,join+1)):return false
	if not prepared_kernel.coupled.set_bend_error(.00002):return false
	prepared_kernel.bend_error_m=.00002;kernels[join]=prepared_kernel;return true

func prime(before: PackedVector3Array) -> void:
	for join: int in [12,20,28,44,76,before.size()-1]:
		if join<before.size():_ensure_kernel(join,before)

func seed(before: PackedVector3Array,goal: Vector3) -> PackedVector3Array:
	return constrained_seed(before,goal,{},{})

func constrained_seed(before: PackedVector3Array,goal: Vector3,planes: Dictionary,requested_pins: Dictionary) -> PackedVector3Array:
	var started: int=Time.get_ticks_usec();last_join=-1;last_error=""
	if rig==null or before.size()!=rig.rest.size() or not goal.is_finite():return PackedVector3Array()
	var direction: Vector3=(before[1]-before[0]).normalized()
	var preferred: Vector3=(before[6]-goal).normalized()
	var angle: float=acos(clampf(direction.dot(preferred),-1.,1.))
	var turn: float=minf(.2,goal.distance_to(before[0])*2.)
	if angle>.000001 and angle<PI-.00001:direction=direction.slerp(preferred,minf(1.,turn/angle)).normalized()
	if tip_direction.length_squared()>.99:direction=tip_direction
	var first: Vector3=goal+direction*rig.strand.lengths[0]
	var second: Vector3=goal+direction*(rig.strand.lengths[0]+rig.strand.lengths[1])
	var joins: Array[int]=[12,20,28,44,76,before.size()-1]
	for join: int in joins:
		if join>=before.size():continue
		var material:=0.
		for i in join:material+=rig.strand.lengths[i]
		if goal.distance_to(before[join])>material:continue
		attempts+=1
		if not _ensure_kernel(join,before):continue
		var kernel: RefCounted=kernels[join]
		var pins: Dictionary={0:goal,1:first,2:second,join-1:before[join-1],join-2:before[join-2]}
		var compatible:=true
		for ring: int in requested_pins:
			if ring>=join-2:
				compatible=compatible and before[ring].distance_to(requested_pins[ring])<.000001
			else:pins[ring]=requested_pins[ring]
		var local_planes: Dictionary={}
		for ring: int in planes:
			if ring<=join:local_planes[ring]=planes[ring]
			else:
				# The retained tail is fixed for this local solve. Expand the
				# solved span if any of its contacts needs actual displacement.
				for plane: Dictionary in planes[ring]:compatible=compatible and plane.normal.dot(before[ring])>=plane.offset-.000001
		if not compatible:continue
		var local: PackedVector3Array=kernel.follow(before.slice(0,join+1),before[join],local_planes,pins)
		if local.is_empty():failures+=1;last_error=kernel.error;continue
		var proposed: PackedVector3Array=before.duplicate()
		for i in local.size():proposed[i]=local[i]
		last_join=join;last_usec=Time.get_ticks_usec()-started
		return proposed
	last_usec=Time.get_ticks_usec()-started
	return PackedVector3Array()
