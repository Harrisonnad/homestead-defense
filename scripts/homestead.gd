extends Node3D

# The player's home base: what enemies raid and what the season is lost
# over. Also where recruited villagers arrive, since it already sits in the
# world with the references a spawn needs.

const PACK_MATERIAL := preload("res://assets/custom_pack/day_night.tres")
const NIGHT_LIGHT_SCRIPT := preload("res://scripts/night_light.gd")
# Age/Era scaling (docs/spec_base_builder.md's progression model) - the
# Homestead is the "Town Center" anchor of the whole system, so it gets the
# biggest HP jump and a scale bump alongside the shared AgeTrim2/AgeTrim3
# node convention every other building uses.
const AGE_MAX_HEALTH := {1: 100, 2: 150, 3: 200}
const AGE_SCALE := {1: 1.0, 2: 1.05, 3: 1.15}

@export var max_health: int = 100
@export var villager_scene: PackedScene
@export var entities_container_path: NodePath
@export var recruit_offset: Vector3 = Vector3(2, 0, 1)

@onready var entities_container: Node3D = get_node(entities_container_path)
@onready var _base_scale: Vector3 = scale

var current_health: int

signal health_changed(current: int)

func _ready() -> void:
	CharacterVisualUtils.apply_pack_material(self, PACK_MATERIAL)
	current_health = max_health
	add_to_group("homestead")
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)
	_apply_age(Progression.homestead_age())
	_add_night_light()

# See scripts/night_light.gd. The Homestead is the base's anchor, so it
# gets a stronger/wider glow than a regular Building (building.gd's own
# _add_night_light()) rather than the same default.
func _add_night_light() -> void:
	var light := OmniLight3D.new()
	light.set_script(NIGHT_LIGHT_SCRIPT)
	light.position = Vector3(0, 2.2, 0)
	light.night_energy = 2.2
	light.light_range = 10.0
	add_child(light)

func take_damage(amount: int) -> void:
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health)
	if current_health <= 0:
		GameState.lose()

func _on_upgrade_purchased(id: String) -> void:
	if id == "recruit_villager":
		var villager := villager_scene.instantiate()
		entities_container.add_child(villager)
		var pos := global_position + recruit_offset
		# Water has real collision (map_builder.gd) - a fixed offset from the
		# Homestead isn't validated against the generated terrain, so nudge
		# off water if it happens to land there (mirrors the same fix for the
		# initial 3 villagers in map_builder.gd's _place_landmarks()).
		var map_builder := get_tree().get_first_node_in_group("map_builder")
		if map_builder and map_builder.placement_grid:
			pos = map_builder.placement_grid.find_nearest_non_water(pos)
		villager.global_position = pos
	elif id.begins_with("advance_age_"):
		_apply_age(Progression.homestead_age())

func _apply_age(age: int) -> void:
	var new_max: int = AGE_MAX_HEALTH.get(age, max_health)
	if current_health > 0:
		current_health += new_max - max_health
	max_health = new_max
	health_changed.emit(current_health)
	scale = _base_scale * AGE_SCALE.get(age, 1.0)
	var trim2 := get_node_or_null("AgeTrim2")
	if trim2:
		trim2.visible = age >= 2
	var trim3 := get_node_or_null("AgeTrim3")
	if trim3:
		trim3.visible = age >= 3
