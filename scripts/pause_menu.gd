extends CanvasLayer

# ui_cancel (Escape / gamepad B by default) toggles this, except while
# BuildManager has an active placement ghost - ui_cancel cancels placement
# instead (checked explicitly here rather than relying on _unhandled_input
# ordering between sibling nodes).

@export var build_manager_path: NodePath

@onready var build_manager = get_node_or_null(build_manager_path)
@onready var panel_root: CenterContainer = $CenterContainer
@onready var settings_panel := $SettingsPanel

func _ready() -> void:
	panel_root.visible = false
	$CenterContainer/PanelContainer/VBoxContainer/ResumeButton.pressed.connect(_close)
	$CenterContainer/PanelContainer/VBoxContainer/SaveButton.pressed.connect(_on_save)
	$CenterContainer/PanelContainer/VBoxContainer/LoadButton.pressed.connect(_on_load)
	$CenterContainer/PanelContainer/VBoxContainer/SettingsButton.pressed.connect(settings_panel.show_panel)
	$CenterContainer/PanelContainer/VBoxContainer/RestartButton.pressed.connect(_on_restart)
	$CenterContainer/PanelContainer/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu)
	$CenterContainer/PanelContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if GameState.ended:
		return
	if build_manager and build_manager.selected_def != null:
		return
	if panel_root.visible:
		_close()
	else:
		_open()
	get_viewport().set_input_as_handled()

func _open() -> void:
	panel_root.visible = true
	get_tree().paused = true
	$CenterContainer/PanelContainer/VBoxContainer/ResumeButton.grab_focus()

func _close() -> void:
	panel_root.visible = false
	get_tree().paused = false

func _on_save() -> void:
	var ok := SaveManager.save_game()
	NotificationManager.notify("Game saved" if ok else "Save failed")

func _on_load() -> void:
	SaveManager.load_game()
	NotificationManager.notify("Game loaded")
	_close()

func _on_restart() -> void:
	_close()
	GameState.restart()

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_quit() -> void:
	get_tree().quit()
