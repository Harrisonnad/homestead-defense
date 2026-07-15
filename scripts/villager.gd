extends CharacterBody3D
class_name Villager

# Gray-box villager: click to select (routes through the Selection autoload
# to the role-assignment UI), then once assigned a Role, autonomously walks
# to the nearest matching task and performs it in a loop. Farmer/Gatherer
# tasks are a single timed action (WorkTimer); Guard instead fights whatever
# it walked up to on a repeating AttackTimer until it or the enemy dies.

enum Role { NONE, FARMER, GATHERER, GUARD }
enum State { IDLE, MOVING, WORKING }

const GUARD_LAYER_BIT := 8

@export var move_speed: float = 3.0
@export var work_duration: float = 1.5
@export var arrival_distance: float = 0.6
@export var idle_retry_seconds: float = 1.0
@export var guard_attack_damage: int = 12
@export var max_health: int = 35
@export var veteran_bonus_health: int = 15
@export var veteran_bonus_damage: int = 6
@export var veteran_work_speed_multiplier: float = 0.7

var role: Role = Role.NONE
var state: State = State.IDLE
var target: Node3D = null
var current_health: int
var _veteran_applied: bool = false

signal died

@onready var work_timer: Timer = $WorkTimer
@onready var retry_timer: Timer = $RetryTimer
@onready var attack_timer: Timer = $AttackTimer
@onready var model_none: Node3D = $ModelNone
@onready var model_farmer: Node3D = $ModelFarmer
@onready var model_gatherer: Node3D = $ModelGatherer
@onready var model_guard: Node3D = $ModelGuard

func _ready() -> void:
	current_health = max_health
	add_to_group("villagers")
	work_timer.wait_time = work_duration
	retry_timer.wait_time = idle_retry_seconds
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)
	work_timer.timeout.connect(_on_work_complete)
	retry_timer.timeout.connect(_on_retry_timeout)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)
	if Progression.is_purchased("veteran_training"):
		_apply_veteran()
	for model in [model_none, model_farmer, model_gatherer, model_guard]:
		CharacterVisualUtils.apply_idle_pose(model)
	_update_model_visibility()

func _on_upgrade_purchased(id: String) -> void:
	if id == "veteran_training":
		_apply_veteran()

func _apply_veteran() -> void:
	if _veteran_applied:
		return
	_veteran_applied = true
	max_health += veteran_bonus_health
	current_health += veteran_bonus_health
	guard_attack_damage += veteran_bonus_damage
	work_timer.wait_time *= veteran_work_speed_multiplier

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		queue_free()

func set_role(new_role: Role) -> void:
	role = new_role
	if new_role == Role.GUARD:
		collision_layer |= GUARD_LAYER_BIT
	else:
		collision_layer &= ~GUARD_LAYER_BIT
	_update_model_visibility()
	if state == State.IDLE:
		_try_find_task()

func _update_model_visibility() -> void:
	model_none.visible = role == Role.NONE
	model_farmer.visible = role == Role.FARMER
	model_gatherer.visible = role == Role.GATHERER
	model_guard.visible = role == Role.GUARD

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Selection.select(self)

func _physics_process(_delta: float) -> void:
	if state != State.MOVING:
		return

	if target == null or not is_instance_valid(target):
		target = null
		state = State.IDLE
		_try_find_task()
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() <= arrival_distance:
		_start_working()
		return

	velocity = to_target.normalized() * move_speed
	move_and_slide()

func _start_working() -> void:
	state = State.WORKING
	if role == Role.GUARD:
		target.died.connect(_on_guard_target_died, CONNECT_ONE_SHOT)
		attack_timer.start()
	else:
		work_timer.start()

func _on_work_complete() -> void:
	if is_instance_valid(target):
		match role:
			Role.FARMER:
				if target.has_method("is_ready") and target.is_ready():
					target.harvest()
				elif target.has_method("is_empty") and target.is_empty():
					target.plant()
			Role.GATHERER:
				if target.has_method("gather"):
					target.gather()
	target = null
	state = State.IDLE
	_try_find_task()

func _on_attack_timer_timeout() -> void:
	if role == Role.GUARD and is_instance_valid(target):
		target.take_damage(guard_attack_damage)

func _on_guard_target_died() -> void:
	attack_timer.stop()
	target = null
	state = State.IDLE
	_try_find_task()

func _on_retry_timeout() -> void:
	if state == State.IDLE:
		_try_find_task()

func _try_find_task() -> void:
	if role == Role.NONE:
		return
	var found: Node3D = null
	if role == Role.FARMER:
		found = _find_nearest_farm_task()
	elif role == Role.GATHERER:
		found = _find_nearest_gatherable()
	elif role == Role.GUARD:
		found = _find_nearest_enemy()

	if found:
		target = found
		state = State.MOVING
	else:
		retry_timer.start()

func _find_nearest_gatherable() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node.is_available():
			var dist := global_position.distance_to(node.global_position)
			if dist < best_dist:
				best_dist = dist
				best = node
	return best

func _find_nearest_farm_task() -> Node3D:
	var best_ready: Node3D = null
	var best_ready_dist := INF
	var best_empty: Node3D = null
	var best_empty_dist := INF
	for node in get_tree().get_nodes_in_group("farm_plots"):
		var dist := global_position.distance_to(node.global_position)
		if node.is_ready() and dist < best_ready_dist:
			best_ready_dist = dist
			best_ready = node
		elif node.is_empty() and dist < best_empty_dist:
			best_empty_dist = dist
			best_empty = node
	return best_ready if best_ready != null else best_empty

func _find_nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var dist := global_position.distance_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best = node
	return best
