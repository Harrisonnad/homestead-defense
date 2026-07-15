extends CanvasLayer

# The unlock board: toggled with T, one button per Progression.UPGRADES
# entry (built dynamically so adding an upgrade needs no scene edit).
# Buttons gray out when unaffordable and disappear once purchased (unless
# repeatable).

@onready var panel: PanelContainer = $PanelContainer
@onready var button_list: VBoxContainer = $PanelContainer/VBoxContainer/ButtonList

var _buttons: Dictionary = {}

func _ready() -> void:
	panel.visible = false
	Economy.resources_changed.connect(_on_resources_changed)
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)
	Progression.state_loaded.connect(_refresh_buttons)
	_build_buttons()
	_refresh_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		panel.visible = not panel.visible

func _build_buttons() -> void:
	for id in Progression.UPGRADES:
		var upgrade: Dictionary = Progression.UPGRADES[id]
		var button := Button.new()
		button.text = "%s (%s)\n%s" % [upgrade["name"], _cost_text(upgrade["costs"]), upgrade["description"]]
		button.tooltip_text = upgrade["description"]
		button.pressed.connect(_on_button_pressed.bind(id))
		button_list.add_child(button)
		_buttons[id] = button

func _cost_text(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for type in costs:
		parts.append("%d %s" % [costs[type], type])
	return ", ".join(parts)

func _on_button_pressed(id: String) -> void:
	Progression.try_purchase(id)

func _on_resources_changed(_type: String, _new_amount: int) -> void:
	_refresh_buttons()

func _on_upgrade_purchased(_id: String) -> void:
	_refresh_buttons()

func _refresh_buttons() -> void:
	for id in _buttons:
		var button: Button = _buttons[id]
		var done: bool = Progression.is_purchased(id) and not Progression.UPGRADES[id]["repeatable"]
		button.visible = not done
		button.disabled = not Progression.can_purchase(id)
