extends Enemy
class_name Locust

# Summer's seasonal identity (master spec §5.7): reshapes what's being
# defended from "the Homestead" to "your fields" - targets the nearest
# non-empty Farm Plot instead of the Homestead, and eats it (destroyed, no
# resource payout - see FarmPlot.get_eaten()) instead of the generic
# raid-loss/homestead-damage path every other enemy uses. Falls back to
# Enemy's normal Homestead-targeting/raiding if no Farm Plot exists (e.g.
# an early map with nothing planted yet).
#
# flee_on_damage is set true on this scene (see locust_enemy.tscn) - any
# hit sends it fleeing rather than fighting, and a Scarecrow's scan only
# ever targets flee_on_damage enemies, so Locusts are the one enemy type a
# Scarecrow actually deters.

func set_initial_target(default_target: Node3D) -> void:
	var plot := _find_nearest_farm_plot()
	target = plot if plot != null else default_target

func _find_nearest_farm_plot() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for plot in get_tree().get_nodes_in_group("farm_plots"):
		if plot.is_empty():
			continue
		var dist := global_position.distance_to(plot.global_position)
		if dist < best_dist:
			best_dist = dist
			best = plot
	return best

func _reach_target() -> void:
	if target != null and target.has_method("get_eaten"):
		if not target.is_empty():
			target.get_eaten()
			NightReport.on_resource_lost("crops", 1)
		queue_free()
		return
	super._reach_target()
