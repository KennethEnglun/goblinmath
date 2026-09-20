extends Node

## Visual QA capture for the authored portrait screens.
## Writes only to /private/tmp and uses an isolated save path.
const OUTPUT_DIR: String = "/private/tmp/candymaths-visual"
const DESIGN_SIZE: Vector2i = Vector2i(1080, 1920)
const COMMON_PHONE_SIZE: Vector2i = Vector2i(393, 852)
const SCENE_PATHS: Dictionary = {
	"start": "res://scenes/main/main_menu.tscn",
	"map": "res://scenes/map/world_map.tscn",
	"character": "res://scenes/character/character.tscn",
	"gacha": "res://scenes/gacha/gacha.tscn",
	"battle": "res://scenes/battle/battle.tscn",
	"pvp_lobby": "res://scenes/pvp/pvp_lobby.tscn",
	"pvp_battle": "res://scenes/pvp/pvp_battle.tscn"
}

var capture_index: int = 0
var successful_capture_count: int = 0
var skipped_capture_count: int = 0
var visual_viewport: SubViewport

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
	visual_viewport = SubViewport.new()
	visual_viewport.name = "VisualCaptureViewport"
	visual_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visual_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	get_tree().root.add_child(visual_viewport)
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
	await _capture_scene("pvp_lobby", Vector2i(1080, 1920))
	await _capture_scene("pvp_battle", Vector2i(1080, 1920))
	await _capture_scene("mobile_start", Vector2i(405, 720), "start")
	await _capture_scene("mobile_map", Vector2i(405, 720), "map")
	await _capture_scene("mobile_character", Vector2i(405, 720), "character", "equipment")
	await _capture_scene("mobile_character_selector", Vector2i(405, 720), "character", "selector")
	await _capture_scene("mobile_gacha", Vector2i(405, 720), "gacha", "summon")
	await _capture_scene("mobile_gacha_result", Vector2i(405, 720), "gacha", "result")
	await _capture_scene("mobile_gacha_merge", Vector2i(405, 720), "gacha", "merge")
	await _capture_scene("mobile_battle", Vector2i(405, 720), "battle")
	await _capture_scene("mobile_battle_pause", Vector2i(405, 720), "battle", "pause")
	await _capture_scene("mobile_battle_victory", Vector2i(405, 720), "battle", "victory")
	await _capture_scene("merge_many", DESIGN_SIZE, "gacha", "many")
	await _capture_scene("merge_selected", DESIGN_SIZE, "gacha", "selected")
	await _capture_scene("auto_merge_preview", DESIGN_SIZE, "gacha", "preview")
	await _capture_scene("battle_pause", DESIGN_SIZE, "battle", "pause")
	await _capture_scene("battle_victory", DESIGN_SIZE, "battle", "victory")
	await _capture_scene("battle_defeat", DESIGN_SIZE, "battle", "defeat")
	await _capture_scene("ten_pull_result", DESIGN_SIZE, "gacha", "ten_result")
	await _capture_scene("character_empty_bag", DESIGN_SIZE, "character", "empty_bag")
	await _capture_scene("character_long_values", DESIGN_SIZE, "character", "long_values")
	await _capture_scene("gacha_long_values", DESIGN_SIZE, "gacha", "long_values")
	await _capture_scene("battle_feedback", DESIGN_SIZE, "battle", "feedback")
	await _capture_scene("character_message", DESIGN_SIZE, "character", "message")
	await _capture_scene("gacha_toast", DESIGN_SIZE, "gacha", "toast")
	await _capture_scene("mobile_battle_feedback", Vector2i(405, 720), "battle", "feedback")
	await _capture_scene("mobile_character_message", Vector2i(405, 720), "character", "message")
	await _capture_scene("mobile_gacha_toast", Vector2i(405, 720), "gacha", "toast")
	# A taller current-phone aspect catches fixed HUDs that look correct at the
	# design ratio but drift toward a gesture area on 19.5:9 devices.
	await _capture_scene("tall_map", COMMON_PHONE_SIZE, "map")
	await _capture_scene("tall_character", COMMON_PHONE_SIZE, "character", "equipment")
	await _capture_scene("tall_gacha", COMMON_PHONE_SIZE, "gacha", "summon")
	await _capture_scene("tall_battle", COMMON_PHONE_SIZE, "battle")
	await _capture_scene("tall_battle_victory", COMMON_PHONE_SIZE, "battle", "victory")
	# Localized surfaces: English and Japanese rebuild every screen from the
	# i18n table, so a compact cross-language pass catches overflow and layout
	# drift before a release.
	for language: String in [LanguageManager.LANGUAGE_EN, LanguageManager.LANGUAGE_JA]:
		LanguageManager.set_language(language)
		GameManager.player_state = SaveManager.current_data.duplicate(true)
		await _capture_scene("%s_start" % language, DESIGN_SIZE, "start")
		await _capture_scene("%s_map" % language, DESIGN_SIZE, "map")
		await _capture_scene("%s_character" % language, DESIGN_SIZE, "character", "profile")
		await _capture_scene("%s_character_selector" % language, DESIGN_SIZE, "character", "selector")
		await _capture_scene("%s_character_bag" % language, DESIGN_SIZE, "character", "bag")
		await _capture_scene("%s_gacha" % language, DESIGN_SIZE, "gacha", "summon")
		await _capture_scene("%s_gacha_merge" % language, DESIGN_SIZE, "gacha", "merge")
		await _capture_scene("%s_battle" % language, DESIGN_SIZE, "battle")
		await _capture_scene("%s_pvp_lobby" % language, DESIGN_SIZE, "pvp_lobby")
		await _capture_scene("%s_pvp_battle" % language, DESIGN_SIZE, "pvp_battle")
		await _capture_scene("%s_battle_victory" % language, DESIGN_SIZE, "battle", "victory")
		await _capture_scene("%s_battle_defeat" % language, DESIGN_SIZE, "battle", "defeat")
	LanguageManager.set_language(LanguageManager.LANGUAGE_ZH_TW)
	GameManager.player_state = SaveManager.current_data.duplicate(true)
	if visual_viewport != null and is_instance_valid(visual_viewport):
		visual_viewport.queue_free()
		await _wait_frames(2)
	SaveManager.storage_path = original_save_path
	if skipped_capture_count > 0:
		push_error("Visual capture incomplete: %d/%d files were written." % [successful_capture_count, capture_index])
		print("VISUAL_CAPTURE_INCOMPLETE %d/%d" % [successful_capture_count, capture_index])
		get_tree().quit(1)
		return
	print("VISUAL_CAPTURE_DONE %d" % successful_capture_count)
	get_tree().quit()

func _capture_scene(file_stem: String, viewport_size: Vector2i, scene_key: String = "", mode: String = "") -> void:
	var key: String = scene_key if not scene_key.is_empty() else file_stem
	var scene_path: String = str(SCENE_PATHS.get(key, ""))
	if scene_path.is_empty():
		push_error("Missing scene key: %s" % key)
		skipped_capture_count += 1
		capture_index += 1
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
	if key == "character" and mode == "empty_bag":
		GameManager.player_state["inventory"] = []
		GameManager.player_state["equipped"] = {"weapon": "", "head": "", "body": ""}
	if key == "character" and mode == "long_values":
		GameManager.player_state["gems"] = 987654321
		GameManager.player_state["coins"] = 1234567890
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
	if key == "gacha" and mode in ["many", "selected", "preview"]:
		var materials: Array = []
		for index: int in range(20):
			materials.append(EquipmentSystem.create_instance("twig_club", "capture_material_%d" % index, 1, 1))
		GameManager.player_state["inventory"] = materials
		GameManager.player_state["equipped"] = {"weapon": "capture_material_0", "head": "", "body": ""}
	if key == "gacha" and mode == "long_values":
		GameManager.player_state["gems"] = 987654321

	# Render at the target pixel size with the project's logical canvas stretch.
	# This exercises mobile rendering instead of resizing a desktop screenshot.
	var viewport: SubViewport = visual_viewport
	if viewport == null or not is_instance_valid(viewport):
		push_error("Visual capture viewport is unavailable before %s." % file_stem)
		skipped_capture_count += 1
		capture_index += 1
		return
	viewport.size = viewport_size
	viewport.size_2d_override = DESIGN_SIZE
	viewport.size_2d_override_stretch = true
	var scene: Control = load(scene_path).instantiate() as Control
	if scene == null:
		push_error("Could not instantiate %s for %s." % [scene_path, file_stem])
		skipped_capture_count += 1
		capture_index += 1
		return
	viewport.add_child(scene)
	await _wait_frames(8)
	if key == "character":
		if mode == "selector" or mode == "confirm":
			scene.set_active_tab("profile")
			scene._on_open_character_selector_pressed()
			if mode == "confirm":
				scene._on_character_card_action_pressed("rabbit_scout")
		else:
			var character_tab: String = "bag" if mode == "empty_bag" or mode == "message" else "profile"
			if mode == "bag" or mode == "equipment":
				character_tab = mode
			scene.set_active_tab(character_tab)
		await _wait_frames(30)
		if mode == "message":
			scene._refresh_all("CONFIRM SELL\n再次按確認出售才會賣出這件裝備。")
	if key == "gacha":
		if mode == "ten_result":
			GameManager.player_state["gems"] = 10000
			scene._on_ten_pull_pressed()
		elif mode == "long_values":
			scene._refresh()
		elif mode == "toast":
			scene._show_toast("MERGE SUCCESS\n合成完成，退還強化金幣。")
		elif mode in ["many", "selected", "preview"]:
			scene._set_mode("merge")
			if mode == "selected":
				for index: int in range(3):
					scene._on_merge_item_pressed("capture_material_%d" % index, "twig_club")
			if mode == "preview":
				scene._on_auto_merge_pressed()
		elif mode != "result":
			scene._set_mode(mode)
		else:
			scene._on_single_pull_pressed()
		await _wait_frames(3)
	if key == "battle" and mode == "pause":
		scene._on_pause_pressed()
		await _wait_frames(3)
	if key == "battle" and mode == "feedback":
		scene._on_digit_pressed("1")
		scene._on_submit_pressed()
		await get_tree().create_timer(0.12).timeout
	if key == "battle" and mode in ["victory", "defeat"]:
		scene.input_locked = true
		scene.enemy_attack_timer.stop()
		scene._set_keypad_disabled(true)
		scene._show_result_panel(mode == "victory", {"levels_gained": 1, "new_level": 20, "stars": 3, "exp": 12345, "coins": 12345, "gems": 30, "accuracy": 0.99, "mistakes": 1, "chapter_complete": true})
		await _wait_frames(3)
	# Keep the target live for several additional process frames. Switching a
	# SubViewport to UPDATE_ONCE while awaiting frame_post_draw can deadlock on
	# the macOS compatibility renderer after the first capture. Allow the GPU
	# command queue a short wall-time settle as the UI now includes themed
	# scrollbars and more texture-backed controls.
	await _wait_frames(8)
	await get_tree().create_timer(0.12).timeout
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		push_warning("Skipping %s because the renderer did not expose a viewport texture." % file_stem)
		skipped_capture_count += 1
		capture_index += 1
		scene.queue_free()
		await get_tree().create_timer(0.12).timeout
		await _wait_frames(8)
		return
	var image: Image = texture.get_image()
	var retry_count: int = 0
	while (image == null or image.is_empty() or image.get_used_rect().size == Vector2i.ZERO) and retry_count < 12:
		await get_tree().process_frame
		image = texture.get_image()
		retry_count += 1
	if image == null or image.is_empty() or image.get_used_rect().size == Vector2i.ZERO:
		push_warning("Skipping %s because the active renderer cannot read viewport pixels." % file_stem)
		skipped_capture_count += 1
		capture_index += 1
		scene.queue_free()
		await get_tree().create_timer(0.12).timeout
		await _wait_frames(8)
		return
	var output_path: String = "%s/%02d_%s.png" % [OUTPUT_DIR, capture_index, file_stem]
	var error: Error = image.save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error])
		skipped_capture_count += 1
	else:
		print("VISUAL_CAPTURE %s" % output_path)
		successful_capture_count += 1
	capture_index += 1
	scene.queue_free()
	await get_tree().create_timer(0.08).timeout
	await _wait_frames(8)

func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame
	# The OpenGL capture command intentionally disables vsync, so a frame loop
	# can finish before authored fade/slide tweens have advanced in wall time.
	# Long waits are used after tab/modal changes; give those transitions enough
	# real time to settle before judging text contrast and panel placement.
	if count >= 24:
		await get_tree().create_timer(0.5).timeout
