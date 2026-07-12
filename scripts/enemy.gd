extends CharacterBody3D
class_name Enemy

# Gray-box enemy: walks straight toward `target` each physics frame. If it
# enters attack range of anything that can take damage (a Wall or a guarding
# Villager) it stops and chips away at it on a timer; once that target falls
# (or it was never blocked) it continues to `target` and triggers a resource
# raid on arrival. Has its own health so Guards can fight back.

@export var move_speed: float = 2.5
@export var attack_damage: int = 10
@export var arrival_distance: float = 0.6
@export var raid_resource_loss: Dictionary = {"wood": 5, "food": 5}
@export var max_health: int = 30
@export var tint_color: Color = Color(0.55, 0.15, 0.15)

var target: Node3D = null
var current_target: Node3D = null
var current_health: int

signal died

@onready var attack_range: Area3D = $AttackRange
@onready var attack_timer: Timer = $AttackTimer
@onready var model: Node3D = $Model

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	attack_range.body_entered.connect(_on_attack_range_body_entered)
	attack_range.body_exited.connect(_on_attack_range_body_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	CharacterVisualUtils.apply_idle_pose(model)
	CharacterVisualUtils.tint_meshes(model, tint_color)

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		queue_free()

func _physics_process(_delta: float) -> void:
	if current_target != null or target == null:
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() <= arrival_distance:
		_reach_target()
		return

	velocity = to_target.normalized() * move_speed
	move_and_slide()

func _on_attack_range_body_entered(body: Node3D) -> void:
	if current_target != null or not body.has_method("take_damage"):
		return
	current_target = body
	current_target.died.connect(_on_target_died, CONNECT_ONE_SHOT)
	attack_timer.start()

func _on_attack_range_body_exited(body: Node3D) -> void:
	if body == current_target:
		current_target = null
		attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if current_target != null:
		current_target.take_damage(attack_damage)

func _on_target_died() -> void:
	current_target = null
	attack_timer.stop()

func _reach_target() -> void:
	for type in raid_resource_loss:
		Economy.remove_resource(type, raid_resource_loss[type])
	queue_free()
