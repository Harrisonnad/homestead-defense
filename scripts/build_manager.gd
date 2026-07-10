extends Node3D

# Gray-box building placement: press 1 to toggle "place wall" mode, 2 to
# toggle "place trap" mode (pressing the other key switches directly), move
# the mouse to raycast a snapped ghost preview against the ground plane, and
# left-click to spend resources and instance the real building.

enum BuildType { NONE, WALL, TRAP }

@export var wall_scene: PackedScene
@export var wood_cost: int = 10
@export var trap_scene: PackedScene
@export var trap_cost_type: String = "stone"
@export var trap_cost_amount: int = 8
@export var grid_size: float = 2.0
@export var camera_path: NodePath
@export var entities_container_path: NodePath

@onready var ghost_wall: MeshInstance3D = $GhostWall
@onready var ghost_trap: MeshInstance3D = $GhostTrap
@onready var camera: Camera3D = get_node(camera_path)
@onready var entities_container: Node3D = get_node(entities_container_path)

const GROUND_PLANE := Plane(Vector3.UP, 0.0)
const GHOST_COLOR_OK := Color(0.2, 1.0, 0.3, 0.4)
const GHOST_COLOR_BLOCKED := Color(1.0, 0.2, 0.2, 0.4)

var build_type: BuildType = BuildType.NONE
var ghost_valid_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	ghost_wall.visible = false
	ghost_trap.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_set_build_type(BuildType.NONE if build_type == BuildType.WALL else BuildType.WALL)
		elif event.keycode == KEY_2:
			_set_build_type(BuildType.NONE if build_type == BuildType.TRAP else BuildType.TRAP)
	elif build_type != BuildType.NONE and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_place()

func _set_build_type(new_type: BuildType) -> void:
	build_type = new_type
	ghost_wall.visible = build_type == BuildType.WALL
	ghost_trap.visible = build_type == BuildType.TRAP

func _active_ghost() -> MeshInstance3D:
	match build_type:
		BuildType.WALL:
			return ghost_wall
		BuildType.TRAP:
			return ghost_trap
		_:
			return null

func _cost_type() -> String:
	return "wood" if build_type == BuildType.WALL else trap_cost_type

func _cost_amount() -> int:
	return wood_cost if build_type == BuildType.WALL else trap_cost_amount

func _process(_delta: float) -> void:
	if build_type == BuildType.NONE:
		return

	var ghost := _active_ghost()
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

	var affordable := Economy.can_afford(_cost_type(), _cost_amount())
	var mat := ghost.get_surface_override_material(0) as StandardMaterial3D
	mat.albedo_color = GHOST_COLOR_OK if affordable else GHOST_COLOR_BLOCKED

func _try_place() -> void:
	if not Economy.spend_resource(_cost_type(), _cost_amount()):
		return
	var scene := wall_scene if build_type == BuildType.WALL else trap_scene
	var instance := scene.instantiate()
	entities_container.add_child(instance)
	instance.global_position = ghost_valid_position
