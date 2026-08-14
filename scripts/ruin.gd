extends StaticBody3D
class_name Ruin

# A repairable ruined building scattered on the map (see
# map_builder.gd._place_ruins()) - a mid/late-game exploration bonus.
# Clicking it while affording repair_cost instantly grants a free, fully
# functioning reward_def building at this exact spot instead of the normal
# build-and-wait ConstructionSite flow. Shown as the reward building's own
# model, ghost-tinted (CharacterVisualUtils.apply_ghost_tint, same utility
# BuildManager uses for placement previews) so the ruin previews what
# repairing it will produce.

const GHOST_TINT := Color(0.35, 0.35, 0.32, 0.6)

@export var reward_def: BuildingDef
@export var repair_cost: Dictionary = {"wood": 50, "stone": 50}

@onready var model_root: Node3D = $Model

var footprint_origin: Vector2i
var footprint_size: Vector2i = Vector2i(1, 1)
var placement_grid: PlacementGrid

func _ready() -> void:
	add_to_group("ruins")
	input_ray_pickable = true
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if reward_def:
		_build_ghost_model()

func _build_ghost_model() -> void:
	var instance: Node3D = reward_def.scene.instantiate()
	instance.set_script(null)
	_disable_collision(instance)
	model_root.add_child(instance)
	CharacterVisualUtils.apply_ghost_tint(instance, GHOST_TINT)

func _disable_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_collision(child)

func _on_mouse_entered() -> void:
	var tooltip := get_tree().get_first_node_in_group("world_tooltip")
	if tooltip:
		tooltip.show_text("Ruined %s - repair for %s" % [reward_def.building_name, _cost_text()])

func _on_mouse_exited() -> void:
	var tooltip := get_tree().get_first_node_in_group("world_tooltip")
	if tooltip:
		tooltip.hide_text()

func _cost_text() -> String:
	var parts: Array[String] = []
	for type in repair_cost:
		parts.append("%d %s" % [repair_cost[type], type])
	return ", ".join(parts)

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_repair()

func _try_repair() -> void:
	if not Economy.can_afford_all(repair_cost):
		NotificationManager.notify("Can't repair yet: need %s" % _cost_text())
		return
	Economy.spend_all(repair_cost)

	var building: Node3D = reward_def.scene.instantiate()
	get_parent().add_child(building)
	building.global_transform = global_transform
	building.footprint_origin = footprint_origin
	building.footprint_size = footprint_size
	building.placement_grid = placement_grid
	if "chokepoint" in building and placement_grid:
		building.chokepoint = placement_grid.is_chokepoint(footprint_origin)
	building.set_meta("building_def_path", reward_def.resource_path)
	building.add_to_group("player_buildings")
	AchievementManager.on_ruin_repaired()
	AchievementManager.on_building_completed(building)

	NotificationManager.notify("Repaired: %s" % reward_def.building_name)
	var tooltip := get_tree().get_first_node_in_group("world_tooltip")
	if tooltip:
		tooltip.hide_text()
	queue_free()
