extends CanvasLayer

# Brief full-screen red flash on Homestead damage - cheap "juice" reusing a
# signal that already exists (same deferred group-lookup pattern hud.gd and
# notification_manager.gd both use).

@onready var rect: ColorRect = $ColorRect

var _last_health: int = -1

func _ready() -> void:
	rect.modulate.a = 0.0
	_connect_homestead.call_deferred()

func _connect_homestead() -> void:
	var homestead := get_tree().get_first_node_in_group("homestead")
	if homestead == null:
		return
	homestead.health_changed.connect(_on_homestead_health_changed)
	_last_health = homestead.current_health

func _on_homestead_health_changed(current: int) -> void:
	if _last_health != -1 and current < _last_health:
		_flash()
	_last_health = current

func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 0.35, 0.08)
	tween.tween_property(rect, "modulate:a", 0.0, 0.6)
