extends Node

## Audio facade for the MVP. Sound files can be added without changing scenes.
var music_volume_db: float = 0.0
var muted: bool = false

func play_bgm(track_id: String) -> void:
	# The first slice ships without audio files; retain the stable call interface.
	if track_id.is_empty():
		return

func play_sfx(effect_id: String) -> void:
	if muted or effect_id.is_empty():
		return

func set_muted(value: bool) -> void:
	muted = value

func set_music_volume(value_db: float) -> void:
	music_volume_db = value_db

