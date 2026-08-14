extends Node3D
class_name PackProp

# Thin wrapper for purely-decorative custom-pack meshes (map-scatter clutter
# with no gameplay hooks): applies the shared day/night material to every
# child mesh at _ready() so these scenes stay a flat list of glb instances
# with no per-scene material boilerplate.

const PACK_MATERIAL := preload("res://assets/custom_pack/day_night.tres")

func _ready() -> void:
	CharacterVisualUtils.apply_pack_material(self, PACK_MATERIAL)
