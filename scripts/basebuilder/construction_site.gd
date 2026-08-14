extends StaticBody3D
class_name ConstructionSite

# On collision layer 2 (set in the scene) so it's attackable like any other
# building while under construction - a raid can interrupt a build.

# Transient in-progress visual (sm_scaffold from the custom pack) that swaps itself for
# the real building scene once build_time_seconds elapses. Has its own HP
# so a raid can interrupt construction, in which case the footprint tile(s)
# are released rather than left permanently blocked.

const SCAFFOLD_NATIVE_WIDTH := 1.0
const PACK_MATERIAL := preload("res://assets/custom_pack/day_night.tres")

@export var build_time_seconds: float = 3.0
@export var final_scene: PackedScene
@export var footprint_size: Vector2i = Vector2i(1, 1)
@export var max_health: int = 20
@export var source_def_path: String = "" # BuildingDef resource_path, for save/load

var current_health: int
var placement_grid: PlacementGrid
var footprint_origin: Vector2i

signal completed(building: Node)
signal died

@onready var model: Node3D = $ScaffoldModel
@onready var timer: Timer = $BuildTimer

func _ready() -> void:
	current_health = max_health
	CharacterVisualUtils.apply_pack_material(model, PACK_MATERIAL)
	var scale_factor: float = maxf(footprint_size.x, footprint_size.y) / SCAFFOLD_NATIVE_WIDTH
	model.scale = Vector3.ONE * scale_factor
	timer.wait_time = build_time_seconds
	timer.one_shot = true
	timer.timeout.connect(_on_complete)
	timer.start()

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		if placement_grid:
			placement_grid.release(footprint_origin, footprint_size)
		queue_free()

func _on_complete() -> void:
	var building: Node3D = final_scene.instantiate()
	get_parent().add_child(building)
	building.global_transform = global_transform
	building.footprint_origin = footprint_origin
	building.footprint_size = footprint_size
	building.placement_grid = placement_grid
	if "chokepoint" in building and placement_grid:
		building.chokepoint = placement_grid.is_chokepoint(footprint_origin)
	# Generic optional hook for buildings that need their footprint_origin
	# already assigned before doing anything (Bridge - see scripts/bridge.gd -
	# can't clear water collision in its own _ready(), which runs synchronously
	# during add_child() above, before footprint_origin is set here).
	if building.has_method("on_footprint_ready"):
		building.on_footprint_ready()
	if source_def_path != "":
		building.set_meta("building_def_path", source_def_path)
	building.add_to_group("player_buildings")
	completed.emit(building)
	AchievementManager.on_building_completed(building)
	queue_free()
