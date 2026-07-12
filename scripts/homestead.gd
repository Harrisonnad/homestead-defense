extends Node3D

# The player's home base: what enemies raid and what the season is lost
# over. Also where recruited villagers arrive, since it already sits in the
# world with the references a spawn needs.

@export var max_health: int = 100
@export var villager_scene: PackedScene
@export var entities_container_path: NodePath
@export var recruit_offset: Vector3 = Vector3(2, 0, 1)

@onready var entities_container: Node3D = get_node(entities_container_path)

var current_health: int

signal health_changed(current: int)

func _ready() -> void:
	current_health = max_health
	add_to_group("homestead")
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)

func take_damage(amount: int) -> void:
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health)
	if current_health <= 0:
		GameState.lose()

func _on_upgrade_purchased(id: String) -> void:
	if id != "recruit_villager":
		return
	var villager := villager_scene.instantiate()
	entities_container.add_child(villager)
	villager.global_position = global_position + recruit_offset
