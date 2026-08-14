extends Area3D
class_name Trap

# Gray-box trap: unlike a Wall, doesn't block movement. Deals one burst of
# damage to the first enemy that steps on it, then consumes itself.

const PACK_MATERIAL := preload("res://assets/custom_pack/day_night.tres")

@export var damage: int = 30
# Empty ammo_type means unlimited/free. Non-empty means the trap needs to be
# "loaded" from stockpile to actually trigger - if unaffordable when an
# enemy steps on it, the trap is a dud for that encounter (stays armed and
# in the tree; body_entered only fires once per entry, so that specific
# enemy just walks past unharmed).
@export var ammo_type: String = ""
@export var ammo_cost: int = 1
# 0.0 = no splash (back-compat default). >0: grenades/Tomato ammo also
# damages other nearby enemies, not just the one that triggered the trap -
# a trap only ever fires once, so unlike Tower's SPLASH this isn't
# multiplier-reduced (see tower.gd's AttackPattern.SPLASH for the repeat-cast
# case that needed toning down).
@export var splash_radius: float = 0.0
# Net Trap (master spec §5.4 non-lethal path): 0.0 = today's damage-dealing
# behavior, fully back-compat with Spike Trap. >0: instead of damage, calls
# Enemy.pacify() on anything that supports it - a non-lethal alternative,
# not a replacement (an already-pacified enemy can still be killed normally
# by anything else in the meantime).
@export var pacify_duration: float = 0.0

# Age/Era damage scaling (docs/spec_base_builder.md's progression model) -
# a Trap has no HP to scale (one-shot, consumed on trigger), so damage is
# the only stat that ages up.
const AGE_DAMAGE_MULT := {1: 1.0, 2: 1.25, 3: 1.5}

# Set by ConstructionSite/BuildManager when placed via the map's
# PlacementGrid; left null for hand-authored scene traps (none currently).
var footprint_origin: Vector2i
var footprint_size: Vector2i = Vector2i(1, 1)
var placement_grid: PlacementGrid

func _ready() -> void:
	CharacterVisualUtils.apply_pack_material(self, PACK_MATERIAL)
	body_entered.connect(_on_body_entered)
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)
	_update_age_trim(Progression.homestead_age())

func _on_upgrade_purchased(id: String) -> void:
	if id.begins_with("advance_age_"):
		_update_age_trim(Progression.homestead_age())

func _update_age_trim(age: int) -> void:
	var trim2 := get_node_or_null("AgeTrim2")
	if trim2:
		trim2.visible = age >= 2
	var trim3 := get_node_or_null("AgeTrim3")
	if trim3:
		trim3.visible = age >= 3

func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("take_damage"):
		return
	if ammo_type != "" and not Economy.can_afford(ammo_type, ammo_cost):
		return
	if ammo_type != "":
		Economy.remove_resource(ammo_type, ammo_cost)
		AchievementManager.on_ammo_fired(ammo_type)
	if pacify_duration > 0.0 and body.has_method("pacify"):
		body.pacify(pacify_duration)
		_release_footprint()
		queue_free()
		return
	var final_damage: int = roundi(damage * Progression.trap_damage_multiplier() * AGE_DAMAGE_MULT.get(Progression.homestead_age(), 1.0))
	body.take_damage(final_damage)
	if splash_radius > 0.0:
		var hit_count := 1
		for node in get_tree().get_nodes_in_group("enemies"):
			if node != body and is_instance_valid(node) and global_position.distance_to(node.global_position) <= splash_radius:
				node.take_damage(final_damage)
				hit_count += 1
		AchievementManager.on_splash_hit(hit_count)
	_release_footprint()
	queue_free()

func _release_footprint() -> void:
	if placement_grid:
		placement_grid.release(footprint_origin, footprint_size)
