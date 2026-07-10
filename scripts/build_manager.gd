extends Node3D

# Gray-box building placement: press B to toggle "place wall" mode, move the
# mouse to raycast a snapped ghost preview against the ground plane, and
# left-click to spend wood and instance a real Wall.

@export var wall_scene: PackedScene
@export var wood_cost: int = 10
@export var grid_size: float = 2.0
@export var camera_path: NodePath
@export var entities_container_path: NodePath

@onready var ghost: MeshInstance3D = $Ghost
@onready var camera: Camera3D = get_node(camera_path)
@onready var entities_container: Node3D = get_node(entities_container_path)

const GROUND_PLANE := Plane(Vector3.UP, 0.0)
const GHOST_COLOR_OK := Color(0.2, 1.0, 0.3, 0.4)
const GHOST_COLOR_BLOCKED := Color(1.0, 0.2, 0.2, 0.4)

var placing: bool = false
var ghost_valid_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	ghost.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		placing = not placing
		ghost.visible = placing
	elif placing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_place_wall()

func _process(_delta: float) -> void:
	if not placing:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var hit = GROUND_PLANE.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return

	var snapped := Vector3(
		round(hit.x / grid_size) * grid_size,
		0.0,
		round(hit.z / grid_size) * grid_size
	)
	ghost_valid_position = snapped
	ghost.position = snapped

	var affordable := Economy.can_afford("wood", wood_cost)
	var mat := ghost.get_surface_override_material(0) as StandardMaterial3D
	mat.albedo_color = GHOST_COLOR_OK if affordable else GHOST_COLOR_BLOCKED

func _try_place_wall() -> void:
	if not Economy.spend_resource("wood", wood_cost):
		return
	var wall := wall_scene.instantiate()
	entities_container.add_child(wall)
	wall.global_position = ghost_valid_position
