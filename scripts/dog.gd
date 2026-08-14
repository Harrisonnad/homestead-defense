extends CharacterBody3D
class_name Dog

# Livestock-as-defense (master spec §5.3): an autonomous homestead defender
# spawned by AnimalPen. Does NOT consume the population cap and isn't part
# of Villager's Guard role/task system - it's a separate, always-on unit.
# Mirrors enemy.gd's "scan a group, move toward nearest, AttackRange+Timer
# once close" shape (see that file's own header comment) rather than
# villager.gd's role-state-machine, since Dog has no other role to juggle -
# just one job: watch a radius around its home spot and fight anything in it.
#
# Also backs Goat (scenes/goat.tscn) with different stats/mesh and
# excluded_creature_names set - "active combat assist on smaller enemies"
# per the spec, rather than a second near-identical script.

const PACK_MATERIAL := preload("res://assets/custom_pack/day_night.tres")

@export var move_speed: float = 3.2
@export var attack_damage: int = 10
@export var attack_interval: float = 1.0
@export var max_health: int = 30
@export var detect_radius: float = 10.0
@export var arrival_distance: float = 0.6
@export var scan_interval: float = 1.0
# Empty = engage anything (Dog's own behavior). Goat reuses this exact
# script with this set to the tanky enemy types, so it only ever assists
# against "smaller enemies" per the design spec rather than trading blows
# with a Brute/Siege-breaker it can't meaningfully hurt.
@export var excluded_creature_names: Array[String] = []

var target: Node3D = null
var current_target: Node3D = null
var current_health: int
var _home_position: Vector3

signal died

@onready var attack_range: Area3D = $AttackRange
@onready var attack_timer: Timer = $AttackTimer
@onready var scan_timer: Timer = $ScanTimer
@onready var model: Node3D = $Model

func _ready() -> void:
	current_health = max_health
	_home_position = global_position
	add_to_group("dogs")
	attack_range.body_entered.connect(_on_attack_range_body_entered)
	attack_range.body_exited.connect(_on_attack_range_body_exited)
	attack_timer.wait_time = attack_interval
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	scan_timer.wait_time = scan_interval
	scan_timer.timeout.connect(_on_scan_timer_timeout)
	scan_timer.start()
	CharacterVisualUtils.apply_pack_material(model, PACK_MATERIAL)
	CharacterVisualUtils.play_creature_idle(model, "sk_dog")

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		queue_free()

func _on_scan_timer_timeout() -> void:
	if target != null and is_instance_valid(target):
		return
	target = _find_nearest_enemy_in_detect_radius()

func _find_nearest_enemy_in_detect_radius() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if "creature_name" in node and node.creature_name in excluded_creature_names:
			continue
		var dist := _home_position.distance_to(node.global_position)
		if dist <= detect_radius and dist < best_dist:
			best_dist = dist
			best = node
	return best

func _physics_process(_delta: float) -> void:
	if current_target != null or target == null:
		return
	if not is_instance_valid(target):
		target = null
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() <= arrival_distance:
		return # close enough that AttackRange should already have it

	velocity = to_target.normalized() * move_speed
	CharacterVisualUtils.face_direction(self, to_target)
	move_and_slide()

func _on_attack_range_body_entered(body: Node3D) -> void:
	if current_target != null or not body.has_method("take_damage"):
		return
	if "creature_name" in body and body.creature_name in excluded_creature_names:
		return
	current_target = body
	current_target.died.connect(_on_target_died, CONNECT_ONE_SHOT)
	attack_timer.start()

func _on_attack_range_body_exited(body: Node3D) -> void:
	if body == current_target:
		if current_target.died.is_connected(_on_target_died):
			current_target.died.disconnect(_on_target_died)
		current_target = null
		attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if current_target != null:
		current_target.take_damage(attack_damage)

func _on_target_died() -> void:
	current_target = null
	attack_timer.stop()
	target = null
	AchievementManager.on_dog_kill()
