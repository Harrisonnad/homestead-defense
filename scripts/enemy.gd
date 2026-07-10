extends CharacterBody3D
class_name Enemy

# Gray-box enemy: walks straight toward `target` each physics frame. If it
# enters attack range of a Wall it stops and chips away at it on a timer;
# once the wall falls (or it was never blocked) it continues to `target` and
# triggers a resource raid on arrival.

@export var move_speed: float = 2.5
@export var attack_damage: int = 10
@export var arrival_distance: float = 0.6
@export var raid_resource_loss: Dictionary = {"wood": 5, "food": 5}

var target: Node3D = null
var current_wall: Wall = null

@onready var attack_range: Area3D = $AttackRange
@onready var attack_timer: Timer = $AttackTimer

func _ready() -> void:
	attack_range.body_entered.connect(_on_attack_range_body_entered)
	attack_range.body_exited.connect(_on_attack_range_body_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func _physics_process(_delta: float) -> void:
	if current_wall != null or target == null:
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() <= arrival_distance:
		_reach_target()
		return

	velocity = to_target.normalized() * move_speed
	move_and_slide()

func _on_attack_range_body_entered(body: Node3D) -> void:
	if current_wall != null or not body.is_in_group("walls"):
		return
	current_wall = body as Wall
	current_wall.died.connect(_on_wall_died, CONNECT_ONE_SHOT)
	attack_timer.start()

func _on_attack_range_body_exited(body: Node3D) -> void:
	if body == current_wall:
		current_wall = null
		attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if current_wall != null:
		current_wall.take_damage(attack_damage)

func _on_wall_died() -> void:
	current_wall = null
	attack_timer.stop()

func _reach_target() -> void:
	for type in raid_resource_loss:
		Economy.remove_resource(type, raid_resource_loss[type])
	queue_free()
