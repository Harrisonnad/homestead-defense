extends Node

# Autoload singleton: ambient background music, one looping track, always on.
# AudioStreamPlayer defaults to the "Master" bus, which Settings.gd already
# drives (volume/mute) - no separate music bus/slider needed yet.

const TRACK := preload("res://assets/audio/music/morning_dew_on_the_farm.mp3")
const VOLUME_DB := -10.0

@onready var player := AudioStreamPlayer.new()

func _ready() -> void:
	add_child(player)
	player.stream = TRACK
	player.volume_db = VOLUME_DB
	if player.stream is AudioStreamMP3:
		player.stream.loop = true
	player.play()
