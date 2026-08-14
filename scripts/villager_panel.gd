extends CanvasLayer

# Hidden-by-default role-assignment panel. Shown when Selection reports a
# villager was clicked; Farmer/Gatherer buttons assign that villager's role.

@onready var panel: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var farmer_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/FarmerButton
@onready var gatherer_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/GathererButton
@onready var guard_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/GuardButton

var current_villager: Villager = null

func _ready() -> void:
	panel.visible = false
	Selection.villager_selected.connect(_on_villager_selected)
	Selection.farm_plot_selected.connect(_on_other_panel_selected)
	farmer_button.pressed.connect(_on_farmer_pressed)
	gatherer_button.pressed.connect(_on_gatherer_pressed)
	guard_button.pressed.connect(_on_guard_pressed)

func _on_other_panel_selected(_plot: Node) -> void:
	panel.visible = false

func _on_villager_selected(villager: Villager) -> void:
	current_villager = villager
	panel.visible = true
	_refresh_title()

func _on_farmer_pressed() -> void:
	_assign(Villager.Role.FARMER)

func _on_gatherer_pressed() -> void:
	_assign(Villager.Role.GATHERER)

func _on_guard_pressed() -> void:
	_assign(Villager.Role.GUARD)

func _assign(role: Villager.Role) -> void:
	if current_villager == null:
		return
	current_villager.set_role(role)
	_refresh_title()

func _refresh_title() -> void:
	title_label.text = "Villager: %s (%d/%d HP)" % [
		Villager.Role.keys()[current_villager.role],
		current_villager.current_health,
		current_villager.max_health,
	]
