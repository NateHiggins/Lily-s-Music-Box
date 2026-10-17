extends Node3D
class Electrical extends RefCounted:
 var stations: Dictionary = {}
 var installed: Array = []
var adapter: Dictionary
func _ready() -> void:
 adapter = {"root":self}
 var electrical = Electrical.new()
 for level in range(1,7):
  var station = StaticBody3D.new()
  station.name = "F%02d_ELECTRICAL_JUNCTION" % level
  add_child(station)
  for label in ["JunctionCover","JunctionCasting"]:
   var draw = MeshInstance3D.new()
   draw.name = label; draw.mesh = BoxMesh.new(); station.add_child(draw)
   electrical.installed.append(draw)
  var collision = CollisionShape3D.new()
  collision.shape = BoxShape3D.new(); station.add_child(collision)
  electrical.stations[str(station.name)] = weakref(station)
 var supply = preload("res://scripts/building/orison_v2_front_lighting_supply.gd").new()
 var ok = supply.mount(self,electrical)
 var count = 0
 for group in supply.instance_groups: count += group.multimesh.instance_count
 ok = ok and supply.installed.size()==18 and supply.instance_groups.size()==12 and count==407 and supply.replaced_covers.size()==6
 print("FRONT SUPPLY IMPORT: ",supply.installed.size()," fixed batches; ",supply.instance_groups.size()," groups; ",count," supports; errors=",supply.errors)
 print("PASS: isolated production supply adapter" if ok else "FAIL: isolated production supply adapter")
 supply.finish()
 get_tree().quit(0 if ok else 1)
