extends CanvasLayer

# Small floating label that follows the mouse while hovering a world object
# (currently resource nodes - see resource_node.gd). Found via group lookup
# (get_tree().get_first_node_in_group("world_tooltip")), same pattern as
# NotificationManager, since callers live deep in the scene tree.

const OFFSET := Vector2(16, 16)

@onready var label: Label = $PanelContainer/Label
@onready var panel: PanelContainer = $PanelContainer

func _ready() -> void:
	add_to_group("world_tooltip")
	panel.visible = false

func _process(_delta: float) -> void:
	if panel.visible:
		panel.position = get_viewport().get_mouse_position() + OFFSET

func show_text(text: String) -> void:
	label.text = text
	panel.visible = true

func hide_text() -> void:
	panel.visible = false
