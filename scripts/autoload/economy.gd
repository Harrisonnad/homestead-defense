extends Node

# Autoload singleton: tracks player resource counts and notifies listeners
# (HUD, build costs, raid losses) when they change.

const STARTING_RESOURCES := {
	"wood": 0,
	"food": 0,
	"stone": 0,
}

var resources: Dictionary = STARTING_RESOURCES.duplicate()

signal resources_changed(type: String, new_amount: int)

func add_resource(type: String, amount: int) -> void:
	resources[type] = get_amount(type) + amount
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

func reset() -> void:
	resources = STARTING_RESOURCES.duplicate()
	for type in resources:
		resources_changed.emit(type, resources[type])
