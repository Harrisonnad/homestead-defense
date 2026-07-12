extends Area3D
class_name Trap

# Gray-box trap: unlike a Wall, doesn't block movement. Deals one burst of
# damage to the first enemy that steps on it, then consumes itself.

@export var damage: int = 30

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage * Progression.trap_damage_multiplier())
		queue_free()
