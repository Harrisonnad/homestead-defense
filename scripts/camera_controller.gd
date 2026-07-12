extends Camera3D

# Pan/zoom for the fixed-angle isometric camera. Translation only — never
# rotates — so the sprite quads placed for this viewing angle stay valid.

@export var pan_speed: float = 14.0
@export var zoom_step: float = 2.0
@export var min_x: float = -18.0
@export var max_x: float = 18.0
@export var min_z: float = 4.0
@export var max_z: float = 34.0
@export var min_y: float = 10.0
@export var max_y: float = 26.0

func _process(delta: float) -> void:
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if pan != Vector3.ZERO:
		position += pan.normalized() * pan_speed * delta
		_clamp_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position += -global_transform.basis.z.normalized() * zoom_step
			_clamp_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position += global_transform.basis.z.normalized() * zoom_step
			_clamp_position()

func _clamp_position() -> void:
	position.x = clampf(position.x, min_x, max_x)
	position.z = clampf(position.z, min_z, max_z)
	position.y = clampf(position.y, min_y, max_y)
