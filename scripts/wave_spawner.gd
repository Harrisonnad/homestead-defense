extends Node

# Spawns a wave of enemies at night, targeting the home base, and
# force-despawns any survivors at dawn so each night is self-contained.
# Wave composition escalates with GameClock.day_count: more Raiders over
# time, plus Brutes once brute_unlock_day is reached.

@export var raider_scene: PackedScene
@export var brute_scene: PackedScene
@export var spawn_point_path: NodePath
@export var home_base_path: NodePath
@export var entities_container_path: NodePath
@export var base_raiders: int = 1
@export var raiders_per_days: int = 2
@export var brute_unlock_day: int = 4
@export var brutes_per_days: int = 4
@export var spawn_jitter: float = 2.0

@onready var spawn_point: Marker3D = get_node(spawn_point_path)
@onready var home_base: Marker3D = get_node(home_base_path)
@onready var entities_container: Node3D = get_node(entities_container_path)

var _active_enemies: Array[Node] = []

func _ready() -> void:
	GameClock.night_started.connect(_on_night_started)
	GameClock.day_started.connect(_on_day_started)

func _compute_wave(day_count: int) -> Dictionary:
	var raiders := base_raiders + (day_count - 1) / raiders_per_days
	var brutes := 0
	if day_count >= brute_unlock_day:
		brutes = 1 + (day_count - brute_unlock_day) / brutes_per_days
	return {"raiders": raiders, "brutes": brutes}

func _on_night_started() -> void:
	var wave := _compute_wave(GameClock.day_count)
	_spawn_enemies(raider_scene, wave["raiders"])
	_spawn_enemies(brute_scene, wave["brutes"])

func _spawn_enemies(scene: PackedScene, count: int) -> void:
	if scene == null:
		return
	for i in count:
		var enemy := scene.instantiate()
		entities_container.add_child(enemy)
		var jitter := Vector3((i - (count - 1) / 2.0) * spawn_jitter, 0.0, 0.0)
		enemy.global_position = spawn_point.global_position + jitter
		enemy.target = home_base
		enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))
		_active_enemies.append(enemy)

func _on_day_started(_day_count: int) -> void:
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()

func _on_enemy_tree_exited(enemy: Node) -> void:
	_active_enemies.erase(enemy)
