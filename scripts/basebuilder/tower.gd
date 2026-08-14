extends Building
class_name Tower

# Static ranged defender. Reuses the "scan a group, act on a timer" pattern
# already used by villager.gd (guard combat) and enemy.gd (wall-engagement).
#
# Each ammo type gets a genuinely different attack pattern (master spec
# §5.1's design rule: "player should look at their field and know what kind
# of night they're preparing for") rather than just a bigger damage number:
# darts/Watchtower stay SINGLE (baseline), cannonballs/Ballista and
# grenades/Spike Trap (see trap.gd) get SPLASH, bullets/Sling Post gets SPRAY.

enum AttackPattern { SINGLE, SPLASH, SPRAY }

@export var damage: int = 8
@export var attack_interval: float = 1.2
@export var attack_range: float = 7.0
# Set by ConstructionSite/Ruin *after* add_child() (so after _ready() has
# already run) - a plain field would silently never apply its bonus because
# of that ordering. The setter recomputes range immediately instead of
# depending on _ready() timing.
@export var chokepoint: bool = false:
	set(value):
		chokepoint = value
		_recompute_attack_range()
# Empty ammo_type means unlimited/free (back-compat for any future tower
# that shouldn't need crop supply chains); farm-fed defenses set this to a
# CropDef.ammo_type ("cannonballs"/"darts"/"grenades"/"bullets").
@export var ammo_type: String = ""
@export var ammo_cost: int = 1

@export var attack_pattern: AttackPattern = AttackPattern.SINGLE
# SPLASH only: extra targets near the primary hit take damage * this
# multiplier (Ballista Tower stays hardest-single-hit; splash rewards
# hitting clusters without making it a strictly-better Watchtower).
@export var splash_radius: float = 2.0
@export var splash_damage_multiplier: float = 0.5
# SPRAY only: hits every enemy in attack_range each shot, capped so a cheap
# fast-firing tower can't solo-delete an entire chokepoint-clustered wave
# for one ammo per volley.
@export var spray_max_targets: int = 3

@onready var attack_timer: Timer = $AttackTimer

# Age/Era combat scaling (docs/spec_base_builder.md's progression model) -
# damage scales by percentage, range by a flat bonus per the design table in
# the Age system plan; chokepoint keeps its own flat +1.0 on top of both.
const DAMAGE_MULT := {1: 1.0, 2: 1.25, 3: 1.5}
const RANGE_BONUS := {1: 0.0, 2: 1.0, 3: 2.0}

var _base_damage: int = 0
var _base_attack_range: float = 0.0
var _current_age: int = 1

func _ready() -> void:
	_base_damage = damage
	_base_attack_range = attack_range
	super._ready()
	attack_timer.wait_time = attack_interval
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

func _apply_age(age: int) -> void:
	_current_age = age
	damage = roundi(_base_damage * DAMAGE_MULT.get(age, 1.0))
	_recompute_attack_range()
	super._apply_age(age)

func _recompute_attack_range() -> void:
	attack_range = _base_attack_range + RANGE_BONUS.get(_current_age, 0.0) + (1.0 if chokepoint else 0.0)

func _on_attack_timer_timeout() -> void:
	var target := _find_nearest_enemy_in_range()
	if target == null:
		return
	if ammo_type != "":
		if not Economy.can_afford(ammo_type, ammo_cost):
			return
		Economy.remove_resource(ammo_type, ammo_cost)
		AchievementManager.on_ammo_fired(ammo_type)
	match attack_pattern:
		AttackPattern.SPLASH:
			target.take_damage(damage)
			var hit_count := 1
			for node in _find_all_enemies_in_range(target.global_position, splash_radius):
				if node != target:
					node.take_damage(int(damage * splash_damage_multiplier))
					hit_count += 1
			AchievementManager.on_splash_hit(hit_count)
		AttackPattern.SPRAY:
			var in_range := _find_all_enemies_in_range(global_position, attack_range)
			in_range.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
			var hit_count := mini(spray_max_targets, in_range.size())
			for i in hit_count:
				in_range[i].take_damage(damage)
			AchievementManager.on_spray_hit(hit_count, spray_max_targets)
		_:
			target.take_damage(damage)

func _find_nearest_enemy_in_range() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var dist := global_position.distance_to(node.global_position)
		if dist <= attack_range and dist < best_dist:
			best_dist = dist
			best = node
	return best

# Shared by SPLASH (centered on the primary target, splash_radius) and SPRAY
# (centered on self, attack_range). Skips anything already queued for
# deletion - two towers/traps can otherwise both scan the same dying enemy
# in the same physics frame before Godot actually frees it.
func _find_all_enemies_in_range(center: Vector3, radius: float) -> Array:
	var result := []
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and center.distance_to(node.global_position) <= radius:
			result.append(node)
	return result
