extends Node

# Autoload singleton: persistent user settings (currently just audio).
# Architected so real sound/music slots in later without touching this file -
# the Master bus volume is already wired and functional, just silent.

const SAVE_PATH := "user://settings.cfg"

var master_volume: float = 0.8:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_volume()
var muted: bool = false:
	set(value):
		muted = value
		_apply_volume()

signal settings_changed

func _ready() -> void:
	_load()
	_apply_volume()

func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus == -1:
		return
	AudioServer.set_bus_mute(bus, muted)
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))

func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "muted", muted)
	config.save(SAVE_PATH)
	settings_changed.emit()

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	master_volume = config.get_value("audio", "master_volume", 0.8)
	muted = config.get_value("audio", "muted", false)
