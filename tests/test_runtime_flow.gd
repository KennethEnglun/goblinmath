extends Node

## Scene-level checks for navigation surfaces, endless map pages, battle, and gear UI.
const START_MENU_DOUBLE = preload("res://tests/start_menu_double.gd")
const STAGE_NODE_SCRIPT = preload("res://scripts/map/stage_node.gd")

var failures: int = 0

func _ready() -> void:
	call_deferred("_run_flow")

func _run_flow() -> void:
	var original_save_path: String = SaveManager.storage_path
	var suite_save_path: String = "/private/tmp/candymaths_runtime_suite_%d.json" % OS.get_process_id()
	SaveManager.storage_path = suite_save_path
	_cleanup_save_files(suite_save_path)

	await _test_start_screen(Vector2i(405, 720), true)
	await _test_start_screen(Vector2i(1080, 1920), false)
	await _test_world_map(1)
	await _test_world_map(2)
	await _test_endless_chapter_map()
	await _test_boss_map_focus()
	await _test_stage_node_signal()
	await _test_actual_map_to_battle_transition()
	await _test_character_screen()
	await _test_selected_character_surfaces()
	await _test_gacha_screen()
	await _test_battle_zone_backgrounds()
	await _test_non_scripted_battle()
	await _test_zero_answer_input()
	await _test_enemy_auto_attack()
	await _test_battle_pause()
	await _test_defeat_retry_flow()
	await _test_real_battle_loop()

	if failures == 0:
		print("RUNTIME_FLOW_TESTS_PASS")
	else:
		print("RUNTIME_FLOW_TESTS_FAIL: %d" % failures)
	_cleanup_save_files(suite_save_path)
	SaveManager.storage_path = original_save_path
	get_tree().quit(failures)

func _test_world_map(unlocked_stage: int) -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["unlocked_stage"] = unlocked_stage
	GameManager.player_state["highest_completed_stage"] = maxi(0, unlocked_stage - 1)

	var viewport: SubViewport = SubViewport.new()
	viewport.name = "WorldMapViewport%d" % unlocked_stage
	viewport.size = Vector2i(1080, 1920)
	get_tree().root.add_child(viewport)
	var map_scene: PackedScene = load("res://scenes/map/world_map.tscn")
	var world_map: Control = map_scene.instantiate() as Control
	viewport.add_child(world_map)
	await _wait_frames(6)

	var content: Control = world_map.get_node_or_null("WorldMapScroll/MapContent") as Control
	_check(content != null and content.size.y >= 4608.0, "World map builds a 1080×4608 chapter canvas")
	if content != null:
		for layer_name: String in ["MapBackgroundLayer", "ZoneEffectsLayer", "PathLayer", "DecorationBackLayer", "StageNodeLayer", "PlayerMarkerLayer", "DecorationFrontLayer"]:
			_check(content.get_node_or_null(layer_name) != null, "World map exposes independent %s" % layer_name)
		var map_asset_paths: Array[String] = [
			"res://assets/ui/map/world1_flower_meadow_bg.png",
			"res://assets/ui/map/world1_sakura_woods_bg.png",
			"res://assets/ui/map/world1_starlight_hill_bg.png",
			"res://assets/ui/map/world1_flower_foreground.png",
			"res://assets/ui/map/world1_sakura_foreground.png",
			"res://assets/ui/map/world1_starlight_foreground.png",
			"res://assets/ui/map/stage_node_base.png",
			"res://assets/ui/map/stage_node_boss.png",
			"res://assets/ui/map/stage_lock.png",
			"res://assets/ui/map/stage_complete_star.png",
			"res://assets/ui/map/stage_current_glow.png"
		]
		for asset_path: String in map_asset_paths:
			_check(ResourceLoader.exists(asset_path), "World map imports generated asset %s" % asset_path.get_file())
		var background_layer: Control = content.get_node_or_null("MapBackgroundLayer") as Control
		_check(background_layer != null and background_layer.get_child_count() == 3, "World map has three zone background segments")
		if background_layer != null:
			for background_name: String in ["StarlightHillBackground", "SakuraWoodsBackground", "FlowerMeadowBackground"]:
				var background: TextureRect = background_layer.get_node_or_null(background_name) as TextureRect
				_check(background != null and background.texture != null, "Zone background uses a real texture: %s" % background_name)
		var foreground_layer: Control = content.get_node_or_null("DecorationFrontLayer") as Control
		_check(foreground_layer != null and foreground_layer.get_child_count() >= 3, "World map has independent foreground decoration textures")
		var node_layer: Control = content.get_node_or_null("StageNodeLayer") as Control
		_check(node_layer != null and node_layer.get_child_count() == 10, "World map creates ten reusable stage nodes")
		if node_layer != null:
			var stage_one = node_layer.get_node_or_null("StageNode1")
			var stage_two = node_layer.get_node_or_null("StageNode2")
			_check(stage_one != null and stage_one.stage_button.size.x >= 96.0 and stage_one.stage_button.size.y >= 96.0, "Stage node keeps a large touch target")
			_check(stage_one != null and stage_one.stage_button is TextureButton, "Stage node uses the generated texture skin")
			_check(stage_one != null and stage_one.find_child("StageNumber", true, false) != null, "Stage number remains a dynamic Godot label")
			_check(stage_one != null and stage_one.find_child("CaptionPanel", true, false) != null, "Stage caption remains an independent dynamic panel")
			if unlocked_stage == 1:
				_check(stage_one.stage_status == &"current", "Fresh progress marks Stage 1 current")
				_check(stage_two.stage_status == &"locked" and stage_two.stage_button.disabled, "Fresh progress keeps Stage 2 locked")
			else:
				_check(stage_one.stage_status == &"completed", "Completed Stage 1 displays its completed state")
				_check(stage_two.stage_status == &"current", "Stage 2 becomes the current node")
			if unlocked_stage == 1 and stage_one != null:
				var map_callback: Callable = Callable(world_map, "_on_stage_selected")
				if stage_one.stage_selected.is_connected(map_callback):
					stage_one.stage_selected.disconnect(map_callback)
				var tapped_stages: Array[int] = []
				stage_one.stage_selected.connect(func(stage_id: int) -> void: tapped_stages.append(stage_id))
				await _push_pointer_tap(viewport, stage_one.stage_button.get_global_rect().get_center())
				_check(tapped_stages == [1], "A real pointer tap passes through the HUD and reaches Stage 1")
				tapped_stages.clear()
				var scroll_before_drag: int = world_map.scroll_container.scroll_vertical
				await _push_pointer_drag(viewport, stage_one.stage_button.get_global_rect().get_center(), stage_one.stage_button.get_global_rect().get_center() + Vector2(0, 120))
				_check(tapped_stages.is_empty(), "Dragging the map does not accidentally launch a stage")
				_check(world_map.scroll_container.scroll_vertical != scroll_before_drag, "Dragging a stage area scrolls the map instead of being swallowed by the button")
				tapped_stages.clear()
				var touch_scroll_before: int = world_map.scroll_container.scroll_vertical
				await _push_screen_drag(viewport, stage_one.stage_button.get_global_rect().get_center(), stage_one.stage_button.get_global_rect().get_center() + Vector2(0, 120))
				_check(tapped_stages.is_empty(), "Touch dragging the map does not accidentally launch a stage")
				_check(world_map.scroll_container.scroll_vertical != touch_scroll_before, "Screen touch drag scrolls the map")

	var hud: Control = world_map.get_node_or_null("FixedHudLayer") as Control
	_check(hud != null and hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Transparent HUD no longer blocks map taps")
	if hud != null:
		var header: Control = hud.find_child("MapHeader", true, false) as Control
		var world_name: Label = hud.find_child("WorldNameLabel", true, false) as Label
		var map_title: Label = hud.find_child("MapTitle", true, false) as Label
		var bottom_hud: Control = hud.find_child("BottomHud", true, false) as Control
		var home: Control = hud.find_child("HomeButton", true, false) as Control
		var character: Control = hud.find_child("CharacterButton", true, false) as Control
		_check(header != null and bottom_hud != null and not header.get_global_rect().intersects(bottom_hud.get_global_rect()), "Fixed header and bottom controls do not overlap")
		_check(_uses_chiron_font(map_title), "World map dynamic title uses the bundled rounded CJK font")
		_check(world_name != null and str(world_name.text).contains("花漾原野"), "Map HUD displays the World 1 name")
		_check(map_title != null and world_name != null and not map_title.get_global_rect().intersects(world_name.get_global_rect()), "Map title and world name keep a readable vertical gap (%s / %s)" % [map_title.get_global_rect(), world_name.get_global_rect()])
		_check(world_name != null and world_map.stats_label != null and not world_name.get_global_rect().intersects(world_map.stats_label.get_global_rect()), "World name and progress stats do not overlap")
		_check(home != null and character != null, "Map exposes home and character/equipment navigation")
		for button: Button in hud.find_children("*", "Button", true, false):
			_check(button.custom_minimum_size.x >= 96.0 or button.size.x >= 96.0, "Map controls keep a horizontal touch target")
			_check(button.custom_minimum_size.y >= 96.0 or button.size.y >= 96.0, "Map controls keep a vertical touch target")
	_check(world_map.scroll_container.scroll_vertical > 2500, "Map initially scrolls to the highest unlocked meadow stage")

	viewport.queue_free()
	await _wait_frames(1)

func _test_endless_chapter_map() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["highest_completed_stage"] = 10
	GameManager.player_state["unlocked_stage"] = 11
	GameManager.player_state["current_stage"] = 11
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	get_tree().root.add_child(viewport)
	var world_map = load("res://scenes/map/world_map.tscn").instantiate()
	viewport.add_child(world_map)
	await _wait_frames(6)
	_check(int(world_map.current_chapter) == 2, "Map opens the chapter containing the highest unlocked stage")
	var node_layer: Control = world_map.get_node_or_null("WorldMapScroll/MapContent/StageNodeLayer") as Control
	_check(node_layer != null and node_layer.get_node_or_null("StageNode11") != null and node_layer.get_node_or_null("StageNode20") != null, "Chapter 2 renders generated Stages 11–20")
	if node_layer != null:
		_check(node_layer.get_node("StageNode11").stage_status == &"current", "Generated Stage 11 is immediately playable")
		_check(node_layer.get_node("StageNode20").stage_status == &"locked", "Later generated boss remains locked")
	_check(not world_map.previous_button.disabled and world_map.next_button.disabled, "Chapter navigation respects unlocked progress")
	viewport.queue_free()
	await _wait_frames(1)

func _test_boss_map_focus() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["highest_completed_stage"] = 10
	GameManager.player_state["unlocked_stage"] = 11
	GameManager.player_state["current_stage"] = 11
	GameManager.map_focus_stage = 10
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	get_tree().root.add_child(viewport)
	var focused_map: Control = load("res://scenes/map/world_map.tscn").instantiate() as Control
	viewport.add_child(focused_map)
	await _wait_frames(6)
	_check(int(focused_map.current_chapter) == 1, "After a boss clear the map opens on the completed World 1 chapter")
	_check(int(GameManager.map_focus_stage) == 0, "Boss map focus is consumed after one map visit")
	_check(focused_map.world_name_label != null and str(focused_map.world_name_label.text) == "花漾原野", "Focused World 1 map shows the correct world name")
	focused_map.queue_free()
	await _wait_frames(1)
	var normal_map: Control = load("res://scenes/map/world_map.tscn").instantiate() as Control
	viewport.add_child(normal_map)
	await _wait_frames(6)
	_check(int(normal_map.current_chapter) == 2, "A later map visit returns to the highest-unlocked endless chapter")
	normal_map.queue_free()
	viewport.queue_free()
	await _wait_frames(1)

func _test_stage_node_signal() -> void:
	var node = STAGE_NODE_SCRIPT.new()
	node.configure(DataManager.get_stage(1), &"current")
	get_tree().root.add_child(node)
	var selected_stage: Array[int] = []
	node.stage_selected.connect(func(stage_id: int) -> void: selected_stage.append(stage_id))
	node.stage_button.emit_signal("pressed")
	await _wait_frames(1)
	_check(selected_stage == [1], "An unlocked stage button emits its battle request")
	node.queue_free()
	await _wait_frames(1)

func _test_actual_map_to_battle_transition() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	var world_map: Control = load("res://scenes/map/world_map.tscn").instantiate() as Control
	get_tree().root.add_child(world_map)
	get_tree().current_scene = world_map
	await _wait_frames(6)
	var transition_finished: bool = false
	var transition_callback: Callable = func(_scene_path: String) -> void: transition_finished = true
	GameManager.scene_transition_completed.connect(transition_callback)
	var stage_one = world_map.get_node_or_null("WorldMapScroll/MapContent/StageNodeLayer/StageNode1")
	if stage_one != null:
		await _push_pointer_tap(get_viewport(), stage_one.stage_button.get_global_rect().get_center())
		if not transition_finished:
			await GameManager.scene_transition_completed
	if GameManager.scene_transition_completed.is_connected(transition_callback):
		GameManager.scene_transition_completed.disconnect(transition_callback)
	await _wait_frames(6)
	var active_scene: Node = get_tree().current_scene
	_check(active_scene != null and active_scene.name == "Battle", "Tapping Stage 1 performs the real map-to-battle scene transition")
	_check(GameManager.transition_layer != null and GameManager.transition_overlay != null and not GameManager.transition_busy, "Scene navigation completes its fade transition without locking input")
	if active_scene != null and active_scene != self:
		active_scene.queue_free()
	get_tree().current_scene = self
	await _wait_frames(2)

func _test_character_screen() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["stat_points"] = 1
	var character_scene: PackedScene = load("res://scenes/character/character.tscn")
	for viewport_size: Vector2i in [Vector2i(405, 720), Vector2i(1080, 1920)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.name = "CharacterViewport_%dx%d" % [viewport_size.x, viewport_size.y]
		viewport.size = viewport_size
		get_tree().root.add_child(viewport)
		var character: Control = character_scene.instantiate() as Control
		viewport.add_child(character)
		await _wait_frames(5)
		_check(character.find_child("BackToMapButton", true, false) != null, "Character screen can return to the map at %s" % viewport_size)
		var merge_entry_button: Button = character.find_child("MergeButton", true, false) as Button
		var gacha_entry_button: Button = character.find_child("GachaButton", true, false) as Button
		var character_coin_badge: Control = character.find_child("CoinBadge", true, false) as Control
		_check(merge_entry_button != null and merge_entry_button.pressed.is_connected(Callable(character, "_on_merge_pressed")), "Character screen exposes a wired MERGE shortcut")
		_check(gacha_entry_button != null and character_coin_badge != null and merge_entry_button != null and not gacha_entry_button.get_global_rect().intersects(merge_entry_button.get_global_rect()) and not merge_entry_button.get_global_rect().intersects(character_coin_badge.get_global_rect()), "Character header shortcuts and currency badge do not overlap")
		for layer_name: String in ["CharacterBackgroundLayer", "CharacterAmbientLayer", "CharacterGoblinLayer", "CharacterPanelLayer", "CharacterEquipmentLayer", "CharacterHudLayer", "CharacterTabLayer", "CharacterActionLayer", "CharacterToastLayer", "CharacterSelectorLayer"]:
			_check(character.find_child(layer_name, true, false) != null, "Character screen exposes independent %s" % layer_name)
		_check(character.find_child("CharacterBackgroundFallback", true, false) != null or character.character_background_layer.texture != null, "Character screen keeps a background fallback when art is unavailable")
		_check(character.character_ambient_layer.texture != null, "Character screen reuses the shared ambient effect layer")
		if merge_entry_button != null:
			_check(merge_entry_button.custom_minimum_size.x >= 96.0 and merge_entry_button.custom_minimum_size.y >= 96.0, "Character MERGE shortcut keeps a touch-safe target")
		for asset_path: String in [
			"res://assets/ui/character/character_upgrade_bg_v1.png",
			"res://assets/ui/character/character_panel_skin_v1.png",
			"res://assets/ui/character/character_tab_skin_v1.png",
			"res://assets/ui/character/character_action_button_skin_v1.png",
			"res://assets/ui/character/character_slot_frame_v1.png",
			"res://assets/ui/character/character_slot_empty_v1.png",
			"res://assets/ui/character/character_coin_badge_v1.png",
			"res://assets/ui/character/icons/character_icon_map_v1.png",
			"res://assets/ui/character/icons/character_icon_gacha_v1.png",
			"res://assets/ui/character/icons/character_icon_merge_v1.png",
			"res://assets/ui/character/icons/character_icon_profile_v1.png",
			"res://assets/ui/character/icons/character_icon_equipment_v1.png",
			"res://assets/ui/character/icons/character_icon_bag_v1.png",
			"res://assets/ui/character/icons/character_icon_equip_v1.png",
			"res://assets/ui/character/icons/character_icon_upgrade_v1.png",
			"res://assets/ui/character/icons/character_icon_sell_v1.png",
			"res://assets/ui/character/icons/character_icon_sort_v1.png",
			"res://assets/ui/character/icons/character_icon_attack_v1.png",
			"res://assets/ui/character/icons/character_icon_health_v1.png",
			"res://assets/ui/character/icons/character_icon_defense_v1.png",
			"res://assets/ui/character/icons/character_icon_luck_v1.png",
			"res://assets/equipment/icons/equipment_weapon_v1.png",
			"res://assets/equipment/icons/equipment_head_v1.png",
			"res://assets/equipment/icons/equipment_body_v1.png"
		]:
			_check(ResourceLoader.exists(asset_path), "Character asset imports: %s" % asset_path.get_file())
		_check(character.active_tab == "profile", "Character screen opens on PROFILE")
		var character_font: Font = character.level_label.get_theme_font("font")
		_check(character_font != null and character_font.resource_path.contains("ChironGoRoundTC"), "Character dynamic labels use the bundled rounded CJK font")
		_check(character.profile_scroll.visible and not character.equipment_scroll.visible and not character.bag_scroll.visible, "PROFILE is the only visible tab at startup")
		var choose_character_button: Button = character.find_child("OpenCharacterSelectorButton", true, false) as Button
		_check(choose_character_button != null and choose_character_button.custom_minimum_size.y >= 96.0, "PROFILE exposes a touch-safe character selector entry")
		var starter_art: TextureRect = character.find_child("EquipmentArtSprite", true, false) as TextureRect
		_check(starter_art != null and starter_art.texture != null and starter_art.texture.resource_path.ends_with("twig_club_v1.png"), "Character equipment UI uses the template-specific starter art")
		var tab_bar: Control = character.find_child("CharacterTabBar", true, false) as Control
		var profile_summary: Control = character.find_child("ProfileSummaryPanel", true, false) as Control
		_check(tab_bar != null and profile_summary != null and not tab_bar.get_global_rect().intersects(character.profile_portrait.get_global_rect()), "PROFILE tab bar stays clear of the goblin portrait")
		_check(profile_summary != null and not profile_summary.get_global_rect().intersects(character.profile_portrait.get_global_rect()), "PROFILE summary panel stays clear of the goblin portrait")
		var state_before_tabs: Dictionary = GameManager.player_state.duplicate(true)
		if viewport_size == Vector2i(1080, 1920):
			var state_before_cancel: Dictionary = GameManager.player_state.duplicate(true)
			character._on_open_character_selector_pressed()
			await _wait_frames(3)
			var selector_panel: Control = character.find_child("CharacterSelectorPanel", true, false) as Control
			var character_cards: HBoxContainer = character.find_child("CharacterCardRow", true, false) as HBoxContainer
			_check(character.character_selector_layer.visible and selector_panel != null and character_cards != null and character_cards.get_child_count() == 6, "Character selector opens with all six heroes")
			for card: Control in character_cards.get_children():
				var action: Button = card.find_child("CharacterAction_*", true, false) as Button
				_check(action != null and action.custom_minimum_size.x >= 96.0 and action.custom_minimum_size.y >= 96.0, "Character cards expose touch-safe purchase or select actions")
			character._on_character_card_action_pressed("rabbit_scout")
			_check(character.purchase_confirm_layer.visible, "Locked character action opens the purchase confirmation")
			character._on_cancel_character_purchase_pressed()
			_check(not character.purchase_confirm_layer.visible and GameManager.player_state == state_before_cancel, "Cancelling a character purchase leaves state untouched")
			character._on_character_card_action_pressed("rabbit_scout")
			character._on_confirm_character_purchase_pressed()
			await _wait_frames(3)
			_check(GameManager.is_character_unlocked("rabbit_scout") and str(GameManager.get_selected_character().get("id", "")) == "rabbit_scout" and GameManager.get_gems() == int(state_before_cancel.get("gems", 0)), "Confirming a free test purchase unlocks and selects without spending gems")
			_check(character.profile_portrait.texture != null and character.profile_portrait.texture.resource_path.ends_with("goblin_rabbit_scout_v1.png"), "Character selector refreshes the profile portrait immediately")
			character._on_close_character_selector_pressed()
			state_before_tabs = GameManager.player_state.duplicate(true)
		character.set_active_tab("equipment")
		_check(not character.profile_scroll.visible and character.equipment_scroll.visible and not character.bag_scroll.visible, "EQUIPMENT tab switches independently")
		_check(character.equipment_row.get_child_count() == 3, "EQUIPMENT renders weapon, head, and body slots")
		var equipment_bonus_value: Label = character.find_child("EquipmentBonusValueLabel", true, false) as Label
		_check(equipment_bonus_value != null and str(equipment_bonus_value.text).contains("ATK +3"), "EQUIPMENT shows the live aggregate bonus values")
		_check(tab_bar != null and not tab_bar.get_global_rect().intersects(character.equipment_portrait.get_global_rect()), "EQUIPMENT tab bar stays clear of the goblin portrait")
		_check(not character.equipment_row.get_global_rect().intersects(character.equipment_portrait.get_global_rect()), "EQUIPMENT slots stay clear of the goblin portrait")
		for slot_card: Control in character.equipment_row.get_children():
			_check(slot_card.custom_minimum_size.y >= 96.0, "Equipment slot keeps a large touch-safe layout")
		character.set_active_tab("bag")
		_check(not character.profile_scroll.visible and not character.equipment_scroll.visible and character.bag_scroll.visible, "BAG tab switches independently")
		_check(not character.character_goblin_layer.visible, "BAG hides the large character showcase")
		var inventory_list: VBoxContainer = character.find_child("InventoryList", true, false) as VBoxContainer
		_check(inventory_list != null and inventory_list.get_child_count() >= 1, "Character screen renders the starter inventory")
		if viewport_size == Vector2i(1080, 1920) and inventory_list != null and inventory_list.get_child_count() >= 1:
			var bag_header: Control = character.find_child("BagHeader", true, false) as Control
			var capacity_panel: Control = character.find_child("BagCapacityPanel", true, false) as Control
			var items_label: Control = character.find_child("BagItemsLabel", true, false) as Control
			var header_sort_button: Control = character.find_child("InventorySortButton", true, false) as Control
			_check(bag_header != null and capacity_panel != null and items_label != null and header_sort_button != null, "BAG header exposes stable readable layout nodes")
			if bag_header != null and capacity_panel != null and items_label != null and header_sort_button != null:
				var header_rect: Rect2 = bag_header.get_global_rect()
				var capacity_rect: Rect2 = capacity_panel.get_global_rect()
				var items_rect: Rect2 = items_label.get_global_rect()
				var header_sort_rect: Rect2 = header_sort_button.get_global_rect()
				_check(header_rect.size.y >= 120.0 and header_rect.encloses(capacity_rect) and header_rect.encloses(items_rect) and header_rect.encloses(header_sort_rect), "BAG header content stays inside its translucent backing panel")
				_check(not capacity_rect.intersects(items_rect) and not items_rect.intersects(header_sort_rect), "BAG capacity, ITEMS, and SORT keep separate readable zones")
			var starter_card: Control = inventory_list.get_child(0) as Control
			var starter_sprite: TextureRect = starter_card.find_child("EquipmentArtSprite", true, false) as TextureRect if starter_card != null else null
			var starter_icon: Control = starter_sprite.get_parent() as Control if starter_sprite != null else null
			var starter_buttons: Array[Node] = starter_card.find_children("*", "Button", true, false) if starter_card != null else []
			_check(starter_icon != null and starter_icon.size == Vector2(196, 196), "BAG item artwork uses the compact production card size")
			if starter_card != null and starter_icon != null:
				var starter_card_rect: Rect2 = starter_card.get_global_rect()
				var starter_icon_rect: Rect2 = starter_icon.get_global_rect()
				_check(starter_icon_rect.position.x >= starter_card_rect.position.x + 32.0 and starter_card_rect.grow(-12.0).encloses(starter_icon_rect), "BAG item artwork keeps a safe inset and remains inside the card")
			for action_node: Node in starter_buttons:
				var action_button: Button = action_node as Button
				if action_button != null:
					var action_rect: Rect2 = action_button.get_global_rect()
					var card_rect: Rect2 = starter_card.get_global_rect()
					_check(action_button.size.x >= 220.0 and action_button.size.y >= 96.0 and card_rect.grow(-12.0).encloses(action_rect), "BAG item action button stays inside the card safe area")
					_check(action_rect.position.x >= card_rect.end.x - 244.0, "BAG item action button stays in the right-side action rail")
		_check(GameManager.player_state == state_before_tabs, "Tab switching does not change saved player state")
		character.set_active_tab("profile")
		_check(character.character_goblin_layer.visible and character.character_action_layer.visible, "PROFILE restores character and stat action layers")
		for button: Button in character.find_children("*", "Button", true, false):
			_check(button.custom_minimum_size.x >= 96.0 or button.size.x >= 96.0, "Character controls keep a horizontal touch target")
			_check(button.custom_minimum_size.y >= 96.0 or button.size.y >= 96.0, "Character controls keep a vertical touch target")
		if viewport_size == Vector2i(1080, 1920):
			var equipment_tab_button: Button = character.find_child("EquipmentTabButton", true, false) as Button
			var bag_tab_button: Button = character.find_child("BagTabButton", true, false) as Button
			var profile_tab_button: Button = character.find_child("ProfileTabButton", true, false) as Button
			_check(equipment_tab_button != null and bag_tab_button != null and profile_tab_button != null, "Character tab buttons expose stable interactive targets")
			if equipment_tab_button != null and bag_tab_button != null and profile_tab_button != null:
				await _push_pointer_tap(viewport, equipment_tab_button.get_global_rect().get_center())
				_check(character.active_tab == "equipment", "A real tap opens the EQUIPMENT tab")
				await _push_pointer_tap(viewport, bag_tab_button.get_global_rect().get_center())
				_check(character.active_tab == "bag", "A real tap opens the BAG tab")
				await _push_pointer_tap(viewport, profile_tab_button.get_global_rect().get_center())
				_check(character.active_tab == "profile", "A real tap returns to the PROFILE tab")
			var attack_before: int = GameManager.get_base_attack()
			var stat_button: Button = character.find_child("StatButton_attack", true, false) as Button
			_check(stat_button != null, "Attack stat button exposes a stable interactive target")
			if stat_button != null:
				await _push_pointer_tap(viewport, stat_button.get_global_rect().get_center())
			_check(GameManager.get_base_attack() == attack_before + 1 and GameManager.get_stat_points() == 0, "Character screen allocates a stat point")
			_check(GameManager.get_total_stat_points() == 1 and str(character.points_label.text).contains("累計獲得 1 點"), "Character screen keeps showing the total stat points after allocation")
			var attack_summary: Label = character.find_child("ProfileStatValue_attack", true, false) as Label
			_check(attack_summary != null and str(attack_summary.text).contains("攻擊 14") and str(attack_summary.text).contains("加點 1"), "Character screen shows each final stat with its allocation breakdown")
			var inventory: Array = GameManager.get_inventory()
			inventory.append(EquipmentSystem.create_instance("leaf_cap", "item_2", 1, 1))
			inventory.append(EquipmentSystem.create_instance("traveler_shorts", "item_3", 1, 1))
			inventory.append(EquipmentSystem.create_instance("twig_club", "item_4", 1, 1))
			inventory.append(EquipmentSystem.create_instance("leaf_cap", "item_5", 1, 1))
			inventory.append(EquipmentSystem.create_instance("traveler_shorts", "item_6", 1, 1))
			GameManager.player_state["inventory"] = inventory
			GameManager.player_state["next_item_uid"] = 7
			GameManager.player_state["coins"] = 1_000
			character._refresh_all()
			character.set_active_tab("bag")
			await _wait_frames(2)
			var bag_scroll_before: int = character.bag_scroll.scroll_vertical
			_check(character.bag_scroll.get_v_scroll_bar().max_value > 0.0, "Inventory list exposes vertical overflow when the bag has multiple items")
			var populated_card: Control = character.find_child("ItemCard_item_2", true, false) as Control
			if populated_card != null:
				var populated_sprite: TextureRect = populated_card.find_child("EquipmentArtSprite", true, false) as TextureRect
				var populated_icon: Control = populated_sprite.get_parent() as Control if populated_sprite != null else null
				var populated_actions: Array[Node] = populated_card.find_children("*", "Button", true, false)
				_check(populated_icon != null and populated_icon.size == Vector2(196, 196), "Populated BAG cards keep the compact production artwork")
				if populated_icon != null:
					_check(populated_card.get_global_rect().grow(-12.0).encloses(populated_icon.get_global_rect()), "Populated BAG artwork remains within the card")
				for action_node: Node in populated_actions:
					var action_button: Button = action_node as Button
					if action_button != null:
						var action_rect: Rect2 = action_button.get_global_rect()
						var populated_card_rect: Rect2 = populated_card.get_global_rect()
						_check(populated_card_rect.grow(-12.0).encloses(action_rect), "Populated BAG action remains within the card")
						_check(action_rect.position.x >= populated_card_rect.end.x - 244.0, "Populated BAG action stays in the right-side action rail")
			await _push_screen_drag(viewport, character.bag_scroll.get_global_rect().get_center(), character.bag_scroll.get_global_rect().get_center() - Vector2(0, 120))
			_check(character.bag_scroll.scroll_vertical > bag_scroll_before, "Touch dragging the inventory list scrolls it vertically")
			character.bag_scroll.scroll_vertical = 0
			await _wait_frames(1)
			var sort_button: Button = character.find_child("InventorySortButton", true, false) as Button
			var sort_before: String = character.inventory_sort_mode
			_check(sort_button != null, "Inventory exposes a stable sort button")
			if sort_button != null:
				await _push_pointer_tap(viewport, sort_button.get_global_rect().get_center())
			_check(character.inventory_sort_mode != sort_before, "A real tap cycles the inventory sort mode")
			var equip_button: Button = character.find_child("EquipButton_item_2", true, false) as Button
			_check(equip_button != null and not equip_button.disabled, "Inventory exposes an enabled EQUIP action for an unequipped item")
			if equip_button != null and not equip_button.disabled:
				await _push_pointer_tap(viewport, equip_button.get_global_rect().get_center())
			_check(GameManager.get_equipped_uid("head") == "item_2", "A real tap equips the selected head item")
			var upgrade_button: Button = character.find_child("UpgradeButton_item_2", true, false) as Button
			_check(upgrade_button != null and not upgrade_button.disabled, "Inventory exposes an enabled UPGRADE action when coins are available")
			if upgrade_button != null and not upgrade_button.disabled:
				await _push_pointer_tap(viewport, upgrade_button.get_global_rect().get_center())
			var upgraded_head: Dictionary = EquipmentSystem.find_item(GameManager.get_inventory(), "item_2")
			_check(int(upgraded_head.get("level", 0)) == 2, "A real tap upgrades the item and persists its level")
			character.set_active_tab("equipment")
			await _wait_frames(2)
			var unequip_button: Button = character.find_child("UnequipButton_head", true, false) as Button
			_check(unequip_button != null, "Equipped gear exposes an UNEQUIP action")
			if unequip_button != null:
				await _push_pointer_tap(viewport, unequip_button.get_global_rect().get_center())
			_check(GameManager.get_equipped_uid("head").is_empty(), "A real tap removes the selected head item")
			var body_hp_before: int = GameManager.get_max_hp()
			var body_level_one_stats: Dictionary = EquipmentSystem.get_item_stats(inventory[2])
			var body_level_two_stats: Dictionary = EquipmentSystem.get_item_stats(EquipmentSystem.create_instance("traveler_shorts", "level_check", 2, 1))
			_check(int(body_level_two_stats.get("max_hp", 0)) > int(body_level_one_stats.get("max_hp", 0)), "Higher equipment levels increase the item bonus")
			character._on_equip_pressed("item_3")
			_check(GameManager.get_equipped_uid("body") == "item_3" and GameManager.get_max_hp() > body_hp_before, "Equipping a body item immediately updates max HP")
			GameManager.unequip_slot("body")
			character._refresh_all()
			var inventory_size_before: int = GameManager.get_inventory().size()
			character.set_active_tab("bag")
			await _wait_frames(2)
			var sell_button: Button = character.find_child("SellButton_item_2", true, false) as Button
			_check(sell_button != null and not sell_button.disabled, "Unequipped gear exposes an enabled SELL action")
			if sell_button != null and not sell_button.disabled:
				await _push_pointer_tap(viewport, sell_button.get_global_rect().get_center())
			_check(GameManager.get_inventory().size() == inventory_size_before and character.pending_sell_uid == "item_2", "First sell tap only requests confirmation")
			sell_button = character.find_child("SellButton_item_2", true, false) as Button
			if sell_button != null and not sell_button.disabled:
				await _push_pointer_tap(viewport, sell_button.get_global_rect().get_center())
			_check(GameManager.get_inventory().size() == inventory_size_before - 1 and character.pending_sell_uid.is_empty(), "Second sell tap confirms the sale")
		viewport.queue_free()
		await _wait_frames(1)

func _test_non_scripted_battle() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 11
	GameManager.player_state["unlocked_stage"] = 11
	var battle: Control = await _spawn_battle()
	_check(["addition", "subtraction"].has(str(battle.current_question.get("type", ""))), "Generated Stage 11 creates a data-driven question immediately")
	_check(int(battle.monster_hp) == int(DataManager.get_stage(11).get("monster_hp", 0)), "Battle uses generated monster HP")
	_check(int(battle.monster_attack) == int(DataManager.get_stage(11).get("monster_attack", 0)), "Battle uses generated monster attack")
	_check(battle.enemy_attack_timer != null and is_equal_approx(battle.enemy_attack_interval, GameBalance.enemy_attack_interval(11, false)), "Battle starts a data-driven enemy attack timer")
	_check(battle.enemy_attack_label != null and str(battle.enemy_attack_label.text).contains("自動攻擊"), "Battle explains the incoming auto attack")
	var generated_sprite_path: String = str(battle.monster_data.get("generated_sprite", ""))
	battle.monster_data["generated_sprite"] = "res://assets/monsters/battle/missing_generated_sprite.png"
	var fallback_sprite_path: String = battle._get_monster_sprite_path()
	_check(fallback_sprite_path.ends_with(".svg"), "Battle falls back to the authored SVG when a generated monster PNG is missing")
	battle.monster_data["generated_sprite"] = generated_sprite_path
	battle._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(battle.battle_suspended and battle.enemy_attack_timer.is_stopped(), "Battle pauses its attack clock when the app loses focus")
	battle._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(not battle.battle_suspended and not battle.enemy_attack_timer.is_stopped(), "Battle resumes its attack clock after the app returns")
	for layer_name: String in ["BattleBackgroundLayer", "BattleAmbientLayer", "BattleGroundLayer", "BattleActorLayer", "BattleFxLayer", "BattleHudLayer", "BattleKeypadLayer"]:
		_check(battle.find_child(layer_name, true, false) != null, "Battle exposes an independent %s" % layer_name)
	var player_texture: Texture2D = battle.player_sprite.texture as Texture2D
	var monster_texture: Texture2D = battle.monster_sprite.texture as Texture2D
	_check(player_texture != null and player_texture.resource_path.contains("goblin_start_v2.png"), "Battle reuses the goblin IP PNG")
	_check(monster_texture != null and monster_texture.resource_path.contains("/assets/monsters/battle/"), "Battle prefers generated monster PNGs")
	_check(battle.keypad_buttons.size() == 12, "Battle keypad keeps twelve touch controls")
	for button: Button in battle.keypad_buttons:
		_check(button.size.x >= 96.0 and button.size.y >= 96.0, "Battle keypad buttons keep a 96 logical pixel touch target")
	battle.queue_free()
	await _wait_frames(1)

func _test_enemy_auto_attack() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 1
	GameManager.player_state["base_defense"] = 4
	var battle: Control = await _spawn_battle()
	var hp_before: int = int(battle.player_hp)
	var expected_damage: int = GameManager.calculate_incoming_damage(int(battle.monster_attack))
	battle.enemy_attack_timer.wait_time = 0.12
	battle.enemy_attack_timer.start()
	await get_tree().create_timer(0.25).timeout
	_check(int(battle.enemy_auto_attack_count) == 1, "Enemy timer performs one automatic attack")
	_check(int(battle.player_hp) == hp_before - expected_damage, "Automatic attack uses the player's defense when calculating damage")
	_check(str(battle.feedback_label.text).contains("自動攻擊"), "Automatic attack gives an explicit player-facing warning")
	battle.enemy_attack_timer.stop()
	battle.queue_free()
	await _wait_frames(1)

func _test_battle_pause() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 1
	var battle: Control = await _spawn_battle()
	var hp_before: int = int(battle.player_hp)
	_check(battle.battle_pause_button != null and battle.battle_pause_button.size.x >= 96.0 and battle.battle_pause_button.size.y >= 96.0, "Battle pause control keeps a touch-safe target")
	battle._on_pause_pressed()
	_check(bool(battle.battle_paused), "Battle pause state turns on from the visible pause button")
	_check(battle.enemy_attack_timer != null and battle.enemy_attack_timer.is_stopped(), "Pausing a battle stops the enemy attack clock")
	_check(battle.find_child("BattlePauseLayer", true, false) != null, "Pausing a battle exposes an independent pause overlay")
	_check(battle.battle_pause_button.disabled, "Pause button cannot be pressed twice while paused")
	var all_keys_disabled: bool = true
	for button: Button in battle.keypad_buttons:
		all_keys_disabled = all_keys_disabled and button.disabled
	_check(all_keys_disabled, "Pausing a battle disables every answer key")
	await get_tree().create_timer(0.25).timeout
	_check(int(battle.player_hp) == hp_before, "A paused battle cannot deal an automatic attack")
	battle._on_resume_pressed()
	_check(not bool(battle.battle_paused), "Resume returns the battle to the active state")
	_check(battle.enemy_attack_timer != null and not battle.enemy_attack_timer.is_stopped(), "Resuming a battle restarts the enemy attack clock")
	_check(not battle.battle_pause_button.disabled, "Pause button becomes available after resume")
	battle.queue_free()
	await _wait_frames(1)

func _test_defeat_retry_flow() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 1
	var battle: Control = await _spawn_battle()
	battle.player_hp = 1
	battle._update_hearts()
	battle.enemy_attack_timer.wait_time = 0.05
	battle.enemy_attack_timer.start()
	await get_tree().create_timer(0.75).timeout
	_check(battle.find_child("BattleResultLayer", true, false) != null, "Losing all HP opens the Defeat result panel")
	_check(int(GameManager.player_state.get("total_defeats", 0)) == 1, "Defeat increments the persistent defeat statistic")
	_check(GameManager.get_exp() == 0 and GameManager.get_coins() == 0, "Defeat grants no accidental EXP or coin reward")
	_check(int(GameManager.player_state.get("unlocked_stage", 0)) == 1 and not GameManager.is_stage_completed(1), "Defeat does not advance or corrupt stage progress")
	var retry_button: Button = battle.find_child("RetryBattleButton", true, false) as Button
	_check(retry_button != null and retry_button.size.x >= 96.0 and retry_button.size.y >= 96.0, "Defeat keeps a touch-safe Retry entry")
	battle.queue_free()
	await _wait_frames(1)

func _test_zero_answer_input() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 3
	var battle: Control = await _spawn_battle()
	battle.current_question = {"question_text": "7 - 7", "answer": 0, "type": "subtraction"}
	battle.answer_text = ""
	battle._on_digit_pressed("0")
	_check(str(battle.answer_text) == "0" and str(battle.answer_label.text) == "0", "A valid zero subtraction answer can be entered")
	battle._on_backspace_pressed()
	_check(str(battle.answer_text).is_empty() and str(battle.answer_label.text) == "—", "Zero answer input can still be edited normally")
	battle.enemy_attack_timer.stop()
	battle.queue_free()
	await _wait_frames(1)

func _test_battle_zone_backgrounds() -> void:
	var cases: Array = [
		[1, "battle_flower_meadow_bg_v1.png"],
		[5, "battle_sakura_woods_bg_v1.png"],
		[8, "battle_starlight_hill_bg_v1.png"]
	]
	for entry: Array in cases:
		GameManager.player_state = SaveManager.create_new_save()
		GameManager.player_state["current_stage"] = int(entry[0])
		var battle: Control = await _spawn_battle()
		var background_texture: Texture2D = battle.battle_background_layer.texture as Texture2D
		_check(background_texture != null and background_texture.resource_path.ends_with(str(entry[1])), "Stage %d selects its zone battle background" % int(entry[0]))
		_check(_uses_chiron_font(battle.question_label), "Battle question uses the bundled rounded font")
		battle.queue_free()
		await _wait_frames(1)

func _test_selected_character_surfaces() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["unlocked_character_ids"] = [GameBalance.DEFAULT_CHARACTER_ID, "dragon_champion"]
	GameManager.player_state["selected_character_id"] = "dragon_champion"
	GameManager.player_state["current_stage"] = 1
	GameManager.player_state["unlocked_stage"] = 1
	var scenes: Array = [
		["start", "res://scenes/main/main_menu.tscn"],
		["map", "res://scenes/map/world_map.tscn"],
		["gacha", "res://scenes/gacha/gacha.tscn"],
		["battle", "res://scenes/battle/battle.tscn"]
	]
	for spec: Array in scenes:
		var key: String = str(spec[0])
		var viewport: SubViewport = SubViewport.new()
		viewport.name = "SelectedCharacterViewport_%s" % key
		viewport.size = Vector2i(1080, 1920)
		get_tree().root.add_child(viewport)
		var scene: Control = (load(str(spec[1])) as PackedScene).instantiate() as Control
		viewport.add_child(scene)
		await _wait_frames(5)
		var sprite: TextureRect
		match key:
			"start":
				sprite = scene.goblin_layer
			"map":
				sprite = scene.player_marker
			"gacha":
				sprite = scene.goblin_sprite
			"battle":
				sprite = scene.player_sprite
		_check(sprite != null and sprite.texture != null and sprite.texture.resource_path.ends_with("goblin_dragon_champion_v1.png"), "Selected character appears on the %s surface" % key)
		viewport.queue_free()
		await _wait_frames(2)

func _test_gacha_screen() -> void:
	var gacha_scene: PackedScene = load("res://scenes/gacha/gacha.tscn")
	for viewport_size: Vector2i in [Vector2i(405, 720), Vector2i(1080, 1920)]:
		GameManager.player_state = SaveManager.create_new_save()
		var viewport: SubViewport = SubViewport.new()
		viewport.name = "GachaViewport_%dx%d" % [viewport_size.x, viewport_size.y]
		viewport.size = viewport_size
		get_tree().root.add_child(viewport)
		var gacha: Control = gacha_scene.instantiate() as Control
		viewport.add_child(gacha)
		await _wait_frames(5)
		var gacha_title_primary: Label = gacha.gacha_title.get_child(0) as Label if gacha.gacha_title != null else null
		_check(_uses_chiron_font(gacha_title_primary), "Gacha dynamic title uses the bundled rounded font")
		for layer_name: String in ["GachaBackgroundLayer", "GachaAmbientLayer", "GachaSummonLayer", "GachaPanelLayer", "GachaResultLayer", "GachaMergeLayer", "GachaAutoMergeLayer", "GachaHudLayer", "GachaActionLayer", "GachaToastLayer"]:
			_check(gacha.find_child(layer_name, true, false) != null, "Gacha screen exposes independent %s" % layer_name)
		_check(gacha.find_child("AutoMergeButton", true, false) != null and gacha.find_child("CancelAutoMergeButton", true, false) != null and gacha.find_child("ConfirmAutoMergeButton", true, false) != null, "Gacha exposes automatic merge and preview actions")
		_check(gacha.find_child("BackToMapButton", true, false) != null, "Gacha screen can return to the map")
		_check(gacha.find_child("GachaBackgroundFallback", true, false) != null or gacha.find_child("GachaBackground", true, false) != null, "Gacha keeps a background fallback")
		var watch_ad_button: Button = gacha.find_child("WatchAdButton", true, false) as Button
		_check(watch_ad_button != null and watch_ad_button.disabled, "Watch Ad stays unavailable off native AdMob runtime")
		_check(watch_ad_button != null and watch_ad_button.pressed.is_connected(Callable(gacha, "_on_watch_ad_pressed")), "Watch Ad is wired to the rewarded-ad request path")
		_check(gacha.find_child("DiamondIcon", true, false) != null and gacha.find_child("AdLockBadge", true, false) != null, "Gacha HUD and locked ad action use independent icon layers")
		var rewarded_ad_service: Node = get_node_or_null("/root/RewardedAdService") as Node
		if not OS.has_feature("ios") and rewarded_ad_service != null:
			var gems_before_ad_hook: int = GameManager.get_gems()
			_check(not bool(rewarded_ad_service.call("is_available")), "Desktop/Web rewarded ads remain unavailable")
			_check(not bool(rewarded_ad_service.call("request_reward")), "Desktop/Web rewarded ad request cannot mint a reward")
			_check(GameManager.get_gems() == gems_before_ad_hook, "Unavailable rewarded ad request does not change gems")
		var legendary_icon: Panel = gacha._make_item_icon("rainbow_star_staff", "weapon", Vector2(96, 96), "legendary")
		var legendary_sprite: TextureRect = legendary_icon.find_child("EquipmentArtSprite", true, false) as TextureRect
		_check(legendary_sprite != null and legendary_sprite.texture != null and legendary_sprite.texture.resource_path.ends_with("rainbow_star_staff_v2.png"), "Gacha result/merge icon resolves the Legendary template art")
		legendary_icon.queue_free()
		_check(gacha.active_mode == "summon" and gacha.summon_panel.visible and not gacha.merge_panel.visible, "Gacha opens in SUMMON mode")
		_check(not gacha.single_pull_button.disabled and gacha.ten_pull_button.disabled, "Gacha disables pulls the player cannot afford")
		var state_before_mode: Dictionary = GameManager.player_state.duplicate(true)
		gacha._set_mode("merge")
		_check(gacha.merge_panel.visible and not gacha.summon_panel.visible and gacha.merge_button.visible, "Gacha MERGE mode switches its independent content layer")
		_check(str((gacha.find_child("GachaTitle", true, false).get_child(1) as Label).text) == "合成", "Gacha title changes to 合成 in MERGE mode")
		_check(gacha.merge_panel.position.y <= 330.0 and gacha.merge_panel.size.y >= 1100.0, "Gacha merge panel uses the reference portrait proportions")
		_check(gacha.find_child("MergeTitleDivider", true, false) != null and gacha.find_child("MergeActionMedallion", true, false) != null, "Gacha merge screen keeps independent generated ornament layers")
		_check(gacha.find_child("LeftSakuraOrnament", true, false) != null and gacha.find_child("RightSakuraOrnament", true, false) != null, "Gacha tabs expose independent corner flower layers")
		_check(gacha.find_child("MergeMaterialRow", true, false) != null, "Gacha merge groups expose a dedicated material row")
		gacha._set_mode("summon")
		_check(gacha.summon_panel.visible and not gacha.merge_panel.visible and GameManager.player_state == state_before_mode, "Gacha mode switching does not mutate saved state")
		for button: Button in gacha.find_children("*", "Button", true, false):
			_check(button.custom_minimum_size.x >= 96.0 or button.size.x >= 96.0, "Gacha controls keep a horizontal touch target")
			_check(button.custom_minimum_size.y >= 96.0 or button.size.y >= 96.0, "Gacha controls keep a vertical touch target")
		if viewport_size == Vector2i(1080, 1920):
			var gems_before_pull: int = GameManager.get_gems()
			var single_pull_button: Button = gacha.find_child("SinglePullButton", true, false) as Button
			_check(single_pull_button != null and not single_pull_button.disabled, "Single-pull button is enabled when the player can afford it")
			if single_pull_button != null and not single_pull_button.disabled:
				await _push_pointer_tap(viewport, single_pull_button.get_global_rect().get_center())
			_check(GameManager.get_gems() == gems_before_pull - 100 and gacha.gacha_result_layer.visible, "Single-pull UI spends gems and opens the result overlay")
			var close_result_button: Button = gacha.find_child("CloseResultButton", true, false) as Button
			_check(close_result_button != null and not close_result_button.disabled, "Gacha result exposes an enabled CLOSE action")
			if close_result_button != null and not close_result_button.disabled:
				await _push_pointer_tap(viewport, close_result_button.get_global_rect().get_center())
			_check(not gacha.gacha_result_layer.visible, "A real tap closes the gacha result overlay")
			var merge_inventory: Array = GameManager.get_inventory()
			merge_inventory.append(EquipmentSystem.create_instance("leaf_cap", "ui_merge_1", 1, 1))
			merge_inventory.append(EquipmentSystem.create_instance("leaf_cap", "ui_merge_2", 2, 1, EquipmentSystem.upgrade_coins_spent_for_level(2, "common")))
			merge_inventory.append(EquipmentSystem.create_instance("leaf_cap", "ui_merge_3", 3, 1, EquipmentSystem.upgrade_coins_spent_for_level(3, "common")))
			for index: int in range(1, 4):
				merge_inventory.append(EquipmentSystem.create_instance("traveler_shorts", "ui_scroll_%d" % index, 1, 1))
			GameManager.player_state["inventory"] = merge_inventory
			GameManager.player_state["equipped"] = {"weapon": "item_1", "head": "ui_merge_1", "body": ""}
			GameManager.player_state["next_item_uid"] = 5
			var merge_tab_button: Button = gacha.find_child("MergeTabButton", true, false) as Button
			if merge_tab_button != null:
				await _push_pointer_tap(viewport, merge_tab_button.get_global_rect().get_center())
			_check(gacha.active_mode == "merge", "A real tap opens the MERGE mode")
			await _wait_frames(2)
			var merge_scroll_before: int = gacha.merge_scroll.scroll_vertical
			_check(gacha.merge_scroll.get_v_scroll_bar().max_value > 0.0, "Merge list exposes vertical overflow for the available material groups")
			await _push_screen_drag(viewport, gacha.merge_scroll.get_global_rect().get_center(), gacha.merge_scroll.get_global_rect().get_center() - Vector2(0, 120))
			_check(gacha.merge_scroll.scroll_vertical > merge_scroll_before, "Touch dragging the merge list scrolls it vertically")
			for uid: String in ["ui_merge_1", "ui_merge_2", "ui_merge_3"]:
				var material_button: Button = gacha.find_child("MergeItem_%s" % uid, true, false) as Button
				_check(material_button != null and not material_button.disabled, "Merge exposes an enabled material button for %s" % uid)
				if material_button != null and not material_button.disabled:
					await _push_pointer_tap(viewport, material_button.get_global_rect().get_center())
			_check(gacha.selected_merge_uids.size() == 3 and not gacha.merge_button.disabled, "Merge UI enables only after three matching materials are selected")
			var merge_action_button: Button = gacha.find_child("MergeButton", true, false) as Button
			_check(merge_action_button != null and not merge_action_button.disabled, "Merge exposes an enabled action after three selections")
			if merge_action_button != null and not merge_action_button.disabled:
				await _push_pointer_tap(viewport, merge_action_button.get_global_rect().get_center())
			var has_merged_head: bool = false
			for raw_item: Variant in GameManager.get_inventory():
				if raw_item is Dictionary and str(raw_item.get("template_id", "")) == "sakura_ribbon":
					has_merged_head = true
			_check(has_merged_head, "Merge UI consumes three materials and stores the next-tier equipment")

			var auto_inventory: Array = []
			for index: int in range(1, 10):
				auto_inventory.append(EquipmentSystem.create_instance("twig_club", "auto_ui_%d" % index, 1, 1))
			GameManager.player_state["inventory"] = auto_inventory
			GameManager.player_state["equipped"] = {"weapon": "auto_ui_1", "head": "", "body": ""}
			GameManager.player_state["next_item_uid"] = 1
			gacha._refresh()
			gacha._set_mode("merge")
			var auto_merge_button: Button = gacha.find_child("AutoMergeButton", true, false) as Button
			_check(auto_merge_button != null and not auto_merge_button.disabled, "Auto merge is enabled when a complete chain is available")
			if auto_merge_button != null and not auto_merge_button.disabled:
				await _push_pointer_tap(viewport, auto_merge_button.get_global_rect().get_center())
			_check(gacha.gacha_auto_merge_layer.visible and gacha.find_child("AutoMergePreviewSummary", true, false) != null, "Auto merge opens a preview without changing the inventory")
			var cancel_auto_button: Button = gacha.find_child("CancelAutoMergeButton", true, false) as Button
			if cancel_auto_button != null:
				await _push_pointer_tap(viewport, cancel_auto_button.get_global_rect().get_center())
			_check(not gacha.gacha_auto_merge_layer.visible and GameManager.get_inventory().size() == 9, "Cancelling the auto merge preview leaves state unchanged")
			if auto_merge_button != null and not auto_merge_button.disabled:
				await _push_pointer_tap(viewport, auto_merge_button.get_global_rect().get_center())
			var confirm_auto_button: Button = gacha.find_child("ConfirmAutoMergeButton", true, false) as Button
			if confirm_auto_button != null:
				await _push_pointer_tap(viewport, confirm_auto_button.get_global_rect().get_center())
			var has_auto_star_hammer: bool = false
			for raw_item: Variant in GameManager.get_inventory():
				if raw_item is Dictionary and str(raw_item.get("template_id", "")) == "star_hammer":
					has_auto_star_hammer = true
			_check(has_auto_star_hammer and str(GameManager.get_equipped_uid("weapon")) != "", "Confirming auto merge updates inventory and keeps the equipped slot populated")
		viewport.queue_free()
		await _wait_frames(1)

	GameManager.player_state = SaveManager.create_new_save()
	var previous_transition_busy: bool = GameManager.transition_busy
	GameManager.transition_busy = true
	GameManager.go_to_gacha("merge", "character")
	GameManager.transition_busy = previous_transition_busy
	var context_viewport: SubViewport = SubViewport.new()
	context_viewport.name = "GachaContextViewport"
	context_viewport.size = Vector2i(1080, 1920)
	get_tree().root.add_child(context_viewport)
	var context_gacha: Control = gacha_scene.instantiate() as Control
	context_viewport.add_child(context_gacha)
	await _wait_frames(5)
	_check(context_gacha.active_mode == "merge" and context_gacha.return_scene == "character", "Character merge navigation opens MERGE mode with a character return context")
	_check(context_gacha.find_child("BackToMapButton", true, false).pressed.is_connected(Callable(context_gacha, "_on_back_pressed")), "Merge page keeps a wired context-aware back action")
	context_viewport.queue_free()
	await _wait_frames(1)

func _test_real_battle_loop() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 1
	var battle: Control = await _spawn_battle()
	_check(battle != null and battle.name == "Battle", "Battle scene instantiates from the project scene")
	if battle == null:
		return
	_check(str(battle.current_question.get("question_text", "")) == "5 + 3", "Stage 1 keeps the scripted 5 + 3 opening")
	_check(str(battle.hearts_label.text).contains("♥♥♥"), "Battle HUD shows three full hearts at full starter HP")
	battle._on_digit_pressed("1")
	battle._on_submit_pressed()
	await get_tree().create_timer(0.7).timeout
	_check(int(battle.player_hp) == GameManager.get_max_hp() - 10, "Wrong answer applies monster damage to player HP")
	_check(int(battle.combo) == 0, "Wrong answer resets combo")
	_check(str(battle.hearts_label.text).contains("♥♥♡"), "Battle HUD shows a visibly missing heart after damage")

	battle.queue_free()
	await _wait_frames(1)
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 1
	battle = await _spawn_battle()
	var safety: int = 0
	while not battle.input_locked and safety < 10:
		var answer: String = str(battle.current_question.get("answer", -1))
		for digit: String in answer:
			battle._on_digit_pressed(digit)
		battle._on_submit_pressed()
		await get_tree().create_timer(0.7).timeout
		safety += 1
	_check(int(GameManager.get_exp()) == 20, "Real battle victory awards EXP")
	_check(int(GameManager.get_coins()) >= 10, "Real battle victory awards coins")
	_check(GameManager.is_stage_unlocked(2), "Real battle victory unlocks Stage 2")
	_check(battle.input_locked, "Victory locks keypad input")
	_check(battle.find_child("BattleResultLayer", true, false) != null, "Victory uses an independent result layer")
	battle.queue_free()
	await _wait_frames(1)

func _test_start_screen(viewport_size: Vector2i, test_button: bool) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "StartScreenViewport_%dx%d" % [viewport_size.x, viewport_size.y]
	viewport.size = viewport_size
	get_tree().root.add_child(viewport)
	var menu = START_MENU_DOUBLE.new()
	menu.name = "MainMenuUnderTest"
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(menu)
	await _wait_frames(3)
	var background: TextureRect = menu.get_node_or_null("BackgroundLayer") as TextureRect
	var stage: Control = menu.get_node_or_null("SafeArea/LayerStage") as Control
	_check(background != null, "Start screen has an independent background layer at %s" % viewport_size)
	_check(stage != null, "Start screen has a safe-area layer stage at %s" % viewport_size)
	if stage != null:
		var effects: TextureRect = stage.get_node_or_null("EffectsLayer") as TextureRect
		var logo: TextureRect = stage.get_node_or_null("LogoLayer") as TextureRect
		var goblin: TextureRect = stage.get_node_or_null("GoblinLayer") as TextureRect
		var button: Button = stage.get_node_or_null("StartAdventureButton") as Button
		_check(effects != null and logo != null and goblin != null and button != null, "Start screen keeps all independent layers")
		if logo != null and goblin != null and button != null:
			var start_copy: Label = button.find_child("PrimaryLabel", true, false) as Label
			_check(_uses_chiron_font(start_copy), "Start screen action copy uses the bundled rounded CJK font")
			_check(not logo.get_rect().intersects(goblin.get_rect()), "Logo and goblin do not overlap at %s" % viewport_size)
			_check(not goblin.get_rect().intersects(button.get_rect()), "Goblin and button do not overlap at %s" % viewport_size)
			_check(button.size.x >= 280.0 and button.size.y >= 100.0, "Start button keeps a large touch target at %s" % viewport_size)
			if test_button:
				button.emit_signal("pressed")
				await get_tree().create_timer(0.3).timeout
				_check(menu.world_map_requested, "Start button requests the World Map transition")
	viewport.queue_free()
	await _wait_frames(1)

func _wait_frames(frame_count: int) -> void:
	for index: int in range(frame_count):
		await get_tree().process_frame

func _uses_chiron_font(control: Control) -> bool:
	if control == null:
		return false
	var font: Font = control.get_theme_font("font")
	return font != null and font.resource_path.contains("ChironGoRoundTC")

func _push_pointer_tap(viewport: Viewport, at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = at
	press.global_position = at
	press.pressed = true
	viewport.push_input(press, true)
	await _wait_frames(1)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	viewport.push_input(release, true)
	await _wait_frames(2)

func _push_pointer_drag(viewport: Viewport, start: Vector2, finish: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = start
	press.global_position = start
	press.pressed = true
	viewport.push_input(press, true)
	await _wait_frames(1)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = finish
	motion.global_position = finish
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion, true)
	await _wait_frames(1)
	var release: InputEventMouseButton = press.duplicate()
	release.position = finish
	release.global_position = finish
	release.pressed = false
	viewport.push_input(release, true)
	await _wait_frames(2)

func _push_screen_drag(viewport: Viewport, start: Vector2, finish: Vector2) -> void:
	var touch_start: InputEventScreenTouch = InputEventScreenTouch.new()
	touch_start.index = 0
	touch_start.position = start
	touch_start.pressed = true
	viewport.push_input(touch_start, true)
	await _wait_frames(1)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = finish
	drag.relative = finish - start
	viewport.push_input(drag, true)
	await _wait_frames(1)
	var touch_end: InputEventScreenTouch = InputEventScreenTouch.new()
	touch_end.index = 0
	touch_end.position = finish
	touch_end.pressed = false
	viewport.push_input(touch_end, true)
	await _wait_frames(2)

func _spawn_battle() -> Control:
	var battle_scene: PackedScene = load("res://scenes/battle/battle.tscn")
	var battle: Control = battle_scene.instantiate() as Control
	get_tree().root.add_child(battle)
	await _wait_frames(3)
	return battle

func _cleanup_save_files(base_path: String) -> void:
	for path: String in [base_path, base_path + ".bak", base_path + ".tmp", base_path + ".recover.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)
