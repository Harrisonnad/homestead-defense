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

const PACK_MATERIAL := preload("res://assets/custom_pack/day_night.tres")
const NIGHT_LIGHT_SCRIPT := preload("res://scripts/night_light.gd")

@export var max_health: int = 80
@export var population_cap_bonus: int = 0
@export var storage_cap_bonus: int = 0
@export var passive_resource_output: Dictionary = {}

# Age/Era economy scaling (docs/spec_base_builder.md's Homestead ->
# Established Farm -> Fortified Farmstead progression - see
# Progression.homestead_age()). _base_* capture each building's own
# scene-authored numbers once at _ready() so _apply_age() can always
# recompute from the same reference point rather than compounding.
const AGE_ECONOMY_MULTIPLIER := {1: 1.0, 2: 1.5, 3: 2.0}
const AGE_SCALE := {1: 1.0, 2: 1.05, 3: 1.15}

var current_health: int
var _base_scale: Vector3 = Vector3.ONE
var footprint_origin: Vector2i
var footprint_size: Vector2i = Vector2i(1, 1)
var placement_grid: PlacementGrid

var _base_population_cap_bonus: int = 0
var _base_storage_cap_bonus: int = 0
var _base_passive_resource_output: Dictionary = {}
var _current_population_cap_bonus: int = 0
var _current_storage_cap_bonus: int = 0

signal died

func _ready() -> void:
	CharacterVisualUtils.apply_pack_material(self, PACK_MATERIAL)
	current_health = max_health
	add_to_group("buildings")
	_base_scale = scale
	_base_population_cap_bonus = population_cap_bonus
	_base_storage_cap_bonus = storage_cap_bonus
	_base_passive_resource_output = passive_resource_output.duplicate()
	if not _base_passive_resource_output.is_empty():
		GameClock.day_started.connect(_on_day_started)
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)
	_apply_age(Progression.homestead_age())
	_add_night_light()

# See scripts/night_light.gd - a warm glow visible only at night, so a base
# with a few buildings actually reads as visible once the sun's night
# energy drops. Not added to Wall/Trap/FarmPlot/Fence/Scarecrow - a whole
# wall perimeter each carrying a light would be visual/performance clutter
# for little gain.
func _add_night_light() -> void:
	var light := OmniLight3D.new()
	light.set_script(NIGHT_LIGHT_SCRIPT)
	light.position = Vector3(0, 1.5, 0)
	add_child(light)

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		_revert_effects()
		if placement_grid:
			placement_grid.release(footprint_origin, footprint_size)
		queue_free()

func _revert_effects() -> void:
	if _current_population_cap_bonus != 0:
		GameState.add_population_cap(-_current_population_cap_bonus)
	if _current_storage_cap_bonus != 0:
		Economy.add_storage_cap_all(-_current_storage_cap_bonus)

func _on_day_started(_day_count: int) -> void:
	for type in passive_resource_output:
		Economy.add_resource(type, passive_resource_output[type])

func _on_upgrade_purchased(id: String) -> void:
	if id.begins_with("advance_age_"):
		_apply_age(Progression.homestead_age())

# Virtual - subclasses (Tower/AnimalPen) override to add their own stat
# scaling, but should call super._apply_age(age) first to keep the generic
# population/storage/passive-output rescaling and AgeTrim2/AgeTrim3 node
# visibility toggling (by convention: a scene may optionally have child
# nodes named "AgeTrim2"/"AgeTrim3", hidden by default in the .tscn).
func _apply_age(age: int) -> void:
	var mult: float = AGE_ECONOMY_MULTIPLIER.get(age, 1.0)
	var new_pop_bonus := roundi(_base_population_cap_bonus * mult)
	if new_pop_bonus != _current_population_cap_bonus:
		GameState.add_population_cap(new_pop_bonus - _current_population_cap_bonus)
		_current_population_cap_bonus = new_pop_bonus
	var new_storage_bonus := roundi(_base_storage_cap_bonus * mult)
	if new_storage_bonus != _current_storage_cap_bonus:
		Economy.add_storage_cap_all(new_storage_bonus - _current_storage_cap_bonus)
		_current_storage_cap_bonus = new_storage_bonus
	for type in _base_passive_resource_output:
		passive_resource_output[type] = roundi(_base_passive_resource_output[type] * mult)
	scale = _base_scale * AGE_SCALE.get(age, 1.0)
	_update_age_trim(age)

func _update_age_trim(age: int) -> void:
	var trim2 := get_node_or_null("AgeTrim2")
	if trim2:
		trim2.visible = age >= 2
	var trim3 := get_node_or_null("AgeTrim3")
	if trim3:
		trim3.visible = age >= 3
