extends Node3D

# Realizes a MapGenerator result as live scene content: terrain tile visuals
# (MultiMesh per biome), resource nodes / farm plots / hay from the map data,
# fence rows dressing the chokepoints, prop scatter, and repositioning of the
# scene-authored landmarks (Homestead, markers, villagers) onto the
# generated buildable core. Gameplay stays on the y=0 plane: terrain is
# visual + placement flavor only, water is wadeable until navmesh lands.

@export var theme: MapTheme
@export var seed_override: int = 0 # 0 = random each session
@export var tree_scene: PackedScene
@export var rock_scene: PackedScene
@export var hay_scene: PackedScene
@export var farm_plot_scene: PackedScene
@export var fence_scene: PackedScene
@export var homestead_path: NodePath
@export var home_base_path: NodePath
@export var enemy_spawn_path: NodePath
@export var villager_paths: Array[NodePath] = []

const MAX_TREES := 50
const MAX_ROCKS := 20
const MAX_HAY := 10
const MAX_PLOTS := 18
const MAX_PROPS := 16
const MAX_CHOKEPOINT_FENCES := 4
const HOMESTEAD_CLEARANCE_TILES := 3.0

const BIOME_COLORS := {
	"dirt": Color(0.42, 0.32, 0.2),
	"water": Color(0.22, 0.38, 0.52),
	"rock": Color(0.45, 0.45, 0.47),
}

var map_data: Dictionary = {}
var placement_grid: PlacementGrid

var _rng := RandomNumberGenerator.new()
var _half_size: Vector2
var _occupied := {}
var _home_tile: Vector2i

func _ready() -> void:
	var session_seed := seed_override if seed_override != 0 else (randi() % 1000000) + 1
	var generator := MapGenerator.new()
	map_data = generator.generate(theme, session_seed)
	if map_data.is_empty():
		push_error("MapBuilder: generation returned no data; map left bare")
		return
	print("MapBuilder: theme=%s seed=%d" % [map_data["theme_name"], map_data["seed_used"]])

	_rng.seed = int(map_data["seed_used"])
	var size: Vector2i = map_data["size"]
	_half_size = Vector2(size.x / 2.0, size.y / 2.0)

	placement_grid = PlacementGrid.new()
	placement_grid.setup(map_data, _half_size)

	_build_terrain()
	_place_landmarks()
	_populate_interactables()
	_dress_chokepoints()
	_scatter_props()

	# Everything spawned above claimed a spacing radius in _occupied; mirror
	# those exact tiles into the PlacementGrid so BuildManager can't place a
	# building on top of a tree, farm plot, fence, or the homestead.
	for tile in _occupied:
		placement_grid.occupied_tiles[tile] = true

func tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3(tile.x - _half_size.x + 0.5, 0.0, tile.y - _half_size.y + 0.5)

func _build_terrain() -> void:
	# Grass is the base ground plane's own color; only the other biomes get
	# tile instances (thin boxes barely above the plane, so no z-fighting).
	var biomes: Array = map_data["biomes"]
	var tiles_by_biome := {"dirt": [], "water": [], "rock": []}
	for y in biomes.size():
		for x in biomes[y].size():
			var biome: String = biomes[y][x]
			if tiles_by_biome.has(biome):
				tiles_by_biome[biome].append(Vector2i(x, y))

	for biome in tiles_by_biome:
		var tiles: Array = tiles_by_biome[biome]
		if tiles.is_empty():
			continue
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Terrain_" + biome
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1, 0.7, 1) if biome == "rock" else Vector3(1, 0.06, 1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BIOME_COLORS[biome]
		mat.roughness = 0.95
		mmi.material_override = mat

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = tiles.size()
		var base_y := 0.3 if biome == "rock" else 0.01
		for i in tiles.size():
			var pos := tile_to_world(tiles[i])
			pos.y = base_y
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
		mmi.multimesh = mm
		add_child(mmi)

func _place_landmarks() -> void:
	var biomes: Array = map_data["biomes"]
	_home_tile = MapValidator.find_buildable_center(biomes)
	if _home_tile == Vector2i(-1, -1):
		_home_tile = Vector2i(int(_half_size.x), int(_half_size.y))

	var home_pos := tile_to_world(_home_tile)
	get_node(homestead_path).global_position = home_pos
	get_node(home_base_path).global_position = home_pos
	_occupied[_home_tile] = true

	var villager_offsets := [Vector3(2, 0, 1), Vector3(-2, 0, 1), Vector3(0, 0, 2.5)]
	for i in villager_paths.size():
		var offset: Vector3 = villager_offsets[i % villager_offsets.size()]
		get_node(villager_paths[i]).global_position = home_pos + offset

	var spawn := get_node(enemy_spawn_path)
	spawn.global_position = Vector3(clampf(home_pos.x, -18.0, 18.0), 0.0, -_half_size.y + 1.5)

func _populate_interactables() -> void:
	var resources: Array = _shuffled(map_data["resources"])
	var trees := 0
	var rocks := 0
	var hay := 0
	for tile in resources:
		if not _claim_tile(tile, 1.8):
			continue
		var roll := _rng.randf()
		if roll < 0.6 and trees < MAX_TREES:
			_spawn_at(tree_scene, tile)
			trees += 1
		elif roll < 0.85 and rocks < MAX_ROCKS:
			_spawn_at(rock_scene, tile)
			rocks += 1
		elif hay < MAX_HAY:
			_spawn_at(hay_scene, tile)
			hay += 1
		elif trees < MAX_TREES:
			_spawn_at(tree_scene, tile)
			trees += 1

	var plots := 0
	for tile in _shuffled(map_data["crop_plots"]):
		if plots >= MAX_PLOTS:
			break
		if _claim_tile(tile, 2.2):
			_spawn_at(farm_plot_scene, tile)
			plots += 1

func _dress_chokepoints() -> void:
	var placed: Array[Vector2i] = []
	for tile in _shuffled(map_data["chokepoints"]):
		if placed.size() >= MAX_CHOKEPOINT_FENCES:
			break
		var too_close := Vector2(tile - _home_tile).length() < 6.0
		for prev in placed:
			if Vector2(tile - prev).length() < 8.0:
				too_close = true
				break
		if too_close:
			continue
		placed.append(tile)
		for offset_x in [-2.0, 0.0, 2.0]:
			var fence := fence_scene.instantiate()
			add_child(fence)
			var pos := tile_to_world(tile) + Vector3(offset_x, 0, 0)
			fence.global_position = pos
			placement_grid.mark_occupied_world(pos)

func _scatter_props() -> void:
	var count := 0
	for prop in _shuffled(map_data["props"]):
		if count >= MAX_PROPS:
			break
		if _claim_tile(prop["pos"], 2.0):
			var instance: Node3D = prop["scene"].instantiate()
			add_child(instance)
			instance.global_position.x = tile_to_world(prop["pos"]).x
			instance.global_position.z = tile_to_world(prop["pos"]).z
			count += 1

func _claim_tile(tile: Vector2i, min_dist: float) -> bool:
	if Vector2(tile - _home_tile).length() < HOMESTEAD_CLEARANCE_TILES:
		return false
	for other in _occupied:
		if Vector2(tile - other).length() < min_dist:
			return false
	_occupied[tile] = true
	return true

func _spawn_at(scene: PackedScene, tile: Vector2i) -> void:
	var instance := scene.instantiate()
	add_child(instance)
	instance.global_position = tile_to_world(tile)

func _shuffled(source: Array) -> Array:
	var arr := source.duplicate()
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr
