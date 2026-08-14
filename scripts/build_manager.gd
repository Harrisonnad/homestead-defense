extends Node3D

# Grid-snapped building placement per docs/spec_base_builder.md. build_menu.gd
# owns the palette UI (B toggle, 1-7 hotkeys) and calls start_placing() with
# a BuildingDef; this script owns the ghost preview, per-tile legality via
# the active MapBuilder's PlacementGrid, and instancing a ConstructionSite
# on confirm. R rotates the ghost, right-click/Escape cancels.

@export var camera_path: NodePath
@export var entities_container_path: NodePath
@export var map_builder_path: NodePath
@export var construction_site_scene: PackedScene
@export var reinforced_stone_surcharge: int = 6

@onready var camera: Camera3D = get_node(camera_path)
@onready var entities_container: Node3D = get_node(entities_container_path)
@onready var map_builder = get_node(map_builder_path)

const GROUND_PLANE := Plane(Vector3.UP, 0.0)
const GHOST_COLOR_OK := Color(0.2, 1.0, 0.3, 0.45)
const GHOST_COLOR_BLOCKED := Color(1.0, 0.2, 0.2, 0.45)
const GHOST_COLOR_BONUS := Color(1.0, 0.85, 0.2, 0.5)

var selected_def: BuildingDef = null
var rotation_steps: int = 0
var ghost_instance: Node3D = null
var ghost_origin_tile: Vector2i = Vector2i.ZERO
var ghost_check: Dictionary = {"ok": false, "reason": "", "chokepoint": false, "bonus": 1.0}

var _last_ghost_color := Color(0, 0, 0, 0)

func start_placing(def: BuildingDef) -> void:
	if selected_def == def:
		cancel_placing()
		return
	_clear_ghost()
	selected_def = def
	rotation_steps = 0
	ghost_instance = def.scene.instantiate()
	ghost_instance.set_script(null)
	_disable_ghost_collision(ghost_instance)
	add_child(ghost_instance)
	_last_ghost_color = Color(0, 0, 0, 0)

func cancel_placing() -> void:
	selected_def = null
	_clear_ghost()

func _clear_ghost() -> void:
	if ghost_instance:
		ghost_instance.queue_free()
		ghost_instance = null

func _disable_ghost_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_ghost_collision(child)

func _unhandled_input(event: InputEvent) -> void:
	if selected_def == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placing()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		rotation_steps = (rotation_steps + 1) % 4
	elif event.is_action_pressed("ui_cancel"):
		cancel_placing()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if selected_def == null or ghost_instance == null:
		return

	var grid: PlacementGrid = map_builder.placement_grid
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var hit = GROUND_PLANE.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return

	var footprint := selected_def.footprint_size
	var origin_tile := grid.world_to_tile(hit) - Vector2i((footprint.x - 1) / 2, (footprint.y - 1) / 2)
	ghost_origin_tile = origin_tile

	var center := grid.tile_to_world(origin_tile) + Vector3((footprint.x - 1) * 0.5, 0.0, (footprint.y - 1) * 0.5)
	ghost_instance.global_position = center
	ghost_instance.rotation.y = rotation_steps * PI / 2.0

	ghost_check = grid.check_placement(origin_tile, footprint, selected_def.category)
	var affordable := Economy.can_afford_all(_actual_cost())

	var new_color: Color
	if not ghost_check["ok"] or not affordable:
		new_color = GHOST_COLOR_BLOCKED
	elif ghost_check["bonus"] > 1.0 or (selected_def.category in ["defense", "wall"] and ghost_check["chokepoint"]):
		new_color = GHOST_COLOR_BONUS
	else:
		new_color = GHOST_COLOR_OK

	if new_color != _last_ghost_color:
		CharacterVisualUtils.apply_ghost_tint(ghost_instance, new_color)
		_last_ghost_color = new_color

func _actual_cost() -> Dictionary:
	var costs: Dictionary = selected_def.resource_cost.duplicate()
	if selected_def.category == "wall" and Progression.wall_tier() >= 2:
		costs["stone"] = costs.get("stone", 0) + reinforced_stone_surcharge
	return costs

func _try_place() -> void:
	var costs := _actual_cost()
	if not ghost_check.get("ok", false):
		NotificationManager.notify("Can't build there: %s" % ghost_check.get("reason", "blocked"))
		return
	if not Economy.can_afford_all(costs):
		NotificationManager.notify("Not enough resources for %s" % selected_def.building_name)
		return

	var grid: PlacementGrid = map_builder.placement_grid
	if not grid.check_placement(ghost_origin_tile, selected_def.footprint_size, selected_def.category)["ok"]:
		return
	if not Economy.spend_all(costs):
		return
	grid.claim(ghost_origin_tile, selected_def.footprint_size)

	var site: ConstructionSite = construction_site_scene.instantiate()
	entities_container.add_child(site)
	site.global_position = ghost_instance.global_position
	site.rotation.y = rotation_steps * PI / 2.0
	site.build_time_seconds = selected_def.build_time_seconds
	site.final_scene = selected_def.scene
	site.footprint_size = selected_def.footprint_size
	site.footprint_origin = ghost_origin_tile
	site.placement_grid = grid
	site.source_def_path = selected_def.resource_path
