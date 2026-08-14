extends StaticBody3D

# Gray-box resource source (tree/rock/hay/berry bush). Only a Gatherer
# villager's AI can gather() it - collection is a role-assignment decision,
# not something the player triggers directly by clicking the node. Hovering
# still shows an identifying tooltip via WorldTooltip (input_ray_pickable is
# on for mouse_entered/exited only - no input_event is connected, so this
# can't reintroduce click-to-gather).

@export var display_name: String = "Resource"
@export var resource_type: String = "wood"
@export var gather_amount: int = 5
@export var respawn_seconds: float = 3.0
# Only set by nodes using a custom-pack mesh (e.g. Hay Bale's sm_prop_hay_bale);
# left null for the still-gray-box Tree/Rock/BerryBush/FishingSpot, whose
# primitive StandardMaterial3D visuals must NOT be overridden.
@export var pack_material: Material = null

@onready var visual: Node3D = $Visual
@onready var cooldown_timer: Timer = $CooldownTimer

func _ready() -> void:
	if pack_material:
		CharacterVisualUtils.apply_pack_material(visual, pack_material)
	add_to_group("gatherable")
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	var tooltip := get_tree().get_first_node_in_group("world_tooltip")
	if tooltip:
		tooltip.show_text("%s (%s)" % [display_name, resource_type.capitalize()])

func _on_mouse_exited() -> void:
	var tooltip := get_tree().get_first_node_in_group("world_tooltip")
	if tooltip:
		tooltip.hide_text()

func is_available() -> bool:
	return cooldown_timer.time_left <= 0.0

func gather() -> void:
	if not is_available():
		return
	Economy.add_resource(resource_type, gather_amount * Progression.gather_multiplier())
	visual.visible = false
	cooldown_timer.start(respawn_seconds)

func _on_cooldown_timeout() -> void:
	visual.visible = true
