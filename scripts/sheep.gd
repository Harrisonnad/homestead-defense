extends StaticBody3D
class_name Sheep

# Livestock-as-defense (master spec §5.3): "padding" - not a fighter, just a
# grazing body with enough HP to matter. Sits on the same collision layer
# Dog/Goat use (8, already inside Enemy's AttackRange mask) so a raider
# passing near the Animal Pen may opportunistically engage it instead of
# continuing straight toward the Homestead - the "physical blockade" role
# from the spec, achieved for free via Enemy's existing generic
# has_method("take_damage") targeting. No enemy.gd changes needed.

const PACK_MATERIAL := preload("res://assets/custom_pack/day_night.tres")

@export var max_health: int = 18

var current_health: int

signal died

@onready var model: Node3D = $Model

func _ready() -> void:
	current_health = max_health
	add_to_group("sheep")
	CharacterVisualUtils.apply_pack_material(model, PACK_MATERIAL)
	CharacterVisualUtils.play_creature_idle(model, "sk_sheep")

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		queue_free()
