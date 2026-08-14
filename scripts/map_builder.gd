extends Node3D

# Realizes a MapGenerator result as live scene content: terrain tile visuals
# (MultiMesh per biome), resource nodes / farm plots / hay from the map data,
# fence rows dressing the chokepoints, prop scatter, and repositioning of the
# scene-authored landmarks (Homestead, markers, villagers) onto the
# generated buildable core. Gameplay stays on the y=0 plane: terrain is
# visual + placement flavor only, EXCEPT water, which now has real collision
# (see _build_water_collision()) so Villagers/Enemies/Dogs can't walk across
# it - it uses the same collision layer Wall/Building/Fence already do, so
# CharacterBody3D movement blocks against it with zero script changes.

@export var theme: MapTheme
@export var seed_override: int = 0 # 0 = random each session
@export var tree_scenes: Array[PackedScene] = []
@export var rock_scene: PackedScene
@export var hay_scene: PackedScene
@export var berry_bush_scene: PackedScene
@export var fishing_spot_scene: PackedScene
@export var farm_plot_scene: PackedScene
@export var fence_scene: PackedScene
@export var ruin_scene: PackedScene
@export var ruin_reward_defs: Array[BuildingDef] = []
# Ambient atmosphere (asset-pack step 3's "hero glow flora" - generated
# early on but never wired into a scatter pass until now). Scattered on
# plain grass/dirt like _scatter_props(), but scarcer and kept off crop/pen
# zones so it never reads as competing with actual gameplay tiles.
@export var flora_scenes: Array[PackedScene] = []
@export var homestead_path: NodePath
@export var home_base_path: NodePath
@export var enemy_spawn_path: NodePath
@export var villager_paths: Array[NodePath] = []
# The base Ground plane (Main.tscn) shares the terrain shader/grass color as
# a seamless backdrop under the tile MultiMeshes (see _build_terrain()'s own
# comment) - its material needs the same seasonal day_color updates the tile
# materials get, or the two would visibly mismatch after a season change.
@export var ground_mesh_path: NodePath

const MAX_TREES := 50
const MAX_ROCKS := 20
const MAX_HAY := 10
const MAX_BERRY_BUSHES := 8
const MAX_FISHING_SPOTS := 10
const MAX_PLOTS := 18
const MAX_PROPS := 16
const MAX_FLORA := 56
const MAX_CHOKEPOINT_FENCES := 4
# Chibi/artsy terrain pass: small per-tile position/rotation jitter so the
# grid doesn't read as perfectly ruled graph paper. A first pass tried a
# chamfered/beveled tile top instead (or in addition) - reverted, since the
# sharp crease between the flat top and the bevel caught the sun as a
# distinct rim-light line at EVERY tile edge, reading as a more visible grid
# than the plain box it replaced, not less. Oversizing each tile beyond its
# 1x1 grid spacing gives the jitter slack to work with so adjacent tiles
# overlap rather than gap (a first pass jittered exact 1x1 tiles and every
# gap exposed the sky-colored background behind as a bright white lattice -
# see _build_terrain()). Water is excluded from all of this - stays flat,
# still, and perfectly grid-aligned, matching its "level surface" role.
const TILE_OVERSIZE := 1.08
const TILE_JITTER_POS := 0.035
const TILE_JITTER_ROT := 0.05
# Shoreline foam (_build_shoreline_foam()) - the single biggest "blocky"
# offender was the water/land boundary: biome tiles are grid-aligned, so
# every shoreline reads as a hard pixel-art staircase. A soft translucent
# gradient strip along every water-tile edge that borders land blurs that
# hard seam without needing true boundary-contour smoothing.
const SHORE_FOAM_WIDTH := 0.5
const SHORE_FOAM_COLOR := Color(0.88, 0.94, 0.92)
const HOMESTEAD_CLEARANCE_TILES := 3.0
const MAX_RUINS := 2
const RUIN_MIN_DISTANCE_FROM_HOME := 10.0
const RUIN_PLACEMENT_ATTEMPTS := 200

const TERRAIN_SHADER := preload("res://assets/terrain/terrain_day_night.gdshader")
const TERRAIN_DAY_COLORS := {
	"grass": Color(0.3, 0.45, 0.25),
	"dirt": Color(0.42, 0.32, 0.2),
	"water": Color(0.22, 0.38, 0.52),
	"rock": Color(0.45, 0.45, 0.47),
}
# Cool, near-black-blue base per the custom pack's own night palette
# (asset-pack/MASTER_ART_DIRECTION.md §4) - the same register every other
# asset in the game already shifts to at night, terrain just never had a
# material that read day_night_ratio before now.
const TERRAIN_NIGHT_COLORS := {
	"grass": Color(0.09, 0.13, 0.15),
	"dirt": Color(0.14, 0.12, 0.15),
	"water": Color(0.08, 0.19, 0.21),
	"rock": Color(0.16, 0.17, 0.2),
}

# Seasonal terrain reskinning (visual counterpart to GameState.current_season(),
# which already drives wave composition - a night that plays differently by
# season should also look different by day). Summer is exactly
# TERRAIN_DAY_COLORS (the pre-existing baseline, so a summer map is pixel-
# identical to before this change - zero regression risk). Night colors stay
# constant across all seasons - the fungal-world night identity (§4) isn't
# seasonal, only the daytime palette shifts. Only a shader-parameter update
# on materials _build_terrain() already creates, re-applied whenever
# GameClock.day_started crosses into a new season - no new geometry/assets.
const SEASON_TERRAIN_DAY_COLORS := {
	"spring": {"grass": Color(0.44, 0.66, 0.32), "dirt": Color(0.48, 0.36, 0.2), "water": Color(0.26, 0.48, 0.6), "rock": Color(0.5, 0.5, 0.5)},
	"summer": {"grass": Color(0.3, 0.45, 0.25), "dirt": Color(0.42, 0.32, 0.2), "water": Color(0.22, 0.38, 0.52), "rock": Color(0.45, 0.45, 0.47)},
	"fall": {"grass": Color(0.55, 0.4, 0.18), "dirt": Color(0.38, 0.26, 0.15), "water": Color(0.2, 0.32, 0.42), "rock": Color(0.5, 0.44, 0.4)},
	"winter": {"grass": Color(0.75, 0.78, 0.8), "dirt": Color(0.55, 0.53, 0.5), "water": Color(0.65, 0.75, 0.8), "rock": Color(0.62, 0.63, 0.65)},
}

# Elevation data (map_data["elevation"]) already drives biome placement but
# was otherwise discarded - never used for anything visual. Quantized into a
# few terraced steps (not smooth per-tile noise, which would read as messy
# at this low-poly scale) for a rolling-hills feel. Kept modest: villagers/
# buildings/enemies still place at a flat y=0 (see this file's header
# comment - full terrain-conforming placement is out of scope, same
# accepted v1 approximation as the existing flat gameplay plane), so too
# much relief would read as floating/sinking rather than "alive terrain."
const ELEVATION_STEPS := 3
const ELEVATION_STEP_HEIGHT := 0.16

# Matches the WorldEnvironment's fog_light_color/background_color (Main.tscn)
# so the ground appears to dissolve into the same haze the distance fog
# already fades toward, instead of hard-cutting to flat sky color.
const EDGE_FADE_COLOR := Color(0.7, 0.75, 0.78)

var map_data: Dictionary = {}
var placement_grid: PlacementGrid

var _rng := RandomNumberGenerator.new()
var _half_size: Vector2
var _occupied := {}
var _home_tile: Vector2i
var _terrain_materials: Dictionary = {} # biome -> ShaderMaterial
var _current_terrain_season: String = ""

func _ready() -> void:
	add_to_group("map_builder")
	var session_seed := seed_override
	if session_seed == 0 and SaveManager.pending_load:
		# Continue from the main menu: reproduce the exact map the save was
		# made on. SaveManager.load_game() itself runs deferred (after every
		# node's _ready(), including this one) and only restores gameplay
		# state, not the map - without this, the map regenerates with a fresh
		# random seed and saved buildings/villagers end up repositioned onto
		# terrain that no longer matches what was actually saved.
		session_seed = SaveManager.peek_saved_seed()
	if session_seed == 0 and GameState.pending_seed != 0:
		# Player typed a custom seed in the New Game screen.
		session_seed = GameState.pending_seed
		AchievementManager.on_custom_seed_used()
	if session_seed == 0:
		session_seed = (randi() % 1000000) + 1
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
	_build_shoreline_foam()
	_build_edge_fade()
	_place_landmarks()
	_populate_interactables()
	_populate_fishing_spots()
	_populate_farm_plots()
	_place_ruins()
	_dress_chokepoints()
	_scatter_props()
	_scatter_flora()

	# Everything spawned above claimed a spacing radius in _occupied; mirror
	# those exact tiles into the PlacementGrid so BuildManager can't place a
	# building on top of a tree, farm plot, fence, or the homestead.
	for tile in _occupied:
		placement_grid.occupied_tiles[tile] = true

	GameClock.day_started.connect(_on_day_started)
	_apply_season_terrain(GameState.current_season())

func _on_day_started(_day_count: int) -> void:
	_apply_season_terrain(GameState.current_season())

func _apply_season_terrain(season: String) -> void:
	if season == _current_terrain_season:
		return
	_current_terrain_season = season
	var day_colors: Dictionary = SEASON_TERRAIN_DAY_COLORS.get(season, TERRAIN_DAY_COLORS)
	for biome in _terrain_materials:
		var mat: ShaderMaterial = _terrain_materials[biome]
		mat.set_shader_parameter("day_color", day_colors.get(biome, TERRAIN_DAY_COLORS[biome]))
	var ground_mesh := get_node_or_null(ground_mesh_path)
	if ground_mesh != null:
		var ground_mat: ShaderMaterial = ground_mesh.get_surface_override_material(0)
		if ground_mat != null:
			ground_mat.set_shader_parameter("day_color", day_colors.get("grass", TERRAIN_DAY_COLORS["grass"]))

func tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3(tile.x - _half_size.x + 0.5, 0.0, tile.y - _half_size.y + 0.5)

func _build_terrain() -> void:
	# All four biomes get their own tile instances now (grass used to be just
	# the base Ground plane's flat color - see Main.tscn - which stays in
	# place underneath as a seamless backdrop, now sharing the same day/night
	# material so it doesn't look inconsistent at tile boundaries/map edges).
	var biomes: Array = map_data["biomes"]
	var elevation: Array = map_data["elevation"]
	var tiles_by_biome := {"grass": [], "dirt": [], "water": [], "rock": []}
	for y in biomes.size():
		for x in biomes[y].size():
			tiles_by_biome[biomes[y][x]].append(Vector2i(x, y))

	var min_elev := INF
	var max_elev := -INF
	for row in elevation:
		for h in row:
			min_elev = minf(min_elev, h)
			max_elev = maxf(max_elev, h)
	var elev_range := maxf(max_elev - min_elev, 0.001)

	for biome in tiles_by_biome:
		var tiles: Array = tiles_by_biome[biome]
		if tiles.is_empty():
			continue
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Terrain_" + biome
		var height := 0.7 if biome == "rock" else 0.12
		var box := BoxMesh.new()
		# Oversized beyond the 1x1 grid spacing for grass/dirt/rock so the
		# position jitter below has slack to work with - adjacent tiles
		# overlap slightly instead of gapping (see the TILE_OVERSIZE const
		# comment for why an exact-1x1 jittered tile is a real problem, not
		# just a cosmetic one).
		var footprint := TILE_OVERSIZE if biome != "water" else 1.0
		box.size = Vector3(footprint, height, footprint)
		var terrain_mat := _terrain_material(biome)
		mmi.material_override = terrain_mat
		_terrain_materials[biome] = terrain_mat

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box
		mm.instance_count = tiles.size()
		var base_y := 0.3 if biome == "rock" else 0.01
		for i in tiles.size():
			var tile: Vector2i = tiles[i]
			var pos := tile_to_world(tile)
			var basis := Basis.IDENTITY
			# Water stays a flat, level, perfectly grid-aligned surface - a
			# river/pool shouldn't be stepped/terraced or jittered the way
			# solid ground reasonably can be.
			if biome != "water":
				var tile_elev: float = elevation[tile.y][tile.x]
				var normalized: float = (tile_elev - min_elev) / elev_range
				var step := mini(int(normalized * ELEVATION_STEPS), ELEVATION_STEPS - 1)
				pos.y = base_y + step * ELEVATION_STEP_HEIGHT
				pos.x += _rng.randf_range(-TILE_JITTER_POS, TILE_JITTER_POS)
				pos.z += _rng.randf_range(-TILE_JITTER_POS, TILE_JITTER_POS)
				basis = Basis(Vector3.UP, _rng.randf_range(-TILE_JITTER_ROT, TILE_JITTER_ROT))
			else:
				pos.y = base_y
			mm.set_instance_transform(i, Transform3D(basis, pos))
		mmi.multimesh = mm
		add_child(mmi)

	if not tiles_by_biome["water"].is_empty():
		_build_water_collision(tiles_by_biome["water"])

# Soft translucent gradient strips along every water-tile edge bordering
# land (see the TILE_BEVEL const block comment) - a symmetric transparent
# -> opaque -> transparent gradient straddling the boundary line, so no
# per-edge orientation logic is needed beyond a 90-degree rotation for
# north/south vs east/west edges.
func _build_shoreline_foam() -> void:
	var biomes: Array = map_data["biomes"]
	if biomes.is_empty():
		return
	var h: int = biomes.size()
	var w: int = biomes[0].size()

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(SHORE_FOAM_COLOR, 0.0), Color(SHORE_FOAM_COLOR, 0.4), Color(SHORE_FOAM_COLOR, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 64
	tex.height = 8

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(SHORE_FOAM_WIDTH, 1.04)

	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var transforms: Array[Transform3D] = []
	for y in h:
		for x in w:
			if biomes[y][x] != "water":
				continue
			var pos := tile_to_world(Vector2i(x, y))
			for dir in dirs:
				var nx: int = x + dir.x
				var ny: int = y + dir.y
				var neighbor_is_land: bool = nx >= 0 and nx < w and ny >= 0 and ny < h and biomes[ny][nx] != "water"
				if not neighbor_is_land:
					continue
				var rot := 0.0 if dir.x != 0 else PI / 2.0
				var edge_pos := pos + Vector3(dir.x * 0.5, 0.08, dir.y * 0.5)
				transforms.append(Transform3D(Basis(Vector3.UP, rot), edge_pos))

	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ShorelineFoam"
	mmi.material_override = mat
	mmi.multimesh = mm
	add_child(mmi)

# One StaticBody3D with one CollisionShape3D per water tile - collision_layer
# 2 matches Wall/Building/Fence (see wall.tscn/animal_pen.tscn etc.), which
# Villager/Enemy/Dog's collision_mask already includes for movement, so this
# needs no changes to any character script. Box reaches from the ground up
# to y=1.2, comfortably intersecting the ~1.5-tall capsule shapes those
# CharacterBody3D nodes use, so move_and_slide() blocks/slides against it
# exactly like it already does against a Wall or a tree.
func _build_water_collision(tiles: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "WaterCollision"
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.2, 1.0)
	for tile in tiles:
		var col := CollisionShape3D.new()
		col.name = _water_collision_name(tile)
		col.shape = shape
		col.position = tile_to_world(tile) + Vector3(0.0, 0.6, 0.0)
		body.add_child(col)

func _water_collision_name(tile: Vector2i) -> String:
	return "Water_%d_%d" % [tile.x, tile.y]

# Bridge's completion hook (see scripts/bridge.gd / #28: water got real
# collision this session, which fixed a walk-on-water bug but also made
# water fully impassable with no way back across) - permanently removes the
# per-tile collision shape(s) under a just-completed Bridge's footprint so
# Villagers/Enemies/Dogs can cross there, same layer everything else already
# collides against.
func open_water_crossing(origin: Vector2i, size: Vector2i) -> void:
	var water_body := get_node_or_null("WaterCollision")
	if water_body == null:
		return
	for dy in size.y:
		for dx in size.x:
			var tile := origin + Vector2i(dx, dy)
			var col := water_body.get_node_or_null(_water_collision_name(tile))
			if col:
				col.queue_free()

func _terrain_material(biome: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("day_color", TERRAIN_DAY_COLORS[biome])
	mat.set_shader_parameter("night_color", TERRAIN_NIGHT_COLORS[biome])
	return mat

# Purely cosmetic: a big radial-gradient plane sitting just above the real
# ground, transparent over the playable area and fading to EDGE_FADE_COLOR
# past it, so panning toward the map boundary reads as dissolving into haze
# instead of the ground mesh hard-cutting to flat sky color.
func _build_edge_fade() -> void:
	var map_radius := maxf(_half_size.x, _half_size.y)
	var outer_radius := map_radius * 2.2
	var inner_radius := map_radius * 0.75

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(EDGE_FADE_COLOR, 0.0), Color(EDGE_FADE_COLOR, 1.0)])
	gradient.offsets = PackedFloat32Array([inner_radius / outer_radius, 1.0])

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(outer_radius * 2.0, outer_radius * 2.0)

	var mmi := MeshInstance3D.new()
	mmi.name = "EdgeFade"
	mmi.mesh = mesh
	mmi.material_override = mat
	mmi.position = Vector3(0.0, 0.05, 0.0)
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

	# Water now has real collision (see _build_water_collision()) - a fixed
	# offset from home_pos isn't validated against the generated terrain, so
	# if water happens to be adjacent to the home tile a villager could spawn
	# stuck inside it. find_nearest_non_water() nudges that one spawn to the
	# nearest dry tile instead.
	var villager_offsets := [Vector3(2, 0, 1), Vector3(-2, 0, 1), Vector3(0, 0, 2.5)]
	for i in villager_paths.size():
		var offset: Vector3 = villager_offsets[i % villager_offsets.size()]
		var pos := placement_grid.find_nearest_non_water(home_pos + offset)
		get_node(villager_paths[i]).global_position = pos

	var spawn := get_node(enemy_spawn_path)
	spawn.global_position = Vector3(clampf(home_pos.x, -18.0, 18.0), 0.0, -_half_size.y + 1.5)

func _populate_interactables() -> void:
	var resources: Array = _shuffled(map_data["resources"])
	var trees := 0
	var rocks := 0
	var hay := 0
	var berries := 0
	for tile in resources:
		if not _claim_tile(tile, 1.8):
			continue
		var roll := _rng.randf()
		if roll < 0.55 and trees < MAX_TREES:
			_spawn_at(_random_tree_scene(), tile)
			trees += 1
		elif roll < 0.75 and rocks < MAX_ROCKS:
			_spawn_at(rock_scene, tile)
			rocks += 1
		elif roll < 0.9 and hay < MAX_HAY:
			_spawn_at(hay_scene, tile)
			hay += 1
		elif berries < MAX_BERRY_BUSHES:
			_spawn_at(berry_bush_scene, tile)
			berries += 1
		elif hay < MAX_HAY:
			_spawn_at(hay_scene, tile)
			hay += 1
		elif trees < MAX_TREES:
			_spawn_at(_random_tree_scene(), tile)
			trees += 1

func _populate_fishing_spots() -> void:
	if fishing_spot_scene == null:
		return
	var spots := 0
	for tile in _shuffled(map_data.get("fishing_spots", [])):
		if spots >= MAX_FISHING_SPOTS:
			break
		if _claim_tile(tile, 3.0):
			_spawn_at(fishing_spot_scene, tile)
			spots += 1

func _populate_farm_plots() -> void:
	var plots := 0
	for tile in _shuffled(map_data["crop_plots"]):
		if plots >= MAX_PLOTS:
			break
		if _claim_tile(tile, 2.2):
			_spawn_at(farm_plot_scene, tile)
			plots += 1

func _place_ruins() -> void:
	if ruin_scene == null or ruin_reward_defs.is_empty():
		return
	var placed := 0
	var attempts := 0
	while placed < MAX_RUINS and attempts < RUIN_PLACEMENT_ATTEMPTS:
		attempts += 1
		var reward: BuildingDef = ruin_reward_defs[_rng.randi_range(0, ruin_reward_defs.size() - 1)]
		var tile := Vector2i(_rng.randi_range(2, int(_half_size.x * 2.0) - 3), _rng.randi_range(2, int(_half_size.y * 2.0) - 3))
		if Vector2(tile - _home_tile).length() < RUIN_MIN_DISTANCE_FROM_HOME:
			continue
		if not _claim_tile(tile, 4.0):
			continue
		var check: Dictionary = placement_grid.check_placement(tile, reward.footprint_size, "core")
		if not check["ok"]:
			continue

		var ruin := ruin_scene.instantiate()
		ruin.reward_def = reward
		ruin.footprint_origin = tile
		ruin.footprint_size = reward.footprint_size
		ruin.placement_grid = placement_grid
		add_child(ruin)
		var center := tile_to_world(tile) + Vector3((reward.footprint_size.x - 1) * 0.5, 0.0, (reward.footprint_size.y - 1) * 0.5)
		ruin.global_position = center
		placement_grid.claim(tile, reward.footprint_size)
		placed += 1

func _dress_chokepoints() -> void:
	var biomes: Array = map_data["biomes"]
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

		# Chokepoints are tiles pinched by rock/water on two sides (see
		# MapGenerator._identify_chokepoints); lay the fence row along the
		# *other* axis so it reads as extending that natural pinch instead of
		# a disconnected prop dropped at a fixed world-space orientation.
		var pinched_horizontally := _is_blocking_biome(biomes, tile + Vector2i(-1, 0)) or _is_blocking_biome(biomes, tile + Vector2i(1, 0))
		var row_axis := Vector3.FORWARD if pinched_horizontally else Vector3.RIGHT
		# sm_fence_post's rails span ~1m (its own MODULE_SIZE-aligned width) so
		# posts need 1.0 spacing to meet edge-to-edge, vs. the old KayKit
		# fence's ~1.75m-wide rails at 2.0 spacing. Same total row span (4m).
		for offset in [-2.0, -1.0, 0.0, 1.0, 2.0]:
			var fence := fence_scene.instantiate()
			add_child(fence)
			var pos: Vector3 = tile_to_world(tile) + row_axis * offset
			fence.global_position = pos
			fence.rotation.y = PI / 2.0 if pinched_horizontally else 0.0
			placement_grid.mark_occupied_world(pos)

func _is_blocking_biome(biomes: Array, tile: Vector2i) -> bool:
	if tile.y < 0 or tile.y >= biomes.size() or tile.x < 0 or tile.x >= biomes[tile.y].size():
		return false
	return biomes[tile.y][tile.x] in ["rock", "water"]

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

func _scatter_flora() -> void:
	if flora_scenes.is_empty():
		return
	var biomes: Array = map_data["biomes"]
	var candidates: Array[Vector2i] = []
	for y in biomes.size():
		for x in biomes[y].size():
			var tile := Vector2i(x, y)
			if biomes[y][x] in ["grass", "dirt"] and not placement_grid.crop_plot_tiles.has(tile) and not placement_grid.animal_zone_tiles.has(tile):
				candidates.append(tile)

	var count := 0
	for tile in _shuffled(candidates):
		if count >= MAX_FLORA:
			break
		if _claim_tile(tile, 1.3):
			var scene: PackedScene = flora_scenes[_rng.randi_range(0, flora_scenes.size() - 1)]
			_spawn_at(scene, tile)
			count += 1

func _claim_tile(tile: Vector2i, min_dist: float) -> bool:
	if Vector2(tile - _home_tile).length() < HOMESTEAD_CLEARANCE_TILES:
		return false
	for other in _occupied:
		if Vector2(tile - other).length() < min_dist:
			return false
	_occupied[tile] = true
	return true

# Picks among tree_scenes (round/pine/tall variants - see #27's "too round,
# not enough variation" fix) instead of a single tree_scene, so map_builder
# has visual variety without map_generator/PlacementGrid needing to know
# trees come in more than one shape.
func _random_tree_scene() -> PackedScene:
	return tree_scenes[_rng.randi_range(0, tree_scenes.size() - 1)]

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
