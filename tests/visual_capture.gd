extends Node

## Visual QA capture for the authored portrait screens.
## Writes only to /private/tmp and uses an isolated save path.
const OUTPUT_DIR: String = "/private/tmp/candymaths-visual"
const DESIGN_SIZE: Vector2i = Vector2i(1080, 1920)
const SCENE_PATHS: Dictionary = {
	"start": "res://scenes/main/main_menu.tscn",
	"map": "res://scenes/map/world_map.tscn",
	"character": "res://scenes/character/character.tscn",
	"gacha": "res://scenes/gacha/gacha.tscn",
	"battle": "res://scenes/battle/battle.tscn"
}

var capture_index: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("Visual capture requires a rendering backend; headless dummy mode completed without pixel output.")
		print("VISUAL_CAPTURE_HEADLESS_SKIP")
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var original_save_path: String = SaveManager.storage_path
	SaveManager.storage_path = "/private/tmp/candymaths_visual_capture_%d.json" % OS.get_process_id()
	SaveManager.current_data = SaveManager.create_new_save()
	GameManager.player_state = SaveManager.current_data.duplicate(true)
	await _capture_scene("start", Vector2i(1080, 1920))
	await _capture_scene("map", Vector2i(1080, 1920))
	await _capture_scene("character_profile", Vector2i(1080, 1920), "character", "profile")
	await _capture_scene("character_selector", Vector2i(1080, 1920), "character", "selector")
	await _capture_scene("character_purchase_confirm", Vector2i(1080, 1920), "character", "confirm")
	await _capture_scene("character_equipment", Vector2i(1080, 1920), "character", "equipment")
	await _capture_scene("character_bag", Vector2i(1080, 1920), "character", "bag")
	await _capture_scene("gacha_summon", Vector2i(1080, 1920), "gacha", "summon")
	await _capture_scene("gacha_result", Vector2i(1080, 1920), "gacha", "result")
	await _capture_scene("gacha_merge", Vector2i(1080, 1920), "gacha", "merge")
	await _capture_scene("battle", Vector2i(1080, 1920))
	await _capture_scene("mobile_start", Vector2i(405, 720), "start")
	await _capture_scene("mobile_character", Vector2i(405, 720), "character", "equipment")
	await _capture_scene("mobile_character_selector", Vector2i(405, 720), "character", "selector")
	await _capture_scene("mobile_gacha", Vector2i(405, 720), "gacha", "summon")
	await _capture_scene("mobile_battle", Vector2i(405, 720), "battle")
	SaveManager.storage_path = original_save_path
	print("VISUAL_CAPTURE_DONE %d" % capture_index)
	get_tree().quit()

func _capture_scene(file_stem: String, viewport_size: Vector2i, scene_key: String = "", mode: String = "") -> void:
	var key: String = scene_key if not scene_key.is_empty() else file_stem
	var scene_path: String = str(SCENE_PATHS.get(key, ""))
	if scene_path.is_empty():
		push_error("Missing scene key: %s" % key)
		return
	if key == "map":
		GameManager.player_state["current_stage"] = 1
		GameManager.player_state["unlocked_stage"] = 1
		GameManager.player_state["highest_completed_stage"] = 0
	if key == "character" and mode == "bag":
		var inventory: Array = GameManager.get_inventory()
		inventory.append(EquipmentSystem.create_instance("leaf_cap", "visual_item_2", 1, 1))
		inventory.append(EquipmentSystem.create_instance("traveler_shorts", "visual_item_3", 2, 1))
		GameManager.player_state["inventory"] = inventory
	if key == "character" and (mode == "selector" or mode == "confirm"):
		GameManager.player_state["gems"] = GameBalance.BASE_GEMS
		GameManager.player_state["unlocked_character_ids"] = [GameBalance.DEFAULT_CHARACTER_ID]
		GameManager.player_state["selected_character_id"] = GameBalance.DEFAULT_CHARACTER_ID
	if key == "gacha" and mode == "merge":
		var merge_inventory: Array = GameManager.get_inventory()
		merge_inventory.append(EquipmentSystem.create_instance("twig_club", "visual_merge_2", 1, 1))
		merge_inventory.append(EquipmentSystem.create_instance("twig_club", "visual_merge_3", 1, 1))
		GameManager.player_state["inventory"] = merge_inventory
	if key == "battle":
		GameManager.player_state["current_stage"] = 1
		GameManager.player_state["unlocked_stage"] = 1

	# Render every screen at the project's logical portrait resolution, then
	# downsample mobile captures. A raw 405x720 SubViewport bypasses Godot's
	# canvas stretch and falsely reports hard-coded design coordinates as clipped.
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "VisualViewport_%s" % file_stem
	viewport.size = DESIGN_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	get_tree().root.add_child(viewport)
	var scene: Control = load(scene_path).instantiate() as Control
	viewport.add_child(scene)
	await _wait_frames(8)
	if key == "character":
		if mode == "selector" or mode == "confirm":
			scene.set_active_tab("profile")
			scene._on_open_character_selector_pressed()
			if mode == "confirm":
				scene._on_character_card_action_pressed("rabbit_scout")
		else:
			scene.set_active_tab(mode)
		await _wait_frames(30)
	if key == "gacha":
		if mode != "result":
			scene._set_mode(mode)
		else:
			scene._on_single_pull_pressed()
		await _wait_frames(3)
	# Keep the target live for two additional process frames. Switching a
	# SubViewport to UPDATE_ONCE while awaiting frame_post_draw can deadlock on
	# the macOS compatibility renderer after the first capture.
	await _wait_frames(2)
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		push_warning("Skipping %s because the renderer did not expose a viewport texture." % file_stem)
		capture_index += 1
		viewport.queue_free()
		await _wait_frames(2)
		return
	var image: Image = texture.get_image()
	var retry_count: int = 0
	while (image == null or image.is_empty() or image.get_used_rect().size == Vector2i.ZERO) and retry_count < 12:
		await get_tree().process_frame
		image = texture.get_image()
		retry_count += 1
	if image == null or image.is_empty() or image.get_used_rect().size == Vector2i.ZERO:
		push_warning("Skipping %s because the active renderer cannot read viewport pixels." % file_stem)
		capture_index += 1
		viewport.queue_free()
		await _wait_frames(2)
		return
	if viewport_size != DESIGN_SIZE:
		image.resize(viewport_size.x, viewport_size.y, Image.INTERPOLATE_LANCZOS)
	var output_path: String = "%s/%02d_%s.png" % [OUTPUT_DIR, capture_index, file_stem]
	var error: Error = image.save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error])
	else:
		print("VISUAL_CAPTURE %s" % output_path)
	capture_index += 1
	viewport.queue_free()
	await _wait_frames(2)

func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
