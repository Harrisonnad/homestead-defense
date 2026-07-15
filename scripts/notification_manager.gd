extends CanvasLayer

# Autoload (scene, not just script) - a small toast queue subscribing
# directly to signals that already exist (Progression.upgrade_purchased,
# the Homestead's health_changed via the same deferred group-lookup pattern
# hud.gd uses) so the scripts that emit them need no changes. BuildManager
# also calls notify() directly for a failed-placement reason.

const DISPLAY_SECONDS := 2.5
const FADE_SECONDS := 0.5

@onready var toast_list: VBoxContainer = $CenterContainer/PanelContainer/ToastList

var _last_homestead_health: int = -1

func _ready() -> void:
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)
	_connect_homestead.call_deferred()

func _connect_homestead() -> void:
	var homestead := get_tree().get_first_node_in_group("homestead")
	if homestead == null:
		return
	homestead.health_changed.connect(_on_homestead_health_changed)
	_last_homestead_health = homestead.current_health

func _on_homestead_health_changed(current: int) -> void:
	if _last_homestead_health != -1 and current < _last_homestead_health:
		notify("The Homestead is under attack!")
	_last_homestead_health = current

func _on_upgrade_purchased(id: String) -> void:
	if Progression.UPGRADES.has(id):
		notify("Upgrade purchased: %s" % Progression.UPGRADES[id]["name"])

func notify(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_list.add_child(label)
	var tween := create_tween()
	tween.tween_interval(DISPLAY_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(label.queue_free)
