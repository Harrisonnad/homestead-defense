extends Building
class_name Tower

# Static ranged defender. Reuses the "scan a group, act on a timer" pattern
# already used by villager.gd (guard combat) and enemy.gd (wall-engagement).

@export var damage: int = 8
@export var attack_interval: float = 1.2
@export var attack_range: float = 7.0
@export var chokepoint: bool = false # set by BuildManager at placement time

@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	super._ready()
	if chokepoint:
		attack_range += 1.0
	attack_timer.wait_time = attack_interval
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

func _on_attack_timer_timeout() -> void:
	var target := _find_nearest_enemy_in_range()
	if target:
		target.take_damage(damage)

func _find_nearest_enemy_in_range() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var dist := global_position.distance_to(node.global_position)
		if dist <= attack_range and dist < best_dist:
			best_dist = dist
			best = node
	return best
