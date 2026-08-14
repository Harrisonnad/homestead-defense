extends StaticBody3D
class_name Bridge

# Water tiles got real collision this session (fixing a walk-on-water
# visual bug), which as a side effect made water fully impassable with no
# way back across (#28). Bridge is the fix: placeable only on water tiles
# (see PlacementGrid.check_placement()'s "bridge" category branch), and on
# completion permanently clears the water collision under its footprint
# (MapBuilder.open_water_crossing()) so Villagers/Enemies/Dogs can cross.
#
# Deliberately NOT built on the generic Building base class: collision
# layer 2 is what makes a structure both attackable AND movement-blocking
# in this codebase (see building.gd/wall.gd) - a bridge can't have the
# first without the second, so this has zero collision of its own
# (collision_layer/mask = 0 in the scene) and can't be attacked or
# destroyed. footprint_origin/footprint_size/placement_grid mirror
# Building's fields since construction_site.gd's _on_complete() assigns
# them on every building type generically, regardless of base class.

var footprint_origin: Vector2i
var footprint_size: Vector2i = Vector2i(1, 1)
var placement_grid: PlacementGrid

func on_footprint_ready() -> void:
	var map_builder := get_tree().get_first_node_in_group("map_builder")
	if map_builder:
		map_builder.open_water_crossing(footprint_origin, footprint_size)
