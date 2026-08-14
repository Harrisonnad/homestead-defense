extends CanvasLayer

# Resource/status readout, restyled to match the build hotbar's look: a
# panel background with color-coded icon chips (build_menu.gd's
# category-color language reused here - wood/stone/food/defense/core) instead
# of a bare stack of plain labels.

const ICON_SIZE := 18
const ICON_COLORS := {
	"wood": Color(0.55, 0.4, 0.25),
	"stone": Color(0.55, 0.55, 0.58),
	"food": Color(0.3, 0.65, 0.25),
	"home": Color(0.8, 0.25, 0.2),
	"pop": Color(0.25, 0.45, 0.85),
	"cannonballs": Color(0.35, 0.35, 0.4),
	"darts": Color(0.65, 0.55, 0.2),
	"grenades": Color(0.6, 0.25, 0.2),
	"bullets": Color(0.4, 0.55, 0.3),
}

# Ammo (§ architecture-decisions.md "known gap": ammo counts weren't shown
# anywhere in the persistent HUD). One chip per ammo type, same shape as
# Home/Pop (non-interactive - ammo isn't a gatherer-priority resource) since
# each is tied to a specific crop (crop_def.gd) and a specific defense
# building's ammo_type, not something a Gatherer villager can prioritize.
const AMMO_TYPES := {
	"cannonballs": "Cannonballs",
	"darts": "Darts",
	"grenades": "Grenades",
	"bullets": "Bullets",
}

@onready var wood_label: Label = $PanelContainer/VBoxContainer/ResourceRow/WoodChip/Label
@onready var food_label: Label = $PanelContainer/VBoxContainer/ResourceRow/FoodChip/Label
@onready var stone_label: Label = $PanelContainer/VBoxContainer/ResourceRow/StoneChip/Label
@onready var home_label: Label = $PanelContainer/VBoxContainer/ResourceRow/HomeChip/Label
@onready var pop_label: Label = $PanelContainer/VBoxContainer/ResourceRow/PopChip/Label
@onready var day_label: Label = $PanelContainer/VBoxContainer/StatusRow/DayLabel
@onready var phase_label: Label = $PanelContainer/VBoxContainer/StatusRow/PhaseLabel
@onready var ammo_labels: Dictionary = {
	"cannonballs": $PanelContainer/VBoxContainer/AmmoRow/CannonballsChip/Label,
	"darts": $PanelContainer/VBoxContainer/AmmoRow/DartsChip/Label,
	"grenades": $PanelContainer/VBoxContainer/AmmoRow/GrenadesChip/Label,
	"bullets": $PanelContainer/VBoxContainer/AmmoRow/BulletsChip/Label,
}

# Wood/Food/Stone chip icons are Buttons, not plain TextureRects (Home/Pop
# still are) - clicking one sets Economy.priority_resource_type so Gatherer
# villagers prefer that resource (#29). Home/Pop aren't gatherable, so they
# stay non-interactive.
const PRIORITY_CHIPS := {
	"wood": "WoodChip",
	"food": "FoodChip",
	"stone": "StoneChip",
}

func _ready() -> void:
	Economy.resources_changed.connect(_on_resources_changed)
	Economy.caps_changed.connect(_on_caps_changed)
	Economy.priority_changed.connect(_on_priority_changed)
	GameClock.day_started.connect(_on_day_started)
	GameClock.night_started.connect(_on_night_started)
	GameState.population_cap_changed.connect(_on_population_cap_changed)
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)

	for type in PRIORITY_CHIPS:
		_set_button_icon(PRIORITY_CHIPS[type], type)
		var button: Button = get_node("PanelContainer/VBoxContainer/ResourceRow/%s/Icon" % PRIORITY_CHIPS[type])
		button.pressed.connect(Economy.set_priority_resource.bind(type))
	_set_icon("HomeChip", "home")
	_set_icon("PopChip", "pop")
	for type in AMMO_TYPES:
		_set_icon("%sChip" % AMMO_TYPES[type], type, "AmmoRow")
		_set_resource_label(ammo_labels[type], AMMO_TYPES[type], type)

	_set_resource_label(wood_label, "Wood", "wood")
	_set_resource_label(food_label, "Food", "food")
	_set_resource_label(stone_label, "Stone", "stone")
	_set_day_label(GameClock.day_count)
	_set_population_label()
	phase_label.text = "Day" if GameClock.is_daytime() else "Night"
	# The Homestead may sit later in the tree, so its group registration can
	# land after this _ready — connect once the first frame has settled.
	_connect_homestead.call_deferred()

func _set_icon(chip_name: String, color_key: String, row_name: String = "ResourceRow") -> void:
	var rect: TextureRect = get_node("PanelContainer/VBoxContainer/%s/%s/Icon" % [row_name, chip_name])
	rect.texture = _make_icon_texture(color_key)

func _set_button_icon(chip_name: String, color_key: String) -> void:
	var button: Button = get_node("PanelContainer/VBoxContainer/ResourceRow/%s/Icon" % chip_name)
	button.icon = _make_icon_texture(color_key)

func _make_icon_texture(color_key: String) -> ImageTexture:
	var image := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(ICON_COLORS[color_key])
	return ImageTexture.create_from_image(image)

func _on_priority_changed(_type: String) -> void:
	_set_resource_label(wood_label, "Wood", "wood")
	_set_resource_label(food_label, "Food", "food")
	_set_resource_label(stone_label, "Stone", "stone")

func _connect_homestead() -> void:
	var homestead := get_tree().get_first_node_in_group("homestead")
	if homestead == null:
		return
	homestead.health_changed.connect(_on_homestead_health_changed)
	home_label.text = "Home: %d" % homestead.current_health

func _on_homestead_health_changed(current: int) -> void:
	home_label.text = "Home: %d" % current

func _set_resource_label(label: Label, display_name: String, type: String) -> void:
	var prefix := "* " if Economy.priority_resource_type == type else ""
	label.text = "%s%s: %d/%d" % [prefix, display_name, Economy.get_amount(type), Economy.get_cap(type)]

func _on_resources_changed(type: String, new_amount: int) -> void:
	if type == "wood":
		_set_resource_label(wood_label, "Wood", "wood")
	elif type == "food":
		_set_resource_label(food_label, "Food", "food")
	elif type == "stone":
		_set_resource_label(stone_label, "Stone", "stone")
	elif AMMO_TYPES.has(type):
		_set_resource_label(ammo_labels[type], AMMO_TYPES[type], type)

func _on_caps_changed(_type: String, _new_cap: int) -> void:
	_set_resource_label(wood_label, "Wood", "wood")
	_set_resource_label(food_label, "Food", "food")
	_set_resource_label(stone_label, "Stone", "stone")
	for type in AMMO_TYPES:
		_set_resource_label(ammo_labels[type], AMMO_TYPES[type], type)

func _set_population_label() -> void:
	pop_label.text = "Pop: %d/%d" % [GameState.current_population(), GameState.population_cap]

func _on_population_cap_changed(_new_cap: int) -> void:
	_set_population_label()

func _on_upgrade_purchased(id: String) -> void:
	if id == "recruit_villager":
		_set_population_label.call_deferred()

func _set_day_label(day_count: int) -> void:
	day_label.text = "Day %d / %d" % [day_count, GameState.season_length_days]

func _on_day_started(day_count: int) -> void:
	_set_day_label(day_count)
	phase_label.text = "Day"

func _on_night_started() -> void:
	phase_label.text = "Night"
