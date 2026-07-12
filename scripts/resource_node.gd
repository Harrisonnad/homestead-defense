extends StaticBody3D

# Clickable gray-box resource source (tree/rock). Left-click (or the
# villager AI calling gather() directly) grants resource_type/gather_amount
# to the Economy autoload while not on cooldown.

@export var resource_type: String = "wood"
@export var gather_amount: int = 5
@export var respawn_seconds: float = 3.0

@onready var visual: Node3D = $Visual
@onready var cooldown_timer: Timer = $CooldownTimer

func _ready() -> void:
	add_to_group("gatherable")
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)

func is_available() -> bool:
	return cooldown_timer.time_left <= 0.0

func gather() -> void:
	if not is_available():
		return
	Economy.add_resource(resource_type, gather_amount * Progression.gather_multiplier())
	visual.visible = false
	cooldown_timer.start(respawn_seconds)

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		gather()

func _on_cooldown_timeout() -> void:
	visual.visible = true
