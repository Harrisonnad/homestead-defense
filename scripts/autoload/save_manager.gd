extends Node

# Autoload singleton: save/load for the state a player actually cares about
# (season progress, economy, upgrades, population, villagers, and every
# player-built structure). Deliberately does NOT preserve map-generated
# resource-node/farm-plot state or mid-raid enemies - see README for the
# exact v1 limitation. The map itself isn't saved tile-by-tile: MapGenerator
# is deterministic, so saving just the theme+seed reproduces identical
# terrain/tree/rock/farm-plot *positions* on load.

const SAVE_PATH := "user://savegame.json"

var pending_load: bool = false
var show_tutorial_prompt: bool = false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Reads just the seed out of the save file without applying the rest of it -
# MapBuilder needs this at its own _ready() time (before the deferred
# load_game() call that restores everything else runs) so the regenerated
# map actually matches the one the save was made on. See docs/architecture-
# decisions.md's "known pre-existing gap" - this is the fix for it.
func peek_saved_seed() -> int:
	if not has_save():
		return 0
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	return int(parsed.get("seed", 0))

func save_game() -> bool:
	var main := get_tree().current_scene
	var map_builder = main.get_node_or_null("MapBuilder")
	var entities = main.get_node_or_null("Entities")
	var homestead = main.get_node_or_null("Homestead")
	if map_builder == null or entities == null or homestead == null:
		return false

	var villagers := []
	for v in get_tree().get_nodes_in_group("villagers"):
		villagers.append({
			"position": _vec3_to_array(v.global_position),
			"role": int(v.role),
			"health": v.current_health,
		})

	var buildings := []
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if not is_instance_valid(b):
			continue
		var def_path: String = b.get_meta("building_def_path", "")
		if def_path == "":
			continue
		buildings.append({
			"def_path": def_path,
			"position": _vec3_to_array(b.global_position),
			"rotation_y": b.rotation.y,
			"health": b.current_health if "current_health" in b else -1,
			"footprint_origin": [b.footprint_origin.x, b.footprint_origin.y] if "footprint_origin" in b else [0, 0],
			"footprint_size": [b.footprint_size.x, b.footprint_size.y] if "footprint_size" in b else [1, 1],
		})

	var data := {
		"theme_path": map_builder.theme.resource_path,
		"seed": int(map_builder.map_data.get("seed_used", 0)),
		"day_count": GameClock.day_count,
		"time_of_day": GameClock.time_of_day,
		"resources": Economy.resources,
		"storage_caps": Economy.storage_caps,
		"purchased": Progression.purchased.keys(),
		"population_cap": GameState.population_cap,
		"homestead_health": homestead.current_health,
		"villagers": villagers,
		"buildings": buildings,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func load_game() -> void:
	if not has_save():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_apply(parsed)

func _apply(data: Dictionary) -> void:
	GameClock.day_count = int(data.get("day_count", 1))
	GameClock.time_of_day = float(data.get("time_of_day", 0.3))

	var saved_resources: Dictionary = data.get("resources", {})
	for type in saved_resources:
		Economy.resources[type] = int(saved_resources[type])
		Economy.resources_changed.emit(type, Economy.resources[type])
	# Storage-cap/population-cap bonuses come from restored buildings'
	# _ready() -> _apply_age() calls below, same as normal gameplay - reset
	# to base here instead of restoring the saved (already bonus-inclusive)
	# totals directly, or every restored House/Storehouse would double-apply
	# its bonus on top of the saved total.
	for type in Economy.storage_caps.keys():
		Economy.storage_caps[type] = Economy.BASE_STORAGE_CAP
		Economy.caps_changed.emit(type, Economy.storage_caps[type])

	Progression.load_state(data.get("purchased", []))
	AchievementManager.reset()
	GameState.population_cap = GameState.BASE_POPULATION_CAP
	GameState.population_cap_changed.emit(GameState.population_cap)

	var main := get_tree().current_scene
	var map_builder = main.get_node_or_null("MapBuilder")
	var entities = main.get_node_or_null("Entities")
	var homestead = main.get_node_or_null("Homestead")
	if map_builder == null or entities == null:
		return

	if homestead:
		homestead.current_health = int(data.get("homestead_health", homestead.max_health))
		homestead.health_changed.emit(homestead.current_health)

	for v in get_tree().get_nodes_in_group("villagers"):
		v.queue_free()
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if "placement_grid" in b and b.placement_grid and "footprint_origin" in b:
			b.placement_grid.release(b.footprint_origin, b.footprint_size)
		b.queue_free()

	var villager_scene: PackedScene = load("res://scenes/villager.tscn")
	for vdata in data.get("villagers", []):
		var v = villager_scene.instantiate()
		entities.add_child(v)
		v.global_position = _array_to_vec3(vdata["position"])
		v.set_role(int(vdata["role"]))
		v.current_health = int(vdata["health"])

	for bdata in data.get("buildings", []):
		var def_path: String = bdata.get("def_path", "")
		if def_path == "" or not ResourceLoader.exists(def_path):
			continue
		var def: BuildingDef = load(def_path)
		var b: Node3D = def.scene.instantiate()
		entities.add_child(b)
		b.global_position = _array_to_vec3(bdata["position"])
		b.rotation.y = float(bdata.get("rotation_y", 0.0))
		var origin_arr: Array = bdata.get("footprint_origin", [0, 0])
		var size_arr: Array = bdata.get("footprint_size", [1, 1])
		if "footprint_origin" in b:
			b.footprint_origin = Vector2i(int(origin_arr[0]), int(origin_arr[1]))
			b.footprint_size = Vector2i(int(size_arr[0]), int(size_arr[1]))
			b.placement_grid = map_builder.placement_grid
		# Mirrors construction_site.gd's _on_complete() - Bridge needs this to
		# reopen its water crossing, and can't do it from its own _ready()
		# since footprint_origin isn't set until the lines above run.
		if b.has_method("on_footprint_ready"):
			b.on_footprint_ready()
		var saved_health: int = int(bdata.get("health", -1))
		if "current_health" in b and saved_health >= 0:
			b.current_health = saved_health
		b.set_meta("building_def_path", def_path)
		b.add_to_group("player_buildings")
		AchievementManager.on_building_completed(b)
		if map_builder.placement_grid:
			map_builder.placement_grid.claim(b.footprint_origin, b.footprint_size)

func _vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _array_to_vec3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
