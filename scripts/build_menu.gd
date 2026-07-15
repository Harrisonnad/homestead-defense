extends CanvasLayer

# Build palette: B toggles panel visibility, 1-7 quick-select a building and
# start placing regardless of whether the panel is open (matches the old
# single-key wall/trap muscle memory). Buttons build from building_defs so
# adding a BuildingDef needs no scene edit, same pattern as the upgrade
# board.

@export var building_defs: Array[BuildingDef] = []
@export var build_manager_path: NodePath

@onready var panel: PanelContainer = $PanelContainer
@onready var button_list: VBoxContainer = $PanelContainer/VBoxContainer/ButtonList
@onready var build_manager = get_node(build_manager_path)

var _buttons: Array[Button] = []

func _ready() -> void:
	panel.visible = false
	Economy.resources_changed.connect(_on_economy_changed)
	Economy.caps_changed.connect(_on_economy_changed)
	_build_buttons()
	_refresh_buttons()

func _build_buttons() -> void:
	for i in building_defs.size():
		var def: BuildingDef = building_defs[i]
		var button := Button.new()
		button.text = "[%d] %s (%s)" % [i + 1, def.building_name, _cost_text(def.resource_cost)]
		button.tooltip_text = def.description
		button.pressed.connect(_on_building_selected.bind(i))
		button_list.add_child(button)
		_buttons.append(button)

func _cost_text(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for type in costs:
		parts.append("%d %s" % [costs[type], type])
	return ", ".join(parts)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_B:
		panel.visible = not panel.visible
	elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
		var index: int = event.keycode - KEY_1
		if index < building_defs.size():
			_on_building_selected(index)

func _on_building_selected(index: int) -> void:
	build_manager.start_placing(building_defs[index])

func _on_economy_changed(_type: String, _amount: int) -> void:
	_refresh_buttons()

func _refresh_buttons() -> void:
	for i in _buttons.size():
		_buttons[i].disabled = not Economy.can_afford_all(building_defs[i].resource_cost)
