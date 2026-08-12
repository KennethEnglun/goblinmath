extends Node

## Headless unit and persistence checks for the long-term progression systems.
var failures: int = 0

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var original_save_path: String = SaveManager.storage_path
	var suite_save_path: String = "/private/tmp/candymaths_vertical_suite_%d.json" % OS.get_process_id()
	SaveManager.storage_path = suite_save_path
	_cleanup_save_files(suite_save_path)

	_test_assets_and_authored_data()
	_test_endless_stage_generation()
	_test_questions_and_balance()
	_test_save_migration()
	_test_save_recovery_and_persistence()
	_test_bounded_endless_metadata()
	_test_character_progression()
	_test_equipment_actions()
	_test_gacha_system()
	_test_project_settings()

	if failures == 0:
		print("LONG_TERM_SYSTEMS_TESTS_PASS")
	else:
		print("LONG_TERM_SYSTEMS_TESTS_FAIL: %d" % failures)
	_cleanup_save_files(suite_save_path)
	SaveManager.storage_path = original_save_path
	get_tree().quit(failures)

func _test_assets_and_authored_data() -> void:
	for asset_path: String in [
		"res://assets/ui/start/start_background_v2.png",
		"res://assets/ui/start/start_effects_v2.png",
		"res://assets/ui/start/start_logo_v2.png",
		"res://assets/ui/start/goblin_start_v2.png",
		"res://assets/ui/start/start_adventure_button_v2.png",
		"res://assets/fonts/ChironGoRoundTC-500M.woff2",
		"res://assets/fonts/ChironGoRoundTC-700B.woff2",
		"res://assets/ui/battle/battle_flower_meadow_bg_v1.png",
		"res://assets/ui/battle/battle_sakura_woods_bg_v1.png",
		"res://assets/ui/battle/battle_starlight_hill_bg_v1.png",
		"res://assets/ui/battle/battle_ambient_effects_v1.png",
		"res://assets/ui/battle/battle_ground_glow_v1.png",
		"res://assets/ui/battle/battle_hit_effect_v1.png",
		"res://assets/ui/battle/battle_miss_effect_v1.png",
		"res://assets/ui/battle/battle_answer_panel_v1.png",
		"res://assets/ui/battle/battle_key_button_skin_v1.png",
		"res://assets/ui/battle/battle_result_panel_v1.png",
		"res://assets/ui/battle/battle_heart_icon_v1.png",
		"res://assets/monsters/green_blob.svg",
		"res://assets/monsters/mushroom.svg",
		"res://assets/monsters/pollen_puff.svg",
		"res://assets/monsters/sakura_sprite.svg",
		"res://assets/monsters/star_puff.svg",
		"res://assets/monsters/crown_slime_boss.svg",
		"res://assets/monsters/battle/green_blob_battle_v1.png",
		"res://assets/monsters/battle/mushroom_battle_v1.png",
		"res://assets/monsters/battle/pollen_puff_battle_v1.png",
		"res://assets/monsters/battle/sakura_sprite_battle_v1.png",
		"res://assets/monsters/battle/star_puff_battle_v1.png",
		"res://assets/monsters/battle/crown_slime_boss_battle_v1.png",
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
		"res://assets/ui/map/stage_current_glow.png",
		"res://assets/ui/gacha/gacha_background_v1.png",
		"res://assets/ui/gacha/gacha_ambient_effects_v1.png",
		"res://assets/ui/gacha/gacha_summon_pedestal_v1.png",
		"res://assets/ui/gacha/gacha_summon_circle_v1.png",
		"res://assets/ui/gacha/gacha_panel_skin_v1.png",
		"res://assets/ui/gacha/gacha_result_card_frame_v1.png",
		"res://assets/ui/gacha/gacha_button_skin_v1.png",
		"res://assets/ui/gacha/gacha_merge_effect_v1.png",
		"res://assets/ui/gacha/gacha_diamond_icon_v1.png",
		"res://assets/ui/gacha/gacha_ad_lock_badge_v1.png"
	]:
		_check(ResourceLoader.exists(asset_path), "Asset imports: %s" % asset_path)
	_check(FileAccess.file_exists("res://assets/fonts/ChironGoRoundTC-OFL.txt"), "Rounded font license is bundled with the game")

	var chapter_one: Array = DataManager.get_stages_for_chapter(1)
	_check(chapter_one.size() == 10, "Chapter 1 contains ten authored stages")
	_check(int(chapter_one.front().get("id", 0)) == 1 and int(chapter_one.back().get("id", 0)) == 10, "Authored stages remain sorted")
	var zone_counts: Dictionary = {"flower_meadow": 0, "sakura_woods": 0, "starlight_hill": 0}
	var previous_monster_attack: int = 0
	var previous_monster_hp: int = 0
	for stage: Dictionary in chapter_one:
		var stage_id: int = int(stage.get("id", 0))
		_check(not DataManager.get_monster(str(stage.get("monster_id", ""))).is_empty(), "Stage %d references a valid monster" % stage_id)
		var map_position: Array = stage.get("map_position", [])
		_check(map_position.size() == 2 and float(map_position[0]) >= 0.0 and float(map_position[0]) <= 1080.0 and float(map_position[1]) >= 0.0 and float(map_position[1]) <= 4608.0, "Stage %d stays inside map bounds" % stage_id)
		var authored_attack: int = int(stage.get("monster_attack", 0))
		_check(authored_attack > previous_monster_attack, "Stage %d raises the authored enemy attack curve" % stage_id)
		previous_monster_attack = authored_attack
		var authored_hp: int = int(stage.get("monster_hp", 0))
		_check(authored_hp > previous_monster_hp, "Stage %d raises the authored enemy HP curve" % stage_id)
		previous_monster_hp = authored_hp
		_check(not (stage.get("question_types", []) as Array).is_empty() and int(stage.get("reward_exp", 0)) > 0 and int(stage.get("reward_coin", 0)) > 0, "Stage %d has playable questions and positive rewards" % stage_id)
		var stage_generator: QuestionGenerator = QuestionGenerator.new()
		for raw_type: Variant in stage.get("question_types", []):
			var typed_stage: Dictionary = stage.duplicate(true)
			typed_stage["question_types"] = [str(raw_type)]
			var sample_question: Dictionary = stage_generator.generate(typed_stage)
			_check(str(sample_question.get("type", "")) == str(raw_type) and not str(sample_question.get("question_text", "")).is_empty(), "Stage %d generates valid %s questions" % [stage_id, str(raw_type)])
		var zone: String = str(stage.get("zone", ""))
		if zone_counts.has(zone):
			zone_counts[zone] = int(zone_counts[zone]) + 1
	_check(int(zone_counts["flower_meadow"]) == 3 and int(zone_counts["sakura_woods"]) == 4 and int(zone_counts["starlight_hill"]) == 3, "Chapter pages use the planned 3/4/3 zone split")
	_check(DataManager.get_stage(0).is_empty() and DataManager.get_monster("missing").is_empty() and DataManager.get_equipment("missing").is_empty(), "Invalid stage, monster, and equipment IDs fail safely")

	var equipment_templates: Array = DataManager.get_all_equipment()
	_check(equipment_templates.size() == 15, "Fifteen equipment templates load with Legendary gear")
	var equipment_sprite_paths: Dictionary = {}
	for template: Dictionary in equipment_templates:
		_check(EquipmentSystem.SLOTS.has(str(template.get("slot", ""))), "Equipment %s has a valid slot" % str(template.get("id", "")))
		var template_id: String = str(template.get("id", ""))
		var sprite_path: String = str(template.get("generated_sprite", ""))
		_check(not sprite_path.is_empty() and ResourceLoader.exists(sprite_path), "Equipment %s has an imported standalone art asset" % template_id)
		_check(EquipmentSystem.get_equipment_sprite_path(template_id) == sprite_path, "Equipment %s resolves its standalone art path" % template_id)
		_check(not equipment_sprite_paths.has(sprite_path), "Equipment %s does not reuse another template's art path" % template_id)
		equipment_sprite_paths[sprite_path] = template_id
	_check(not DataManager.get_equipment("rainbow_star_staff").is_empty() and str(DataManager.get_equipment("crown_staff").get("merge_to", "")) == "rainbow_star_staff", "Legendary merge targets are data-driven")
	_check(DataManager.get_gacha_config().get("single_cost", 0) == 100 and DataManager.get_gacha_config().get("ten_cost", 0) == 1000, "Gacha economy data loads")

func _test_endless_stage_generation() -> void:
	_check(DataManager.get_next_stage_id(9) == 10, "Stage 9 advances to the authored boss")
	_check(DataManager.get_next_stage_id(10) == 11, "Stage 10 opens the first endless chapter")
	_check(DataManager.get_next_stage_id(GameBalance.MAX_STAGE_ID) == -1, "Corrupt progress cannot exceed the practical stage guard")
	var stage_eleven: Dictionary = DataManager.get_stage(11)
	var stage_twenty: Dictionary = DataManager.get_stage(20)
	var stage_thousand: Dictionary = DataManager.get_stage(1000)
	_check(not stage_eleven.is_empty() and bool(stage_eleven.get("is_endless", false)), "Stage 11 is generated on demand")
	_check(int(stage_eleven.get("world", 0)) == 2 and int(stage_eleven.get("id", 0)) == 11, "Generated stages map to the correct chapter")
	_check(bool(stage_twenty.get("is_boss", false)) and str(stage_twenty.get("monster_id", "")) == "crown_slime_boss", "Every tenth generated stage is a boss")
	_check(DataManager.get_stage(1000) == stage_thousand, "Endless stage generation is deterministic")
	_check(int(stage_eleven.get("monster_attack", 0)) > int(DataManager.get_stage(10).get("monster_attack", 0)), "Endless progression does not weaken after the World 1 boss")
	_check(int(stage_eleven.get("monster_hp", 0)) > int(DataManager.get_stage(10).get("monster_hp", 0)), "Endless HP grows smoothly after the World 1 boss")
	_check(int(DataManager.get_stage(21).get("monster_attack", 0)) > int(stage_twenty.get("monster_attack", 0)), "A generated boss does not make the following stage weaker")
	_check(int(DataManager.get_stage(21).get("monster_hp", 0)) > int(stage_twenty.get("monster_hp", 0)), "A generated boss does not make the following stage less durable")
	_check(int(stage_thousand.get("monster_hp", 0)) > int(stage_eleven.get("monster_hp", 0)), "Endless monster HP continues scaling")
	_check(int(stage_thousand.get("monster_attack", 0)) > int(stage_eleven.get("monster_attack", 0)), "Endless enemy attack power continues scaling")
	_check(GameBalance.enemy_attack_interval(10) < GameBalance.enemy_attack_interval(1), "Enemy attack interval gets shorter in later stages")
	_check(GameBalance.enemy_attack_interval(20, true) < GameBalance.enemy_attack_interval(20, false), "Bosses attack on a faster clock")
	_check(GameBalance.enemy_attack_interval(10, true) < GameBalance.enemy_attack_interval(9, false), "World 1 boss is faster than the preceding normal stage")
	_check(GameBalance.enemy_attack_interval(10, true) <= GameBalance.enemy_attack_interval(10, false) * 0.95, "Boss speed-up is large enough to be readable")
	_check(GameBalance.enemy_attack_interval(10, true) >= 5.0, "World 1 boss keeps a child-friendly answer window")
	_check(GameBalance.enemy_attack_interval(11) < GameBalance.enemy_attack_interval(10, false) and GameBalance.enemy_attack_interval(21) < GameBalance.enemy_attack_interval(20, false), "Normal stages keep the continuous speed curve after each boss")
	_check(GameBalance.enemy_attack_interval(GameBalance.MAX_STAGE_ID) >= GameBalance.MIN_ENEMY_ATTACK_INTERVAL, "Endless enemy attack interval has a fairness floor")
	_check(DataManager.get_stages_for_chapter(100).size() == 10, "Distant chapters still generate ten playable stages")
	var fresh_state: Dictionary = SaveManager.create_new_save()
	GameManager.player_state = fresh_state
	var starter_attack: int = GameManager.get_attack()
	var stage_one_hp: int = int(DataManager.get_stage(1).get("monster_hp", 30))
	var stage_one_damage: int = 0
	var stage_one_hits: int = 0
	for combo_index: int in range(1, 12):
		stage_one_damage += GameBalance.calculate_damage(starter_attack, combo_index)
		stage_one_hits += 1
		if stage_one_damage >= stage_one_hp:
			break
	_check(stage_one_hits <= 4, "A clean Stage 1 run remains beatable in a small number of answers")
	var boss_hp: int = int(DataManager.get_stage(10).get("monster_hp", 72))
	var boss_damage: int = 0
	var boss_hits: int = 0
	for combo_index: int in range(1, 20):
		boss_damage += GameBalance.calculate_damage(starter_attack, combo_index)
		boss_hits += 1
		if boss_damage >= boss_hp:
			break
	_check(boss_hits <= 10, "A clean World 1 boss run remains beatable without an unbounded question count")
	for stage_id: int in range(1, GameBalance.STAGES_PER_CHAPTER + 1):
		var authored_stage: Dictionary = DataManager.get_stage(stage_id)
		var incoming_damage: int = GameBalance.damage_taken(int(authored_stage.get("monster_attack", 1)), GameManager.get_defense())
		_check(incoming_damage < GameManager.get_max_hp(), "World 1 Stage %d does not one-shot a fresh player's full HP" % stage_id)

func _test_questions_and_balance() -> void:
	var generator: QuestionGenerator = QuestionGenerator.new()
	generator.set_seed(12345)
	var stage_one: Dictionary = DataManager.get_stage(1)
	for index: int in range(30):
		var addition: Dictionary = generator.generate(stage_one)
		_check(str(addition.get("type", "")) == "addition", "Stage 1 stays addition-only")

	var subtraction_stage: Dictionary = {"question_types": ["subtraction"], "min_number": 1, "max_number": 30}
	var division_stage: Dictionary = {"question_types": ["division"], "min_number": 1, "max_number": 12}
	for index: int in range(50):
		var subtraction: Dictionary = generator.generate(subtraction_stage)
		var subtraction_parts: PackedStringArray = str(subtraction.get("question_text", "")).split(" - ")
		_check(subtraction_parts.size() == 2 and int(subtraction_parts[0]) >= int(subtraction_parts[1]), "Subtraction never produces a negative answer")
		var division: Dictionary = generator.generate(division_stage)
		var division_parts: PackedStringArray = str(division.get("question_text", "")).split(" ÷ ")
		_check(division_parts.size() == 2 and int(division_parts[1]) != 0 and int(division_parts[0]) % int(division_parts[1]) == 0, "Division always divides evenly")

	var distant_stage: Dictionary = DataManager.get_stage(10_000)
	for index: int in range(100):
		var question: Dictionary = generator.generate(distant_stage)
		_check(absi(int(question.get("answer", 0))) <= 198, "Endless mental-math answers stay within the two-digit operand band")

	generator.set_seed(24680)
	var recent_prompts: Array[String] = []
	for index: int in range(24):
		var prompt: String = str(generator.generate({"question_types": ["addition"], "min_number": 1, "max_number": 20}).get("question_text", ""))
		_check(not recent_prompts.has(prompt), "Question generator avoids short-window repeats")
		recent_prompts.push_back(prompt)
		if recent_prompts.size() > QuestionGenerator.RECENT_QUESTION_LIMIT:
			recent_prompts.pop_front()

	_check(GameBalance.calculate_damage(10, 1) == 10, "Combo 1 damage")
	_check(GameBalance.calculate_damage(10, 2) == 11, "Combo 2 damage")
	_check(GameBalance.calculate_damage(10, 5) == 12, "Combo 5 damage")
	_check(GameBalance.calculate_damage(10, 10) == 15, "Combo 10 damage")
	_check(GameBalance.damage_taken(12, 4) == 8 and GameBalance.damage_taken(20, 999) == 5, "Defense reduces damage while preserving the 25 percent consequence floor")
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["base_max_hp"] = 2_000_000_000
	_check(GameManager.get_player_hearts() == GameBalance.MAX_DISPLAY_HEARTS, "Extreme HP values stay safe in the compact heart HUD")
	_check(GameBalance.stage_stars(0) == 3 and GameBalance.stage_stars(2) == 2 and GameBalance.stage_stars(3) == 1, "Clear ratings reward accuracy without making mistakes unrecoverable")
	_check(is_equal_approx(GameBalance.reward_multiplier_for_clear(false), 0.5), "Replay rewards are reduced but remain earnable")

func _test_save_migration() -> void:
	_check(SaveManager._absolute_path("user://save.json").begins_with("/"), "Virtual save paths resolve before atomic file operations")
	var normalized: Dictionary = SaveManager._normalize_save({
		"level": 3,
		"base_attack": 15,
		"unlocked_stage": 99,
		"completed_stages": [1, 1, 10, 11, GameBalance.MAX_STAGE_ID + 1, "bad"],
		"stage_scores": {"1": {"best_stars": 9, "best_accuracy": 4.0}, "2": {"best_stars": 0}, "bad": {"best_stars": 3}},
		"owned_equipment": ["twig_club", "bad_item", "twig_club"],
		"equipped_weapon": "twig_club"
	})
	_check(int(normalized.get("save_version", 0)) == SaveManager.SAVE_VERSION and SaveManager.SAVE_VERSION == 7, "Old saves migrate to the current version")
	_check(int(normalized.get("stat_points_total", -1)) == 2, "Migrated saves retain the total level-earned stat points")
	_check(int((normalized.get("stat_points_spent", {}) as Dictionary).get("attack", 0)) == 1, "Migrated saves reconstruct legacy attack allocation points")
	_check(int(normalized.get("gems", 0)) == GameBalance.BASE_GEMS, "Migrated saves receive the one-time gacha introduction gems")
	_check(int(normalized.get("base_attack", 0)) == 15, "Legacy attack progression survives migration")
	_check(int(normalized.get("unlocked_stage", 0)) == 99, "Progress is no longer capped at Stage 10")
	_check(int(normalized.get("highest_completed_stage", 0)) == 98, "Legacy unlocked progress migrates to a sequential high-water mark")
	_check(normalized.get("completed_stages", []) == [1, 10, 11], "Completed stages are valid, unique, and sorted")
	var migrated_scores: Dictionary = normalized.get("stage_scores", {})
	_check(int((migrated_scores.get("1", {}) as Dictionary).get("best_stars", 0)) == GameBalance.MAX_STAGE_STARS and is_equal_approx(float((migrated_scores.get("1", {}) as Dictionary).get("best_accuracy", 0.0)), 1.0), "Stage score records are clamped during migration")
	_check((normalized.get("inventory", []) as Array).size() == 1, "Legacy equipment migrates without duplicates")
	_check(str((normalized.get("equipped", {}) as Dictionary).get("weapon", "")) == "item_1", "Legacy equipped weapon migrates to an item instance")
	var legacy_levelled: Dictionary = SaveManager._normalize_save({
		"inventory": [{"uid": "legacy_levelled", "template_id": "twig_club", "level": 3, "acquired_stage": 2}]
	})
	var legacy_levelled_item: Dictionary = (legacy_levelled.get("inventory", []) as Array)[0]
	_check(int(legacy_levelled_item.get("upgrade_coins_spent", 0)) == EquipmentSystem.upgrade_coins_spent_for_level(3, "common"), "Legacy equipment reconstructs cumulative strengthening coins")

func _test_save_recovery_and_persistence() -> void:
	var original_path: String = SaveManager.storage_path
	var test_path: String = "/private/tmp/candymaths_save_test_%d.json" % OS.get_process_id()
	SaveManager.storage_path = test_path
	_cleanup_save_files(test_path)

	var legacy_file: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	if legacy_file != null:
		legacy_file.store_string(JSON.stringify({"level": 2, "unlocked_stage": 7, "current_stage": 7, "coins": 9}))
		legacy_file = null
	var migrated: Dictionary = SaveManager.load_game()
	var persisted_migration: Variant = JSON.parse_string(FileAccess.get_file_as_string(test_path))
	_check(int(migrated.get("highest_completed_stage", 0)) == 6, "Loading a legacy save infers its sequential completion progress")
	_check(persisted_migration is Dictionary and int(persisted_migration.get("save_version", 0)) == SaveManager.SAVE_VERSION, "Legacy migration is immediately persisted")
	_cleanup_save_files(test_path)

	var missing_result: Dictionary = SaveManager.load_game()
	_check(int(missing_result.get("unlocked_stage", 0)) == 1 and FileAccess.file_exists(test_path), "Missing save is recreated safely")
	missing_result["unlocked_stage"] = 123
	missing_result["current_stage"] = 123
	missing_result["highest_completed_stage"] = 122
	missing_result["coins"] = 37
	missing_result["stage_scores"] = {"123": {"best_stars": 2, "best_accuracy": 0.75, "clear_count": 1}}
	missing_result["stage_attempts"] = {"123": 2}
	_check(SaveManager.save_game(missing_result), "Progress writes atomically to disk")
	SaveManager.current_data = {}
	var reloaded: Dictionary = SaveManager.load_game()
	_check(int(reloaded.get("unlocked_stage", 0)) == 123 and int(reloaded.get("coins", 0)) == 37, "Endless progress survives a reload")
	_check(int((reloaded.get("stage_scores", {}) as Dictionary).get("123", {}).get("best_stars", 0)) == 2 and int((reloaded.get("stage_attempts", {}) as Dictionary).get("123", 0)) == 2, "Replay ratings and attempt counts survive a reload")
	GameManager.player_state = reloaded.duplicate(true)
	GameManager._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_saved: Dictionary = SaveManager.load_game()
	_check(int(focus_saved.get("coins", 0)) == 37, "Application focus-out persists the latest progress")
	reloaded["coins"] = 50
	_check(SaveManager.save_game(reloaded), "A second save creates a recovery backup")

	var corrupt_file: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{broken save")
		corrupt_file = null
	var recovered: Dictionary = SaveManager.load_game()
	_check(int(recovered.get("coins", 0)) == 37 and int(recovered.get("unlocked_stage", 0)) == 123, "Corrupt main save recovers the previous backup")
	var repaired_primary: Variant = JSON.parse_string(FileAccess.get_file_as_string(test_path))
	_check(repaired_primary is Dictionary and int((repaired_primary as Dictionary).get("coins", 0)) == 37, "Recovered save repairs the corrupt primary for the next launch")

	_cleanup_save_files(test_path)
	SaveManager.storage_path = original_path

func _test_bounded_endless_metadata() -> void:
	var raw_scores: Dictionary = {}
	var raw_attempts: Dictionary = {}
	for stage_id: int in range(1, 301):
		raw_scores[str(stage_id)] = {
			"best_stars": 1,
			"best_accuracy": 0.5,
			"best_combo": 1,
			"clear_count": 1,
			"last_stars": 1,
			"last_accuracy": 0.5,
			"last_mistakes": 2
		}
		raw_attempts[str(stage_id)] = 1
	var normalized: Dictionary = SaveManager._normalize_save({
		"stage_scores": raw_scores,
		"stage_attempts": raw_attempts,
		"highest_completed_stage": 300,
		"unlocked_stage": 301
	})
	var scores: Dictionary = normalized.get("stage_scores", {})
	var attempts: Dictionary = normalized.get("stage_attempts", {})
	_check(scores.size() == GameBalance.MAX_PERSISTED_STAGE_RECORDS, "Endless stage scores stay bounded in the save")
	_check(attempts.size() == GameBalance.MAX_PERSISTED_STAGE_RECORDS, "Endless stage attempts stay bounded in the save")
	_check(scores.has("1") and scores.has("10") and scores.has("300"), "World 1 and newest score records are retained")
	_check(attempts.has("1") and attempts.has("10") and attempts.has("300"), "World 1 and newest attempt records are retained")
	_check(int(normalized.get("highest_completed_stage", 0)) == 300 and int(normalized.get("unlocked_stage", 0)) == 301, "Bounded metadata does not reduce endless unlock progress")

	var migration_path: String = SaveManager.storage_path
	_cleanup_save_files(migration_path)
	var old_version_file: FileAccess = FileAccess.open(migration_path, FileAccess.WRITE)
	if old_version_file != null:
		old_version_file.store_string(JSON.stringify({
			"save_version": 3,
			"unlocked_stage": 301,
			"highest_completed_stage": 300,
			"stage_scores": raw_scores,
			"stage_attempts": raw_attempts
		}))
		old_version_file = null
	var migrated_current: Dictionary = SaveManager.load_game()
	var persisted_current: Variant = JSON.parse_string(FileAccess.get_file_as_string(migration_path))
	_check(int(migrated_current.get("save_version", 0)) == SaveManager.SAVE_VERSION and persisted_current is Dictionary and int((persisted_current as Dictionary).get("save_version", 0)) == SaveManager.SAVE_VERSION, "Version 3 saves migrate and persist the bounded metadata schema")
	_cleanup_save_files(migration_path)

func _test_character_progression() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	_check(GameManager.get_inventory().size() == 1 and not GameManager.get_equipped_uid("weapon").is_empty(), "A new goblin starts with an equipped club")
	_check(GameManager.get_attack() > GameManager.get_base_attack(), "Equipped gear contributes to combat stats")

	GameManager.player_state["current_stage"] = 1
	var stage_one_result: Dictionary = GameManager.apply_victory(20, 10, {"highest_combo": 3, "correct_answers": 3, "total_answers": 3})
	_check(int(stage_one_result.get("stage_unlocked", 0)) == 2, "Victory unlocks the next stage")
	_check(GameManager.is_stage_completed(1), "Victory records completion through the high-water mark")
	_check(int(GameManager.player_state.get("highest_combo", 0)) == 3, "Battle records retain the best combo")
	_check(bool(stage_one_result.get("first_clear", false)) and int(stage_one_result.get("best_stars", 0)) == 3 and int(stage_one_result.get("accuracy", 0.0) * 100.0) == 100, "A clean first clear records a three-star score")
	_check(int(stage_one_result.get("gems", 0)) == 30 and GameManager.get_gems() == 330, "First clear awards 30 gems")
	var first_clear_exp: int = int(stage_one_result.get("exp", 0))
	GameManager.player_state["current_stage"] = 1
	var replay_result: Dictionary = GameManager.apply_victory(20, 10, {"highest_combo": 1, "correct_answers": 1, "mistakes": 3, "total_answers": 4})
	_check(not bool(replay_result.get("first_clear", true)) and int(replay_result.get("stars", 0)) == 1 and int(replay_result.get("exp", 0)) < first_clear_exp, "Replay keeps progress but uses a fair reduced reward")
	_check(int(replay_result.get("gems", 0)) == 0 and GameManager.get_gems() == 330, "Replay victories do not award additional gems")
	_check(GameManager.get_stage_stars(1) == 3 and int(GameManager.get_stage_score(1).get("clear_count", 0)) == 2, "Replay improves attempts without downgrading the best stage rating")

	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 2
	var locked_result: Dictionary = GameManager.apply_victory(25, 12)
	_check(bool(locked_result.get("invalid_stage", false)) and str(locked_result.get("reason", "")) == "stage_locked", "Locked stages cannot receive rewards through a stale battle state")

	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 10
	GameManager.player_state["unlocked_stage"] = 10
	GameManager.player_state["highest_completed_stage"] = 9
	var boss_result: Dictionary = GameManager.apply_victory(160, 50)
	_check(bool(boss_result.get("chapter_complete", false)), "Boss victory completes a chapter")
	_check(bool(boss_result.get("world_complete", false)), "Boss victory reports the completed chapter/world milestone")
	_check(GameManager.map_focus_stage == 10, "Boss victory prepares a one-time map focus on the completed boss")
	_check(int(boss_result.get("stage_unlocked", 0)) == 11 and GameManager.is_stage_unlocked(11), "Chapter 1 boss unlocks generated Stage 11")
	_check(not (boss_result.get("dropped_item", {}) as Dictionary).is_empty(), "Boss victory guarantees equipment")

	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 20
	GameManager.player_state["unlocked_stage"] = 20
	GameManager.player_state["highest_completed_stage"] = 19
	var endless_boss_result: Dictionary = GameManager.apply_victory(100, 30)
	_check(bool(endless_boss_result.get("chapter_complete", false)) and not bool(endless_boss_result.get("world_complete", false)), "Generated chapter bosses do not masquerade as World 1 completion")

	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["current_stage"] = 1
	var level_result: Dictionary = GameManager.apply_victory(GameManager.get_required_exp(), 0)
	_check(int(level_result.get("levels_gained", 0)) >= 1 and GameManager.get_level() >= 2, "Enough EXP levels the character")
	_check(GameManager.get_stat_points() >= 1, "Leveling awards a permanent stat point")
	var attack_before: int = GameManager.get_base_attack()
	var total_stat_points_before_spend: int = GameManager.get_total_stat_points()
	_check(GameManager.spend_stat_point("attack") and GameManager.get_base_attack() == attack_before + 1, "Stat points can permanently improve attack")
	_check(GameManager.get_total_stat_points() == total_stat_points_before_spend and GameManager.get_stat_points() == total_stat_points_before_spend - 1, "Spending a point keeps the total stat point count visible")
	var attack_breakdown: Dictionary = GameManager.get_stat_breakdown().get("attack", {})
	_check(int(attack_breakdown.get("total", 0)) == GameManager.get_attack() and int(attack_breakdown.get("allocated_points", 0)) == 1 and int(attack_breakdown.get("allocated_value", 0)) == 1, "Stat breakdown reports the allocated attack point and final total")

func _test_equipment_actions() -> void:
	GameManager.player_state = SaveManager.create_new_save()
	GameManager.player_state["coins"] = 10_000
	var level_one_rare: Dictionary = EquipmentSystem.create_instance("star_hammer", "formula_level_1", 1, 8)
	var level_three_rare: Dictionary = EquipmentSystem.create_instance("star_hammer", "formula_level_3", 3, 8)
	var level_one_stats: Dictionary = EquipmentSystem.get_item_stats(level_one_rare)
	var level_three_stats: Dictionary = EquipmentSystem.get_item_stats(level_three_rare)
	_check(int(level_three_stats.get("attack", 0)) > int(level_one_stats.get("attack", 0)), "Flat equipment stats increase with item level")
	_check(int(level_three_stats.get("max_hp", 0)) >= int(level_one_stats.get("max_hp", 0)), "Every populated flat stat follows the level multiplier without regression")
	var percent_level_one: Dictionary = EquipmentSystem.get_item_stats(EquipmentSystem.create_instance("crown_staff", "formula_percent_1", 1, 10))
	var percent_level_twenty: Dictionary = EquipmentSystem.get_item_stats(EquipmentSystem.create_instance("crown_staff", "formula_percent_20", 20, 10))
	_check(float(percent_level_twenty.get("exp_bonus", 0.0)) > float(percent_level_one.get("exp_bonus", 0.0)) and float(percent_level_twenty.get("exp_bonus", 0.0)) <= 0.75, "Percentage equipment bonuses scale by level and stay bounded")
	var duplicate_state: Dictionary = SaveManager.create_new_save()
	duplicate_state["equipped"] = {"weapon": "item_1", "head": "item_1", "body": ""}
	var duplicate_aggregate: Dictionary = EquipmentSystem.aggregate_equipped_stats(duplicate_state)
	var starter_stats: Dictionary = EquipmentSystem.get_item_stats(EquipmentSystem.starter_item())
	_check(int(duplicate_aggregate.get("attack", 0)) == int(starter_stats.get("attack", 0)), "The same equipped UID cannot double-count across slots")
	var inventory: Array = GameManager.get_inventory()
	var rare_item: Dictionary = EquipmentSystem.create_instance("star_hammer", "item_2", 1, 8)
	inventory.append(rare_item)
	GameManager.player_state["inventory"] = inventory
	GameManager.player_state["next_item_uid"] = 3
	var attack_before: int = GameManager.get_attack()
	_check(GameManager.equip_item("item_2") and GameManager.get_attack() > attack_before, "A weapon can be equipped and changes attack")
	var upgrade_cost_before: int = EquipmentSystem.upgrade_cost(rare_item)
	var upgrade_result: Dictionary = GameManager.upgrade_item("item_2")
	_check(bool(upgrade_result.get("success", false)) and int((upgrade_result.get("item", {}) as Dictionary).get("level", 0)) == 2 and int((upgrade_result.get("item", {}) as Dictionary).get("upgrade_coins_spent", 0)) == upgrade_cost_before, "Equipment strengthening records the paid coins")
	_check(not bool(GameManager.sell_item("item_2").get("success", false)), "Equipped gear cannot be sold accidentally")
	_check(GameManager.unequip_slot("weapon"), "Equipment can be removed")
	_check(bool(GameManager.sell_item("item_2").get("success", false)), "Unequipped gear can be sold")
	var guaranteed_drop: Dictionary = EquipmentSystem.roll_drop(20, 0, 1, 0, true)
	_check(not guaranteed_drop.is_empty() and guaranteed_drop == EquipmentSystem.roll_drop(20, 0, 1, 0, true), "Drop generation is deterministic and boss-safe")

func _test_gacha_system() -> void:
	_check(GachaSystem.get_available_rarities(0) == ["common"], "Fresh players only see the common gacha pool")
	_check(GachaSystem.get_available_rarities(4).has("uncommon") and not GachaSystem.get_available_rarities(4).has("rare"), "Stage progress unlocks uncommon without skipping ahead")
	_check(GachaSystem.get_available_rarities(10) == ["common", "uncommon", "rare", "epic"], "Stage 10 unlocks the direct Epic pool but not Legendary")

	var fresh_state: Dictionary = SaveManager.create_new_save()
	var one_pull: Dictionary = GachaSystem.roll(fresh_state, 1, 1001)
	_check(bool(one_pull.get("success", false)) and int(one_pull.get("cost", 0)) == 100 and (one_pull.get("items", []) as Array).size() == 1, "Single pull costs 100 gems and returns one item")
	var ten_state: Dictionary = SaveManager.create_new_save()
	ten_state["gems"] = 1000
	ten_state["highest_completed_stage"] = 10
	var ten_pull: Dictionary = GachaSystem.roll(ten_state, 10, 1002)
	var ten_items: Array = ten_pull.get("items", [])
	var has_uncommon_plus: bool = false
	for item: Dictionary in ten_items:
		if ["uncommon", "rare", "epic"].has(str(item.get("rarity", ""))):
			has_uncommon_plus = true
	_check(bool(ten_pull.get("success", false)) and int(ten_pull.get("cost", 0)) == 1000 and ten_items.size() == 10 and has_uncommon_plus, "Ten pull costs 1000 gems and guarantees an available higher rarity")
	var no_gems_state: Dictionary = SaveManager.create_new_save()
	no_gems_state["gems"] = 99
	_check(not bool(GachaSystem.roll(no_gems_state, 1, 1003).get("success", false)), "Insufficient gems reject a pull without changing state")

	GameManager.player_state = SaveManager.create_new_save()
	var merge_inventory: Array = GameManager.get_inventory()
	merge_inventory.append(EquipmentSystem.create_instance("twig_club", "item_2", 1, 1))
	merge_inventory.append(EquipmentSystem.create_instance("twig_club", "item_3", 2, 1, EquipmentSystem.upgrade_coins_spent_for_level(2, "common")))
	merge_inventory.append(EquipmentSystem.create_instance("twig_club", "item_4", 3, 1, EquipmentSystem.upgrade_coins_spent_for_level(3, "common")))
	GameManager.player_state["inventory"] = merge_inventory
	GameManager.player_state["next_item_uid"] = 5
	var coins_before_merge: int = GameManager.get_coins()
	var expected_refund: int = EquipmentSystem.upgrade_coins_spent_for_level(2, "common") + EquipmentSystem.upgrade_coins_spent_for_level(3, "common")
	var merge_result: Dictionary = GameManager.merge_equipment(["item_2", "item_3", "item_4"])
	var merged_item: Dictionary = merge_result.get("item", {})
	_check(bool(merge_result.get("success", false)) and str(merged_item.get("template_id", "")) == "peach_wand" and int(merged_item.get("level", 0)) == 1 and int(merged_item.get("upgrade_coins_spent", -1)) == 0, "Same-template materials at different levels merge into a fresh next-tier Lv.1 item")
	_check(int(merge_result.get("refund_coins", 0)) == expected_refund and GameManager.get_coins() == coins_before_merge + expected_refund, "Merging refunds all recorded strengthening coins")

	GameManager.player_state = SaveManager.create_new_save()
	var equipped_merge_inventory: Array = [
		EquipmentSystem.create_instance("leaf_cap", "equipped_merge_1", 1, 1),
		EquipmentSystem.create_instance("leaf_cap", "equipped_merge_2", 1, 1),
		EquipmentSystem.create_instance("leaf_cap", "equipped_merge_3", 1, 1)
	]
	GameManager.player_state["inventory"] = equipped_merge_inventory
	GameManager.player_state["equipped"] = {"weapon": "", "head": "equipped_merge_1", "body": ""}
	GameManager.player_state["next_item_uid"] = 1
	var equipped_merge_validation: Dictionary = GachaSystem.validate_merge(equipped_merge_inventory, GameManager.player_state)
	_check(bool(equipped_merge_validation.get("success", false)), "Equipped equipment is accepted as a merge material")
	var equipped_merge_result: Dictionary = GameManager.merge_equipment(["equipped_merge_1", "equipped_merge_2", "equipped_merge_3"])
	var equipped_merge_item: Dictionary = equipped_merge_result.get("item", {})
	_check(bool(equipped_merge_result.get("success", false)) and str(GameManager.get_equipped_uid("head")) == str(equipped_merge_item.get("uid", "")), "Manual merge replaces a consumed equipped slot with the new item")

	GameManager.player_state = SaveManager.create_new_save()
	var chain_inventory: Array = GameManager.get_inventory()
	for index: int in range(2, 10):
		var chain_level: int = 2 if index == 2 else (3 if index == 3 else 1)
		var chain_spent: int = EquipmentSystem.upgrade_coins_spent_for_level(chain_level, "common")
		chain_inventory.append(EquipmentSystem.create_instance("twig_club", "chain_%d" % index, chain_level, 1, chain_spent))
	chain_inventory[0]["uid"] = "chain_1"
	GameManager.player_state["inventory"] = chain_inventory
	GameManager.player_state["equipped"] = {"weapon": "chain_1", "head": "", "body": ""}
	GameManager.player_state["next_item_uid"] = 1
	var chain_coins_before: int = GameManager.get_coins()
	var chain_plan: Dictionary = GameManager.preview_auto_merge()
	_check(bool(chain_plan.get("has_plan", false)) and int(chain_plan.get("merge_count", 0)) == 4 and int(chain_plan.get("consumed_count", 0)) == 9, "Auto merge plans a complete three-to-one chain and consumes only original materials")
	_check(str((chain_plan.get("equipped_replacements", {}) as Dictionary).get("weapon", "")).begins_with("__auto_output_"), "Auto merge carries equipped status through intermediate outputs")
	var chain_expected_refund: int = EquipmentSystem.upgrade_coins_spent_for_level(2, "common") + EquipmentSystem.upgrade_coins_spent_for_level(3, "common")
	var chain_result: Dictionary = GameManager.auto_merge_equipment()
	var chain_output: Dictionary = {}
	for raw_item: Variant in GameManager.get_inventory():
		if raw_item is Dictionary and str(raw_item.get("template_id", "")) == "star_hammer":
			chain_output = raw_item
	_check(bool(chain_result.get("success", false)) and not chain_output.is_empty() and GameManager.get_inventory().size() == 1, "Auto merge stores the final chained equipment and removes intermediate materials")
	_check(str(GameManager.get_equipped_uid("weapon")) == str(chain_output.get("uid", "")) and int(chain_result.get("refund_coins", 0)) == chain_expected_refund and GameManager.get_coins() == chain_coins_before + chain_expected_refund, "Auto merge equips the final result and refunds original strengthening coins once")
	GameManager.player_state = SaveManager.create_new_save()
	var no_merge_snapshot: Dictionary = GameManager.player_state.duplicate(true)
	var no_merge_plan: Dictionary = GameManager.preview_auto_merge()
	var no_merge_result: Dictionary = GameManager.auto_merge_equipment()
	_check(not bool(no_merge_plan.get("has_plan", false)) and not bool(no_merge_result.get("success", false)) and GameManager.player_state == no_merge_snapshot, "Auto merge with insufficient materials leaves state untouched")

	GameManager.player_state = SaveManager.create_new_save()
	var legendary_inventory: Array = GameManager.get_inventory()
	for index: int in range(3):
		legendary_inventory.append(EquipmentSystem.create_instance("crown_staff", "item_%d" % (index + 2), 1, 10))
	GameManager.player_state["inventory"] = legendary_inventory
	GameManager.player_state["next_item_uid"] = 5
	var legendary_result: Dictionary = GameManager.merge_equipment(["item_2", "item_3", "item_4"])
	_check(bool(legendary_result.get("success", false)) and str((legendary_result.get("item", {}) as Dictionary).get("template_id", "")) == "rainbow_star_staff", "Three Epic items merge into Legendary")

	var invalid_items: Array = [
		EquipmentSystem.create_instance("twig_club", "item_5", 2, 1),
		EquipmentSystem.create_instance("leaf_cap", "item_6", 1, 1),
		EquipmentSystem.create_instance("twig_club", "item_7", 1, 1)
	]
	var invalid_state: Dictionary = SaveManager.create_new_save()
	invalid_state["inventory"] = invalid_items
	_check(str(GachaSystem.validate_merge(invalid_items, invalid_state).get("reason", "")) == "templates_must_match", "Different equipment templates cannot be merged")

	var large_inventory: Array = []
	for index: int in range(130):
		large_inventory.append(EquipmentSystem.create_instance("twig_club", "large_%d" % index, 1, 1))
	var normalized_large: Dictionary = SaveManager._normalize_save({"inventory": large_inventory})
	_check((normalized_large.get("inventory", []) as Array).size() == 130, "Inventory normalization no longer truncates at 120 items")

func _test_project_settings() -> void:
	var features: PackedStringArray = ProjectSettings.get_setting("application/config/features", PackedStringArray())
	_check(str(ProjectSettings.get_setting("application/config/name", "")) == "哥布林升級中", "Project display name matches the game identity")
	_check(ResourceLoader.exists(UITheme.BODY_FONT_PATH) and ResourceLoader.exists(UITheme.BOLD_FONT_PATH), "Rounded Traditional Chinese font weights are bundled for cross-platform UI")
	_check(UITheme.shared_font(UITheme.FontRole.BODY) != null and UITheme.shared_font(UITheme.FontRole.BOLD) != null, "Rounded Traditional Chinese font weights load as Godot Font resources")
	var safe_area_probe: Control = Control.new()
	get_tree().root.add_child(safe_area_probe)
	var safe_insets: Vector4 = UITheme.safe_area_insets(safe_area_probe)
	_check(safe_insets.x >= 0.0 and safe_insets.y >= 0.0 and safe_insets.z >= 0.0 and safe_insets.w >= 0.0, "Safe-area calculation remains available in headless mode")
	safe_area_probe.queue_free()
	_check(features.has("4.6"), "Project targets the specified Godot 4.6 feature set")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1080, "Logical portrait width remains 1080")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 1920, "Logical portrait height remains 1920")
	_check(int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)) == 405, "Small portrait preview width remains 405")
	_check(int(ProjectSettings.get_setting("display/window/size/window_height_override", 0)) == 720, "Small portrait preview height remains 720")
	var export_config: ConfigFile = ConfigFile.new()
	_check(export_config.load("res://export_presets.cfg") == OK, "Export presets are parseable")
	_check(str(export_config.get_value("preset.0", "name", "")) == "Web QA" and str(export_config.get_value("preset.0", "platform", "")) == "Web", "Web QA export preset is configured")
	_check(str(export_config.get_value("preset.1", "name", "")) == "iOS Xcode" and str(export_config.get_value("preset.1", "platform", "")) == "iOS", "iOS Xcode export preset is configured")

func _cleanup_save_files(base_path: String) -> void:
	for path: String in [base_path, base_path + ".bak", base_path + ".tmp", base_path + ".recover.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)
