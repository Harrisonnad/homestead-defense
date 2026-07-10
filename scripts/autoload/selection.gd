extends Node

# Autoload singleton: tracks which villager is currently selected so the
# villager role-assignment UI can react without a direct scene reference.

signal villager_selected(villager: Node)

func select(villager: Node) -> void:
	villager_selected.emit(villager)
