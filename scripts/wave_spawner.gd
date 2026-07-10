extends Node

# Spawns enemies at night, targeting the home base, and force-despawns any
# survivors at dawn so each night is self-contained.

@export var enemy_scene: PackedScene
@export var spawn_point_path: NodePath
@export var home_base_path: NodePath
@export var entities_container_path: NodePath
@export var enemies_per_night: int = 1

@onready var spawn_point: Marker3D = get_node(spawn_point_path)
@onready var home_base: Marker3D = get_node(home_base_path)
@onready var entities_container: Node3D = get_node(entities_container_path)

var _active_enemies: Array[Node] = []

func _ready() -> void:
	GameClock.night_started.connect(_on_night_started)
	GameClock.day_started.connect(_on_day_started)

func _on_night_started() -> void:
	for i in enemies_per_night:
		var enemy := enemy_scene.instantiate()
		entities_container.add_child(enemy)
		enemy.global_position = spawn_point.global_position
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
