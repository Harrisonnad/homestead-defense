extends CanvasLayer

@onready var wood_label: Label = $VBoxContainer/WoodLabel
@onready var food_label: Label = $VBoxContainer/FoodLabel
@onready var stone_label: Label = $VBoxContainer/StoneLabel
@onready var home_label: Label = $VBoxContainer/HomeLabel
@onready var day_label: Label = $VBoxContainer/DayLabel
@onready var phase_label: Label = $VBoxContainer/PhaseLabel

func _ready() -> void:
	Economy.resources_changed.connect(_on_resources_changed)
	GameClock.day_started.connect(_on_day_started)
	GameClock.night_started.connect(_on_night_started)

	wood_label.text = "Wood: %d" % Economy.get_amount("wood")
	food_label.text = "Food: %d" % Economy.get_amount("food")
	stone_label.text = "Stone: %d" % Economy.get_amount("stone")
	_set_day_label(GameClock.day_count)
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

func _on_resources_changed(type: String, new_amount: int) -> void:
	if type == "wood":
		wood_label.text = "Wood: %d" % new_amount
	elif type == "food":
		food_label.text = "Food: %d" % new_amount
	elif type == "stone":
		stone_label.text = "Stone: %d" % new_amount

func _set_day_label(day_count: int) -> void:
	day_label.text = "Day %d / %d" % [day_count, GameState.season_length_days]

func _on_day_started(day_count: int) -> void:
	_set_day_label(day_count)
	phase_label.text = "Day"

func _on_night_started() -> void:
	phase_label.text = "Night"
