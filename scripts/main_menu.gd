extends Control

@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var settings_panel := $SettingsPanel
@onready var seed_input: LineEdit = $CenterContainer/VBoxContainer/SeedRow/SeedInput
@onready var difficulty_option: OptionButton = $CenterContainer/VBoxContainer/DifficultyRow/DifficultyOption

func _ready() -> void:
	continue_button.disabled = not SaveManager.has_save()
	new_game_button.pressed.connect(_on_new_game)
	continue_button.pressed.connect(_on_continue)
	settings_button.pressed.connect(settings_panel.show_panel)
	quit_button.pressed.connect(_on_quit)
	# Gamepad-only players need a starting focus - ui_up/down/accept are
	# already gamepad-mapped by Godot's default InputMap, this is the only
	# missing piece for menu navigation without a mouse.
	(continue_button if not continue_button.disabled else new_game_button).grab_focus()

func _on_new_game() -> void:
	SaveManager.pending_load = false
	SaveManager.show_tutorial_prompt = true
	GameState.pending_seed = _parse_seed(seed_input.text)
	GameState.difficulty = GameState.DIFFICULTIES[difficulty_option.selected]
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# Blank or non-numeric input means "random" (0), matching MapBuilder's own
# seed_override convention - a typo in the seed field should never crash
# the New Game flow.
func _parse_seed(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty() or not trimmed.is_valid_int():
		return 0
	return int(trimmed)

func _on_continue() -> void:
	SaveManager.pending_load = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_quit() -> void:
	get_tree().quit()
