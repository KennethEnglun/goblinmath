extends Node

## Owns progression, character stats, inventory actions, rewards, and navigation.
signal player_state_changed(state: Dictionary)
signal stage_unlocked(stage_id: int)
signal battle_completed(result: Dictionary)
signal equipment_changed()
signal scene_transition_completed(scene_path: String)

const MAIN_MENU_SCENE: String = "res://scenes/main/main_menu.tscn"
const WORLD_MAP_SCENE: String = "res://scenes/map/world_map.tscn"
const BATTLE_SCENE: String = "res://scenes/battle/battle.tscn"
const CHARACTER_SCENE: String = "res://scenes/character/character.tscn"
const GACHA_SCENE: String = "res://scenes/gacha/gacha.tscn"
const SCENE_FADE_DURATION: float = 0.08

var player_state: Dictionary = {}
var transition_layer: CanvasLayer
var transition_overlay: ColorRect
var transition_busy: bool = false
# A one-use navigation hint for the map. It is intentionally transient rather
# than persisted: after a boss clear the player sees the milestone once, while
# a later fresh map entry still follows the highest-unlocked-stage rule.
var map_focus_stage: int = 0

func _ready() -> void:
	player_state = SaveManager.load_game()
	_emit_state_changed()

func _notification(what: int) -> void:
	# Mobile platforms may suspend the process without giving the current scene
	# another chance to save. Persist the latest normalized state as soon as the
	# app loses focus or the window receives a close request.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not player_state.is_empty():
			SaveManager.save_game(player_state)

func _ensure_transition_layer() -> void:
	if transition_layer != null and is_instance_valid(transition_layer):
		return
	transition_layer = CanvasLayer.new()
	transition_layer.name = "SceneTransitionLayer"
	transition_layer.layer = 100
	add_child(transition_layer)
	transition_overlay = ColorRect.new()
	transition_overlay.name = "SceneTransitionOverlay"
	transition_overlay.color = Color("#5c2d2d")
	transition_overlay.modulate.a = 0.0
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_layer.add_child(transition_overlay)

func start_stage(stage_id: int) -> bool:
	if transition_busy:
		return false
	var stage: Dictionary = DataManager.get_stage(stage_id)
	if stage.is_empty():
		push_warning("Cannot start missing stage: %d" % stage_id)
		return false
	if not is_stage_unlocked(stage_id):
		push_warning("Stage is locked: %d" % stage_id)
		return false
	map_focus_stage = 0
	player_state["current_stage"] = stage_id
	var attempts: Dictionary = player_state.get("stage_attempts", {}).duplicate() if player_state.get("stage_attempts", {}) is Dictionary else {}
	var attempt_key: String = str(stage_id)
	attempts[attempt_key] = int(attempts.get(attempt_key, 0)) + 1
	player_state["stage_attempts"] = attempts
	_save_and_emit()
	_change_scene(BATTLE_SCENE)
	return true

func go_to_world_map() -> void:
	_change_scene(WORLD_MAP_SCENE)

func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)

func go_to_character() -> void:
	_change_scene(CHARACTER_SCENE)

func go_to_gacha() -> void:
	_change_scene(GACHA_SCENE)

func is_stage_unlocked(stage_id: int) -> bool:
	return stage_id >= 1 and stage_id <= int(player_state.get("unlocked_stage", 1)) and not DataManager.get_stage(stage_id).is_empty()

func is_stage_completed(stage_id: int) -> bool:
	if stage_id < 1 or DataManager.get_stage(stage_id).is_empty():
		return false
	if stage_id <= int(player_state.get("highest_completed_stage", 0)):
		return true
	var completed: Variant = player_state.get("completed_stages", [])
	return completed is Array and completed.has(stage_id)

func get_level() -> int:
	return int(player_state.get("level", GameBalance.BASE_LEVEL))

func get_exp() -> int:
	return int(player_state.get("exp", GameBalance.BASE_EXP))

func get_coins() -> int:
	return int(player_state.get("coins", GameBalance.BASE_COINS))

func get_gems() -> int:
	return maxi(0, int(player_state.get("gems", GameBalance.BASE_GEMS)))

func get_stat_points() -> int:
	return int(player_state.get("stat_points", 0))

func get_required_exp() -> int:
	return GameBalance.required_exp(get_level())

func get_base_attack() -> int:
	return int(player_state.get("base_attack", GameBalance.BASE_ATTACK))

func get_equipped_stats() -> Dictionary:
	return EquipmentSystem.aggregate_equipped_stats(player_state)

func get_attack() -> int:
	return maxi(1, get_base_attack() + int(get_equipped_stats().get("attack", 0)))

func get_max_hp() -> int:
	return maxi(1, int(player_state.get("base_max_hp", GameBalance.BASE_MAX_HP)) + int(get_equipped_stats().get("max_hp", 0)))

func get_defense() -> int:
	return maxi(0, int(player_state.get("base_defense", GameBalance.BASE_DEFENSE)) + int(get_equipped_stats().get("defense", 0)))

func get_luck() -> int:
	return maxi(0, int(player_state.get("base_luck", GameBalance.BASE_LUCK)) + int(get_equipped_stats().get("luck", 0)))

func get_exp_bonus() -> float:
	return clampf(float(get_equipped_stats().get("exp_bonus", 0.0)), 0.0, 1.5)

func get_coin_bonus() -> float:
	return clampf(float(get_equipped_stats().get("coin_bonus", 0.0)), 0.0, 1.5)

func add_gems(amount: int, _reason: String = "") -> bool:
	if amount <= 0:
		return false
	player_state["gems"] = get_gems() + amount
	_save_and_emit()
	return true

func spend_gems(amount: int) -> bool:
	if amount <= 0 or get_gems() < amount:
		return false
	player_state["gems"] = get_gems() - amount
	_save_and_emit()
	return true

func get_stage_score(stage_id: int) -> Dictionary:
	if stage_id < GameBalance.STARTING_STAGE or DataManager.get_stage(stage_id).is_empty():
		return {}
	var scores: Variant = player_state.get("stage_scores", {})
	if not scores is Dictionary:
		return {}
	var raw_score: Variant = scores.get(str(stage_id), scores.get(stage_id, {}))
	return raw_score.duplicate(true) if raw_score is Dictionary else {}

func get_stage_stars(stage_id: int) -> int:
	var score: Dictionary = get_stage_score(stage_id)
	return clampi(int(score.get("best_stars", score.get("stars", 0))), 0, GameBalance.MAX_STAGE_STARS)

func get_total_stars() -> int:
	var scores: Variant = player_state.get("stage_scores", {})
	if not scores is Dictionary:
		return 0
	var total: int = 0
	for raw_score: Variant in scores.values():
		if raw_score is Dictionary:
			total += clampi(int(raw_score.get("best_stars", 0)), 0, GameBalance.MAX_STAGE_STARS)
	return total

func get_player_hearts() -> int:
	# HP remains numeric and uncapped; only the compact HUD representation is
	# bounded so a malformed or extremely advanced save cannot allocate an
	# enormous repeated-heart string.
	return clampi(int(ceil(float(get_max_hp()) / 10.0)), GameBalance.BASE_HEARTS, GameBalance.MAX_DISPLAY_HEARTS)

func calculate_damage(combo: int) -> int:
	return GameBalance.calculate_damage(get_attack(), combo)

func calculate_incoming_damage(monster_attack: int) -> int:
	return GameBalance.damage_taken(monster_attack, get_defense())

func apply_victory(exp_reward: int, coin_reward: int, battle_meta: Dictionary = {}) -> Dictionary:
	var old_level: int = get_level()
	var current_stage: int = int(player_state.get("current_stage", GameBalance.STARTING_STAGE))
	if DataManager.get_stage(current_stage).is_empty():
		push_warning("Cannot apply victory to an invalid stage: %d" % current_stage)
		return {"invalid_stage": true}
	if not is_stage_unlocked(current_stage):
		push_warning("Cannot apply victory to a locked stage: %d" % current_stage)
		return {"invalid_stage": true, "reason": "stage_locked"}

	var first_clear: bool = not is_stage_completed(current_stage)
	var mistakes: int = maxi(0, int(battle_meta.get("mistakes", 0)))
	var correct_answers: int = maxi(0, int(battle_meta.get("correct_answers", 0)))
	var total_answers: int = maxi(correct_answers + mistakes, int(battle_meta.get("total_answers", 0)))
	var accuracy: float = 1.0 if total_answers <= 0 else clampf(float(correct_answers) / float(total_answers), 0.0, 1.0)
	var stars: int = GameBalance.stage_stars(mistakes)
	var score: Dictionary = _record_stage_score(current_stage, stars, accuracy, mistakes, int(battle_meta.get("highest_combo", 0)))

	var previous_highest: int = int(player_state.get("highest_completed_stage", 0))
	player_state["highest_completed_stage"] = maxi(previous_highest, current_stage)
	var completed: Array = player_state.get("completed_stages", []).duplicate() if player_state.get("completed_stages", []) is Array else []
	if not completed.has(current_stage):
		completed.append(current_stage)
		completed.sort()
	if completed.size() > 100:
		completed = completed.slice(completed.size() - 100)
	player_state["completed_stages"] = completed

	var next_stage: int = DataManager.get_next_stage_id(current_stage)
	var old_unlock: int = int(player_state.get("unlocked_stage", 1))
	var newly_unlocked_stage: int = -1
	if first_clear and next_stage > old_unlock and current_stage >= old_unlock:
		player_state["unlocked_stage"] = next_stage
		newly_unlocked_stage = next_stage

	var reward_multiplier: float = GameBalance.reward_multiplier_for_clear(first_clear)
	var scaled_exp: int = maxi(0, int(round(float(maxi(0, exp_reward)) * reward_multiplier)))
	var scaled_coins: int = maxi(0, int(round(float(maxi(0, coin_reward)) * reward_multiplier)))
	var awarded_exp: int = maxi(0, int(round(float(scaled_exp) * (1.0 + get_exp_bonus()))))
	var awarded_coins: int = maxi(0, int(round(float(scaled_coins) * (1.0 + get_coin_bonus()))))
	var gacha_config: Dictionary = DataManager.get_gacha_config()
	var first_clear_gem_reward: int = maxi(0, int(gacha_config.get("first_clear_reward", GameBalance.FIRST_CLEAR_GEM_REWARD)))
	var awarded_gems: int = first_clear_gem_reward if first_clear else 0
	player_state["exp"] = maxi(0, get_exp() + awarded_exp)
	player_state["coins"] = maxi(0, get_coins() + awarded_coins)
	player_state["gems"] = get_gems() + awarded_gems
	player_state["total_victories"] = int(player_state.get("total_victories", 0)) + 1
	player_state["highest_combo"] = maxi(int(player_state.get("highest_combo", 0)), int(battle_meta.get("highest_combo", 0)))
	player_state["total_questions"] = int(player_state.get("total_questions", 0)) + total_answers
	player_state["total_correct_answers"] = int(player_state.get("total_correct_answers", 0)) + correct_answers
	player_state["total_mistakes"] = int(player_state.get("total_mistakes", 0)) + mistakes

	var levels_gained: int = _apply_level_ups()
	var drop_result: Dictionary = _roll_and_store_drop(current_stage)
	var chapter_complete: bool = GameBalance.is_boss_stage(current_stage) and first_clear and current_stage > previous_highest
	# Only the authored World 1 boss completes the named starting world. Later
	# tenth-stage bosses complete their generated chapter, but must not reuse the
	# World 1 copy in the result panel.
	var world_complete: bool = current_stage == GameBalance.STAGES_PER_CHAPTER and chapter_complete
	if chapter_complete:
		map_focus_stage = current_stage

	_save_and_emit()
	if newly_unlocked_stage > 0:
		stage_unlocked.emit(newly_unlocked_stage)
	var result: Dictionary = {
		"exp": awarded_exp,
		"base_exp": maxi(0, exp_reward),
		"coins": awarded_coins,
		"base_coins": maxi(0, coin_reward),
		"gems": awarded_gems,
		"total_gems": get_gems(),
		"first_clear": first_clear,
		"reward_multiplier": reward_multiplier,
		"stars": stars,
		"best_stars": int(score.get("best_stars", stars)),
		"accuracy": accuracy,
		"mistakes": mistakes,
		"clear_count": int(score.get("clear_count", 1)),
		"old_level": old_level,
		"new_level": get_level(),
		"levels_gained": levels_gained,
		"stage_unlocked": newly_unlocked_stage,
		"chapter_complete": chapter_complete,
		"world_complete": world_complete,
		"dropped_item": drop_result.get("item", {}),
		"auto_salvage_coins": int(drop_result.get("auto_salvage_coins", 0))
	}
	battle_completed.emit(result.duplicate(true))
	return result

func apply_defeat(battle_meta: Dictionary = {}) -> void:
	player_state["total_defeats"] = int(player_state.get("total_defeats", 0)) + 1
	player_state["highest_combo"] = maxi(int(player_state.get("highest_combo", 0)), int(battle_meta.get("highest_combo", 0)))
	var mistakes: int = maxi(0, int(battle_meta.get("mistakes", 0)))
	var correct_answers: int = maxi(0, int(battle_meta.get("correct_answers", 0)))
	var total_answers: int = maxi(correct_answers + mistakes, int(battle_meta.get("total_answers", 0)))
	player_state["total_questions"] = int(player_state.get("total_questions", 0)) + total_answers
	player_state["total_correct_answers"] = int(player_state.get("total_correct_answers", 0)) + correct_answers
	player_state["total_mistakes"] = int(player_state.get("total_mistakes", 0)) + mistakes
	_save_and_emit()
	battle_completed.emit({"defeated": true})

func pull_gacha(count: int) -> Dictionary:
	var roll: Dictionary = GachaSystem.roll(player_state, count)
	if not bool(roll.get("success", false)):
		return roll
	var rolled_items: Variant = roll.get("items", [])
	if not rolled_items is Array or rolled_items.is_empty():
		return {"success": false, "reason": "empty_gacha_result"}
	var inventory: Array = get_inventory()
	var created_items: Array = []
	var next_uid: int = maxi(1, int(player_state.get("next_item_uid", 1)))
	for raw_item: Variant in rolled_items:
		if not raw_item is Dictionary:
			return {"success": false, "reason": "invalid_gacha_item"}
		var item_data: Dictionary = raw_item
		var item: Dictionary = EquipmentSystem.create_instance(
			str(item_data.get("template_id", "")),
			"item_%d" % next_uid,
			1,
			int(item_data.get("acquired_stage", get_current_progress_stage()))
		)
		if item.is_empty():
			return {"success": false, "reason": "invalid_gacha_template"}
		inventory.append(item)
		created_items.append(item.duplicate(true))
		next_uid += 1
	player_state["gems"] = get_gems() - int(roll.get("cost", 0))
	player_state["next_item_uid"] = next_uid
	player_state["inventory"] = inventory
	_save_and_emit()
	equipment_changed.emit()
	roll["items"] = created_items
	roll["gems"] = get_gems()
	return roll

func merge_equipment(item_uids: Array[String]) -> Dictionary:
	var inventory: Array = get_inventory()
	var selected_items: Array = []
	for uid: String in item_uids:
		var item: Dictionary = EquipmentSystem.find_item(inventory, uid)
		if item.is_empty():
			return {"success": false, "reason": "missing_item"}
		selected_items.append(item)
	var validation: Dictionary = GachaSystem.validate_merge(selected_items, player_state)
	if not bool(validation.get("success", false)):
		return validation
	var target_id: String = str(validation.get("target_id", ""))
	var target_item: Dictionary = EquipmentSystem.create_instance(
		target_id,
		"item_%d" % maxi(1, int(player_state.get("next_item_uid", 1))),
		1,
		get_current_progress_stage()
	)
	if target_item.is_empty():
		return {"success": false, "reason": "invalid_merge_target"}
	var remove_indices: Array[int] = []
	for uid: String in item_uids:
		remove_indices.append(EquipmentSystem.find_item_index(inventory, uid))
	remove_indices.sort()
	remove_indices.reverse()
	for index: int in remove_indices:
		inventory.remove_at(index)
	inventory.append(target_item)
	player_state["inventory"] = inventory
	player_state["next_item_uid"] = int(player_state.get("next_item_uid", 1)) + 1
	_save_and_emit()
	equipment_changed.emit()
	return {
		"success": true,
		"consumed_uids": item_uids.duplicate(),
		"target_id": target_id,
		"item": target_item.duplicate(true)
	}

func get_current_progress_stage() -> int:
	return maxi(1, int(player_state.get("highest_completed_stage", 0)))

func spend_stat_point(stat: String) -> bool:
	if get_stat_points() <= 0:
		return false
	match stat:
		"attack":
			player_state["base_attack"] = get_base_attack() + 1
		"max_hp":
			player_state["base_max_hp"] = int(player_state.get("base_max_hp", GameBalance.BASE_MAX_HP)) + 3
		"defense":
			player_state["base_defense"] = int(player_state.get("base_defense", GameBalance.BASE_DEFENSE)) + 1
		"luck":
			player_state["base_luck"] = int(player_state.get("base_luck", GameBalance.BASE_LUCK)) + 1
		_:
			return false
	player_state["stat_points"] = get_stat_points() - 1
	_save_and_emit()
	return true

func get_inventory() -> Array:
	var inventory: Variant = player_state.get("inventory", [])
	return inventory.duplicate(true) if inventory is Array else []

func get_equipped_uid(slot: String) -> String:
	var equipped: Variant = player_state.get("equipped", {})
	if not equipped is Dictionary:
		return ""
	return str(equipped.get(slot, ""))

func equip_item(uid: String) -> bool:
	var inventory: Array = get_inventory()
	var item: Dictionary = EquipmentSystem.find_item(inventory, uid)
	var template: Dictionary = EquipmentSystem.get_item_template(item)
	var slot: String = str(template.get("slot", ""))
	if item.is_empty() or not EquipmentSystem.SLOTS.has(slot):
		return false
	var equipped: Dictionary = player_state.get("equipped", {}).duplicate() if player_state.get("equipped", {}) is Dictionary else {}
	# A malformed legacy save may reference the same item in multiple slots. Clear
	# any stale duplicate before applying the new slot assignment.
	for other_slot: String in EquipmentSystem.SLOTS:
		if other_slot != slot and str(equipped.get(other_slot, "")) == uid:
			equipped[other_slot] = ""
	equipped[slot] = uid
	player_state["equipped"] = equipped
	_save_and_emit()
	equipment_changed.emit()
	return true

func unequip_slot(slot: String) -> bool:
	if not EquipmentSystem.SLOTS.has(slot):
		return false
	var equipped: Dictionary = player_state.get("equipped", {}).duplicate() if player_state.get("equipped", {}) is Dictionary else {}
	if str(equipped.get(slot, "")).is_empty():
		return false
	equipped[slot] = ""
	player_state["equipped"] = equipped
	_save_and_emit()
	equipment_changed.emit()
	return true

func upgrade_item(uid: String) -> Dictionary:
	var inventory: Array = get_inventory()
	var index: int = EquipmentSystem.find_item_index(inventory, uid)
	if index < 0:
		return {"success": false, "reason": "missing_item"}
	var item: Dictionary = inventory[index].duplicate(true)
	var cost: int = EquipmentSystem.upgrade_cost(item)
	if cost <= 0 or get_coins() < cost:
		return {"success": false, "reason": "not_enough_coins", "cost": cost}
	player_state["coins"] = get_coins() - cost
	item["level"] = int(item.get("level", 1)) + 1
	inventory[index] = item
	player_state["inventory"] = inventory
	_save_and_emit()
	equipment_changed.emit()
	return {"success": true, "cost": cost, "item": item.duplicate(true)}

func sell_item(uid: String) -> Dictionary:
	var inventory: Array = get_inventory()
	var index: int = EquipmentSystem.find_item_index(inventory, uid)
	if index < 0:
		return {"success": false, "reason": "missing_item"}
	if EquipmentSystem.is_equipped(player_state, uid):
		return {"success": false, "reason": "equipped"}
	var item: Dictionary = inventory[index]
	var value: int = EquipmentSystem.sell_value(item)
	inventory.remove_at(index)
	player_state["inventory"] = inventory
	player_state["coins"] = get_coins() + value
	_save_and_emit()
	equipment_changed.emit()
	return {"success": true, "coins": value}

func reset_progress() -> void:
	map_focus_stage = 0
	player_state = SaveManager.reset_save()
	_emit_state_changed()
	equipment_changed.emit()

func commit_state() -> bool:
	return _save_and_emit()

func _apply_level_ups() -> int:
	var levels_gained: int = 0
	while get_exp() >= get_required_exp():
		var required: int = get_required_exp()
		player_state["exp"] = get_exp() - required
		player_state["level"] = get_level() + 1
		player_state["base_attack"] = get_base_attack() + GameBalance.LEVEL_ATTACK_GAIN
		player_state["base_max_hp"] = int(player_state.get("base_max_hp", GameBalance.BASE_MAX_HP)) + GameBalance.LEVEL_HP_GAIN
		player_state["stat_points"] = get_stat_points() + GameBalance.LEVEL_STAT_POINT_GAIN
		levels_gained += 1
		if levels_gained >= 10_000:
			push_warning("Stopped an excessive level-up loop from an invalid save value.")
			break
	return levels_gained

func _roll_and_store_drop(stage_id: int) -> Dictionary:
	var pity: int = int(player_state.get("loot_pity", 0))
	var guaranteed: bool = GameBalance.is_boss_stage(stage_id) or pity >= 4
	var drop: Dictionary = EquipmentSystem.roll_drop(
		stage_id,
		get_luck(),
		int(player_state.get("total_victories", 0)),
		pity,
		guaranteed
	)
	if drop.is_empty():
		player_state["loot_pity"] = mini(4, pity + 1)
		return {}
	player_state["loot_pity"] = 0
	var uid_number: int = maxi(1, int(player_state.get("next_item_uid", 1)))
	var item: Dictionary = EquipmentSystem.create_instance(
		str(drop.get("template_id", "")),
		"item_%d" % uid_number,
		int(drop.get("level", 1)),
		int(drop.get("acquired_stage", stage_id))
	)
	if item.is_empty():
		return {}
	player_state["next_item_uid"] = uid_number + 1
	var inventory: Array = get_inventory()
	inventory.append(item)
	player_state["inventory"] = inventory
	equipment_changed.emit()
	return {"item": item.duplicate(true)}

func _record_stage_score(stage_id: int, stars: int, accuracy: float, mistakes: int, best_combo: int) -> Dictionary:
	var scores: Dictionary = player_state.get("stage_scores", {}).duplicate(true) if player_state.get("stage_scores", {}) is Dictionary else {}
	var key: String = str(stage_id)
	var previous: Variant = scores.get(key, {})
	var old_score: Dictionary = previous.duplicate(true) if previous is Dictionary else {}
	var score: Dictionary = {
		"best_stars": maxi(clampi(int(old_score.get("best_stars", 0)), 0, GameBalance.MAX_STAGE_STARS), clampi(stars, 1, GameBalance.MAX_STAGE_STARS)),
		"best_accuracy": maxf(clampf(float(old_score.get("best_accuracy", 0.0)), 0.0, 1.0), clampf(accuracy, 0.0, 1.0)),
		"best_combo": maxi(maxi(0, int(old_score.get("best_combo", 0))), maxi(0, best_combo)),
		"clear_count": maxi(0, int(old_score.get("clear_count", 0))) + 1,
		"last_stars": clampi(stars, 1, GameBalance.MAX_STAGE_STARS),
		"last_accuracy": clampf(accuracy, 0.0, 1.0),
		"last_mistakes": maxi(0, mistakes)
	}
	scores[key] = score
	player_state["stage_scores"] = scores
	return score

func _save_and_emit() -> bool:
	var saved: bool = SaveManager.save_game(player_state)
	player_state = SaveManager._normalize_save(player_state)
	_emit_state_changed()
	return saved

func _emit_state_changed() -> void:
	player_state_changed.emit(player_state.duplicate(true))

func _change_scene(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("Cannot navigate to missing scene: %s" % scene_path)
		return
	if transition_busy:
		return
	transition_busy = true
	_ensure_transition_layer()
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_out: Tween = create_tween()
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(transition_overlay, "modulate:a", 1.0, SCENE_FADE_DURATION)
	await fade_out.finished
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Scene transition failed (%s): %s" % [error_string(error), scene_path])
	await get_tree().process_frame
	var fade_in: Tween = create_tween()
	fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_in.tween_property(transition_overlay, "modulate:a", 0.0, SCENE_FADE_DURATION)
	await fade_in.finished
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_busy = false
	scene_transition_completed.emit(scene_path)
