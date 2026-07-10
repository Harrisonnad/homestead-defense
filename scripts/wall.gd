extends StaticBody3D
class_name Wall

@export var max_health: int = 50

var current_health: int

signal died

func _ready() -> void:
	current_health = max_health
	add_to_group("walls")

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		queue_free()
