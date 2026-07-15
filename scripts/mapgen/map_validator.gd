extends Object
class_name MapValidator

## Stateless validation pass. Returns {passed: bool, reason: String}.
## Add/remove checks here as your playability rules evolve —
## this is the single source of truth for "is this map fair."

static func validate(map_data: Dictionary, theme: MapTheme) -> Dictionary:
	if map_data.is_empty():
		return {"passed": false, "reason": "empty map data"}

	var biomes: Array = map_data["biomes"]

	var core_check := _check_buildable_core(biomes, theme.min_buildable_core_tiles)
	if not core_check.passed:
		return core_check

	var water_check := _check_water_present(biomes)
	if not water_check.passed:
		return water_check

	var chokepoint_check := _check_chokepoints(map_data["chokepoints"], theme.min_chokepoints)
	if not chokepoint_check.passed:
		return chokepoint_check

	var overlap_check := _check_no_zone_overlap(map_data["animal_zones"], map_data["crop_plots"])
	if not overlap_check.passed:
		return overlap_check

	return {"passed": true, "reason": ""}

static func find_buildable_center(biomes: Array) -> Vector2i:
	# The tile the buildable-core flood fill starts from: map center, nudged
	# to the nearest buildable tile in a small radius. Shared with MapBuilder
	# so the homestead is guaranteed to sit inside the validated core.
	var height := biomes.size()
	var width: int = biomes[0].size()
	var start := Vector2i(width / 2, height / 2)

	if biomes[start.y][start.x] in ["grass", "dirt"]:
		return start
	for r in range(1, 5):
		for offset in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			var p: Vector2i = start + offset
			if p.x >= 0 and p.x < width and p.y >= 0 and p.y < height:
				if biomes[p.y][p.x] in ["grass", "dirt"]:
					return p
	return Vector2i(-1, -1)

static func _check_buildable_core(biomes: Array, min_tiles: int) -> Dictionary:
	# Flood-fill from center to find contiguous buildable area.
	var height := biomes.size()
	var width: int = biomes[0].size()
	var start := find_buildable_center(biomes)
	if start == Vector2i(-1, -1):
		return {"passed": false, "reason": "no buildable tile near map center"}

	var visited := {}
	var stack := [start]
	var count := 0
	while not stack.is_empty():
		var pos: Vector2i = stack.pop_back()
		if visited.has(pos):
			continue
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			continue
		if biomes[pos.y][pos.x] not in ["grass", "dirt"]:
			continue
		visited[pos] = true
		count += 1
		stack.append(pos + Vector2i(1, 0))
		stack.append(pos + Vector2i(-1, 0))
		stack.append(pos + Vector2i(0, 1))
		stack.append(pos + Vector2i(0, -1))

	if count < min_tiles:
		return {"passed": false, "reason": "buildable core too small (%d < %d)" % [count, min_tiles]}
	return {"passed": true, "reason": ""}

static func _check_water_present(biomes: Array) -> Dictionary:
	for row in biomes:
		if "water" in row:
			return {"passed": true, "reason": ""}
	return {"passed": false, "reason": "no water tile present"}

static func _check_chokepoints(chokepoints: Array, min_count: int) -> Dictionary:
	if chokepoints.size() < min_count:
		return {"passed": false, "reason": "not enough chokepoints (%d < %d)" % [chokepoints.size(), min_count]}
	return {"passed": true, "reason": ""}

static func _check_no_zone_overlap(animal_zones: Array, crop_plots: Array) -> Dictionary:
	var crop_set := {}
	for p in crop_plots:
		crop_set[p] = true
	for a in animal_zones:
		if crop_set.has(a):
			return {"passed": false, "reason": "animal zone overlaps crop plot at %s" % str(a)}
	return {"passed": true, "reason": ""}
