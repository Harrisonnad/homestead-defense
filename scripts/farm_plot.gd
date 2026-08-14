extends StaticBody3D
class_name FarmPlot

# Gray-box farm plot: EMPTY -> (plant) -> GROWING -> (days_to_grow dawns) ->
# READY -> (harvest) -> EMPTY. Growth is tied to GameClock.day_started so it
# stays locked to the core day/night rhythm rather than a separate timer.
#
# Four crops (see crops/*.tres). plant() with no argument auto-cycles through
# available_crops in order - the Farmer AI always plants this way (see
# villager.gd's _on_work_complete()), so an untended plot still produces
# every ammo type over time. A player clicking an empty plot instead gets a
# crop-choice panel (Selection.select_farm_plot() -> scripts/crop_select_panel.gd)
# and plant()s whichever CropDef they pick explicitly.

enum State { EMPTY, GROWING, READY }

@export var available_crops: Array[CropDef] = []
@export var days_to_grow: int = 1 # fallback only; each CropDef sets its own

# Step 6 art pass: the plot's crop is now a real low-poly 3D mesh from the
# custom asset pack (assets/custom_pack), swapped in for the old Kenney sprite,
# and wearing the shared day/night ShaderMaterial so it shifts with the global
# day_night_ratio uniform. Growth stage picks the mesh: GROWING -> young (_2),
# READY -> ripe/fruiting (_4). The game's crops map onto the pack's crop
# silhouettes by name (fallback: leafy herb). Pea now gets its own real
# trellis mesh (gen_crop_pea.py) instead of borrowing "corn" as a
# placeholder; that frees "sunflower" for the actual Sunflower crop below.
const CROP_MATERIAL := preload("res://assets/custom_pack/day_night.tres")
const CROP_MESH_MAP := {
	"Pumpkin": "pumpkin",
	"Tomato": "tomato",
	"Carrot": "herb",
	"Pea": "pea",
	"Corn": "corn",
	"Sunflower": "sunflower",
}
const CROP_MESH_FALLBACK := "herb"

# Sunflower fulfills the game's own master spec (§5.1: "Sunflowers - Light
# source that wards off dark-seeking enemies"), never actually built until
# now. Two effects, both while a Sunflower plot is GROWING or READY (not
# just at harvest, so it's earning its keep the whole time it occupies a
# plot, not only at the end):
#   - a NightLight (see scripts/night_light.gd), parented to the crop mesh
#     itself so it's freed automatically whenever that mesh is (harvest/
#     replant/eaten) - no separate lifecycle tracking needed.
#   - a passive ward against Locust Swarms, reusing scarecrow.gd's exact
#     scan-timer + start_fleeing() mechanic rather than inventing a new
#     one. Deliberately scoped the same way Scarecrow already is: only
#     enemies with flee_on_damage (Locusts) respond to this - a universal
#     "no enemy can approach" ward would trivialize the night defense the
#     rest of the game is built around.
const NIGHT_LIGHT_SCRIPT := preload("res://scripts/night_light.gd")
const SUNFLOWER_LIGHT_ENERGY := 1.1
const SUNFLOWER_LIGHT_RANGE := 5.0
const SUNFLOWER_WARD_RADIUS := 5.0
const SUNFLOWER_WARD_INTERVAL := 1.0

# Age/Era yield scaling (docs/spec_base_builder.md's progression model) -
# growth speed stays the same across ages (keeps day/night rhythm
# predictable); only the harvested amount grows.
const AGE_YIELD_MULT := {1: 1.0, 2: 1.25, 3: 1.5}

# Companion planting (master spec §5.2) - real permaculture pairings applied
# to this game's crops. Carrot+Tomato is a classic pair on its own; Corn/Pea/
# Pumpkin form a "Three Sisters" group (the real technique is corn+beans+
# squash grown together - Pea stands in for beans, Pumpkin for squash - each
# of the three counts as a companion of the other two, not just one fixed
# partner, so this maps to a list per crop rather than the original 1:1
# pairing). Checked by world-position proximity rather than footprint_origin/
# PlacementGrid, since map-generated crop plots (see map_builder.gd's
# _populate_farm_plots()) are spawned directly and never get a
# footprint_origin assigned - position works uniformly for both player-built
# and map-generated plots. 1.1 catches only orthogonal neighbors (exactly 1.0
# apart) and excludes diagonal ones (~1.41 apart).
const COMPANION_PAIRS := {
	"Carrot": ["Tomato"],
	"Tomato": ["Carrot"],
	"Pea": ["Pumpkin", "Corn"],
	"Pumpkin": ["Pea", "Corn"],
	"Corn": ["Pea", "Pumpkin"],
}
const COMPANION_NEIGHBOR_DISTANCE := 1.1
const COMPANION_YIELD_BONUS := 0.25

var state: State = State.EMPTY
var current_crop: CropDef = null
var _days_growing: int = 0
var _next_crop_index: int = 0

# Set by ConstructionSite when placed via the map's PlacementGrid; farm
# plots have no HP/combat, so these are only used for read access, never
# released (a plot never "dies").
var footprint_origin: Vector2i
var footprint_size: Vector2i = Vector2i(1, 1)
var placement_grid: PlacementGrid

@onready var crop_sprite: Sprite3D = $Crop
# Dirt carries a +0.4 Y offset in the scene itself, not just here in script -
# FarmPlot always spawns at y=0 (map_builder.gd's tile_to_world), but the
# terrain's own ground BoxMesh (_build_terrain()) can sit up to y=0.39 at the
# highest of its 3 elevation steps, which fully swallowed the flat tilled-soil
# tile when it had no offset (the old Sprite3D billboard this replaced was at
# y=2.0, clear of the terrain by a wide margin, so this never showed up before).
@onready var dirt: Node3D = $Dirt
@onready var ward_timer: Timer = $WardTimer

var _crop_mesh: Node3D = null

func _ready() -> void:
	add_to_group("farm_plots")
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	GameClock.day_started.connect(_on_day_started)
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)
	crop_sprite.visible = false # replaced by a 3D mesh; kept in-scene for compatibility
	CharacterVisualUtils.apply_pack_material(dirt, CROP_MATERIAL)
	_update_visual()
	_update_age_trim(Progression.homestead_age())
	ward_timer.wait_time = SUNFLOWER_WARD_INTERVAL
	ward_timer.timeout.connect(_on_ward_timer_timeout)
	ward_timer.start()

# Same WorldTooltip every resource node (Tree/Rock/etc. - see
# resource_node.gd) already uses - a FarmPlot was the one clickable world
# object that never told you what was planted or how close it was to ready.
func _on_mouse_entered() -> void:
	var tooltip := get_tree().get_first_node_in_group("world_tooltip")
	if tooltip:
		tooltip.show_text(_tooltip_text())

func _on_mouse_exited() -> void:
	var tooltip := get_tree().get_first_node_in_group("world_tooltip")
	if tooltip:
		tooltip.hide_text()

func _tooltip_text() -> String:
	match state:
		State.READY:
			return "%s - ready to harvest!" % current_crop.crop_name
		State.GROWING:
			var grow_time: int = current_crop.days_to_grow if current_crop else days_to_grow
			return "%s - growing (%d/%d days)" % [current_crop.crop_name, _days_growing, grow_time]
		_:
			return "Empty Plot - click to plant"

# Sunflower's ward effect (see the class comment above) - a no-op scan for
# every other crop, cheap enough to just always run rather than starting/
# stopping the timer as crops change.
func _on_ward_timer_timeout() -> void:
	if state == State.EMPTY or current_crop == null or current_crop.crop_name != "Sunflower":
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not ("flee_on_damage" in node) or not node.flee_on_damage:
			continue
		if global_position.distance_to(node.global_position) <= SUNFLOWER_WARD_RADIUS:
			node.start_fleeing()

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

func is_ready() -> bool:
	return state == State.READY

# Locust Swarm's target (locust.gd) - the crop is destroyed, not harvested,
# so no resource payout (distinct from harvest()). No-op if already empty,
# so a Locust that arrives just as a Farmer beat it to the harvest doesn't
# do anything strange.
func get_eaten() -> void:
	if state == State.EMPTY:
		return
	state = State.EMPTY
	current_crop = null
	_update_visual()

func is_empty() -> bool:
	return state == State.EMPTY

func plant(crop: CropDef = null) -> void:
	if state != State.EMPTY:
		return
	if crop == null and not available_crops.is_empty():
		crop = available_crops[_next_crop_index % available_crops.size()]
		_next_crop_index += 1
	current_crop = crop
	state = State.GROWING
	_days_growing = 0
	_update_visual()

func harvest() -> void:
	if state != State.READY:
		return
	if current_crop:
		var mult: float = AGE_YIELD_MULT.get(Progression.homestead_age(), 1.0)
		var companion := _has_companion_neighbor()
		if companion:
			mult += COMPANION_YIELD_BONUS
		var amount: int = roundi(current_crop.yield_amount * mult)
		Economy.add_resource(current_crop.ammo_type, amount)
		var message := "Harvested +%d %s (%s)" % [amount, current_crop.ammo_type.capitalize(), current_crop.crop_name]
		if companion:
			message += " - companion planting bonus!"
		NotificationManager.notify(message)
		AchievementManager.on_crop_harvested(current_crop.crop_name)
	state = State.EMPTY
	current_crop = null
	_update_visual()

func _has_companion_neighbor() -> bool:
	if current_crop == null or not COMPANION_PAIRS.has(current_crop.crop_name):
		return false
	var companions: Array = COMPANION_PAIRS[current_crop.crop_name]
	for plot in get_tree().get_nodes_in_group("farm_plots"):
		if plot == self or not is_instance_valid(plot):
			continue
		if global_position.distance_to(plot.global_position) <= COMPANION_NEIGHBOR_DISTANCE and plot.current_crop != null and plot.current_crop.crop_name in companions:
			return true
	return false

func _on_day_started(_day_count: int) -> void:
	if state != State.GROWING:
		return
	_days_growing += 1
	var grow_time := current_crop.days_to_grow if current_crop else days_to_grow
	if _days_growing >= grow_time:
		state = State.READY
		_update_visual()

func _update_visual() -> void:
	if is_instance_valid(_crop_mesh):
		_crop_mesh.queue_free()
		_crop_mesh = null
	if state == State.EMPTY:
		return
	var crop_kind: String = CROP_MESH_FALLBACK
	if current_crop and CROP_MESH_MAP.has(current_crop.crop_name):
		crop_kind = CROP_MESH_MAP[current_crop.crop_name]
	var stage := 4 if state == State.READY else 2
	var path := "res://assets/custom_pack/models/sm_crop_%s_%d.glb" % [crop_kind, stage]
	var scene: PackedScene = load(path)
	if scene == null:
		return
	_crop_mesh = scene.instantiate()
	add_child(_crop_mesh)
	CharacterVisualUtils.apply_pack_material(_crop_mesh, CROP_MATERIAL)
	if current_crop and current_crop.crop_name == "Sunflower":
		# Parented to the crop mesh itself (not this FarmPlot) so it's freed
		# automatically along with it on the next harvest/replant/eaten -
		# no separate lifecycle tracking needed.
		var light := OmniLight3D.new()
		light.set_script(NIGHT_LIGHT_SCRIPT)
		light.position = Vector3(0, 0.5, 0)
		light.night_energy = SUNFLOWER_LIGHT_ENERGY
		light.light_range = SUNFLOWER_LIGHT_RANGE
		_crop_mesh.add_child(light)

func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	match state:
		State.EMPTY:
			Selection.select_farm_plot(self)
		State.READY:
			harvest()
		State.GROWING:
			pass
