extends "res://tests/v2_nook_world_profile.gd"
## INERT native geometry/image diagnostic; qualification requires separate runtime contracts.
## Same nearby route and actual Space/primary ownership as the original candidate.
var optics: Array[Dictionary]=[]
var installed_reading: Dictionary = {}
var lamp_controls: Array[Dictionary]=[]
var hand_observations: Array[Dictionary]=[]
var comparison_poses: Dictionary={}
var two_style_controls: Dictionary={"executed":false,"completed":false,"frames":[],"attempts":[]}
var held_controls: Dictionary={"executed":false,"two_style_closed_open":{"executed":false,"reason":"Parent route selects one reachable copy; two-style closed/open actual acquisition is not established."}}
const NATIVE_PIXELS := Vector2i(3440,1440)
const COMPACT_PIXELS := Vector2i(800,600)
var _optics_pixels := NATIVE_PIXELS
var _compact_paperback := false
const OWNER_SOURCES: Array[String]=[
	"res://scripts/props/v2_readable_book.gd",
	"res://scripts/props/v2_library_movable.gd",
	"res://scripts/building/v2_loose_library.gd",
	"res://scripts/building/v2_readable_bookshelf.gd",
	"res://scripts/device/companion_world_carrier.gd",
	"res://scripts/device/companion_screen_frame.gd",
	"res://scripts/device/service_set_carrier.gd",
	"res://scripts/player/player_controller.gd",
	"res://scripts/player/constrained_grab.gd",
	"res://scripts/lamp/carried_lamp_optical_driver.gd",
	"res://scripts/lamp/lamp_optical_state.gd",
	"res://scripts/props/book_print_preparation.gd",
	"res://scripts/props/book_print_mesh.gd",
	"res://scripts/device/companion_motion.gd"]

func _ready() -> void:
	_compact_paperback = OS.get_environment("ORISON_BOOK_COMPACT_PAPERBACK") == "1"
	if _compact_paperback:
		_optics_pixels = COMPACT_PIXELS
		var viewport := get_viewport() as SubViewport
		if not _require(viewport != null, "compact paperback uses a detached input viewport"):
			get_tree().quit(1)
			return
		viewport.size = _optics_pixels
	super._ready()

func _accept_nook_book(book: Node3D) -> bool:
	return not _compact_paperback or book.construction.get("opening_style") == "paperback"

func _inspect_stock_review(book: Node3D) -> void:
	profile_active=false # Readback, hashing and queries are not frame-budget proof.
	var sources_before: Dictionary=_optics_sources()
	var original_power: bool=player.lamp_is_enabled()
	await _observe_book("inspection",book)
	for pressed: bool in [true,false]:
		var key:=InputEventKey.new()
		key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=pressed
		player._unhandled_input(key)
	if not _require(not player.inspecting() and player._grab.holding_pickup() and player._grab.target.part==book,"optical comparison returns the same book through actual Space"):return
	for frame in 110:await get_tree().process_frame
	for treatment: Array in [["returned_hand",true],["lamp_off",false],["lamp_restored",true]]:
		if not await _optics_lamp_power(bool(treatment[1]),str(treatment[0])):break
		await _optics_hand(book,str(treatment[0]))
		await _observe_book(str(treatment[0]),book)
	var restored: bool=await _optics_lamp_power(original_power,"restore_original_switch")
	_require(restored and player.lamp_is_enabled()==original_power,"normal lamp input restores original logical power")
	_require(optics.size()==4 and _optics_same_subjects(),"all four optical phases retain the same book/camera/lamp/carrier/device/aperture identities")
	if OS.get_environment("ORISON_BOOK_HELD_PANEL_CONTROL")=="1" and failures.is_empty():await _held_panel_control(book)
	var reading_requested := OS.get_environment("ORISON_BOOK_INSTALLED_READING") == "1"
	var reading_ok := true
	if reading_requested:
		var viewport := get_viewport() as SubViewport
		reading_ok = false
		if failures.is_empty() and _require(viewport != null, "installed reading uses detached viewport"):
			var prior_msaa := viewport.msaa_3d
			viewport.msaa_3d = get_tree().root.msaa_3d
			reading_ok = await _installed_reading(book)
			viewport.msaa_3d = prior_msaa
			installed_reading.restored_viewport_msaa = viewport.msaa_3d
		installed_reading.completed = reading_ok
		_require(reading_ok, "requested installed same-book reading programme completed")
	var released := false
	if reading_ok:
		_click_library()
		released = _require(not player._grab.active() and not book._held,"optical diagnostic releases the same book through actual primary")
	if released and bool(held_controls.get("completed",false)):await _held_empty_fallback(book)
	if OS.get_environment("ORISON_BOOK_TWO_STYLE_HELD")=="1" and released and failures.is_empty():
		await _two_style_run(book.shelf)
		player.cancel_manipulation() # Normal owned-test cleanup; failures retained.
	var output: String=OS.get_environment("SHOT_DIR")
	var sources: Dictionary=_optics_sources()
	_require(sources==sources_before,"named optical observer/owner sources unchanged through controls")
	var report: Dictionary={"evidence_class":"INERT","kind":"book_lamp_geometry_diagnostic","frames":optics,"source_files_sha256":sources,"source_files_before_sha256":sources_before,"released_same_book":released,"lamp_controls":lamp_controls,"hand_observations":hand_observations,"original_lamp_power":original_power,"original_lamp_restored":restored,"held_controls":held_controls,"two_style_controls":two_style_controls,
		"independent_opaque_control":{"executed":false,"reason":"No independently operable opaque blocker is proven reachable by this preserved parent route. Existing first hits are observations, not an invented clear/blocked/restored control."},
		"scope":"Same installed book/native lamp, inspection and actual FPS hand; real polled on/off/restored power. Geometry/image-region observations only; no independent opaque control, readability acceptance, performance, save or artistic acceptance.","failures":failures}
	if reading_requested:
		report.installed_reading = installed_reading
	var file:=FileAccess.open(output.path_join("book_lamp_geometry.json"),FileAccess.WRITE)
	if not _require(file!=null,"book lamp diagnostic report opens"):return
	file.store_string(JSON.stringify(report,"\t"));file.close()

func _observe_book(phase: String,book: Node3D) -> void:
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var light: SpotLight3D=player.flashlight
	var title: Label3D
	for label: Label3D in book.printed_labels:
		if label.name=="CoverTitle":title=label;break
	if not _require(title!=null and light!=null,"actual cover title anchor and lamp exist for diagnostic"):return
	var carrier: Node3D=player.carried_device
	var device: Node=carrier.get("device") as Node if carrier!=null else null
	var motion: Variant=carrier.get("motion") if carrier!=null else null
	var target: Variant=motion.light_target if motion!=null else null
	var lens: MeshInstance3D
	if device!=null and device.get("teletype")!=null:lens=device.teletype.torch_lens
	if not _require(carrier!=null and bool(carrier.get("world_ready")) and device!=null and motion!=null and lens!=null,"actual V2 world carrier/device/motion/native aperture hierarchy exists"):return
	var origin: Vector3=light.global_position
	var forward: Vector3=-light.global_basis.orthonormalized().z
	# CoverTitle is authored in OpeningGathering at z=thickness/2+60um.
	# Its local +Z is the printed front; inspect dot signs without assuming litness.
	var width: float=book.construction.width
	var height: float=book.construction.height
	var z: float=float(book.construction.thickness)*.5+.00006
	var samples: Array[Dictionary]=[]
	samples.append(_sample("title_anchor",title.global_position,title.global_basis.orthonormalized().z,origin,forward,light,book))
	for spec: Array in [["lower_left",.1,.1],["lower_right",.9,.1],["centre",.5,.5],["upper_left",.1,.9],["upper_right",.9,.9]]:
		var at: Vector3=book.left.to_global(Vector3(width*float(spec[1]),height*float(spec[2]),z))
		samples.append(_sample(str(spec[0]),at,book.left.global_basis.orthonormalized().z,origin,forward,light,book))
	var geometry: Dictionary=_optics_geometry(book,title)
	var draws: Array[Dictionary]=[]
	for draw: MeshInstance3D in book.find_children("*","MeshInstance3D",true,false):
		draws.append({"path":str(draw.get_path()),"layers":draw.layers,"visible":draw.is_visible_in_tree(),"lamp_layer_overlap":(draw.layers&light.light_cull_mask)!=0,"cast_shadow":draw.cast_shadow})
	var image: Image=get_viewport().get_texture().get_image()
	_require(image.get_size()==_optics_pixels and get_viewport().get_visible_rect().size==Vector2(_optics_pixels),
		"optical image and viewport are actual native%dx%d" % [_optics_pixels.x,_optics_pixels.y])
	var filename: String=phase+"_book_lamp.png"
	var output: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var png_path: String=output.path_join(filename)
	_require(image.save_png(png_path)==OK,"optical comparison frame saved: "+phase)
	var png_pixels: Vector2i=_optics_png_size(FileAccess.get_file_as_bytes(png_path))
	_require(png_pixels==_optics_pixels,"saved optical PNG has actual native IHDR dimensions: "+phase)
	var regions: Dictionary={}
	for key: String in geometry:regions[key]=_optics_region(image,geometry[key].get("roi",[]))
	var holding: bool=player._grab.holding_pickup() and player._grab.target.get("part")==book
	optics.append({"phase":phase,"file":filename,"stock_id":book.stock_id,"book_identity":_identity(book),"shelf_identity":_identity(book.shelf),
		"camera_identity":_identity(player.camera),"expected_title":str(book.entry.title),"expected_author":str(book.entry.author),"title_id":book.title_id,"matches_retained_dark_copy":book.stock_id=="nook_books__Volume0","opening":book.opening,
		"png_sha256":FileAccess.get_sha256(png_path),"actual_png_pixels":[png_pixels.x,png_pixels.y],"projected_final_geometry":geometry,"capture_region_observations":regions,"optical_power_state":_optics_lamp_snapshot(),"pose_deltas_to_returned_hand":_optics_pose_deltas(phase,book,light,lens),
		"viewport":var_to_str(get_viewport().get_visible_rect().size),"camera":var_to_str(player.camera.global_transform),"book":var_to_str(book.global_transform),
		"cover_title":{"identity":_identity(title),"layers":title.layers,"lamp_layer_overlap":(title.layers&light.light_cull_mask)!=0,"visible":title.is_visible_in_tree(),"shaded":title.shaded,"double_sided":title.double_sided,"no_depth_test":title.no_depth_test},
		"lamp":{"identity":_identity(light),"transform":var_to_str(light.global_transform),"visible":light.is_visible_in_tree(),"logical_player_enabled":player.lamp_is_enabled(),"logical_device_enabled":device.get("lamp_enabled") if device!=null else null,"energy":light.light_energy,"range":light.spot_range,"half_angle_deg":light.spot_angle,"light_cull_mask":light.light_cull_mask,"shadow_enabled":light.shadow_enabled},
		"carrier":{"identity":_identity(carrier),"device_identity":_identity(device),"beam_valid":carrier.get("beam_valid") if carrier!=null else null,"native_lens_identity":_identity(lens),"native_lens_transform":var_to_str(lens.global_transform) if lens!=null else "","native_aperture":var_to_str(lens.to_global(lens.mesh.get_aabb().get_center())) if lens!=null and lens.mesh!=null else "","reticle_target":var_to_str(target),"target_valid":motion.light_target_valid if motion!=null else null},
		"samples":samples,"book_draws":draws,"reading_aim":_reading_aim_observation(book,lens,carrier),"inspecting":player.inspecting(),"holding_same_book":holding,"current_hand_centre_error_m":(book.global_transform*book.pickup_centre()).distance_to(player.camera.global_transform*Vector3(.17,-.16,-.48)) if holding else null})

func _reading_aim_observation(book: Node3D,lens: MeshInstance3D,carrier: Node3D) -> Dictionary:
	var aperture: Vector3=lens.to_global(lens.mesh.get_aabb().get_center())
	var target: Vector3=book.reading_light_target(aperture)
	var result: Dictionary={"actual_held_body_is_book":player.held_stock_body()==book,"book_held":book._held,"profile_target":var_to_str(target),"native_aperture":var_to_str(aperture),"carrier_target_queries":carrier.lamp_target_queries,"carrier_target_frame":carrier._lamp_target_frame,"physics_frame":Engine.get_physics_frames(),"diagnostic_query_issued":false,"first_hit":{},"scope":"Separate diagnostic ray, not the production query counter, shadow-map proof or performance sample."}
	if not target.is_finite() or target.distance_to(aperture)>player.flashlight.spot_range:return result
	var query:=PhysicsRayQueryParameters3D.create(aperture,target,1)
	query.collide_with_bodies=true;query.collide_with_areas=false
	query.hit_from_inside=true;query.hit_back_faces=true
	var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(query)
	result.diagnostic_query_issued=true
	result.first_hit=_hit_record(hit,book,target)
	result.actual_motion_target=var_to_str(carrier.motion.light_target)
	result.target_valid=carrier.motion.light_target_valid
	return result

func _sample(label: String,at: Vector3,normal: Vector3,origin: Vector3,forward: Vector3,light: SpotLight3D,book: Node3D) -> Dictionary:
	var direction: Vector3=(at-origin).normalized()
	# Match the production body-only optical mask; record both raw and carrier-
	# excluded hits. Neither removes real opaque world stock or book collision.
	var query:=PhysicsRayQueryParameters3D.create(origin,at,1)
	var raw: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(query)
	query.exclude=[player.get_rid()]
	var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(query)
	var angle: float=rad_to_deg(acos(clampf(forward.dot(direction),-1.,1.)))
	return {"sample":label,"position":var_to_str(at),"pixel":var_to_str(player.camera.unproject_position(at)),"behind_camera":player.camera.is_position_behind(at),"normal":var_to_str(normal),"normal_dot_toward_lamp":normal.dot(-direction),"angle_deg":angle,"inside_nominal_cone":angle<=light.spot_angle,"distance_m":origin.distance_to(at),"inside_range":origin.distance_to(at)<=light.spot_range,"unfiltered_hit":_hit_record(raw,book,at),"player_excluded_hit":_hit_record(hit,book,at)}

func _hit_record(hit: Dictionary,book: Node3D,sample_at: Vector3) -> Dictionary:
	var collider: Node=hit.get("collider") as Node
	return {"collider":_identity(collider),"position":var_to_str(hit.get("position")),"normal":var_to_str(hit.get("normal")),"shape":hit.get("shape"),"hit_to_sample_distance_m":sample_at.distance_to(hit.position) if not hit.is_empty() else null,"is_same_book":collider==book or (collider!=null and book.is_ancestor_of(collider))}

func _identity(node: Node) -> Dictionary:
	if node==null:return {}
	return {"path":str(node.get_path()),"instance_id":node.get_instance_id(),"script":node.get_script().resource_path if node.get_script()!=null else ""}

func _optics_lamp_snapshot() -> Dictionary:
	var light: SpotLight3D=player.flashlight
	var carrier: Node3D=player.carried_device
	var device: Node=carrier.get("device") as Node if carrier!=null else null
	var result: Dictionary={"ticks_usec":Time.get_ticks_usec(),"logical_player":player.lamp_is_enabled(),"logical_device":device.get("lamp_enabled") if device!=null else null,"energy":light.light_energy,"visible":light.is_visible_in_tree(),"legacy_phase":player._lamp_phase}
	var driver: Node=player.lamp_presentation
	if is_instance_valid(driver):
		result.presentation_owner=_identity(driver)
		result.output=driver.output.duplicate(true)
		result.filament_emission=float(driver.output.filament_emission)
		result.filament_temperature_k=float(driver.state.filament_temperature_k)
		result.intensity_rate=float(driver.state.intensity_rate)
	return result

func _optics_lamp_power(on: bool,phase: String) -> bool:
	# Input.action_press stamps the CURRENT process frame. At post_draw the
	# player's poll has already run; resume at the next pre-process signal.
	await get_tree().process_frame
	var record: Dictionary={"phase":phase,"requested_on":on,"before":_optics_lamp_snapshot(),"action_delivered":false,"samples":[]}
	if player.lamp_is_enabled()!=on:
		if not _require(not is_instance_valid(player.text_input_owner) and not Input.is_action_pressed("lamp_toggle"),"lamp input is available without taking over another input owner: "+phase):return false
		Input.action_press("lamp_toggle")
		record.press_process_frame=Engine.get_process_frames()
		record.press_action_state={"pressed":Input.is_action_pressed("lamp_toggle"),"just_pressed":Input.is_action_just_pressed("lamp_toggle")}
		await RenderingServer.frame_post_draw
		record.after_actual_process=_optics_lamp_snapshot()
		Input.action_release("lamp_toggle")
		await get_tree().process_frame
		record.action_delivered=true
	var deadline: int=Time.get_ticks_msec()+8000
	var previous: Dictionary={}
	var steady: int=0
	while Time.get_ticks_msec()<deadline:
		await get_tree().create_timer(.1).timeout
		var sample: Dictionary=_optics_lamp_snapshot()
		record.samples.append(sample)
		var logical: bool=sample.logical_player==on and sample.logical_device is bool and bool(sample.logical_device)==on
		# Numerical convergence only, not a readability/contrast threshold.
		# The .001 dark boundary is the production presentation visibility floor.
		var dark: bool=not on and not sample.visible and float(sample.energy)<=.001
		var powered: bool=on and sample.visible and float(sample.energy)>0.
		var converged: bool=not previous.is_empty() and absf(float(sample.energy)-float(previous.energy))<=.001
		if sample.has("filament_emission") and previous.has("filament_emission"):
			converged=converged and absf(float(sample.filament_emission)-float(previous.filament_emission))<=.001
		else:converged=converged and float(sample.legacy_phase)<=0.
		steady=steady+1 if logical and (dark or powered) and converged else 0
		previous=sample
		if steady>=4:break
	var accepted: bool=steady>=4
	record.settled=accepted;record.after=previous
	lamp_controls.append(record)
	print("BOOK LAMP INPUT: ",JSON.stringify(record))
	return _require(accepted,"actual polled lamp input reaches matching logical/device and settled filament output: "+phase)

func _optics_hand(book: Node3D,phase: String) -> void:
	var samples: Array[Dictionary]=[]
	var previous: Transform3D=book.global_transform
	var same: bool=true
	for frame in 12:
		await get_tree().physics_frame
		var pose: Transform3D=book.global_transform
		var holding: bool=player._grab.holding_pickup() and player._grab.target.get("part")==book
		same=same and holding and book._held and book.freeze
		var collider: Variant=book._last_motion.get("collider")
		samples.append({"physics_frame":Engine.get_physics_frames(),"same_book_in_hand":holding,"held":book._held,"frozen":book.freeze,"centre_error_m":(pose*book.pickup_centre()).distance_to(player.camera.global_transform*Vector3(.17,-.16,-.48)),"successive_origin_drift_m":pose.origin.distance_to(previous.origin),"successive_basis_drift_rad":pose.basis.orthonormalized().get_rotation_quaternion().angle_to(previous.basis.orthonormalized().get_rotation_quaternion()),"successive_transform_approx_equal":pose.is_equal_approx(previous),"book_pose":var_to_str(pose),"camera_pose":var_to_str(player.camera.global_transform),"last_contact":var_to_str(book._last_motion),"contact_identity":_identity(collider) if collider is Node else {},"hold_blocked":book._hold_blocked})
		previous=pose
	var result: Dictionary={"phase":phase,"samples":samples,"same_hand_throughout":same,"final_centre_error_m":samples[-1].centre_error_m,"drift_is_observed_not_forced":true}
	hand_observations.append(result)
	print("BOOK HAND SETTLE OBSERVATION: ",JSON.stringify(result))
	# Keep the existing installed return route's .01m swept-hand bound.
	_require(same and float(result.final_centre_error_m)<.01,"same frozen/held book reaches existing installed FPS-hand error bound: "+phase)

func _optics_geometry(book: Node3D,title: Label3D) -> Dictionary:
	var cover_points:=PackedVector3Array()
	var cover_parts: Array[String]=[]
	for draw: MeshInstance3D in book._native_draws:
		var part_id: String=str(draw.get_meta("readable_library_part",""))
		if part_id not in [str(book.stock_id)+"__left_board",str(book.stock_id)+"__continuous_wrap"] or not draw.is_visible_in_tree():continue
		var mesh: Mesh=draw.mesh
		if draw.get_blend_shape_count()>0:
			# New temporary mesh only: never assign it to the production instance.
			mesh=draw.bake_mesh_from_current_blend_shape_mix()
		if mesh==null:continue
		cover_parts.append(str(draw.get_path()))
		cover_points.append_array(_optics_vertices(mesh.get_rid(),draw.global_transform))
	var result: Dictionary={"cover":_optics_project(cover_points)}
	result.cover.drawn_parts=cover_parts
	result.cover.geometry_source="actual loaded cover board or continuous-wrapper mesh and current blend-shape mix; bounds, not occlusion/silhouette proof"
	for label: Label3D in book.printed_labels:
		if label!=title and label.name!="CoverAuthor":continue
		var mesh_rid: RID=label.get_base()
		var source: String="loaded Label3D glyph mesh"
		for printed: Dictionary in book._print_surfaces:
			if printed.node==label:
				mesh_rid=printed.mesh;source="current warped print instance mesh";break
		var bounds: Dictionary=_optics_project(_optics_vertices(mesh_rid,label.global_transform))
		bounds.geometry_source=source;bounds.mesh_rid=mesh_rid.get_id();bounds.label=_identity(label)
		bounds.expected_text=str(book.entry.title) if label==title else str(book.entry.author)
		bounds.authored_text=label.text;bounds.label_visible=label.is_visible_in_tree()
		bounds.em_m=label.font_size*label.pixel_size
		result["title" if label==title else "author"]=bounds
	_require(not cover_points.is_empty() and result.has("title") and int(result.title.vertices)>0,"loaded final cover and glyph geometry available")
	return result

func _optics_vertices(mesh_rid: RID,pose: Transform3D) -> PackedVector3Array:
	var points:=PackedVector3Array()
	if not mesh_rid.is_valid():return points
	for surface in RenderingServer.mesh_get_surface_count(mesh_rid):
		var arrays: Array=RenderingServer.mesh_surface_get_arrays(mesh_rid,surface)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX]==null:continue
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:points.append(pose*point)
	return points

func _optics_project(points: PackedVector3Array) -> Dictionary:
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF);var behind: int=0
	for point: Vector3 in points:
		if player.camera.is_position_behind(point):behind+=1;continue
		var pixel: Vector2=player.camera.unproject_position(point)
		low=low.min(pixel);high=high.max(pixel)
	var result: Dictionary={"vertices":points.size(),"behind_vertices":behind,"all_behind":behind==points.size(),"roi":[],"bounds_are_not_visible_ink_mask":true}
	if behind==points.size():return result
	var size: Vector2i=get_viewport().get_visible_rect().size
	var x0: int=clampi(floori(low.x),0,size.x);var y0: int=clampi(floori(low.y),0,size.y)
	var x1: int=clampi(ceili(high.x),0,size.x);var y1: int=clampi(ceili(high.y),0,size.y)
	result.projected_bounds_px=[low.x,low.y,high.x,high.y]
	result.projected_width_px=high.x-low.x;result.projected_height_px=high.y-low.y
	result.frame_clipped=low.x<0. or low.y<0. or high.x>size.x or high.y>size.y or behind>0
	result.roi=[x0,y0,maxi(0,x1-x0),maxi(0,y1-y0)]
	return result

func _reading_hull_projection(book: Node3D) -> Dictionary:
	var points:=PackedVector3Array()
	for solid: CollisionShape3D in book._solids:
		var hull:=solid.shape as ConvexPolygonShape3D
		for point: Vector3 in hull.points:
			points.append(solid.global_transform*point)
	return _optics_project(points)

func _optics_region(image: Image,roi: Array) -> Dictionary:
	if roi.size()!=4 or int(roi[2])<=0 or int(roi[3])<=0:return {"sample_count":0,"valid_region":false}
	var stride: int=maxi(1,ceili(sqrt(float(int(roi[2])*int(roi[3]))/65536.)))
	var count: int=0;var black: int=0;var saturated: int=0
	var total: float=0.;var low: float=INF;var high: float=-INF
	for y in range(int(roi[1]),int(roi[1])+int(roi[3]),stride):
		for x in range(int(roi[0]),int(roi[0])+int(roi[2]),stride):
			var pixel: Color=image.get_pixel(x,y)
			var linear: Color=pixel.srgb_to_linear()
			var luma: float=.2126*linear.r+.7152*linear.g+.0722*linear.b
			total+=luma;low=minf(low,luma);high=maxf(high,luma);count+=1
			if pixel.r<=0. and pixel.g<=0. and pixel.b<=0.:black+=1
			if pixel.r>=1. or pixel.g>=1. or pixel.b>=1.:saturated+=1
	return {"valid_region":count>0,"roi":roi,"uniform_sample_stride":stride,"sample_count":count,"capture_rgb_linearized_luminance_mean":total/maxi(1,count),"luminance_min":low,"luminance_max":high,"black_endpoint_fraction":float(black)/maxi(1,count),"any_channel_saturated_endpoint_fraction":float(saturated)/maxi(1,count),"scope":"Exposure/tonemap-applied capture region includes paper/background. Not segmented ink contrast, physical irradiance, OCR or readability acceptance."}

func _optics_png_size(raw: PackedByteArray) -> Vector2i:
	if raw.size()<24 or raw.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or raw.slice(12,16).get_string_from_ascii()!="IHDR":return Vector2i.ZERO
	return Vector2i((int(raw[16])<<24)|(int(raw[17])<<16)|(int(raw[18])<<8)|int(raw[19]),(int(raw[20])<<24)|(int(raw[21])<<16)|(int(raw[22])<<8)|int(raw[23]))

func _optics_same_subjects() -> bool:
	if optics.is_empty():return false
	var first: Dictionary=optics[0]
	for frame: Dictionary in optics:
		if frame.book_identity!=first.book_identity or frame.camera_identity!=first.camera_identity or frame.lamp.identity!=first.lamp.identity:return false
		for key: String in ["identity","device_identity","native_lens_identity"]:
			if frame.carrier[key]!=first.carrier[key] or frame.carrier[key].is_empty():return false
	return true

func _optics_pose_deltas(phase: String,book: Node3D,light: SpotLight3D,lens: Node3D) -> Dictionary:
	var current: Dictionary={"book":book.global_transform,"camera":player.camera.global_transform,"lamp":light.global_transform,"native_aperture_frame":lens.global_transform}
	if phase=="returned_hand":comparison_poses=current.duplicate()
	if comparison_poses.is_empty():return {"reference_available":false}
	var result: Dictionary={"reference_available":true,"reference_phase":"returned_hand","poses_not_forced":true}
	for key: String in current:
		var before: Transform3D=comparison_poses[key]
		var after: Transform3D=current[key]
		result[key]={"origin_delta_m":before.origin.distance_to(after.origin),"basis_delta_rad":before.basis.orthonormalized().get_rotation_quaternion().angle_to(after.basis.orthonormalized().get_rotation_quaternion())}
	return result

func _optics_sources() -> Dictionary:
	var result: Dictionary={get_script().resource_path:_optics_text_hash(get_script().resource_path),"res://tests/V2BookLampDiagnostic.tscn":_optics_text_hash("res://tests/V2BookLampDiagnostic.tscn")}
	for path: String in OWNER_SOURCES:result[path]=_optics_text_hash(path)
	var actual_scene: String=get_tree().current_scene.scene_file_path
	result[actual_scene]=_optics_text_hash(actual_scene)
	return result

func _optics_text_hash(path: String) -> String:
	if not FileAccess.file_exists(path):return ""
	return FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()

# Optional same-current-book technical panel control. Fixture insertion/removal,
# NOT a second player hand or a new installed-world/player-operated mechanism.
func _held_panel_control(book: Node3D) -> void:
	held_controls.executed=true;held_controls.scope="Same current closed book, real original pickup/Space/power programme. Owned panel is fixture-inserted, not player-operated; no two-style/open/readability/artistic/performance acceptance."
	held_controls.completed=false;held_controls.frames=[];held_controls.budget=[]
	if not _require(player.held_stock_body()==book and book._held and not player.inspecting(),"panel control retains actual current book in free hand"):return
	if not _require(is_zero_approx(book.opening) and player.lamp_is_enabled(),"panel control starts from actual closed book and powered lamp"):return
	var carrier: Node3D=player.carried_device
	var lens: MeshInstance3D=carrier.device.teletype.torch_lens
	if not _require(is_instance_valid(lens) and lens.mesh!=null,"panel control uses actual native aperture"):return
	var aperture: Vector3=lens.to_global(lens.mesh.get_aabb().get_center())
	var target: Vector3=book.reading_light_target(aperture)
	if not _require(target.is_finite() and aperture.distance_to(target)>.08,"panel control has finite nondegenerate real profile target"):return
	var original_book: Transform3D=book.global_transform
	var original_camera: Transform3D=player.camera.global_transform
	var direction: Vector3=(target-aperture).normalized()
	var up: Vector3=Vector3.UP if absf(direction.dot(Vector3.UP))<.95 else Vector3.RIGHT
	var pose:=Transform3D(Basis.looking_at(direction,up),(aperture+target)*.5)
	var box:=BoxShape3D.new();box.size=Vector3(.12,.16,.012)
	# Fail first setup if real stock/player overlaps proposed witness. Never
	# exclude them, disable collisions, move the hand, or hunt a passing pose.
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=box;query.transform=pose
	query.collision_mask=1;query.collide_with_bodies=true;query.collide_with_areas=false;query.margin=0.
	var overlaps: Array[Dictionary]=player.get_world_3d().direct_space_state.intersect_shape(query,8)
	held_controls.overlaps_before_insertion=[]
	for hit: Dictionary in overlaps:held_controls.overlaps_before_insertion.append({"collider":_identity(hit.get("collider") as Node),"rid":str(hit.get("rid",RID())),"shape":hit.get("shape",-1)})
	if not _require(overlaps.is_empty(),"owned opaque panel pose clears actual player/book/world stock before insertion"):return
	if not await _held_panel_stage("panel_clear",book,carrier,lens,original_book,original_camera,null):return
	var panel:=StaticBody3D.new();panel.name="BookLampOwnedOpaquePanel";panel.collision_layer=1;panel.collision_mask=1
	var solid:=CollisionShape3D.new();solid.shape=box;panel.add_child(solid)
	var draw:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box.size;draw.mesh=mesh;draw.layers=1
	var finish: StandardMaterial3D=MatLib.get_mat("cast_iron").duplicate();finish.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
	draw.material_override=finish;draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;panel.add_child(draw)
	add_child(panel);panel.global_transform=pose
	held_controls.panel={"identity":_identity(panel),"rid":str(panel.get_rid()),"pose":var_to_str(pose),"size":var_to_str(box.size),"layers":draw.layers,"cast_shadow":draw.cast_shadow,"transparency":finish.transparency,"fixture_inserted":true}
	for frame in 6:await get_tree().physics_frame
	var blocked: bool=await _held_panel_stage("panel_blocked",book,carrier,lens,original_book,original_camera,panel)
	panel.free() # Retire only this fixture's solid/draw, including failure path.
	for frame in 6:await get_tree().physics_frame
	if not blocked:return
	if not await _held_panel_stage("panel_restored",book,carrier,lens,original_book,original_camera,null):return
	held_controls.completed=true

func _held_panel_stage(phase: String,book: Node3D,carrier: Node3D,lens: MeshInstance3D,book_pose: Transform3D,camera_pose: Transform3D,panel: StaticBody3D) -> bool:
	if not _require(player.held_stock_body()==book and book._held and book.global_transform.is_equal_approx(book_pose) and player.camera.global_transform.is_equal_approx(camera_pose),"actual hand/book/camera retained without forced pose: "+phase):return false
	if not _require(player.lamp_is_enabled() and carrier.device.lamp_enabled and player.flashlight.shadow_enabled,"native powered shadow-casting lamp retained: "+phase):return false
	var aperture: Vector3=lens.to_global(lens.mesh.get_aabb().get_center())
	var target: Vector3=book.reading_light_target(aperture)
	if not _require(target.is_finite(),"real held profile target remains available: "+phase):return false
	var query:=PhysicsRayQueryParameters3D.create(aperture,target,1)
	query.collide_with_bodies=true;query.collide_with_areas=false;query.hit_from_inside=true;query.hit_back_faces=true
	var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(query)
	var hit_record: Dictionary=_hit_record(hit,book,target)
	hit_record.rid=str(hit.get("rid",RID()))
	if panel!=null:
		if not _require(hit.get("collider")==panel and hit.get("rid",RID())==panel.get_rid(),"unfiltered actual first solid is exact owned panel: "+phase):return false
	else:
		# Baseline may meet the book's own hull near the requested printed point;
		# do not skip other stock or claim any same-book hit proves occlusion.
		if not _require(hit.is_empty() or bool(hit_record.is_same_book),"unfiltered clear/restored line has no other first solid: "+phase):return false
	var observations: Array=[]
	# Pure counter/frame observation, no ray/capture/IO inside this interval.
	for frame in 13:
		await get_tree().physics_frame
		observations.append({"physics_frame":Engine.get_physics_frames(),"queries":carrier.lamp_target_queries,"target_frame":carrier._lamp_target_frame})
	var first: Dictionary=observations[0];var last: Dictionary=observations[-1]
	var delta: int=int(last.queries)-int(first.queries);var ticks: int=int(last.physics_frame)-int(first.physics_frame)
	held_controls.budget.append({"phase":phase,"samples":observations,"query_delta":delta,"physics_frame_delta":ticks,"boundary_allowance":1,"scope":"Endpoint ordering may include one current-frame callback. Production counter only, diagnostic rays excluded; not CPU duration/performance acceptance."})
	if not _require(delta>=0 and delta<=ticks+1,"bounded powered production query count: "+phase):return false
	var before_failures: int=failures.size()
	var before: int=optics.size()
	await _observe_book(phase,book)
	if not _require(optics.size()==before+1,"owned panel phase saves actual original image: "+phase):return false
	var image_record: Dictionary=optics.pop_back() # Keep original FOUR-phase list.
	image_record.unfiltered_panel_ray={"aperture":var_to_str(aperture),"requested_profile":var_to_str(target),"first_hit":hit_record,"exclusions":[],"hit_from_inside":true,"hit_back_faces":true}
	held_controls.frames.append(image_record)
	if failures.size()!=before_failures:return false
	var captured_hit: Dictionary=image_record.reading_aim.first_hit
	if panel!=null:
		if not _require(captured_hit.get("collider",{}).get("instance_id",0)==panel.get_instance_id(),"capture-time unfiltered first solid retains exact panel: "+phase):return false
	else:
		if not _require(captured_hit.get("collider",{}).is_empty() or bool(captured_hit.get("is_same_book",false)),"capture-time clear/restored first solid retains baseline scope: "+phase):return false
	return true

func _held_empty_fallback(book: Node3D) -> void:
	var carrier: Node3D=player.carried_device
	var lens: MeshInstance3D=carrier.device.teletype.torch_lens
	var before_queries: int=carrier.lamp_target_queries
	var before_frame: int=Engine.get_physics_frames()
	for frame in 13:await get_tree().physics_frame
	var target: Vector3=book.reading_light_target(lens.to_global(lens.mesh.get_aabb().get_center()))
	held_controls.empty_hand_fallback={"actual_held_body_absent":player.held_stock_body()==null,"book_held":book._held,"released_book_profile_target":var_to_str(target),"actual_motion_target":var_to_str(carrier.motion.light_target),"query_delta":carrier.lamp_target_queries-before_queries,"physics_frame_delta":Engine.get_physics_frames()-before_frame,"scope":"Actual next-click release; empty-hand/default-reticle eligibility and bounded counter observation. No non-book pickup or exact reticle-hit/render acceptance."}
	_require(player.held_stock_body()==null and not book._held and not target.is_finite(),"actual primary release disables held-book profile target")
	_require(carrier.lamp_target_queries-before_queries<=Engine.get_physics_frames()-before_frame+1,"empty-hand fallback retains bounded query budget")

# Separate opt-in continuation; real current world/library/native carrier reused.
func _two_style_run(owner: Node3D) -> void:
	two_style_controls.executed=true;two_style_controls.scope="Actual nearby installed collection, two construction styles, real ray/primary/cover hinge/Space return. Initial eye aim only; no book/holder transforms or physics exclusions. Not access/save/optical/artistic/performance acceptance."
	if not _require(get_viewport() is SubViewport,"two-style controls require detached event-owned pointer viewport"):return
	if not _require(player.held_stock_body()==null and not player.inspecting() and player.lamp_is_enabled(),"two-style continuation starts from original actual release and powered lamp"):return
	for family: String in ["hardback","flexible"]:
		var candidates: Array[Dictionary]=[]
		for book: Node3D in owner._books.values():
			var style: String=str(book.construction.get("opening_style","hardback"))
			if (style=="hardback")!=(family=="hardback"):continue
			if style not in ["hardback","paperback","pamphlet"] or book.shelf_slot<0:continue
			var point: Vector3=book.to_global(Vector3(-.001,float(book.construction.height)*.65,0))
			var distance: float=player.camera.global_position.distance_to(point)
			if distance<=2.1:candidates.append({"book":book,"point":point,"distance":distance})
		if not _require(not candidates.is_empty(),"actual same collection has in-reach placed "+family+" copy"):return
		candidates.sort_custom(func(a: Dictionary,b: Dictionary):return float(a.distance)<float(b.distance))
		# Pick ONCE by geometry. Do not skip the first occluded/blocked attempt.
		var selected: Dictionary=candidates[0]
		var book: Node3D=selected.book
		two_style_controls.attempts.append({"family":family,"identity":_identity(book),"stock_id":book.stock_id,"title_id":book.title_id,"style":book.construction.get("opening_style","hardback"),"distance_m":selected.distance,"opening_before":book.opening,"eligible_count":candidates.size()})
		if not _require(is_zero_approx(book.opening),"selected actual binding begins closed: "+family):return
		player.camera.look_at(selected.point) # Same acquisition-only aim as parent.
		for frame in 2:await get_tree().physics_frame
		var descriptor: Dictionary=player._grab.find_target()
		if not _require(descriptor.get("part")==book and descriptor.get("kind")=="free","first real spine ray selects chosen "+family+" copy without bypass"):return
		_click_library()
		if not _require(player.held_stock_body()==book,"actual primary picks up chosen "+family+" body"):return
		two_style_controls.attempts[-1].withdrawal_start=_two_style_withdrawal_state(book)
		for frame in 130:await get_tree().physics_frame
		two_style_controls.attempts[-1].withdrawal_end=_two_style_withdrawal_state(book)
		if not _require(player.held_stock_body()==book and (book.global_transform*book.pickup_centre()).distance_to(player.camera.global_transform*Vector3(.17,-.16,-.48))<.003,"actual "+family+" withdrawal reaches original FPS hand"):return
		if not await _two_style_capture(family+"_closed_held",book):return
		await _two_style_space()
		if not _require(player.inspecting() and not player._grab.active(),"actual Space supports selected "+family+" for cover grip"):return
		for frame in 110:await get_tree().physics_frame
		var contact: Vector3=book.left.to_global(Vector3(float(book.construction.width)*.7,float(book.construction.height)*.7,float(book.construction.thickness)*.5))
		if not _require(await _two_style_cursor(contact),"detached pointer delivers actual "+family+" cover point"):return
		var cover: Dictionary=player._grab.find_target()
		if not _require(cover.get("part")==book.left and cover.get("kind")=="hinge","actual physical "+family+" cover supplies hinge"):return
		_click_library()
		if not _require(player._grab.active() and player._grab.target.get("part")==book.left,"actual primary latches "+family+" cover"):return
		if not _require(await _two_style_hinge(PI),"actual mouse opens "+family+" cover without forced state"):return
		_click_library()
		if not _require(not player._grab.active(),"next primary releases "+family+" cover"):return
		var pickup_pose: Transform3D=book._reading_pickup_pose
		var pickup_slot: int=book._reading_pickup_slot
		await _two_style_space()
		if not _require(not player.inspecting() and player.held_stock_body()==null and not book._held
				and book.transform.is_equal_approx(pickup_pose) and book.shelf_slot==pickup_slot,
				"Space sets the read "+family+" copy back at pickup"):return
		for frame in 6:await get_tree().physics_frame
	two_style_controls.completed=true

func _cold_nook_first_use(book: Node3D, space: InputEventKey) -> bool:
	if OS.get_environment("ORISON_BOOK_COLD_FIRST_USE") != "1":
		return false
	profile_active = false
	var viewport := get_viewport() as SubViewport
	var initial := {"pages_ready":book._pages_ready, "print_ready":book._print_ready,
		"opening":book.opening, "source":_identity(book)}
	var observation := {"evidence_class":"INERT", "initial":initial,
		"scope":"Fresh isolated native process, original nearby standing pickup, first actual Space and cover drag. OS and driver caches uncontrolled."}
	if _require(viewport != null and not initial.pages_ready and not initial.print_ready
			and is_zero_approx(initial.opening) and player.held_stock_body() == book,
			"first use begins with the original closed binding and no page or print preparation"):
		var previous_msaa := viewport.msaa_3d
		viewport.msaa_3d = get_tree().root.msaa_3d
		var started := Time.get_ticks_usec()
		player._unhandled_input(space)
		observation.space_dispatch_us = Time.get_ticks_usec() - started
		var end := started + 6000000
		while player.inspecting() and book.is_physics_processing() and Time.get_ticks_usec() < end:
			await get_tree().physics_frame
		observation.first_supported_view_us = Time.get_ticks_usec() - started
		observation.print_ready_at_first_supported_view = book._print_ready
		var opened := await _installed_reading(book, true)
		installed_reading.completed = opened
		viewport.msaa_3d = previous_msaa
		observation.reading = installed_reading
		observation.print_preparation_ms = book.get_meta("print_preparation_ms", -1.)
		observation.print_preparation_max_slice_ms = book.get_meta("print_preparation_max_slice_ms", -1.)
		observation.print_preparation_latency_ms = book.get_meta("print_preparation_latency_ms", -1.)
		if _require(opened and observation.print_preparation_ms >= 0.,
				"first supported use opens the actual cover and retains the prepared printed spread"):
			_require(not player._grab.active() and not book._held, "first-use exit sets down the original binding")
	if player.inspecting():
		player.end_inspection()
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("nook_cold_first_use.json"), FileAccess.WRITE)
	if _require(file != null, "first-use report opens"):
		observation.failures = failures
		file.store_string(JSON.stringify(observation, "\t", true, true))
		file.close()
	return true


# One opt-in installed sample. Original closed optics and the independent save
# driver keep their existing paths and contract boundaries.
func _installed_reading(book: Node3D, already_inspecting := false) -> bool:
	var viewport := get_viewport() as SubViewport
	var camera: Camera3D = player.camera
	var held_fov: float = player._inspect_camera_fov if already_inspecting else camera.fov
	var held_camera: Transform3D = player._inspect_camera_pose if already_inspecting else camera.transform
	var matched_msaa: Viewport.MSAA = get_tree().root.msaa_3d
	installed_reading = {"attempted":true, "completed":false, "book":_identity(book),
		"binding_style":book.construction.get("opening_style"), "timing":[], "frames":[],
		"timing_scope":"First observed physical opening and same-book repeat in this session; per-motion input dispatch and paced hinge elapsed times exclude PNG work. No cold launch or performance claim."}
	var same_owner: bool = player.inspect_owner == book.shelf if already_inspecting else player.held_stock_body() == book
	if not _require(viewport != null and viewport.msaa_3d == matched_msaa and matched_msaa == Viewport.MSAA_8X
			and same_owner and player.lamp_is_enabled() and is_zero_approx(book.opening),
			"installed reading starts with same closed book, default powered lamp and matched 8x MSAA"):
		return false
	if not already_inspecting:
		await _two_style_space()
		for frame in 110:
			await get_tree().physics_frame
	if not _require(player.inspecting() and player.inspect_owner == book.shelf and book.shelf.supports_inspected_stock(book)
			and not player._grab.active() and not book.is_physics_processing() and is_equal_approx(camera.fov, 40.),
			"normal Space settles the same binding at 40 degrees"):
		return false
	var original: Dictionary
	if already_inspecting:
		# The cold path has no earlier image. Bind these owners before the
		# first physical cover input, without reading back a warm control.
		var carrier: Node3D = player.carried_device
		var device: Node = carrier.device
		original = {"camera_identity":_identity(camera), "lamp":{"identity":_identity(player.flashlight)},
			"carrier":{"identity":_identity(carrier), "device_identity":_identity(device),
				"native_lens_identity":_identity(device.teletype.torch_lens)}}
	else:
		original = optics[1] # Closed same-book returned_hand.
	var contact: Vector3 = book.left.to_global(Vector3(float(book.construction.width) * .7,
		float(book.construction.height) * .7, float(book.construction.thickness) * .5))
	if not _require(await _two_style_cursor(contact), "installed reading reaches the actual free cover cursor"):
		return false
	var cover: Dictionary = player._grab.find_target()
	installed_reading.cover_ray = {"part":_identity(cover.get("part") as Node), "kind":cover.get("kind", ""),
		"requested_point":var_to_str(contact), "cursor":var_to_str(viewport.get_mouse_position())}
	if not _require(cover.get("part") == book.left and cover.get("kind") == "hinge",
			"first actual cover ray resolves the same binding hinge"):
		return false
	_click_library()
	if not _require(player._grab.active() and player._grab.target.get("part") == book.left,
			"actual primary grips the same binding cover"):
		return false
	for leg: Array in [["first_open", PI], ["close", 0.], ["repeat_open", PI]]:
		var sample: Dictionary = {"phase":leg[0], "start_angle":book.opening, "goal_angle":leg[1],
			"print_ready_before":book._print_ready, "pages_ready_before":book._pages_ready, "dispatch_us":[]}
		installed_reading.timing.append(sample)
		var started := Time.get_ticks_usec()
		var completed: bool = await _two_style_hinge(float(leg[1]), sample)
		sample.elapsed_us = Time.get_ticks_usec() - started
		sample.end_angle = book.opening
		sample.print_ready_after = book._print_ready
		sample.pages_ready_after = book._pages_ready
		if not _require(completed and not sample.dispatch_us.is_empty()
				and absf(float(sample.end_angle) - float(leg[1])) < .00001,
				"installed cover mouse motion reaches " + str(leg[0])):
			installed_reading.cover_blocked = book._cover_blocked
			installed_reading.last_body_motion = _two_style_withdrawal_state(book).body_hit
			return false
	var before_fit: Transform3D = book.global_transform
	var eye_before_fit: Transform3D = camera.global_transform
	var projection_before:=_reading_hull_projection(book)
	_click_library()
	installed_reading.fit_motion={"before":_reading_fit_motion(book,camera),"samples":[]}
	if not _require(not player._grab.active() and player.inspecting() and book._print_ready
			and book._sheets.size() == 2, "next primary releases opened binding with two printed pages"):
		return false
	for frame in 120:
		if not book.is_physics_processing():
			break
		await get_tree().physics_frame
		if frame in [0,1,2,5,15,35,59,119]:
			installed_reading.fit_motion.samples.append(_reading_fit_motion(book,camera))
	await RenderingServer.frame_post_draw
	installed_reading.fit_motion.after=_reading_fit_motion(book,camera)
	var projection_after:=_reading_hull_projection(book)
	installed_reading.fit_projection={"before":projection_before,"after":projection_after}
	if not _require(not book.is_physics_processing() and camera.global_position.is_equal_approx(eye_before_fit.origin)
			and camera.global_position.distance_to(book.global_position) + .05
				< camera.global_position.distance_to(before_fit.origin),
			"open binding settles toward the fixed eye before optical fitting"):
		return false
	var area_before: float=projection_before.get("projected_width_px",0.)*projection_before.get("projected_height_px",0.)
	var area_after: float=projection_after.get("projected_width_px",0.)*projection_after.get("projected_height_px",0.)
	if not _require(area_before>0. and area_after>area_before and not bool(projection_after.get("frame_clipped",true)),
			"centred reading fit increases projected book area while keeping the complete binding in view"):
		return false
	var default_fov:=camera.fov
	var default_bounds: Array=projection_after.projected_bounds_px
	var default_size:=viewport.get_visible_rect().size
	var default_margin:=minf(minf(float(default_bounds[0]),float(default_bounds[1])),
		minf(default_size.x-float(default_bounds[2]),default_size.y-float(default_bounds[3])))
	installed_reading.default_fit={"fov":default_fov,"projection":projection_after,"minimum_margin_px":default_margin}
	if not _require(default_margin>=minf(default_size.x,default_size.y)*.05 and not player._inspect_manual_zoom,
			"automatic optical fit keeps the complete binding inside a screen margin"):
		return false
	if not await _installed_reading_frame("installed_reading_default",book,default_fov,matched_msaa,original):
		return false
	if _compact_paperback:
		for pixels: Vector2i in [Vector2i(960,600),COMPACT_PIXELS]:
			await _resize_reading_view(book,pixels)
			var resized:=_reading_hull_projection(book)
			if not _require(not bool(resized.get("frame_clipped",true)) and not book._optical_fit_pending
					and camera.global_position.is_equal_approx(eye_before_fit.origin) and not player._inspect_manual_zoom,
					"resize refits the complete binding before manual zoom"):
				return false
	if not _require(await _two_style_cursor(camera.global_position-camera.global_basis.z),
			"free cursor reaches centre for the original zoom controls"):
		return false
	var baseline_wheel:=InputEventMouseButton.new()
	baseline_wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if camera.fov<40. else MOUSE_BUTTON_WHEEL_UP
	baseline_wheel.pressed=true
	baseline_wheel.factor=absf(camera.fov-40.)*.5
	player._unhandled_input(baseline_wheel)
	var reading_pose: Transform3D = book.global_transform
	var reading_eye: Vector3 = camera.global_position
	var reading_basis: Basis = camera.global_basis
	if not await _installed_reading_frame("installed_reading_40", book, 40., matched_msaa, original):
		return false
	var companion: Node3D=player.carried_device
	var shoulder: Vector3=camera.to_local(companion.rig.to_global(companion.screen_frame.stock_bounds.get_center()))
	installed_reading.shoulder_center_from_eye=var_to_str(shoulder)
	if not _require(absf(shoulder.x)>.40 and shoulder.y>.05 and shoulder.z>-.04
			and companion.inspected_readable_stock()==book,
			"same companion reaches a shoulder station and tracks the inspected book"):
		return false
	var reading_aim: Dictionary=installed_reading.frames.back().reading_aim
	if not _require(not book._held and bool(reading_aim.diagnostic_query_issued)
			and bool(reading_aim.get("target_valid",false)),
			"released inspection keeps a native page target for the shoulder lamp"):
		return false
	if not _require(await _two_style_cursor(camera.global_position - camera.global_basis.z),
			"detached reading cursor reaches camera centre"):
		return false
	_installed_reading_wheel(MOUSE_BUTTON_WHEEL_UP)
	if not await _installed_reading_frame("installed_reading_24", book, 24., matched_msaa, original):
		return false
	if not await _optics_lamp_power(false, "installed_reading_lamp_off"):
		return false
	if not await _installed_reading_frame("installed_reading_24_off", book, 24., matched_msaa, original, false):
		return false
	if not await _optics_lamp_power(true, "installed_reading_lamp_restored"):
		return false
	if not await _installed_reading_frame("installed_reading_24_restored", book, 24., matched_msaa, original):
		return false
	_installed_reading_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	if not await _installed_reading_frame("installed_reading_40_return", book, 40., matched_msaa, original):
		return false
	if not _require(player.inspecting() and camera.global_position.is_equal_approx(reading_eye)
			and camera.global_basis.is_equal_approx(reading_basis) and book.global_transform.is_equal_approx(reading_pose),
			"centred 40/24/40 preserves floating pose and physical eye"):
		return false

	# Exercise an actual off-centre anchor as well as the exact-centre baseline.
	var pixel: Vector2 = viewport.get_visible_rect().size * Vector2(.55, .5)
	var pointer_point: Vector3 = camera.project_position(pixel, .8)
	if not _require(await _two_style_cursor(pointer_point), "detached reading cursor reaches off-centre witness"):
		return false
	pixel = viewport.get_mouse_position()
	var pointer_ray: Vector3 = camera.project_ray_normal(pixel)
	_installed_reading_wheel(MOUSE_BUTTON_WHEEL_UP)
	if not await _installed_reading_frame("installed_reading_24_off_centre", book, 24., matched_msaa, original):
		return false
	if not _require(camera.global_position.is_equal_approx(reading_eye) and book.global_transform.is_equal_approx(reading_pose)
			and camera.project_ray_normal(pixel).distance_to(pointer_ray) < .0001
			and not camera.global_basis.is_equal_approx(reading_basis),
			"off-centre wheel preserves its real world ray and changes the view basis"):
		return false
	_installed_reading_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	if not _require(is_equal_approx(camera.fov, 40.) and camera.project_ray_normal(pixel).distance_to(pointer_ray) < .0001,
			"same off-centre cursor returns normally to entry FOV"):
		return false
	if _compact_paperback:
		var manual_pose:=camera.global_transform
		var manual_fov:=camera.fov
		for pixels: Vector2i in [Vector2i(960,600),COMPACT_PIXELS]:
			await _resize_reading_view(book,pixels)
			if not _require(player._inspect_manual_zoom and camera.global_transform.is_equal_approx(manual_pose)
					and is_equal_approx(camera.fov,manual_fov),"resize preserves the player's chosen zoom and viewing axis"):
				return false

	var pickup_pose: Transform3D=book._reading_pickup_pose
	var pickup_slot: int=book._reading_pickup_slot
	var pickup_angle: float=book._reading_pickup_opening
	var blocker: StaticBody3D
	if OS.get_environment("ORISON_BOOK_RETURN_OBSTRUCTED")=="1":
		blocker=StaticBody3D.new()
		blocker.name="BookPickupDestinationObstruction"
		var shape:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=Vector3(.024,.025,.024)
		shape.shape=box
		blocker.add_child(shape)
		add_child(blocker)
		var collection:=book.get_parent_node_3d()
		blocker.global_position=collection.to_global(pickup_pose*book.pickup_centre())
		await get_tree().physics_frame
		await get_tree().physics_frame
	var release_pose: Transform3D=book.global_transform
	var return_requested: bool=book.should_return_after_reading()
	installed_reading.return_attempt={
		"requested":return_requested,"source_pose":var_to_str(pickup_pose),
		"source_slot":pickup_slot,"source_opening":pickup_angle,
		"release_pose":var_to_str(release_pose),"preflight":_reading_return_preflight(book,pickup_slot,pickup_pose,pickup_angle)
	}
	await _two_style_space()
	var returned: bool=book.transform.is_equal_approx(pickup_pose) and book.shelf_slot==pickup_slot \
		and is_equal_approx(book.opening,pickup_angle)
	if pickup_slot>=0:
		returned=returned and book.freeze
		if is_zero_approx(pickup_angle):
			returned=returned and book._solids.size()==1 and book._solids[0]==book._closed_solid
	var released_nearby: bool=not returned and book.shelf_slot==-1 and not book.freeze \
		and release_pose.origin.distance_to(book.global_position)<.18
	var blocked_test:=is_instance_valid(blocker)
	if blocked_test: blocker.queue_free()
	installed_reading.return_attempt.merge({
		"returned":returned,"released_nearby":released_nearby,
		"actual_pose":var_to_str(book.transform),"actual_slot":book.shelf_slot,
		"actual_opening":book.opening,"frozen":book.freeze,"book_held":book._held,
		"grab_active":player._grab.active(),"inspecting":player.inspecting(),
		"actual_fov":camera.fov,"expected_fov":held_fov
	})
	if not _require(not player.inspecting() and not player._grab.active()
			and is_equal_approx(camera.fov, held_fov) and not book._held
			and camera.transform.origin.distance_to(held_camera.origin)<.005
			and camera.basis.get_rotation_quaternion().angle_to(held_camera.basis.get_rotation_quaternion())<.001
			and (released_nearby if blocked_test else returned),
			"blocked pickup leaves the same read copy to settle locally" if blocked_test
			else "normal Space puts the same read copy back at its pickup pose and restores FOV"):
		return false
	installed_reading.return_test_obstructed=blocked_test
	installed_reading.return_pose=var_to_str(book.transform)
	installed_reading.return_slot=book.shelf_slot
	for frame in 110:
		await get_tree().physics_frame
	if not _require(not companion.screen_frame._shoulder_center.is_finite()
			and companion.inspected_readable_stock()==null,
			"companion leaves the shoulder after actual reading exit"):
		return false
	var samples: Array = installed_reading.frames
	var reference: Vector3 = str_to_var(samples[0].carrier.native_aperture)
	var front_and_bounded := true
	for sample: Dictionary in samples:
		var aperture: Vector3 = str_to_var(sample.carrier.native_aperture)
		sample.aperture_travel_from_40_m = aperture.distance_to(reference)
		# Wide enough for normal carrier drift, below the 248 mm failed move.
		# These are physical witness bounds, independent of image readability.
		front_and_bounded = front_and_bounded and sample.aperture_front_of_book_m > .02 \
			and sample.aperture_travel_from_40_m < .10 \
			and is_equal_approx(float(sample.companion_crop_size_m), float(samples[0].companion_crop_size_m))
	return _require(front_and_bounded, "native aperture stays on the reading side within bounded travel and stable companion projection")

func _resize_reading_view(book: Node3D, pixels: Vector2i) -> void:
	(get_viewport() as SubViewport).size=pixels
	for frame in 120:
		await get_tree().physics_frame
		if not book.is_physics_processing() and (player._inspect_manual_zoom or not book._optical_fit_pending):
			break
	await RenderingServer.frame_post_draw


func _installed_reading_wheel(button: MouseButton) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = button
	wheel.pressed = true
	wheel.factor = 8.
	player._unhandled_input(wheel)

func _reading_fit_motion(book: Node3D, camera: Camera3D) -> Dictionary:
	var sample:=_two_style_withdrawal_state(book)
	var carrier: Node3D=player.carried_device
	sample["target_in_eye_frame"]=var_to_str(book._reading_target)
	sample["body_in_eye_frame"]=var_to_str(camera.to_local(book.global_position))
	sample["lamp_in_eye_frame"]=var_to_str(camera.to_local(player.flashlight.global_position))
	sample["carrier_centre_in_eye_frame"]=var_to_str(camera.to_local(
		carrier.rig.to_global(carrier.screen_frame.stock_bounds.get_center())))
	sample["fit_frames"]=book._floating_frames
	sample["fit_processing"]=book.is_physics_processing()
	sample["hand_tag"]=book._hand_tag
	return sample

func _reading_return_preflight(book: Node3D, slot: int, pickup_pose: Transform3D, angle: float) -> Dictionary:
	var collection:=book.get_parent_node_3d()
	var source: Transform3D=book.shelf.book_slots[slot] if slot>=0 else pickup_pose
	var destination:=collection.global_transform*source
	var groups: Dictionary=book.stock.posed_gatherings(book.stock_id,angle)
	var contacts:=groups.values()
	if slot>=0 and is_zero_approx(angle):
		contacts=[{"shape":book._closed_solid.shape,"pose":book._closed_solid.transform}]
	var result: Dictionary={"slot_free":slot<0 or book.shelf.book_slot_is_free(slot,book),
		"folded_start_contacts":[],"clear_through":[]}
	var space:=book.get_world_3d().direct_space_state
	for group: Dictionary in contacts:
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=group.shape
		query.exclude=book._query_exclusions()
		query.collision_mask=book.collision_mask
		query.transform=Transform3D(destination.basis,book.global_position)*group.pose
		for hit: Dictionary in space.intersect_shape(query,8):
			result.folded_start_contacts.append(_identity(hit.collider))
	var path: Array[Vector3]=[]
	if slot>=0: path.append(collection.to_global(book._reading_pickup_exit))
	path.append(destination.origin+Vector3.UP*.004)
	path.append(destination.origin)
	var prefix: Array[Vector3]=[]
	for point: Vector3 in path:
		prefix.append(point)
		result.clear_through.append({"goal":var_to_str(point),
			"clear":book._reading_return_is_clear(book.global_position,destination.basis,contacts,prefix)})
	result.clear_via_view_station=book._reading_return_via_view_station(destination.basis,contacts,path)
	return result

func _installed_reading_frame(phase: String, book: Node3D, fov: float, msaa: Viewport.MSAA,
		original: Dictionary, lamp_on := true) -> bool:
	for frame in 2:
		await RenderingServer.frame_post_draw
	var before := optics.size()
	var failed := failures.size()
	await _observe_book(phase, book)
	if not _require(optics.size() == before + 1, "installed reading uses original native capture: " + phase):
		return false
	var row: Dictionary = optics.pop_back()
	row.fov_deg = player.camera.fov
	row.viewport_msaa = get_viewport().msaa_3d
	var foreground_camera: Camera3D = player.carried_device.screen_frame.view_camera
	row.companion_crop_size_m = foreground_camera.size
	var aperture: Vector3 = str_to_var(row.carrier.native_aperture)
	row.aperture_front_of_book_m = (aperture - book.global_position).dot(book.global_basis.z.normalized())
	row.loaded_page_glyphs = []
	var sides: Dictionary = {}
	for printed: Dictionary in book._print_surfaces:
		var label := printed.node as Label3D
		if label == null or printed.side not in ["left", "right"]:
			continue
		var geometry: Dictionary = _optics_project(_optics_vertices(printed.mesh, label.global_transform))
		var visible: bool = label.is_visible_in_tree()
		row.loaded_page_glyphs.append({"identity":_identity(label), "side":printed.side,
			"expected_text":label.text, "visible":visible, "geometry":geometry})
		if visible and int(geometry.vertices) > 0:
			sides[printed.side] = true
	installed_reading.frames.append(row)
	return _require(failures.size() == failed and sides.size() == 2
		and is_equal_approx(float(row.fov_deg), fov) and int(row.viewport_msaa) == msaa
		and absf(book.opening - PI) < .00001 and player.lamp_is_enabled() == lamp_on
		and bool(row.lamp.logical_device_enabled) == lamp_on and bool(row.lamp.shadow_enabled)
		and row.book_identity == installed_reading.book and row.camera_identity == original.camera_identity
		and row.lamp.identity == original.lamp.identity and row.carrier.identity == original.carrier.identity
		and row.carrier.device_identity == original.carrier.device_identity
		and row.carrier.native_lens_identity == original.carrier.native_lens_identity,
		"installed reading captures same open binding and both loaded glyph sides: " + phase)

func _two_style_space() -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_SPACE;event.physical_keycode=KEY_SPACE;event.pressed=pressed
		player._unhandled_input(event)
		for frame in 3:await get_tree().physics_frame

func _two_style_cursor(point: Vector3) -> bool:
	var viewport: Viewport=get_viewport()
	if not viewport is SubViewport or player.camera.is_position_behind(point):return false
	var pixel: Vector2=player.camera.unproject_position(point).round()
	if not viewport.get_visible_rect().has_point(pixel):return false
	var event:=InputEventMouseMotion.new();event.position=pixel;event.global_position=pixel
	viewport.push_input(event,true)
	await get_tree().process_frame
	return viewport.get_mouse_position().distance_to(pixel)<.6

func _two_style_hinge(goal: float, timing: Dictionary = {}) -> bool:
	var stalled:=0
	for frame in 160:
		if not player._grab.active() or player._grab.target.get("kind")!="hinge":return false
		var target: Dictionary=player._grab.target
		var before: float=target.read.call()
		if absf(goal-before)<.00001:return true
		var point: Vector3=target.part.to_global(player._grab.contact)
		var axis: Vector3=target.frame.global_basis*Vector3(target.axis)
		var tangent: Vector3=axis.cross(point-target.part.global_position)
		if tangent.length()<float(target.get("minimum_lever",.025)):tangent=axis.cross(player.camera.global_basis.x)*.06
		var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		if screen.length()<24. and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:screen=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.)
		var event:=InputEventMouseMotion.new();event.relative=screen*clampf(goal-before,-.12,.12)
		if timing.is_empty():
			player._unhandled_input(event)
		else:
			var tick := Time.get_ticks_usec()
			player._unhandled_input(event)
			timing.dispatch_us.append(Time.get_ticks_usec() - tick)
		await get_tree().physics_frame
		stalled=stalled+1 if is_equal_approx(before,float(target.read.call())) else 0
		if stalled>8:return false
	return false

func _two_style_capture(phase: String,book: Node3D) -> bool:
	var carrier: Node3D=player.carried_device
	var lens: MeshInstance3D=carrier.device.teletype.torch_lens
	var aperture: Vector3=lens.to_global(lens.mesh.get_aabb().get_center())
	var target: Vector3=book.reading_light_target(aperture)
	if not _require(target.is_finite() and player.held_stock_body()==book,"actual held native profile target exists: "+phase):return false
	if phase.ends_with("open_held") and not _require(book.opening>=PI-.00001 and book._print_ready and book._sheets.size()==2,"real opened spread printing ready: "+phase):return false
	var before: int=optics.size();var failed: int=failures.size()
	await _observe_book(phase,book)
	if not _require(optics.size()==before+1,"native actual held frame saved: "+phase):return false
	var row: Dictionary=optics.pop_back() # Original four-phase list stays intact.
	row.binding_style=book.construction.get("opening_style","hardback")
	row.loaded_page_glyphs=[]
	if phase.ends_with("open_held"):
		for printed: Dictionary in book._print_surfaces:
			var node: Node3D=printed.node
			if node is not Label3D or printed.side not in ["left","right"]:continue
			row.loaded_page_glyphs.append({"identity":_identity(node),"side":printed.side,"expected_text":node.text,"visible":node.is_visible_in_tree(),"geometry":_optics_project(_optics_vertices(printed.mesh,node.global_transform))})
		_require(not row.loaded_page_glyphs.is_empty(),"actual opened printed-page glyph meshes observed: "+phase)
	two_style_controls.frames.append(row)
	return failures.size()==failed

func _two_style_withdrawal_state(book: Node3D) -> Dictionary:
	var motion: Dictionary=book._last_motion
	var wanted: Vector3=player.camera.global_transform*Vector3(.17,-.16,-.48)
	return {"book":_identity(book),"book_pose":var_to_str(book.global_transform),"player_pose":var_to_str(player.global_transform),"camera_pose":var_to_str(player.camera.global_transform),"hand_target":var_to_str(wanted),"hand_error_m":(book.global_transform*book.pickup_centre()).distance_to(wanted),"same_held_body":player.held_stock_body()==book,"pickup_lifted":book._pickup_lifted,"pickup_extracted":book._pickup_extracted,"pickup_lift_goal":var_to_str(book._pickup_lift_goal),"pickup_exit":var_to_str(book._pickup_exit),"hold_blocked":book._hold_blocked,"body_hit":{"present":not motion.is_empty(),"collider":_identity(motion.get("collider") as Node),"normal":var_to_str(motion.get("normal",Vector3.ZERO)),"point":var_to_str(motion.get("point",Vector3.ZERO)),"unresolved_native_impact":bool(motion.get("unresolved_native_impact",false))},"physics_frame":Engine.get_physics_frames()}
