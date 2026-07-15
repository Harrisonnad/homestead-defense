extends StaticBody3D
class_name Wall

# Tier is read once at placement time (_ready), so walls placed before the
# Reinforced Walls upgrade keep their original stats and look. Fences and
# the gate reuse this script with upgradable = false so the perimeter never
# inherits the reinforced tier.

@export var max_health: int = 50
@export var upgradable: bool = true
@export var reinforced_max_health: int = 120
@export var reinforced_texture: Texture2D
# Fallback for 3D-model walls that can't swap a single texture: tint every
# mesh part instead. Alpha 0 (default) means "don't tint."
@export var reinforced_tint: Color = Color(0, 0, 0, 0)

# Optional: variants like the gate use differently-named sprites and never
# swap texture (upgradable = false), so this may be null.
@onready var sprite: Sprite3D = get_node_or_null("Sprite3D")

var current_health: int

# Set by ConstructionSite/BuildManager when placed via the map's
# PlacementGrid; left null for hand-authored scene walls (fences/gate),
# which don't need footprint release.
var footprint_origin: Vector2i
var footprint_size: Vector2i = Vector2i(1, 1)
var placement_grid: PlacementGrid

signal died

func _ready() -> void:
	if upgradable and Progression.wall_tier() >= 2:
		max_health = reinforced_max_health
		if sprite and reinforced_texture:
			sprite.texture = reinforced_texture
		elif reinforced_tint.a > 0.0:
			CharacterVisualUtils.tint_meshes(self, reinforced_tint)
	current_health = max_health
	add_to_group("walls")

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		if placement_grid:
			placement_grid.release(footprint_origin, footprint_size)
		queue_free()
