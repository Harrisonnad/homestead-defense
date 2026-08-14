extends Node

# Autoload singleton: persistent user settings (audio + display).
# Architected so real sound/music slots in later without touching this file -
# the Master bus volume is already wired and functional, just silent.

const SAVE_PATH := "user://settings.cfg"

# Common 16:9/16:10 desktop + Steam Deck (1280x800) presets. Index into this
# array is what's actually saved/restored, not the raw Vector2i, so the list
# can grow later without breaking old settings.cfg files.
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var master_volume: float = 0.8:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_volume()
var muted: bool = false:
	set(value):
		muted = value
		_apply_volume()
var fullscreen: bool = false:
	set(value):
		fullscreen = value
		_apply_display()
var resolution_index: int = 0:
	set(value):
		resolution_index = clampi(value, 0, RESOLUTIONS.size() - 1)
		_apply_display()
var vsync: bool = true:
	set(value):
		vsync = value
		_apply_display()

signal settings_changed

func _ready() -> void:
	_load()
	_apply_volume()
	_apply_display()

func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus == -1:
		return
	AudioServer.set_bus_mute(bus, muted)
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))

# Headless test runs (--headless --script ...) have no DisplayServer window,
# so every call here is guarded - calling window_set_* under the dummy
# display driver either no-ops or errors depending on the call, and none of
# this matters for logic tests anyway.
func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if not fullscreen:
		DisplayServer.window_set_size(RESOLUTIONS[resolution_index])
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "muted", muted)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "vsync", vsync)
	config.save(SAVE_PATH)
	settings_changed.emit()

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	master_volume = config.get_value("audio", "master_volume", 0.8)
	muted = config.get_value("audio", "muted", false)
	fullscreen = config.get_value("display", "fullscreen", false)
	resolution_index = config.get_value("display", "resolution_index", 0)
	vsync = config.get_value("display", "vsync", true)
