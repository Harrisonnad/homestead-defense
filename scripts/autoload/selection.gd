extends Node

# Autoload singleton: tracks which villager/farm plot is currently selected
# so their respective UI panels can react without a direct scene reference.

signal villager_selected(villager: Node)
signal farm_plot_selected(plot: Node)

func select(villager: Node) -> void:
	villager_selected.emit(villager)

func select_farm_plot(plot: Node) -> void:
	farm_plot_selected.emit(plot)
