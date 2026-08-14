extends CharacterBody3D
class_name Enemy

# Gray-box enemy: walks straight toward `target` each physics frame. If it
# enters attack range of anything that can take damage (a Wall or a Villager -
# any role, not just Guard, per villager_detection_radius below) it stops and
# chips away at it on a timer; once that target falls (or it was never
# blocked) it continues to `target` and triggers a resource raid on arrival.
# Has its own health so Guards can fight back.
#
# Villager targeting: a raid used to be purely building-focused - an enemy
# would walk straight past an unarmed Farmer or Gatherer standing right next
# to its path toward the Homestead, only ever fighting a Villager
# incidentally if it happened to be a Guard (the only role on a collision
# layer AttackRange's mask covered). VillagerScanTimer periodically looks for
# the nearest villager (any role) within villager_detection_radius and, if
# one's found, redirects movement there instead of `target` - makes raids a
# real threat to villagers working out in the open, not just to buildings.
# `target` itself (the Homestead, or a subclass's redirected Farm
# Plot/Animal Pen - see locust.gd/wolf.gd) is left untouched so the enemy
# falls back to its original raid the moment no villager is nearby, and
# _reach_target()'s raid-the-destination payload only ever fires for that
# original `target`, never for an opportunistic villager chase (that combat
# runs through the existing AttackRange/current_target path instead).
#
# Seasonal enemy identity + non-lethal deterrence (master spec §5.4/§5.7):
# AIState formalizes two more behaviors on top of the always-on
# APPROACHING/ENGAGED pair above. Both existing hooks are opt-in and default
# to never firing, so all 4 pre-existing enemy types (Raider/Ranged Raider/
# Brute/Siege-breaker) are completely unaffected:
# - FLEEING (Locust Swarm's `flee_on_damage`, triggered by a Scarecrow or any
#   hit): runs away and despawns - an escape, not a kill, so it deliberately
#   does not call the kill-tracking hooks `take_damage`'s death branch does.
# - PACIFIED (any enemy, via a Net Trap's `pacify()`): frozen in place for a
#   duration, still killable normally by anything else in the meantime -
#   non-lethal is an option, not a forced replacement for combat.

enum AIState { APPROACHING, ENGAGED, FLEEING, PACIFIED }

@export var move_speed: float = 2.5
@export var attack_damage: int = 10
@export var arrival_distance: float = 0.6
@export var raid_resource_loss: Dictionary = {"wood": 5, "food": 5}
@export var raid_homestead_damage: int = 15
@export var max_health: int = 30
# Custom pack sk_ creature name (e.g. "sk_sporehound") backing $Model - picks
# the material (violet day_night_hostile.tres, §4) and idle animation.
@export var creature_name: String = "sk_sporehound"
# Locust Swarm sets this true - any hit sends it fleeing instead of fighting
# back, and a Scarecrow's scan only ever targets enemies with this set, so
# it never affects Raiders/Brutes/Wolves/etc.
@export var flee_on_damage: bool = false
@export var flee_speed_multiplier: float = 1.8
@export var flee_distance: float = 15.0
@export var villager_detection_radius: float = 6.0

var target: Node3D = null
var current_target: Node3D = null
var current_health: int
var ai_state: AIState = AIState.APPROACHING
var _flee_direction: Vector3 = Vector3.ZERO
var _flee_origin: Vector3 = Vector3.ZERO
# Opportunistic movement destination - a nearby villager the enemy is
# steering toward instead of `target`. Never used for the raid payload
# itself (see _physics_process/_reach_target).
var _villager_target: Node3D = null

signal died

const HOSTILE_MATERIAL := preload("res://assets/custom_pack/day_night_hostile.tres")
const PACIFIED_TINT := Color(0.5, 0.5, 0.5, 1)
const NO_TINT := Color(1, 1, 1, 1)

@onready var attack_range: Area3D = $AttackRange
@onready var attack_timer: Timer = $AttackTimer
@onready var villager_scan_timer: Timer = $VillagerScanTimer
@onready var model: Node3D = $Model

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	attack_range.body_entered.connect(_on_attack_range_body_entered)
	attack_range.body_exited.connect(_on_attack_range_body_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	villager_scan_timer.timeout.connect(_on_villager_scan_timer_timeout)
	villager_scan_timer.start()
	CharacterVisualUtils.apply_pack_material(model, HOSTILE_MATERIAL)
	CharacterVisualUtils.play_creature_idle(model, creature_name)

# Periodic (not per-frame - matches scarecrow.gd's own scan-timer cadence)
# nearest-villager scan. Only matters during APPROACHING - once ENGAGED, the
# enemy is already fighting something via AttackRange and movement is
# irrelevant; FLEEING/PACIFIED shouldn't newly commit to a chase either.
func _on_villager_scan_timer_timeout() -> void:
	if ai_state != AIState.APPROACHING:
		return
	var best: Node3D = null
	var best_dist := villager_detection_radius
	for node in get_tree().get_nodes_in_group("villagers"):
		if not is_instance_valid(node):
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist < best_dist:
			best_dist = dist
			best = node
	_villager_target = best

# Virtual - WaveSpawner calls this instead of setting `target` directly on
# spawn, so a subclass (Locust, Wolf) can redirect to a different default
# target (a Farm Plot, the Animal Pen) instead of always the Homestead.
func set_initial_target(default_target: Node3D) -> void:
	target = default_target

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		died.emit()
		AchievementManager.on_enemy_killed(creature_name)
		NightReport.on_enemy_killed(creature_name)
		queue_free()
		return
	if flee_on_damage and ai_state in [AIState.APPROACHING, AIState.ENGAGED]:
		start_fleeing()

# Public - called directly by Scarecrow (scarecrow.gd) on anything with
# flee_on_damage in its scan radius, same as a hit triggering it.
func start_fleeing() -> void:
	if ai_state == AIState.FLEEING:
		return
	ai_state = AIState.FLEEING
	if current_target != null:
		if current_target.died.is_connected(_on_target_died):
			current_target.died.disconnect(_on_target_died)
		current_target = null
	attack_timer.stop()
	var away_from: Vector3 = target.global_position if target != null else global_position + Vector3.FORWARD
	_flee_direction = (global_position - away_from)
	_flee_direction.y = 0.0
	_flee_direction = _flee_direction.normalized() if _flee_direction.length() > 0.01 else Vector3.FORWARD
	_flee_origin = global_position

# Public - called directly by Net Trap (trap.gd's pacify_duration path) on
# contact. Works on any enemy, not just ones with flee_on_damage - nets are
# a general tool, unlike the Scarecrow's narrower scope.
func pacify(duration: float) -> void:
	if ai_state == AIState.PACIFIED:
		return
	ai_state = AIState.PACIFIED
	attack_timer.stop()
	CharacterVisualUtils.tint_meshes(model, PACIFIED_TINT)
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self):
		return
	ai_state = AIState.ENGAGED if current_target != null else AIState.APPROACHING
	CharacterVisualUtils.tint_meshes(model, NO_TINT)
	if current_target != null:
		attack_timer.start()

func _physics_process(_delta: float) -> void:
	if ai_state == AIState.PACIFIED:
		velocity = Vector3.ZERO
		return
	if ai_state == AIState.FLEEING:
		velocity = _flee_direction * move_speed * flee_speed_multiplier
		CharacterVisualUtils.face_direction(self, _flee_direction)
		move_and_slide()
		if global_position.distance_to(_flee_origin) >= flee_distance:
			queue_free()
		return

	if current_target != null or target == null:
		return

	# Steer toward a nearby villager if VillagerScanTimer found one, instead
	# of the raid destination - but the raid payload in _reach_target() only
	# ever applies to reaching `target` itself. Reaching a villager instead
	# is handled by AttackRange overlap (see _on_attack_range_body_entered),
	# which fires well before arrival_distance since its range is larger.
	var move_target: Node3D = target
	if _villager_target != null and is_instance_valid(_villager_target):
		move_target = _villager_target

	var to_target := move_target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() <= arrival_distance:
		if move_target == target:
			_reach_target()
		return

	velocity = to_target.normalized() * move_speed
	CharacterVisualUtils.face_direction(self, to_target)
	move_and_slide()

func _on_attack_range_body_entered(body: Node3D) -> void:
	if current_target != null or not body.has_method("take_damage"):
		return
	if ai_state in [AIState.FLEEING, AIState.PACIFIED]:
		return
	current_target = body
	ai_state = AIState.ENGAGED
	current_target.died.connect(_on_target_died, CONNECT_ONE_SHOT)
	attack_timer.start()

func _on_attack_range_body_exited(body: Node3D) -> void:
	if body == current_target:
		# Undo the body_entered connect() below - without this, the same
		# still-alive target walking back into range later hits "already
		# connected" (Godot disallows duplicate signal connections).
		if current_target.died.is_connected(_on_target_died):
			current_target.died.disconnect(_on_target_died)
		current_target = null
		attack_timer.stop()
		if ai_state == AIState.ENGAGED:
			ai_state = AIState.APPROACHING

func _on_attack_timer_timeout() -> void:
	if ai_state != AIState.ENGAGED:
		return
	if current_target != null:
		current_target.take_damage(attack_damage)

func _on_target_died() -> void:
	current_target = null
	attack_timer.stop()
	if ai_state == AIState.ENGAGED:
		ai_state = AIState.APPROACHING

func _reach_target() -> void:
	for type in raid_resource_loss:
		Economy.remove_resource(type, raid_resource_loss[type])
		NightReport.on_resource_lost(type, raid_resource_loss[type])
	var homestead := get_tree().get_first_node_in_group("homestead")
	if homestead:
		homestead.take_damage(raid_homestead_damage)
		NightReport.on_homestead_damaged(raid_homestead_damage)
	queue_free()
