extends CharacterBody3D
class_name Villager

# Gray-box villager: click to select (routes through the Selection autoload
# to the role-assignment UI), then once assigned a Role, autonomously walks
# to the nearest matching task and performs it in a loop. Farmer/Gatherer
# tasks are a single timed action (WorkTimer); Guard instead fights whatever
# it walked up to on a repeating AttackTimer until it or the enemy dies.

enum Role { NONE, FARMER, GATHERER, GUARD }
enum State { IDLE, MOVING, WORKING, WANDERING }

const GUARD_LAYER_BIT := 8
const PACK_MATERIAL := preload("res://assets/custom_pack/day_night.tres")
# Role tint on the shared sk_villager mesh (§4-style color coding, reused
# from the old KayKit-recolor Enemy approach) - the pack has one Villager
# mesh, not 4 separate outfits, so role reads via a vest-color tint instead
# (targeted at just the "vest" material - see tint_meshes' material_filter).
const ROLE_TINTS := {
	Role.FARMER: Color(0.62, 0.78, 0.5, 1),
	Role.GATHERER: Color(0.82, 0.62, 0.4, 1),
	Role.GUARD: Color(0.5, 0.58, 0.72, 1),
}

@export var move_speed: float = 3.0
@export var work_duration: float = 1.5
@export var arrival_distance: float = 0.6
@export var idle_retry_seconds: float = 1.0
# Wander (no assigned task, or nothing to do right now): amble to a random
# point near the base and pause, purely so an idle villager reads as "alive
# but unassigned" rather than a frozen prop - distinct from wander_radius
# and a slower wander_speed so it doesn't look like task-focused movement.
@export var wander_radius: float = 5.0
@export var wander_speed: float = 1.5
@export var wander_min_pause: float = 1.0
@export var wander_max_pause: float = 2.5
@export var guard_attack_damage: int = 12
@export var max_health: int = 35
@export var veteran_bonus_health: int = 15
@export var veteran_bonus_damage: int = 6
@export var veteran_work_speed_multiplier: float = 0.7

var role: Role = Role.NONE
var state: State = State.IDLE
var target: Node3D = null
var _wander_target: Vector3
var _rng := RandomNumberGenerator.new()
var current_health: int
var _veteran_applied: bool = false
# Veteran Guard achievement: only accumulates while both this villager is
# currently a Guard AND Veteran Training is already purchased (per the
# design doc's "survives 5+ nights afterward" wording - nights before the
# upgrade or spent on another role don't count, and switching away resets
# it since it's specifically about this villager holding the line).
var _guard_nights_survived: int = 0

signal died

@onready var work_timer: Timer = $WorkTimer
@onready var retry_timer: Timer = $RetryTimer
@onready var wander_timer: Timer = $WanderTimer
@onready var attack_timer: Timer = $AttackTimer
@onready var model_none: Node3D = $ModelNone
@onready var model_farmer: Node3D = $ModelFarmer
@onready var model_gatherer: Node3D = $ModelGatherer
@onready var model_guard: Node3D = $ModelGuard
# Held tools so each role reads at a glance by silhouette, not just tunic
# tint - a hoe/axe/sword is a far stronger "what is this villager doing"
# signal than color alone (no tool for NONE, matching "not assigned yet").
@onready var tool_farmer: Node3D = $ToolFarmer
@onready var tool_gatherer: Node3D = $ToolGatherer
@onready var tool_guard: Node3D = $ToolGuard
# Role-distinguishing outfits (headwear + a small back/shoulder accessory) -
# see gen_prop_farmer_hat.py / gen_prop_gatherer_gear.py / gen_prop_guard_gear.py.
# Built in sk_villager's own local coordinate frame, so they use the exact
# same fixed remap transform as the ModelXXX nodes (see villager.tscn) -
# unlike the tools, which are generic hand-held props positioned by a
# hand-tuned offset instead. Role.NONE gets no gear (bare head/body) -
# that's deliberately its own distinct "not yet assigned a job" look, not
# an oversight.
@onready var gear_farmer: Node3D = $GearFarmer
@onready var gear_gatherer: Node3D = $GearGatherer
@onready var gear_guard: Node3D = $GearGuard

func _ready() -> void:
	current_health = max_health
	_rng.randomize()
	add_to_group("villagers")
	work_timer.wait_time = work_duration
	retry_timer.wait_time = idle_retry_seconds
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)
	work_timer.timeout.connect(_on_work_complete)
	retry_timer.timeout.connect(_on_retry_timeout)
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)
	GameClock.day_started.connect(_on_day_started)
	if Progression.is_purchased("veteran_training"):
		_apply_veteran()
	for r in [Role.NONE, Role.FARMER, Role.GATHERER, Role.GUARD]:
		var model := _model_for_role(r)
		# sk_villager carries its own dedicated materials now (fur, eyes,
		# horns, outfit - see gen_villager.py), not the shared trim-sheet
		# day/night material every other pack mesh uses, so no
		# apply_pack_material() here. Role tint targets just the "vest"
		# surface (tint_meshes' material_filter) so it recolors the
		# outfit without touching fur/eyes/horns.
		if ROLE_TINTS.has(r):
			CharacterVisualUtils.tint_meshes(model, ROLE_TINTS[r], "vest")
		CharacterVisualUtils.play_creature_idle(model, "sk_villager")
	# Tools keep their own natural wood/stone/metal colors (not role-tinted)
	# so they read as a distinct object against the tinted tunic, not blend
	# into it.
	for tool in [tool_farmer, tool_gatherer, tool_guard]:
		CharacterVisualUtils.apply_pack_material(tool, PACK_MATERIAL)
	_update_model_visibility()
	_try_find_task()

func _model_for_role(r: Role) -> Node3D:
	match r:
		Role.FARMER: return model_farmer
		Role.GATHERER: return model_gatherer
		Role.GUARD: return model_guard
		_: return model_none

func _on_upgrade_purchased(id: String) -> void:
	if id == "veteran_training":
		_apply_veteran()

func _on_day_started(_day_count: int) -> void:
	if role == Role.GUARD and Progression.is_purchased("veteran_training"):
		_guard_nights_survived += 1
		if _guard_nights_survived >= 5:
			AchievementManager.on_veteran_guard_milestone()
	else:
		_guard_nights_survived = 0

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
		AchievementManager.on_villager_died()
		NightReport.on_villager_lost()
		queue_free()

func set_role(new_role: Role) -> void:
	role = new_role
	if new_role == Role.GUARD:
		collision_layer |= GUARD_LAYER_BIT
	else:
		collision_layer &= ~GUARD_LAYER_BIT
	_update_model_visibility()
	_reset_task()
	_try_find_task()

# Drops whatever task the old role was mid-way through (a leftover target
# from the previous role is often the wrong kind of node for the new one -
# e.g. a resource node isn't an Enemy, so _start_working()'s Guard branch
# would error out on target.died.connect() and leave state stuck at
# WORKING forever with no timer left running to recover it).
func _reset_task() -> void:
	work_timer.stop()
	attack_timer.stop()
	retry_timer.stop()
	wander_timer.stop()
	if target != null and is_instance_valid(target) and target.has_signal("died") and target.died.is_connected(_on_guard_target_died):
		target.died.disconnect(_on_guard_target_died)
	target = null
	state = State.IDLE

func _update_model_visibility() -> void:
	model_none.visible = role == Role.NONE
	model_farmer.visible = role == Role.FARMER
	model_gatherer.visible = role == Role.GATHERER
	model_guard.visible = role == Role.GUARD
	tool_farmer.visible = role == Role.FARMER
	tool_gatherer.visible = role == Role.GATHERER
	tool_guard.visible = role == Role.GUARD
	gear_farmer.visible = role == Role.FARMER
	gear_gatherer.visible = role == Role.GATHERER
	gear_guard.visible = role == Role.GUARD

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Selection.select(self)

func _physics_process(_delta: float) -> void:
	if state == State.WANDERING:
		_process_wandering()
		return

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
	CharacterVisualUtils.face_direction(self, to_target)
	move_and_slide()

func _process_wandering() -> void:
	var to_target := _wander_target - global_position
	to_target.y = 0.0
	if to_target.length() <= arrival_distance:
		velocity = Vector3.ZERO
		state = State.IDLE
		wander_timer.wait_time = _rng.randf_range(wander_min_pause, wander_max_pause)
		wander_timer.start()
		return

	velocity = to_target.normalized() * wander_speed
	CharacterVisualUtils.face_direction(self, to_target)
	move_and_slide()

func _start_wandering() -> void:
	state = State.WANDERING
	_wander_target = _pick_wander_point()

func _pick_wander_point() -> Vector3:
	var homestead := get_tree().get_first_node_in_group("homestead")
	var base_pos: Vector3 = homestead.global_position if homestead != null else global_position
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(0.0, wander_radius)
	return base_pos + Vector3(cos(angle), 0.0, sin(angle)) * distance

func _on_wander_timer_timeout() -> void:
	if state == State.IDLE:
		_start_wandering()

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
	if state == State.IDLE or state == State.WANDERING:
		_try_find_task()

# Role.NONE (not yet assigned) always falls through to "not found" below, so
# an unassigned villager wanders near the base just like an assigned one
# with nothing to do right now - both read as "inactive" rather than frozen.
func _try_find_task() -> void:
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
		if state != State.WANDERING:
			_start_wandering()

# Strictly prefers Economy.priority_resource_type when one is set (#29: no
# way to prioritize which resource Gatherers fetch) - if any available node
# of that type exists anywhere, it wins over a closer node of another type;
# nearest-available-of-any-type (the original behavior) is still the
# fallback both when no priority is set and when the priority type has no
# available node right now.
func _find_nearest_gatherable() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	var priority_type := Economy.priority_resource_type
	var priority_best: Node3D = null
	var priority_best_dist := INF
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node.is_available():
			var dist := global_position.distance_to(node.global_position)
			if dist < best_dist:
				best_dist = dist
				best = node
			if priority_type != "" and node.resource_type == priority_type and dist < priority_best_dist:
				priority_best_dist = dist
				priority_best = node
	return priority_best if priority_best != null else best

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
