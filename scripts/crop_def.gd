extends Resource
class_name CropDef

# Data-driven crop definition, one .tres per plantable crop (mirrors the
# BuildingDef pattern). FarmPlot cycles through available_crops automatically
# rather than asking the player to choose per-plot - see farm_plot.gd.

@export var crop_name: String = "Crop"
@export var ammo_type: String = "food" # Economy resource id this crop yields
@export var yield_amount: int = 10
@export var days_to_grow: int = 1
# FarmPlot reuses the corn Sprite3D shape (no dedicated art per crop) and
# tints it via modulate so each crop still reads as visually distinct.
@export var tint: Color = Color(1, 1, 1)
