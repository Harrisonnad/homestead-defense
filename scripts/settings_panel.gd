extends CanvasLayer

# Reusable settings overlay instanced from both the main menu and the
# in-game pause menu. Master volume is functional now (wired to the Master
# audio bus via the Settings autoload) even though the project has no sound
# assets yet - ready for audio to slot in later.

@onready var volume_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var mute_check: CheckBox = $CenterContainer/PanelContainer/VBoxContainer/MuteCheck
@onready var resolution_option: OptionButton = $CenterContainer/PanelContainer/VBoxContainer/ResolutionRow/ResolutionOption
@onready var fullscreen_check: CheckBox = $CenterContainer/PanelContainer/VBoxContainer/FullscreenCheck
@onready var vsync_check: CheckBox = $CenterContainer/PanelContainer/VBoxContainer/VsyncCheck
@onready var close_button: Button = $CenterContainer/PanelContainer/VBoxContainer/CloseButton

func _ready() -> void:
	visible = false
	volume_slider.value = Settings.master_volume
	mute_check.button_pressed = Settings.muted
	for res in Settings.RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])
	resolution_option.selected = Settings.resolution_index
	fullscreen_check.button_pressed = Settings.fullscreen
	resolution_option.disabled = Settings.fullscreen
	vsync_check.button_pressed = Settings.vsync
	volume_slider.value_changed.connect(_on_volume_changed)
	mute_check.toggled.connect(_on_mute_toggled)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	close_button.pressed.connect(hide_panel)

func show_panel() -> void:
	visible = true
	close_button.grab_focus()

func hide_panel() -> void:
	visible = false
	Settings.save()

func _on_volume_changed(value: float) -> void:
	Settings.master_volume = value

func _on_mute_toggled(pressed: bool) -> void:
	Settings.muted = pressed

func _on_resolution_selected(index: int) -> void:
	Settings.resolution_index = index

func _on_fullscreen_toggled(pressed: bool) -> void:
	Settings.fullscreen = pressed
	# Windowed-only choice - fullscreen ignores it, so gray it out rather
	# than let a selection silently do nothing until fullscreen is unchecked.
	resolution_option.disabled = pressed

func _on_vsync_toggled(pressed: bool) -> void:
	Settings.vsync = pressed
