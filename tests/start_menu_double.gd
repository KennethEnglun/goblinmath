extends "res://scripts/main/main_menu.gd"

## Keeps the start-button test inside the runner instead of replacing its scene.
var world_map_requested: bool = false

func _go_to_world_map() -> void:
	world_map_requested = true
