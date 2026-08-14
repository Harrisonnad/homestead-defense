extends Building
class_name AnimalPen

# Livestock is real sk_ meshes from the custom pack (cow was a Kenney sprite -
# a "sticker"-style visual seam flagged in the README) and the perimeter is
# the pack's sm_fence_post kit piece; day_night.tres for all since day
# animals/structures are environmental, not hostile (§4 cyan vs violet).
#
# Livestock-as-defense (master spec §5.3, docs/roadmap_steam_mvp.md Phase C):
# the pen doubles as a defense subsystem, not just passive food - a Chicken
# raises the alarm the moment a raid gets close (the spec splits this into a
# loud Goose + a subtler Chicken; no sk_goose exists in the pack, so this is
# a deliberate v1 merge of both into one alarm - see the roadmap doc), a Dog
# is a free, always-on combat defender, a Sheep is passive "padding" (just a
# body with HP that a raider may opportunistically engage instead of
# continuing straight to the Homestead), and a Goat is a lighter combat
# assistant restricted to smaller enemies (reuses dog.gd - see that file).
# None of these compete with Farmer/Gatherer/Guard for the villager
# population pool.

const ALARM_MESSAGE := "The chickens are raising a racket - something's approaching!"

@export var dog_scene: PackedScene = preload("res://scenes/dog.tscn")
@export var dog_local_offset: Vector3 = Vector3(1.6, 0, 1.6)
@export var goat_scene: PackedScene = preload("res://scenes/goat.tscn")
@export var goat_local_offset: Vector3 = Vector3(-1.6, 0, 1.6)
@export var sheep_scene: PackedScene = preload("res://scenes/sheep.tscn")
@export var sheep_local_offset: Vector3 = Vector3(-1.6, 0, -1.6)
@export var alarm_radius: float = 13.0
@export var alarm_scan_interval: float = 1.0

@onready var cow: Node3D = $Cow
@onready var chicken: Node3D = $Chicken
@onready var alarm_timer: Timer = $AlarmTimer

var _alarmed: bool = false

func _ready() -> void:
	super._ready()
	CharacterVisualUtils.play_creature_idle(cow, "sk_cow")
	CharacterVisualUtils.play_creature_idle(chicken, "sk_chicken")
	# Distance-scan-on-a-timer rather than an Area3D/body_entered trigger -
	# same proven pattern as tower.gd's _find_nearest_enemy_in_range() and
	# dog.gd's detect-radius scan, reused here after an Area3D nested under
	# this StaticBody3D mysteriously never reported overlaps in headless
	# testing (shape registered correctly per PhysicsServer3D inspection,
	# correct mask/radius/transform, yet get_overlapping_bodies() stayed
	# empty - an identical Area3D added to the same node at runtime instead
	# of via the scene file worked fine). Not fully root-caused; this
	# sidesteps it rather than fighting an engine-level mystery.
	alarm_timer.wait_time = alarm_scan_interval
	alarm_timer.timeout.connect(_on_alarm_timer_timeout)
	alarm_timer.start()
	_spawn_livestock_unit(dog_scene, dog_local_offset)
	_spawn_livestock_unit(goat_scene, goat_local_offset)
	_spawn_livestock_unit(sheep_scene, sheep_local_offset)

func _spawn_livestock_unit(scene: PackedScene, local_offset: Vector3) -> void:
	if scene == null:
		return
	var unit: Node3D = scene.instantiate()
	# Position must be set before add_child() - Dog/Goat's own _ready() reads
	# global_position (_home_position), which _ready() runs synchronously
	# during add_child(), same ordering gotcha documented for Ruin rewards
	# in docs/architecture-decisions.md.
	unit.position = _safe_local_offset(local_offset)
	add_child(unit)

# A Pen's own footprint tiles are always buildable (grass/dirt - see
# PlacementGrid.check_placement()), but a fixed local offset can still land
# on an adjacent water tile if the pen sits right at the water's edge, and
# Dog/Goat are CharacterBody3D that patrol via move_and_slide() - the same
# spawn-stuck-on-water risk villagers have (see map_builder.gd's
# _place_landmarks()/homestead.gd's recruit_villager handler). Nudges the
# spawn's *world* position off water first, then converts back to local so
# Dog/Goat's home-position patrol anchor still lines up with where they
# actually end up.
func _safe_local_offset(local_offset: Vector3) -> Vector3:
	var map_builder := get_tree().get_first_node_in_group("map_builder")
	if map_builder == null or map_builder.placement_grid == null:
		return local_offset
	var safe_world_pos: Vector3 = map_builder.placement_grid.find_nearest_non_water(to_global(local_offset))
	return to_local(safe_world_pos)

func _on_alarm_timer_timeout() -> void:
	if _alarmed:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(node.global_position) <= alarm_radius:
			_alarmed = true
			NotificationManager.notify(ALARM_MESSAGE)
			AchievementManager.on_alarm_raised()
			return

func _on_day_started(day_count: int) -> void:
	# Building._ready() already connects GameClock.day_started to
	# _on_day_started (for passive_resource_output payout) - this override
	# extends that instead of adding a second connection to the same signal
	# + method, which Godot rejects as a duplicate (found via headless test).
	super._on_day_started(day_count)
	_alarmed = false
