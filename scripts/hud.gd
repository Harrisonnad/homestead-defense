extends CanvasLayer

@onready var wood_label: Label = $VBoxContainer/WoodLabel
@onready var food_label: Label = $VBoxContainer/FoodLabel
@onready var stone_label: Label = $VBoxContainer/StoneLabel
@onready var home_label: Label = $VBoxContainer/HomeLabel
@onready var pop_label: Label = $VBoxContainer/PopLabel
@onready var day_label: Label = $VBoxContainer/DayLabel
@onready var phase_label: Label = $VBoxContainer/PhaseLabel

func _ready() -> void:
	Economy.resources_changed.connect(_on_resources_changed)
	Economy.caps_changed.connect(_on_caps_changed)
	GameClock.day_started.connect(_on_day_started)
	GameClock.night_started.connect(_on_night_started)
	GameState.population_cap_changed.connect(_on_population_cap_changed)
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)

	_set_resource_label(wood_label, "Wood", "wood")
	_set_resource_label(food_label, "Food", "food")
	_set_resource_label(stone_label, "Stone", "stone")
	_set_day_label(GameClock.day_count)
	_set_population_label()
	phase_label.text = "Day" if GameClock.is_daytime() else "Night"
	# The Homestead may sit later in the tree, so its group registration can
	# land after this _ready — connect once the first frame has settled.
	_connect_homestead.call_deferred()

func _connect_homestead() -> void:
	var homestead := get_tree().get_first_node_in_group("homestead")
	if homestead == null:
		return
	homestead.health_changed.connect(_on_homestead_health_changed)
	home_label.text = "Home: %d" % homestead.current_health

func _on_homestead_health_changed(current: int) -> void:
	home_label.text = "Home: %d" % current

func _set_resource_label(label: Label, display_name: String, type: String) -> void:
	label.text = "%s: %d/%d" % [display_name, Economy.get_amount(type), Economy.get_cap(type)]

func _on_resources_changed(type: String, new_amount: int) -> void:
	if type == "wood":
		_set_resource_label(wood_label, "Wood", "wood")
	elif type == "food":
		_set_resource_label(food_label, "Food", "food")
	elif type == "stone":
		_set_resource_label(stone_label, "Stone", "stone")

func _on_caps_changed(_type: String, _new_cap: int) -> void:
	_set_resource_label(wood_label, "Wood", "wood")
	_set_resource_label(food_label, "Food", "food")
	_set_resource_label(stone_label, "Stone", "stone")

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
