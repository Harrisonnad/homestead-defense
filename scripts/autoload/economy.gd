extends Node

# Autoload singleton: tracks player resource counts and notifies listeners
# (HUD, build costs, raid losses) when they change.

var resources: Dictionary = {
	"wood": 0,
	"food": 0,
}

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

func get_amount(type: String) -> int:
	return resources.get(type, 0)
