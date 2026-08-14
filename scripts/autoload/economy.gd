extends Node

# Autoload singleton: tracks player resource counts and notifies listeners
# (HUD, build costs, raid losses) when they change. Storage caps start flat
# per resource and rise with built Storehouses (BuildingDef.storage_cap_bonus).

const STARTING_RESOURCES := {
	"wood": 0,
	"food": 0,
	"stone": 0,
	# Ammo, produced by FarmPlot crops (see CropDef) and consumed by
	# Watchtower/Ballista Tower/Spike Trap per shot - see crops/ *.tres.
	"cannonballs": 0,
	"darts": 0,
	"grenades": 0,
	"bullets": 0,
}
const BASE_STORAGE_CAP := 100

var resources: Dictionary = STARTING_RESOURCES.duplicate()
var storage_caps: Dictionary = _default_storage_caps()
# Which gatherable resource_type (see resource_node.gd) Gatherer villagers
# should prefer over "nearest available node of any type" - empty means no
# preference (today's original behavior). Set via the HUD's resource chips
# (hud.gd/hud.tscn); read by villager.gd's _find_nearest_gatherable().
var priority_resource_type: String = ""

signal resources_changed(type: String, new_amount: int)
signal caps_changed(type: String, new_cap: int)
signal priority_changed(type: String)

# Click a resource chip to prefer it (Gatherers path to the nearest
# available node of that type over anything closer of another type);
# click the same one again to clear back to nearest-of-any-type.
func set_priority_resource(type: String) -> void:
	priority_resource_type = "" if priority_resource_type == type else type
	priority_changed.emit(priority_resource_type)

func add_resource(type: String, amount: int) -> void:
	resources[type] = mini(get_amount(type) + amount, get_cap(type))
	resources_changed.emit(type, resources[type])

func can_afford(type: String, amount: int) -> bool:
	return get_amount(type) >= amount

func spend_resource(type: String, amount: int) -> bool:
	if not can_afford(type, amount):
		return false
	resources[type] = get_amount(type) - amount
	resources_changed.emit(type, resources[type])
	return true

func remove_resource(type: String, amount: int) -> void:
	var new_amount := maxi(get_amount(type) - amount, 0)
	if new_amount == get_amount(type):
		return
	resources[type] = new_amount
	resources_changed.emit(type, new_amount)

func can_afford_all(costs: Dictionary) -> bool:
	for type in costs:
		if not can_afford(type, costs[type]):
			return false
	return true

func spend_all(costs: Dictionary) -> bool:
	if not can_afford_all(costs):
		return false
	for type in costs:
		spend_resource(type, costs[type])
	return true

func get_amount(type: String) -> int:
	return resources.get(type, 0)

func get_cap(type: String) -> int:
	return storage_caps.get(type, BASE_STORAGE_CAP)

func add_storage_cap_all(bonus: int) -> void:
	for type in storage_caps:
		storage_caps[type] += bonus
		caps_changed.emit(type, storage_caps[type])

func reset() -> void:
	resources = STARTING_RESOURCES.duplicate()
	storage_caps = _default_storage_caps()
	priority_resource_type = ""
	priority_changed.emit(priority_resource_type)
	for type in resources:
		resources_changed.emit(type, resources[type])
		caps_changed.emit(type, storage_caps[type])

func _default_storage_caps() -> Dictionary:
	var caps := {}
	for type in STARTING_RESOURCES:
		caps[type] = BASE_STORAGE_CAP
	return caps
