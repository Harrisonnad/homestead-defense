extends CanvasLayer

# Hidden-by-default crop-choice panel. Shown when Selection reports an empty
# FarmPlot was clicked (see farm_plot.gd) - lets the player pick which of the
# plot's available_crops to plant, instead of always getting the Farmer AI's
# auto-cycle (farm_plot.gd's plant() with no argument, unaffected by this
# panel - untended plots still rotate through every crop on their own).

const ICON_SIZE := 20

@onready var panel: PanelContainer = $PanelContainer
@onready var button_list: HBoxContainer = $PanelContainer/VBoxContainer/ButtonList

var current_plot: FarmPlot = null

func _ready() -> void:
	panel.visible = false
	Selection.farm_plot_selected.connect(_on_farm_plot_selected)
	Selection.villager_selected.connect(_on_other_panel_selected)

func _on_farm_plot_selected(plot: Node) -> void:
	current_plot = plot
	_rebuild_buttons()
	panel.visible = true

func _on_other_panel_selected(_villager: Node) -> void:
	panel.visible = false

func _rebuild_buttons() -> void:
	for child in button_list.get_children():
		child.queue_free()
	if current_plot == null:
		return
	for crop in current_plot.available_crops:
		var button := Button.new()
		button.text = "%s\n%d %s" % [crop.crop_name, crop.yield_amount, crop.ammo_type.capitalize()]
		button.tooltip_text = "%s: %d day(s) to grow, yields %d %s per harvest" % [
			crop.crop_name, crop.days_to_grow, crop.yield_amount, crop.ammo_type.capitalize(),
		]
		# CropDef.tint was a leftover from the old tinted-sprite crop visual
		# (real 3D meshes replaced it and never read this field again) -
		# repurposed here as a color swatch per button, same runtime-texture
		# trick build_menu.gd/hud.gd already use for their icon chips.
		button.icon = _make_icon(crop.tint)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.pressed.connect(_on_crop_pressed.bind(crop))
		button_list.add_child(button)

func _make_icon(color: Color) -> ImageTexture:
	var image := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _on_crop_pressed(crop: CropDef) -> void:
	if current_plot:
		current_plot.plant(crop)
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		panel.visible = false
		get_viewport().set_input_as_handled()
