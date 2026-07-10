extends StaticBody3D

# Clickable gray-box resource source (tree/farm plot). Left-click while not
# on cooldown grants resource_type/gather_amount to the Economy autoload.

@export var resource_type: String = "wood"
@export var gather_amount: int = 5
@export var respawn_seconds: float = 3.0

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var cooldown_timer: Timer = $CooldownTimer

func _ready() -> void:
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if cooldown_timer.time_left > 0.0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Economy.add_resource(resource_type, gather_amount)
		mesh.visible = false
		cooldown_timer.start(respawn_seconds)

func _on_cooldown_timeout() -> void:
	mesh.visible = true
