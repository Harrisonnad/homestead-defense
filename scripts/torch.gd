extends Building
class_name Torch

# A cheap, dedicated light source - unlike every other Building, whose
# NightLight glow (see building.gd/night_light.gd) is a side effect of
# being a structure, this exists purely to let players patch dark gaps
# between buildings/walls without paying for a full structure. Overrides
# the Building default light because sm_prop_spore_lantern is much smaller
# than a house or tower, so the light should sit low and close to the
# ground rather than at head height.

func _add_night_light() -> void:
	var light := OmniLight3D.new()
	light.set_script(NIGHT_LIGHT_SCRIPT)
	light.position = Vector3(0, 0.55, 0)
	light.night_energy = 1.6
	light.light_range = 7.0
	add_child(light)
