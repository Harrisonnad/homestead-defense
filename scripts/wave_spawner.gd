extends Node

# Spawns a wave of enemies at night, targeting the home base, and
# force-despawns any survivors at dawn so each night is self-contained.
# Wave composition escalates with GameClock.day_count: more Raiders over
# time, plus Ranged Raiders once ranged_unlock_day is reached and Brutes
# once brute_unlock_day is reached.

@export var raider_scene: PackedScene
@export var ranged_raider_scene: PackedScene
@export var brute_scene: PackedScene
@export var siege_scene: PackedScene
# Seasonal enemy identity (master spec §5.7) - gated by GameState.current_season()
# instead of a day threshold, since the season *is* the unlock condition.
@export var locust_scene: PackedScene
@export var wolf_scene: PackedScene
@export var spawn_point_path: NodePath
@export var home_base_path: NodePath
@export var entities_container_path: NodePath
@export var map_builder_path: NodePath
@export var base_raiders: int = 1
@export var raiders_per_days: int = 3
@export var ranged_unlock_day: int = 3
@export var ranged_per_days: int = 4
@export var brute_unlock_day: int = 6
@export var brutes_per_days: int = 5
# Siege-breaker: rare, tanky, slow, high wall-smashing damage - the "breaks
# through defenses" archetype the design spec calls for that didn't exist
# yet (only fast/fragile, slow/tanky, ranged did). Unlocks later and scales
# slower than Brutes so it stays a rare late-game threat, not a reskin.
@export var siege_unlock_day: int = 10
@export var siege_per_days: int = 8
# Locust Swarm (summer) and Wolf Pack (winter) - see locust.gd/wolf.gd for
# their behavioral identity (Farm Plot / Animal Pen targeting). Counts
# escalate across their season the same way Raiders escalate across days.
@export var locust_base_count: int = 3
@export var locust_per_days: int = 3
@export var wolf_base_count: int = 2
@export var wolf_per_days: int = 4
@export var max_enemies_per_night: int = 12
@export var min_spawn_distance: float = 18.0
@export var max_spawn_distance: float = 30.0
@export var wall_clearance: float = 3.0
@export var max_spawn_attempts: int = 12

# Player-chosen difficulty (GameState.difficulty, set by the New Game
# screen) scales the whole wave, not individual tunables above - simpler
# than retuning every unlock_day/per_days pair per difficulty, and the
# difference naturally grows more pronounced in the late game (when counts
# are larger) rather than making early nights feel wildly different.
const DIFFICULTY_MULTIPLIERS := {"easy": 0.7, "normal": 1.0, "hard": 1.4}
var _difficulty_multiplier: float = 1.0

@onready var spawn_point: Marker3D = get_node(spawn_point_path)
@onready var home_base: Marker3D = get_node(home_base_path)
@onready var entities_container: Node3D = get_node(entities_container_path)
@onready var map_builder = get_node_or_null(map_builder_path)

var _active_enemies: Array[Node] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_difficulty_multiplier = DIFFICULTY_MULTIPLIERS.get(GameState.difficulty, 1.0)
	GameClock.night_started.connect(_on_night_started)
	GameClock.day_started.connect(_on_day_started)

func _compute_wave(day_count: int) -> Dictionary:
	var raiders := roundi((base_raiders + (day_count - 1) / raiders_per_days) * _difficulty_multiplier)
	var ranged := 0
	if day_count >= ranged_unlock_day:
		ranged = roundi((1 + (day_count - ranged_unlock_day) / ranged_per_days) * _difficulty_multiplier)
	var brutes := 0
	if day_count >= brute_unlock_day:
		brutes = roundi((1 + (day_count - brute_unlock_day) / brutes_per_days) * _difficulty_multiplier)
	var siege := 0
	if day_count >= siege_unlock_day:
		siege = roundi((1 + (day_count - siege_unlock_day) / siege_per_days) * _difficulty_multiplier)

	var locusts := 0
	var wolves := 0
	var season := GameState.current_season()
	if season == "summer":
		var start := _season_start_day("summer")
		locusts = roundi((locust_base_count + (day_count - start) / locust_per_days) * _difficulty_multiplier)
	elif season == "winter":
		var start := _season_start_day("winter")
		wolves = roundi((wolf_base_count + (day_count - start) / wolf_per_days) * _difficulty_multiplier)

	# Trim toward the per-night cap, weakest/most-expendable first: Locusts,
	# then plain Raiders, then Ranged Raiders, then Wolves, then Brutes, then
	# Siege-breakers (the biggest, rarest threat) last - keep this order if a
	# further enemy tier is ever added. The cap itself also scales with
	# difficulty so Hard can genuinely push more enemies through per night,
	# not just reshuffle the same total.
	var cap := roundi(max_enemies_per_night * _difficulty_multiplier)
	var over := raiders + ranged + brutes + siege + locusts + wolves - cap
	if over > 0:
		var trim_locusts := mini(over, locusts)
		locusts -= trim_locusts
		over -= trim_locusts
		var trim_raiders := mini(over, raiders)
		raiders -= trim_raiders
		over -= trim_raiders
		var trim_ranged := mini(over, ranged)
		ranged -= trim_ranged
		over -= trim_ranged
		var trim_wolves := mini(over, wolves)
		wolves -= trim_wolves
		over -= trim_wolves
		var trim_brutes := mini(over, brutes)
		brutes -= trim_brutes
		over -= trim_brutes
		siege -= mini(over, siege)

	return {
		"raiders": maxi(raiders, 0), "ranged": maxi(ranged, 0),
		"brutes": maxi(brutes, 0), "siege": maxi(siege, 0),
		"locusts": maxi(locusts, 0), "wolves": maxi(wolves, 0),
	}

# The day the given season name starts, derived from GameState's own
# quarter-of-the-season math rather than a hardcoded day number, so this
# stays correct if season_length_days is ever tuned.
func _season_start_day(season_name: String) -> int:
	var index := GameState.SEASONS.find(season_name)
	var quarter_length: float = GameState.season_length_days / float(GameState.SEASONS.size())
	return int(quarter_length * index) + 1

func _on_night_started() -> void:
	var wave := _compute_wave(GameClock.day_count)
	_spawn_enemies(raider_scene, wave["raiders"])
	_spawn_enemies(ranged_raider_scene, wave["ranged"])
	_spawn_enemies(brute_scene, wave["brutes"])
	_spawn_enemies(siege_scene, wave["siege"])
	_spawn_enemies(locust_scene, wave["locusts"])
	_spawn_enemies(wolf_scene, wave["wolves"])

func _spawn_enemies(scene: PackedScene, count: int) -> void:
	if scene == null:
		return
	for i in count:
		var enemy := scene.instantiate()
		entities_container.add_child(enemy)
		enemy.global_position = _pick_spawn_position()
		enemy.set_initial_target(home_base)
		enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))
		_active_enemies.append(enemy)

# Enemies used to always spawn from the same fixed marker north of the base.
# Instead, ring around the base at a random angle/distance each time, skipping
# any candidate too close to a wall so raiders don't spawn stuck inside the
# player's own defenses. Falls back to the original marker if none clear.
func _pick_spawn_position() -> Vector3:
	var base_pos := home_base.global_position
	for attempt in max_spawn_attempts:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(min_spawn_distance, max_spawn_distance)
		var candidate := base_pos + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if _is_clear_of_walls(candidate) and not _is_on_water(candidate):
			return candidate
	return spawn_point.global_position

func _is_clear_of_walls(pos: Vector3) -> bool:
	for wall in get_tree().get_nodes_in_group("walls"):
		if wall.global_position.distance_to(pos) < wall_clearance:
			return false
	return true

# Water now has real collision (map_builder.gd) - without this check, the
# random spawn ring could land an enemy on/inside a water tile and it would
# immediately get stuck rather than gracefully sliding, since it would spawn
# already overlapping the collider instead of walking into it.
func _is_on_water(pos: Vector3) -> bool:
	if map_builder == null or map_builder.placement_grid == null:
		return false
	var tile: Vector2i = map_builder.placement_grid.world_to_tile(pos)
	return map_builder.placement_grid.is_water(tile)

func _on_day_started(_day_count: int) -> void:
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()

func _on_enemy_tree_exited(enemy: Node) -> void:
	_active_enemies.erase(enemy)
