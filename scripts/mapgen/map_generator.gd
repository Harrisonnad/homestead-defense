extends RefCounted
class_name MapGenerator

## Orchestrates the generation pipeline for a single session map.
## Usage:
##   var gen := MapGenerator.new()
##   var result := gen.generate(theme_resource, session_seed)
## Deterministic: same theme + same seed => same map.

signal generation_failed(reason: String)

var theme: MapTheme
var seed_value: int
var rng := RandomNumberGenerator.new()

var elevation_noise := FastNoiseLite.new()
var moisture_noise := FastNoiseLite.new()

var map_size: Vector2i = Vector2i(64, 64)

func generate(p_theme: MapTheme, p_seed: int) -> Dictionary:
	theme = p_theme
	seed_value = p_seed

	for attempt in range(theme.max_regen_attempts):
		var candidate_seed := seed_value + attempt
		var map_data := _generate_pass(candidate_seed)

		var validation := MapValidator.validate(map_data, theme)
		if validation.passed:
			map_data["seed_used"] = candidate_seed
			map_data["theme_name"] = theme.theme_name
			return map_data
		else:
			push_warning("Map attempt %d failed: %s" % [attempt, validation.reason])

	generation_failed.emit("Exceeded max_regen_attempts for theme %s" % theme.theme_name)
	return _fallback_map()

func _generate_pass(p_seed: int) -> Dictionary:
	rng.seed = p_seed
	_configure_noise(p_seed)

	var elevation := _generate_elevation()
	var moisture := _generate_moisture()
	var biomes := _assign_biomes(elevation, moisture)
	var resources := _place_resources(biomes)
	var crop_plots := _place_crop_plots(biomes)
	var chokepoints := _identify_chokepoints(elevation, biomes)
	var animal_zones := _place_animal_zones(biomes, crop_plots)
	var props := _scatter_props(biomes)

	return {
		"elevation": elevation,
		"moisture": moisture,
		"biomes": biomes,
		"resources": resources,
		"crop_plots": crop_plots,
		"chokepoints": chokepoints,
		"animal_zones": animal_zones,
		"props": props,
		"size": map_size,
	}

func _configure_noise(p_seed: int) -> void:
	elevation_noise.seed = p_seed
	elevation_noise.frequency = theme.noise_frequency
	elevation_noise.fractal_octaves = theme.noise_octaves

	moisture_noise.seed = p_seed + 1000
	moisture_noise.frequency = theme.moisture_frequency

func _generate_elevation() -> Array:
	var out := []
	for y in range(map_size.y):
		var row := []
		for x in range(map_size.x):
			var n := elevation_noise.get_noise_2d(x, y) # -1..1
			var h := remap(n, -1.0, 1.0, theme.elevation_amplitude.x, theme.elevation_amplitude.y)
			row.append(h)
		out.append(row)
	return out

func _generate_moisture() -> Array:
	var out := []
	for y in range(map_size.y):
		var row := []
		for x in range(map_size.x):
			row.append(moisture_noise.get_noise_2d(x, y))
		out.append(row)
	return out

func _assign_biomes(elevation: Array, moisture: Array) -> Array:
	# Biome weights are treated as target area shares, converted into
	# thresholds against the actual elevation/moisture distributions
	# (quantiles, so shares hold regardless of the noise's value spread):
	# water floods the lowest-elevation share, rock caps the highest,
	# dirt takes the most-moist share of the remaining land, grass the rest.
	# Thresholding keeps features contiguous - rivers along the valley
	# floor and rocky valley walls instead of per-tile scatter.
	var total_weight := 0.0
	for w in theme.biome_weights.values():
		total_weight += w

	var water_share: float = theme.biome_weights.get("water", 0.0) / total_weight
	var rock_share: float = theme.biome_weights.get("rock", 0.0) / total_weight
	var land_weight: float = theme.biome_weights.get("grass", 1.0) + theme.biome_weights.get("dirt", 0.0)
	var dirt_share_of_land: float = theme.biome_weights.get("dirt", 0.0) / land_weight if land_weight > 0.0 else 0.0

	var waterline := _quantile(elevation, water_share)
	var rockline := _quantile(elevation, 1.0 - rock_share)
	var dirt_moisture_line := _quantile(moisture, 1.0 - dirt_share_of_land)

	var out := []
	for y in range(map_size.y):
		var row := []
		for x in range(map_size.x):
			var h: float = elevation[y][x]
			if h <= waterline:
				row.append("water")
			elif h >= rockline:
				row.append("rock")
			elif moisture[y][x] >= dirt_moisture_line:
				row.append("dirt")
			else:
				row.append("grass")
		out.append(row)
	return out

func _quantile(grid: Array, share: float) -> float:
	if share <= 0.0:
		return -INF
	var values := []
	for row in grid:
		values.append_array(row)
	values.sort()
	var idx := clampi(int(share * values.size()), 0, values.size() - 1)
	return values[idx]

func _place_resources(biomes: Array) -> Array:
	var nodes := []
	var density := rng.randf_range(theme.resource_node_density.x, theme.resource_node_density.y)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if biomes[y][x] in ["grass", "dirt"] and rng.randf() < density:
				nodes.append(Vector2i(x, y))
	return nodes

func _place_crop_plots(biomes: Array) -> Array:
	var plots := []
	var density := rng.randf_range(theme.crop_plot_density.x, theme.crop_plot_density.y)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if biomes[y][x] == "dirt" and rng.randf() < density:
				plots.append(Vector2i(x, y))
	return plots

func _identify_chokepoints(_elevation: Array, biomes: Array) -> Array:
	# Scan for walkable tiles pinched between non-walkable (rock/water)
	# neighbors. Replace with real pathing analysis when movement blocking
	# lands (navmesh follow-up).
	var chokepoints := []
	for y in range(1, map_size.y - 1):
		for x in range(1, map_size.x - 1):
			if biomes[y][x] in ["grass", "dirt"]:
				var blocked_neighbors := 0
				for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nb: Vector2i = Vector2i(x, y) + offset
					if biomes[nb.y][nb.x] in ["rock", "water"]:
						blocked_neighbors += 1
				if blocked_neighbors >= 2 and rng.randf() < theme.chokepoint_bias:
					chokepoints.append(Vector2i(x, y))
	return chokepoints

func _place_animal_zones(biomes: Array, crop_plots: Array) -> Array:
	var zones := []
	var crop_set := {}
	for p in crop_plots:
		crop_set[p] = true

	for y in range(map_size.y):
		for x in range(map_size.x):
			var pos := Vector2i(x, y)
			if biomes[y][x] == "grass" and not crop_set.has(pos) and rng.randf() < 0.01:
				zones.append(pos)
	return zones

func _scatter_props(biomes: Array) -> Array:
	var props := []
	if theme.prop_scenes.is_empty():
		return props
	for y in range(map_size.y):
		for x in range(map_size.x):
			if biomes[y][x] != "water" and rng.randf() < theme.prop_density:
				var scene := theme.prop_scenes[rng.randi_range(0, theme.prop_scenes.size() - 1)]
				props.append({"pos": Vector2i(x, y), "scene": scene})
	return props

func _fallback_map() -> Dictionary:
	# Last resort: one unvalidated pass with the theme's pre-verified
	# fallback seed, so the session always gets a playable map.
	push_error("Falling back to fallback_seed %d for theme: %s" % [theme.fallback_seed, theme.theme_name])
	var map_data := _generate_pass(theme.fallback_seed)
	map_data["seed_used"] = theme.fallback_seed
	map_data["theme_name"] = theme.theme_name
	return map_data
