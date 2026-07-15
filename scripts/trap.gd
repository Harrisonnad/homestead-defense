extends Area3D
class_name Trap

# Gray-box trap: unlike a Wall, doesn't block movement. Deals one burst of
# damage to the first enemy that steps on it, then consumes itself.

@export var damage: int = 30

# Set by ConstructionSite/BuildManager when placed via the map's
# PlacementGrid; left null for hand-authored scene traps (none currently).
var footprint_origin: Vector2i
var footprint_size: Vector2i = Vector2i(1, 1)
var placement_grid: PlacementGrid

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage * Progression.trap_damage_multiplier())
		_release_footprint()
		queue_free()

func _release_footprint() -> void:
	if placement_grid:
		placement_grid.release(footprint_origin, footprint_size)
