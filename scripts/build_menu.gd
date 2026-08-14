extends CanvasLayer

# Build hotbar: a persistent bottom-of-screen bar (B toggles it away if it's
# in the way); number keys starting at 1 quick-select regardless of whether
# the bar is visible (matches the old single-key wall/trap muscle memory).
# Buttons build from building_defs so adding a BuildingDef needs no scene
# edit, same pattern as the upgrade board.
#
# Top-level slots are grouped by BuildingDef.category, not one slot per
# building - a category with only one building (farm/core/storage/pen/wall/
# utility today) still shows and hotkeys directly, exactly like before. A
# category with more than one building (defense: Watchtower/Ballista/Sling
# Post/Spike Trap/Scarecrow/Net Trap) collapses into a single group button;
# pressing its hotkey (or clicking it) opens a flyout row of that
# category's buildings, each with its own 1-9 hotkey while the flyout is
# open. This is what keeps the bar from growing one slot per new building
# forever while staying fully keyboard-driven. Only the first HOTKEY_SLOTS
# top-level slots (and, independently, the first HOTKEY_SLOTS buildings
# within an open flyout) get a number hotkey - anything past that is still
# fully clickable, just unlabeled/no-hotkey.

const HOTKEY_SLOTS := 9
const PANEL_BASE_OFFSET_TOP := -84.0
const FLYOUT_ROW_HEIGHT := 68.0

@export var building_defs: Array[BuildingDef] = []
@export var build_manager_path: NodePath

const ICON_SIZE := 28
const CATEGORY_COLORS := {
	"wall": Color(0.55, 0.55, 0.58),
	"defense": Color(0.8, 0.25, 0.2),
	"farm": Color(0.3, 0.65, 0.25),
	"core": Color(0.25, 0.45, 0.85),
	"storage": Color(0.75, 0.55, 0.2),
	"pen": Color(0.75, 0.65, 0.4),
	"utility": Color(0.85, 0.7, 0.35),
	"bridge": Color(0.45, 0.55, 0.7),
}
const CATEGORY_LABELS := {
	"defense": "Defenses",
	"utility": "Utility",
}
const DEFAULT_ICON_COLOR := Color(0.6, 0.6, 0.6)

@onready var panel: PanelContainer = $PanelContainer
@onready var hint_label: Label = $PanelContainer/VBoxContainer/HintLabel
@onready var flyout_list: HBoxContainer = $PanelContainer/VBoxContainer/FlyoutList
@onready var button_list: HBoxContainer = $PanelContainer/VBoxContainer/ButtonList
@onready var build_manager = get_node(build_manager_path)

# Each entry: {"category": String, "def_indices": Array[int]} - built once
# from building_defs, grouping same-category defs together in the order
# their category first appears.
var _top_level: Array = []
var _buttons: Array[Button] = []
var _open_group_index: int = -1
var _flyout_buttons: Array[Button] = []
var _flyout_def_indices: Array[int] = []

func _ready() -> void:
	panel.visible = true
	Economy.resources_changed.connect(_on_economy_changed)
	Economy.caps_changed.connect(_on_economy_changed)
	_group_building_defs()
	_build_buttons()
	_refresh_buttons()

func _process(_delta: float) -> void:
	hint_label.visible = build_manager.selected_def != null

func _group_building_defs() -> void:
	_top_level.clear()
	var category_to_index := {}
	for i in building_defs.size():
		var def: BuildingDef = building_defs[i]
		if category_to_index.has(def.category):
			_top_level[category_to_index[def.category]].def_indices.append(i)
		else:
			category_to_index[def.category] = _top_level.size()
			_top_level.append({"category": def.category, "def_indices": [i]})

func _build_buttons() -> void:
	for i in _top_level.size():
		var group: Dictionary = _top_level[i]
		var show_hotkey: bool = i < HOTKEY_SLOTS
		var button: Button
		if group.def_indices.size() == 1:
			button = _make_building_button(building_defs[group.def_indices[0]], i, show_hotkey)
		else:
			button = _make_group_button(group, i, show_hotkey)
		button.pressed.connect(_on_top_level_selected.bind(i))
		button_list.add_child(button)
		_buttons.append(button)

func _make_building_button(def: BuildingDef, hotkey_index: int, show_hotkey: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(88, 64)
	button.icon = _make_icon(def.category)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if show_hotkey:
		button.text = "[%d] %s" % [hotkey_index + 1, def.building_name]
		button.tooltip_text = "%s\nCost: %s\nHotkey: %d" % [def.description, _cost_text(def.resource_cost), hotkey_index + 1]
	else:
		button.text = def.building_name
		button.tooltip_text = "%s\nCost: %s" % [def.description, _cost_text(def.resource_cost)]
	return button

func _make_group_button(group: Dictionary, hotkey_index: int, show_hotkey: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(88, 64)
	var label: String = CATEGORY_LABELS.get(group.category, String(group.category).capitalize())
	button.icon = _make_icon(group.category)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var names: Array[String] = []
	for def_index in group.def_indices:
		names.append(building_defs[def_index].building_name)
	var name_list: String = ", ".join(names)
	if show_hotkey:
		button.text = "[%d] %s +" % [hotkey_index + 1, label]
		button.tooltip_text = "%s: %s\nHotkey %d, then 1-%d to pick one" % [label, name_list, hotkey_index + 1, names.size()]
	else:
		button.text = "%s +" % label
		button.tooltip_text = "%s: %s" % [label, name_list]
	return button

func _make_icon(category: String) -> ImageTexture:
	var color: Color = CATEGORY_COLORS.get(category, DEFAULT_ICON_COLOR)
	var image := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

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
		_close_flyout()
		if panel.visible and _buttons.size() > 0:
			_buttons[0].grab_focus()
		return
	if event.keycode < KEY_1 or event.keycode > KEY_9:
		return
	var slot: int = event.keycode - KEY_1
	if _open_group_index != -1:
		var group: Dictionary = _top_level[_open_group_index]
		if slot < mini(group.def_indices.size(), HOTKEY_SLOTS):
			_on_building_selected(group.def_indices[slot])
			return
		_close_flyout()
	if slot < mini(_top_level.size(), HOTKEY_SLOTS):
		_on_top_level_selected(slot)

func _on_top_level_selected(index: int) -> void:
	var group: Dictionary = _top_level[index]
	if group.def_indices.size() == 1:
		_on_building_selected(group.def_indices[0])
	else:
		_toggle_flyout(index)

func _on_building_selected(index: int) -> void:
	build_manager.start_placing(building_defs[index])
	_close_flyout()

func _toggle_flyout(index: int) -> void:
	if _open_group_index == index:
		_close_flyout()
		return
	_open_group_index = index
	for child in flyout_list.get_children():
		child.queue_free()
	_flyout_buttons.clear()
	_flyout_def_indices.clear()
	var group: Dictionary = _top_level[index]
	for i in group.def_indices.size():
		var def_index: int = group.def_indices[i]
		var button := _make_building_button(building_defs[def_index], i, i < HOTKEY_SLOTS)
		button.pressed.connect(_on_building_selected.bind(def_index))
		flyout_list.add_child(button)
		_flyout_buttons.append(button)
		_flyout_def_indices.append(def_index)
	flyout_list.visible = true
	panel.offset_top = PANEL_BASE_OFFSET_TOP - FLYOUT_ROW_HEIGHT
	_refresh_buttons()

func _close_flyout() -> void:
	if _open_group_index == -1:
		return
	_open_group_index = -1
	flyout_list.visible = false
	for child in flyout_list.get_children():
		child.queue_free()
	_flyout_buttons.clear()
	_flyout_def_indices.clear()
	panel.offset_top = PANEL_BASE_OFFSET_TOP

func _on_economy_changed(_type: String, _amount: int) -> void:
	_refresh_buttons()

func _refresh_buttons() -> void:
	for i in _buttons.size():
		var group: Dictionary = _top_level[i]
		var affordable := false
		for def_index in group.def_indices:
			if Economy.can_afford_all(building_defs[def_index].resource_cost):
				affordable = true
				break
		_buttons[i].disabled = not affordable
	for i in _flyout_buttons.size():
		_flyout_buttons[i].disabled = not Economy.can_afford_all(building_defs[_flyout_def_indices[i]].resource_cost)
