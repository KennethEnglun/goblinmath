extends Node

## Entry scene. The dedicated PvP server boots with --pvp-server (or
## PVP_SERVER=1) and simply stays here: PvpNetwork is already listening.
## Normal clients continue to the main menu immediately.

func _ready() -> void:
	if PvpNetwork.is_server_mode:
		print("Bootstrap: PvP server mode, staying idle.")
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/main/main_menu.tscn")
