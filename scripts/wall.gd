extends StaticBody3D
class_name Wall

# Age/Era-aware (docs/spec_base_builder.md's progression model, see
# Progression.homestead_age()/wall_tier()) - reacts live to
# Progression.upgrade_purchased instead of only reading tier once at
# placement, so walls already standing when the homestead ages up get
# stronger retroactively, not just newly-placed ones. Fences and the gate
# reuse this script with upgradable = false so the perimeter never inherits
# the age tier.

const PACK_MATERIAL := preload("res://assets/custom_pack/day_night.tres")
const AGE_MAX_HEALTH := {1: 50, 2: 120, 3: 200}

@export var max_health: int = 50
@export var upgradable: bool = true
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
	CharacterVisualUtils.apply_pack_material(self, PACK_MATERIAL)
	add_to_group("walls")
	current_health = max_health
	if upgradable:
		Progression.upgrade_purchased.connect(_on_upgrade_purchased)
		_apply_age(Progression.homestead_age())

func _on_upgrade_purchased(id: String) -> void:
	if id.begins_with("advance_age_"):
		_apply_age(Progression.homestead_age())

func _apply_age(age: int) -> void:
	var new_max: int = AGE_MAX_HEALTH.get(age, max_health)
	if current_health > 0:
		current_health += new_max - max_health
	max_health = new_max
	if sprite and reinforced_texture:
		sprite.texture = reinforced_texture if age >= 2 else null
	elif reinforced_tint.a > 0.0:
		CharacterVisualUtils.tint_meshes(self, reinforced_tint if age >= 2 else Color(1, 1, 1, 1))
	var trim2 := get_node_or_null("AgeTrim2")
	if trim2:
		trim2.visible = age >= 2
	var trim3 := get_node_or_null("AgeTrim3")
	if trim3:
		trim3.visible = age >= 3

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		if placement_grid:
			placement_grid.release(footprint_origin, footprint_size)
		queue_free()
