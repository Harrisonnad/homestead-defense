extends CharacterBody3D
class_name Villager

# Gray-box villager: click to select (routes through the Selection autoload
# to the role-assignment UI), then once assigned a Role, autonomously walks
# to the nearest matching task, "works" for a fixed duration, performs the
# same action a player click would, and goes idle to search again.

enum Role { NONE, FARMER, GATHERER }
enum State { IDLE, MOVING, WORKING }

@export var move_speed: float = 3.0
@export var work_duration: float = 1.5
@export var arrival_distance: float = 0.6
@export var idle_retry_seconds: float = 1.0

var role: Role = Role.NONE
var state: State = State.IDLE
var target: Node3D = null

@onready var work_timer: Timer = $WorkTimer
@onready var retry_timer: Timer = $RetryTimer

func _ready() -> void:
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)
	work_timer.timeout.connect(_on_work_complete)
	retry_timer.timeout.connect(_on_retry_timeout)

func set_role(new_role: Role) -> void:
	role = new_role
	if state == State.IDLE:
		_try_find_task()

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
		state = State.WORKING
		work_timer.start()
		return

	velocity = to_target.normalized() * move_speed
	move_and_slide()

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
