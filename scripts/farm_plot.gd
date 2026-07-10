extends StaticBody3D
class_name FarmPlot

# Gray-box farm plot: EMPTY -> (plant) -> GROWING -> (days_to_grow dawns) ->
# READY -> (harvest) -> EMPTY. Growth is tied to GameClock.day_started so it
# stays locked to the core day/night rhythm rather than a separate timer.

enum State { EMPTY, GROWING, READY }

@export var food_yield: int = 15
@export var days_to_grow: int = 1

const CROP_COLOR_GROWING := Color(0.35, 0.55, 0.2)
const CROP_COLOR_READY := Color(0.85, 0.7, 0.15)

var state: State = State.EMPTY
var _days_growing: int = 0

@onready var crop_mesh: MeshInstance3D = $Crop

func _ready() -> void:
	add_to_group("farm_plots")
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)
	GameClock.day_started.connect(_on_day_started)
	_update_visual()

func is_ready() -> bool:
	return state == State.READY

func is_empty() -> bool:
	return state == State.EMPTY

func plant() -> void:
	if state != State.EMPTY:
		return
	state = State.GROWING
	_days_growing = 0
	_update_visual()

func harvest() -> void:
	if state != State.READY:
		return
	Economy.add_resource("food", food_yield)
	state = State.EMPTY
	_update_visual()

func _on_day_started(_day_count: int) -> void:
	if state != State.GROWING:
		return
	_days_growing += 1
	if _days_growing >= days_to_grow:
		state = State.READY
		_update_visual()

func _update_visual() -> void:
	crop_mesh.visible = state != State.EMPTY
	if state == State.GROWING:
		crop_mesh.get_surface_override_material(0).albedo_color = CROP_COLOR_GROWING
	elif state == State.READY:
		crop_mesh.get_surface_override_material(0).albedo_color = CROP_COLOR_READY

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	match state:
		State.EMPTY:
			plant()
		State.READY:
			harvest()
		State.GROWING:
			pass
