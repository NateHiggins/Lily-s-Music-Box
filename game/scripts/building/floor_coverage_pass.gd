class_name FloorCoveragePass
extends RefCounted
## SUPERSEDED 2026-08-21 by SurfacePass (the floors class carries these same
## rules as COVERAGE_RULES inside the layered surface). Kept as the reference
## implementation of M-COVER and for the probe harness; BuildingRoot no
## longer applies it.
##
## M-COVER in production (owner ruling 2026-08-21). At build, every floor
## set's shipping StandardMaterial3D is replaced on the `*_floors_*` surfaces
## by `floor_coverage.gdshader` carrying the SAME maps and scalars plus the
## anti-repetition rule that suits the set's structure:
##
##   terrazzo*   cell-snapped hex  (dividers stay on their lattice, aggregate shuffled)
##   floor_oak*  board-row offsets (board edges exact, joint line gone)
##   ceramic*    hex               (hex mosaic is a field; nothing to keep)
##   concrete*   hex               (field)
##
## One ShaderMaterial per shipping material, cached, so the surface count and
## the draw count do not change; no texture is added. Frames and costs that
## chose the rules: art/renders/material_coverage_m/README.md. Setting
## `FLOOR_COVERAGE=0` in the environment leaves the shipping materials in
## place, which is the A of every A/B.

const SHADER := preload("res://shaders/floor_coverage.gdshader")

## Per-set rule, keyed by the substring of the albedo texture file name.
## `cells` is the divider grid per tile, counted on the albedo
## (terrazzo, _b, _d: 3 x 3; _c: 2 x 2). Oak maps have their seams along V
## (29 dark column bands, 3 row bands), so rows step across U.
const RULES := {
	"terrazzo_b": {"coverage": 2, "cells": 3.0},
	"terrazzo_c": {"coverage": 2, "cells": 2.0},
	"terrazzo_d": {"coverage": 2, "cells": 3.0},
	"terrazzo": {"coverage": 2, "cells": 3.0},
	"floor_oak": {"coverage": 3, "rows": 14.0, "grain_along_u": false},
	"ceramic": {"coverage": 1, "hex_scale": 1.0},
	"concrete": {"coverage": 1, "hex_scale": 1.0},
}

var swapped := 0
var surfaces := 0
var _cache := {}


## Returns the number of surfaces swapped. Idempotent per surface.
func apply(floor_nodes: Dictionary) -> int:
	if OS.get_environment("FLOOR_COVERAGE") == "0":
		return 0
	for fid in floor_nodes:
		var floor_node: Node = floor_nodes[fid]
		for node in floor_node.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or not mi.name.contains("_floors_"):
				continue
			for s in mi.mesh.get_surface_count():
				surfaces += 1
				var original := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if original == null or original.albedo_texture == null:
					continue
				var rule := _rule_for(original.albedo_texture.resource_path)
				if rule.is_empty():
					continue
				mi.set_surface_override_material(s, _material_for(original, rule))
				swapped += 1
	print("[FLOOR COVERAGE] %d of %d floor surfaces re-covered (%d materials)"
			% [swapped, surfaces, _cache.size()])
	return swapped


static func _rule_for(texture_path: String) -> Dictionary:
	var file := texture_path.get_file()
	# Longest key first so "terrazzo_b" wins over "terrazzo".
	var keys: Array = RULES.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for key in keys:
		if file.contains("_%s_" % key):
			return RULES[key]
	return {}


func _material_for(original: BaseMaterial3D, rule: Dictionary) -> ShaderMaterial:
	var key := original.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("coverage", int(rule.coverage))
	m.set_shader_parameter("albedo_tex", original.albedo_texture)
	m.set_shader_parameter("albedo_color", original.albedo_color)
	if original.normal_texture != null:
		m.set_shader_parameter("normal_tex", original.normal_texture)
		m.set_shader_parameter("normal_scale",
				original.normal_scale if original.normal_enabled else 0.0)
	else:
		m.set_shader_parameter("normal_scale", 0.0)
	if original.roughness_texture != null:
		m.set_shader_parameter("rough_tex", original.roughness_texture)
		m.set_shader_parameter("has_rough_tex", true)
	else:
		m.set_shader_parameter("has_rough_tex", false)
	m.set_shader_parameter("roughness_mul", original.roughness)
	m.set_shader_parameter("metallic", original.metallic)
	var stats := _texture_stats(original)
	m.set_shader_parameter("albedo_mean", stats.albedo_mean)
	m.set_shader_parameter("rough_mean", stats.rough_mean)
	if rule.has("cells"):
		m.set_shader_parameter("lattice_cells", float(rule.cells))
	if rule.has("rows"):
		m.set_shader_parameter("rows_per_tile", float(rule.rows))
		m.set_shader_parameter("grain_along_u", bool(rule.get("grain_along_u", true)))
	if rule.has("hex_scale"):
		m.set_shader_parameter("hex_scale", float(rule.hex_scale))
	_cache[key] = m
	return m


## Means of the albedo and roughness maps from a 32x32 resample — once per
## shipping material at build, a few hundred microseconds each.
static func _texture_stats(original: BaseMaterial3D) -> Dictionary:
	var out := {"albedo_mean": Vector3(0.5, 0.5, 0.5), "rough_mean": 0.5}
	var img := original.albedo_texture.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.resize(32, 32, Image.INTERPOLATE_BILINEAR)
		var sum := Vector3.ZERO
		for y in 32:
			for x in 32:
				var c := img.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b)
		out.albedo_mean = sum / 1024.0
	if original.roughness_texture != null:
		var rimg := original.roughness_texture.get_image()
		if rimg != null:
			if rimg.is_compressed():
				rimg.decompress()
			rimg.resize(32, 32, Image.INTERPOLATE_BILINEAR)
			var rsum := 0.0
			for y in 32:
				for x in 32:
					rsum += rimg.get_pixel(x, y).r
			out.rough_mean = rsum / 1024.0
	return out
