extends CanvasLayer

# Opt-in interactive tutorial for new games. main_menu.gd sets
# SaveManager.show_tutorial_prompt = true only from "New Game" (never
# "Continue"), so returning players loading a save never see this prompt.
# Pauses the tree while active (process_mode = Always, same convention as
# pause_menu.gd/settings_panel.tscn) so a new player isn't rushed into the
# first night while reading.

@onready var prompt_panel: CenterContainer = $PromptPanel
@onready var step_panel: CenterContainer = $StepPanel
@onready var title_label: Label = $StepPanel/PanelContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $StepPanel/PanelContainer/VBoxContainer/BodyLabel
@onready var step_count_label: Label = $StepPanel/PanelContainer/VBoxContainer/StepCountLabel
@onready var next_button: Button = $StepPanel/PanelContainer/VBoxContainer/HBoxContainer/NextButton
@onready var skip_button: Button = $StepPanel/PanelContainer/VBoxContainer/HBoxContainer/SkipButton
@onready var yes_button: Button = $PromptPanel/PanelContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_button: Button = $PromptPanel/PanelContainer/VBoxContainer/HBoxContainer/NoButton

var _steps: Array[Dictionary] = []
var _step_index: int = 0

func _ready() -> void:
	prompt_panel.visible = false
	step_panel.visible = false
	if not SaveManager.show_tutorial_prompt:
		return
	SaveManager.show_tutorial_prompt = false
	_steps = _build_steps()
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_close)
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_close)
	prompt_panel.visible = true
	get_tree().paused = true

func _build_steps() -> Array[Dictionary]:
	return [
		{
			"title": "Welcome to Homestead Defense",
			"body": "Survive %d days and nights. By day, gather resources and build up defenses; by night, raiders head straight for your home base. If its health hits zero, the season is lost." % GameState.season_length_days,
		},
		{
			"title": "Resources",
			"body": "Wood and Stone construct buildings; Food feeds your population and some upgrades. Watch the HUD in the top-left for current amounts and storage caps.",
		},
		{
			"title": "Villagers",
			"body": "Click a villager to open its role panel: Farmer tends farm plots, Gatherer harvests trees/rocks/hay, Guard fights off enemies. An unassigned villager just stands idle, so give everyone a job.",
		},
		{
			"title": "Building",
			"body": "Press B to toggle the build bar at the bottom of the screen, or press 1-7 to instantly select a building. Left-click to place, R to rotate, right-click or Esc to cancel.",
		},
		{
			"title": "Day & Night",
			"body": "Daylight is your prep window. At night, raiders spawn around your base and beeline for it - walls, towers, and Guards are your line of defense. A red screen flash and camera shake mean your base just took a hit.",
		},
		{
			"title": "You're ready",
			"body": "Press Esc any time to pause, save, or check settings. Good luck out there!",
		},
	]

func _on_yes() -> void:
	prompt_panel.visible = false
	_step_index = 0
	step_panel.visible = true
	_show_step()

func _show_step() -> void:
	var step: Dictionary = _steps[_step_index]
	title_label.text = step["title"]
	body_label.text = step["body"]
	step_count_label.text = "%d / %d" % [_step_index + 1, _steps.size()]
	next_button.text = "Finish" if _step_index == _steps.size() - 1 else "Next"

func _on_next() -> void:
	if _step_index >= _steps.size() - 1:
		_close()
		return
	_step_index += 1
	_show_step()

func _close() -> void:
	prompt_panel.visible = false
	step_panel.visible = false
	get_tree().paused = false
