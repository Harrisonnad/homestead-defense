extends Enemy
class_name Wolf

# Winter's seasonal identity (master spec §5.7): reshapes what's being
# defended from "the Homestead" to "your livestock" - targets the nearest
# Animal Pen instead of the Homestead, and damages that structure directly
# on arrival instead of the generic raid-loss/homestead-damage path. Falls
# back to Enemy's normal Homestead-targeting/raiding if no Animal Pen
# exists yet. Along the way it'll naturally engage a Dog/Goat/Sheep (or the
# pen itself) via Enemy's existing generic AttackRange targeting if one
# gets in its path first - no extra code needed for that part.

@export var pen_raid_damage: int = 20

func set_initial_target(default_target: Node3D) -> void:
	var pen := _find_nearest_animal_pen()
	target = pen if pen != null else default_target

func _find_nearest_animal_pen() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for building in get_tree().get_nodes_in_group("buildings"):
		if building is AnimalPen:
			var dist := global_position.distance_to(building.global_position)
			if dist < best_dist:
				best_dist = dist
				best = building
	return best

func _reach_target() -> void:
	if target != null and target is AnimalPen:
		target.take_damage(pen_raid_damage)
		queue_free()
		return
	super._reach_target()
