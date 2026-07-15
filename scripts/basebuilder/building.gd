extends StaticBody3D
class_name Building

# Shared base for player-built structures beyond Wall/Trap (which keep their
# existing scripts). Lives on collision layer 2, same as Wall, so enemies
# already engage it via enemy.gd's generalized has_method("take_damage")
# AttackRange check - no enemy-side changes needed. Category effects apply
# when this node enters the tree (i.e. when construction actually
# completes - the ghost/in-progress phase is a separate ConstructionSite
# node that only instances this scene on completion) and are cleanly
# reverted on death.

@export var max_health: int = 80
@export var population_cap_bonus: int = 0
@export var storage_cap_bonus: int = 0
@export var passive_resource_output: Dictionary = {}

var current_health: int
var footprint_origin: Vector2i
var footprint_size: Vector2i = Vector2i(1, 1)
var placement_grid: PlacementGrid

signal died

func _ready() -> void:
	current_health = max_health
	add_to_group("buildings")
	if population_cap_bonus != 0:
		GameState.add_population_cap(population_cap_bonus)
	if storage_cap_bonus != 0:
		Economy.add_storage_cap_all(storage_cap_bonus)
	if not passive_resource_output.is_empty():
		GameClock.day_started.connect(_on_day_started)

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		_revert_effects()
		if placement_grid:
			placement_grid.release(footprint_origin, footprint_size)
		queue_free()

func _revert_effects() -> void:
	if population_cap_bonus != 0:
		GameState.add_population_cap(-population_cap_bonus)
	if storage_cap_bonus != 0:
		Economy.add_storage_cap_all(-storage_cap_bonus)

func _on_day_started(_day_count: int) -> void:
	for type in passive_resource_output:
		Economy.add_resource(type, passive_resource_output[type])
