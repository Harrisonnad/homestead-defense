extends CanvasLayer

# Season end screen. PROCESS_MODE_ALWAYS (set in the scene) so the Restart
# button still works while the tree is paused.

@onready var root: Control = $Root
@onready var title_label: Label = $Root/CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Root/CenterContainer/VBoxContainer/SubtitleLabel
@onready var restart_button: Button = $Root/CenterContainer/VBoxContainer/RestartButton

func _ready() -> void:
	root.visible = false
	GameState.game_ended.connect(_on_game_ended)
	restart_button.pressed.connect(_on_restart_pressed)

func _on_game_ended(won: bool, day: int) -> void:
	if won:
		title_label.text = "Season Survived!"
		subtitle_label.text = "Your homestead made it through all %d days." % day
	else:
		title_label.text = "The Homestead Has Fallen"
		subtitle_label.text = "You held out until day %d." % day
	root.visible = true
	get_tree().paused = true

func _on_restart_pressed() -> void:
	GameState.restart()
