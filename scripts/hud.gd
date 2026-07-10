extends CanvasLayer

@onready var wood_label: Label = $VBoxContainer/WoodLabel
@onready var food_label: Label = $VBoxContainer/FoodLabel
@onready var stone_label: Label = $VBoxContainer/StoneLabel
@onready var day_label: Label = $VBoxContainer/DayLabel
@onready var phase_label: Label = $VBoxContainer/PhaseLabel

func _ready() -> void:
	Economy.resources_changed.connect(_on_resources_changed)
	GameClock.day_started.connect(_on_day_started)
	GameClock.night_started.connect(_on_night_started)

	wood_label.text = "Wood: %d" % Economy.get_amount("wood")
	food_label.text = "Food: %d" % Economy.get_amount("food")
	stone_label.text = "Stone: %d" % Economy.get_amount("stone")
	day_label.text = "Day %d" % GameClock.day_count
	phase_label.text = "Day" if GameClock.is_daytime() else "Night"

func _on_resources_changed(type: String, new_amount: int) -> void:
	if type == "wood":
		wood_label.text = "Wood: %d" % new_amount
	elif type == "food":
		food_label.text = "Food: %d" % new_amount
	elif type == "stone":
		stone_label.text = "Stone: %d" % new_amount

func _on_day_started(day_count: int) -> void:
	day_label.text = "Day %d" % day_count
	phase_label.text = "Day"

func _on_night_started() -> void:
	phase_label.text = "Night"
