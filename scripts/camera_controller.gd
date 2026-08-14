extends Camera3D

# Pan/zoom for the fixed-angle isometric camera. Translation only — never
# rotates — so the sprite quads placed for this viewing angle stay valid.
# Also shakes briefly on Homestead damage (same deferred group-lookup
# pattern damage_vignette.gd/hud.gd/notification_manager.gd all use) so a
# raid landing a hit reads as more than just the red flash.
#
# Supports gamepad (left stick pan, shoulder-button zoom) alongside
# WASD/arrows/mouse-wheel - building placement itself stays mouse/touch-only
# (Steam Deck's trackpad-as-cursor covers that without extra code here).

@export var pan_speed: float = 14.0
@export var zoom_step: float = 2.0
@export var min_x: float = -18.0
@export var max_x: float = 18.0
@export var min_z: float = 4.0
@export var max_z: float = 34.0
@export var min_y: float = 10.0
@export var max_y: float = 26.0
@export var shake_strength: float = 0.35
@export var shake_decay: float = 6.0 # magnitude lost per second
@export var joy_deadzone: float = 0.2
@export var joy_device: int = 0

var _base_position: Vector3
var _shake_magnitude: float = 0.0
var _last_health: int = -1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_base_position = position
	_rng.randomize()
	_connect_homestead.call_deferred()

func _connect_homestead() -> void:
	var homestead := get_tree().get_first_node_in_group("homestead")
	if homestead == null:
		return
	homestead.health_changed.connect(_on_homestead_health_changed)
	_last_health = homestead.current_health

func _on_homestead_health_changed(current: int) -> void:
	if _last_health != -1 and current < _last_health:
		shake()
	_last_health = current

func shake(strength: float = shake_strength) -> void:
	_shake_magnitude = maxf(_shake_magnitude, strength)

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

	# Left stick pans the same as WASD, direct axis polling rather than
	# InputMap actions so this works with any connected gamepad without
	# project.godot input-map edits.
	var stick_x := Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_X)
	var stick_y := Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_Y)
	if absf(stick_x) > joy_deadzone:
		pan.x += stick_x
	if absf(stick_y) > joy_deadzone:
		pan.z += stick_y

	if pan != Vector3.ZERO:
		_base_position += pan.normalized() * pan_speed * delta
		_clamp_base_position()

	if _shake_magnitude > 0.0:
		var offset := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * _shake_magnitude
		position = _base_position + offset
		_shake_magnitude = maxf(_shake_magnitude - shake_decay * delta, 0.0)
	else:
		position = _base_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_zoom(-1.0)
		elif event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_zoom(1.0)

func _zoom(direction: float) -> void:
	_base_position += global_transform.basis.z.normalized() * zoom_step * direction
	_clamp_base_position()

func _clamp_base_position() -> void:
	_base_position.x = clampf(_base_position.x, min_x, max_x)
	_base_position.z = clampf(_base_position.z, min_z, max_z)
	_base_position.y = clampf(_base_position.y, min_y, max_y)
