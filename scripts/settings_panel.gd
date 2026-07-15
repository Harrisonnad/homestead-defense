extends CanvasLayer

# Reusable settings overlay instanced from both the main menu and the
# in-game pause menu. Master volume is functional now (wired to the Master
# audio bus via the Settings autoload) even though the project has no sound
# assets yet - ready for audio to slot in later.

@onready var volume_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var mute_check: CheckBox = $CenterContainer/PanelContainer/VBoxContainer/MuteCheck
@onready var close_button: Button = $CenterContainer/PanelContainer/VBoxContainer/CloseButton

func _ready() -> void:
	visible = false
	volume_slider.value = Settings.master_volume
	mute_check.button_pressed = Settings.muted
	volume_slider.value_changed.connect(_on_volume_changed)
	mute_check.toggled.connect(_on_mute_toggled)
	close_button.pressed.connect(hide_panel)

func show_panel() -> void:
	visible = true

func hide_panel() -> void:
	visible = false
	Settings.save()

func _on_volume_changed(value: float) -> void:
	Settings.master_volume = value

func _on_mute_toggled(pressed: bool) -> void:
	Settings.muted = pressed
