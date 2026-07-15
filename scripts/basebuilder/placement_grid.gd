extends RefCounted
class_name PlacementGrid

# Runtime, per-tile placement legality — the lightweight sibling of
# MapValidator's full-map validation (spec_base_builder.md: "reuse, don't
# duplicate"). Owned by MapBuilder, which seeds it with the generated map's
# biome grid and zone data, then keeps it updated as buildings are placed.

const BUILDABLE_BIOMES := ["grass", "dirt"]

var biomes: Array = []
var half_size: Vector2 = Vector2.ZERO
var crop_plot_tiles: Dictionary = {}
var animal_zone_tiles: Dictionary = {}
var chokepoint_tiles: Dictionary = {}
var occupied_tiles: Dictionary = {} # Vector2i -> true

func setup(map_data: Dictionary, p_half_size: Vector2) -> void:
	biomes = map_data["biomes"]
	half_size = p_half_size
	crop_plot_tiles.clear()
	for t in map_data["crop_plots"]:
		crop_plot_tiles[t] = true
	animal_zone_tiles.clear()
	for t in map_data["animal_zones"]:
		animal_zone_tiles[t] = true
	chokepoint_tiles.clear()
	for t in map_data["chokepoints"]:
		chokepoint_tiles[t] = true

func world_to_tile(world_pos: Vector3) -> Vector2i:
	return Vector2i(floori(world_pos.x + half_size.x), floori(world_pos.z + half_size.y))

func tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3(tile.x - half_size.x + 0.5, 0.0, tile.y - half_size.y + 0.5)

func footprint_tiles(origin: Vector2i, footprint_size: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dy in footprint_size.y:
		for dx in footprint_size.x:
			tiles.append(origin + Vector2i(dx, dy))
	return tiles

func in_bounds(tile: Vector2i) -> bool:
	return tile.y >= 0 and tile.y < biomes.size() and tile.x >= 0 and tile.x < biomes[0].size()

func is_buildable_biome(tile: Vector2i) -> bool:
	return in_bounds(tile) and biomes[tile.y][tile.x] in BUILDABLE_BIOMES

func is_chokepoint(tile: Vector2i) -> bool:
	return chokepoint_tiles.has(tile)

func zone_bonus_multiplier(tile: Vector2i, category: String) -> float:
	if category == "farm" and crop_plot_tiles.has(tile):
		return 1.25
	if category == "pen" and animal_zone_tiles.has(tile):
		return 1.5
	return 1.0

# Returns {ok: bool, reason: String, chokepoint: bool, bonus: float}
func check_placement(origin: Vector2i, footprint_size: Vector2i, category: String) -> Dictionary:
	var tiles := footprint_tiles(origin, footprint_size)
	var any_chokepoint := false
	var bonus := 1.0
	for tile in tiles:
		if not in_bounds(tile):
			return {"ok": false, "reason": "out of bounds", "chokepoint": false, "bonus": 1.0}
		if not is_buildable_biome(tile):
			return {"ok": false, "reason": "not buildable terrain", "chokepoint": false, "bonus": 1.0}
		if occupied_tiles.has(tile):
			return {"ok": false, "reason": "tile occupied", "chokepoint": false, "bonus": 1.0}
		if category not in ["farm", "pen"]:
			if crop_plot_tiles.has(tile):
				return {"ok": false, "reason": "reserved crop plot", "chokepoint": false, "bonus": 1.0}
			if animal_zone_tiles.has(tile):
				return {"ok": false, "reason": "reserved animal zone", "chokepoint": false, "bonus": 1.0}
		if is_chokepoint(tile):
			any_chokepoint = true
		bonus = maxf(bonus, zone_bonus_multiplier(tile, category))
	return {"ok": true, "reason": "", "chokepoint": any_chokepoint, "bonus": bonus}

func claim(origin: Vector2i, footprint_size: Vector2i) -> void:
	for tile in footprint_tiles(origin, footprint_size):
		occupied_tiles[tile] = true

func release(origin: Vector2i, footprint_size: Vector2i) -> void:
	for tile in footprint_tiles(origin, footprint_size):
		occupied_tiles.erase(tile)

func mark_occupied_world(world_pos: Vector3) -> void:
	occupied_tiles[world_to_tile(world_pos)] = true
