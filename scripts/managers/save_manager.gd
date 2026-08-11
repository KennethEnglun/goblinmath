extends Node

## Versioned local persistence with migration, normalization, and a backup file.
const SAVE_VERSION: int = 5
const SAVE_PATH: String = "user://save.json"

var current_data: Dictionary = {}
var storage_path: String = SAVE_PATH

func _ready() -> void:
	current_data = load_game()

func create_new_save() -> Dictionary:
	var starter: Dictionary = EquipmentSystem.starter_item()
	return {
		"save_version": SAVE_VERSION,
		"level": GameBalance.BASE_LEVEL,
		"exp": GameBalance.BASE_EXP,
		"coins": GameBalance.BASE_COINS,
		"gems": GameBalance.BASE_GEMS,
		"stat_points": 0,
		"base_attack": GameBalance.BASE_ATTACK,
		"base_max_hp": GameBalance.BASE_MAX_HP,
		"base_defense": GameBalance.BASE_DEFENSE,
		"base_luck": GameBalance.BASE_LUCK,
		"current_stage": GameBalance.STARTING_STAGE,
		"unlocked_stage": GameBalance.STARTING_STAGE,
		"highest_completed_stage": 0,
		"completed_stages": [],
		"stage_scores": {},
		"stage_attempts": {},
		"inventory": [starter] if not starter.is_empty() else [],
		"equipped": {"weapon": str(starter.get("uid", "")), "head": "", "body": ""},
		"next_item_uid": 2,
		"loot_pity": 0,
		"total_victories": 0,
		"total_defeats": 0,
		"highest_combo": 0,
		"total_questions": 0,
		"total_correct_answers": 0,
		"total_mistakes": 0
	}

func load_game() -> Dictionary:
	if not FileAccess.file_exists(storage_path):
		var fresh: Dictionary = create_new_save()
		current_data = fresh.duplicate(true)
		save_game(fresh)
		return fresh.duplicate(true)

	var parsed: Dictionary = _read_save_dictionary(storage_path)
	if parsed.is_empty():
		var backup_path: String = _backup_path()
		var backup: Dictionary = _read_save_dictionary(backup_path) if FileAccess.file_exists(backup_path) else {}
		if not backup.is_empty():
			push_warning("Save file is invalid. Recovered the previous backup.")
			current_data = _normalize_save(backup)
			_restore_recovered_primary(current_data)
			return current_data.duplicate(true)
		push_warning("Save file is invalid. Creating a new save.")
		return _replace_with_new_save()

	var source_version: int = _to_int(parsed.get("save_version", 0), 0)
	current_data = _normalize_save(parsed)
	# Persist migrations immediately. The player should not have to finish a
	# battle before a legacy save receives the new progression fields.
	if source_version != SAVE_VERSION:
		save_game(current_data)
	return current_data.duplicate(true)

func save_game(data: Dictionary = current_data) -> bool:
	var normalized: Dictionary = _normalize_save(data)
	var temporary_path: String = storage_path + ".tmp"
	var temporary_file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary_file == null:
		push_warning("Could not open temporary save file.")
		return false
	temporary_file.store_string(JSON.stringify(normalized))
	temporary_file.flush()
	temporary_file = null

	if FileAccess.file_exists(storage_path):
		DirAccess.copy_absolute(_absolute_path(storage_path), _absolute_path(_backup_path()))
		var remove_error: Error = DirAccess.remove_absolute(_absolute_path(storage_path))
		if remove_error != OK:
			DirAccess.remove_absolute(_absolute_path(temporary_path))
			push_warning("Could not replace the existing save file.")
			return false
	var rename_error: Error = DirAccess.rename_absolute(_absolute_path(temporary_path), _absolute_path(storage_path))
	if rename_error != OK:
		# The previous file has already moved to the backup at this point. Restore
		# it if finalizing the replacement fails so a transient disk error cannot
		# leave the player without a primary save.
		if FileAccess.file_exists(_backup_path()) and not FileAccess.file_exists(storage_path):
			var restore_error: Error = DirAccess.copy_absolute(_absolute_path(_backup_path()), _absolute_path(storage_path))
			if restore_error != OK:
				push_warning("Could not restore the previous save after a failed replacement.")
		if FileAccess.file_exists(temporary_path):
			DirAccess.remove_absolute(_absolute_path(temporary_path))
		push_warning("Could not finalize the save file.")
		return false
	current_data = normalized.duplicate(true)
	return true

func reset_save() -> Dictionary:
	return _replace_with_new_save()

func _replace_with_new_save() -> Dictionary:
	var fresh: Dictionary = create_new_save()
	current_data = fresh.duplicate(true)
	save_game(fresh)
	return fresh.duplicate(true)

func _restore_recovered_primary(data: Dictionary) -> bool:
	# Keep the known-good .bak untouched while replacing the corrupt primary with
	# a freshly serialized, normalized copy. This makes recovery a one-time event.
	var recovery_path: String = storage_path + ".recover.tmp"
	var recovery_file: FileAccess = FileAccess.open(recovery_path, FileAccess.WRITE)
	if recovery_file == null:
		push_warning("Could not open recovered save file for repair.")
		return false
	recovery_file.store_string(JSON.stringify(_normalize_save(data)))
	recovery_file.flush()
	recovery_file = null

	if FileAccess.file_exists(storage_path):
		var remove_error: Error = DirAccess.remove_absolute(_absolute_path(storage_path))
		if remove_error != OK:
			DirAccess.remove_absolute(_absolute_path(recovery_path))
			push_warning("Could not replace the corrupt primary save file.")
			return false
	var rename_error: Error = DirAccess.rename_absolute(_absolute_path(recovery_path), _absolute_path(storage_path))
	if rename_error != OK:
		if FileAccess.file_exists(recovery_path):
			DirAccess.remove_absolute(_absolute_path(recovery_path))
		push_warning("Could not finalize the recovered primary save file.")
		return false
	return true

func _normalize_save(raw: Dictionary) -> Dictionary:
	var defaults: Dictionary = create_new_save()
	var normalized: Dictionary = defaults.duplicate(true)
	for key: Variant in defaults.keys():
		if raw.has(key):
			normalized[key] = raw[key]

	normalized["save_version"] = SAVE_VERSION
	normalized["level"] = clampi(_to_int(normalized["level"], GameBalance.BASE_LEVEL), 1, 2_000_000_000)
	normalized["exp"] = clampi(_to_int(normalized["exp"], GameBalance.BASE_EXP), 0, GameBalance.required_exp(int(normalized["level"])) * 10_000)
	normalized["coins"] = maxi(0, _to_int(normalized["coins"], GameBalance.BASE_COINS))
	normalized["gems"] = maxi(0, _to_int(normalized["gems"], GameBalance.BASE_GEMS))
	normalized["stat_points"] = maxi(0, _to_int(normalized["stat_points"], 0))
	normalized["base_attack"] = maxi(1, _to_int(normalized["base_attack"], GameBalance.BASE_ATTACK))
	normalized["base_max_hp"] = maxi(1, _to_int(normalized["base_max_hp"], GameBalance.BASE_MAX_HP))
	normalized["base_defense"] = maxi(0, _to_int(normalized["base_defense"], GameBalance.BASE_DEFENSE))
	normalized["base_luck"] = maxi(0, _to_int(normalized["base_luck"], GameBalance.BASE_LUCK))
	if not raw.has("base_max_hp"):
		normalized["base_max_hp"] = GameBalance.BASE_MAX_HP + ((int(normalized["level"]) - 1) * GameBalance.LEVEL_HP_GAIN)
	if not raw.has("base_attack"):
		normalized["base_attack"] = GameBalance.BASE_ATTACK + ((int(normalized["level"]) - 1) * GameBalance.LEVEL_ATTACK_GAIN)

	normalized["current_stage"] = clampi(_to_int(normalized["current_stage"], GameBalance.STARTING_STAGE), 1, GameBalance.MAX_STAGE_ID)
	normalized["unlocked_stage"] = clampi(_to_int(normalized["unlocked_stage"], GameBalance.STARTING_STAGE), 1, GameBalance.MAX_STAGE_ID)
	normalized["highest_completed_stage"] = clampi(_to_int(normalized["highest_completed_stage"], 0), 0, GameBalance.MAX_STAGE_ID)
	var clean_completed: Array[int] = _normalize_completed_stages(raw.get("completed_stages", normalized["completed_stages"]))
	normalized["completed_stages"] = clean_completed
	if not clean_completed.is_empty():
		normalized["highest_completed_stage"] = maxi(int(normalized["highest_completed_stage"]), clean_completed.back())
	# Pre-v2 saves only stored the highest unlocked stage. Progression was
	# sequential, so every earlier stage can safely become the completion
	# high-water mark during migration.
	if not raw.has("highest_completed_stage") and int(normalized["unlocked_stage"]) > 1:
		normalized["highest_completed_stage"] = maxi(int(normalized["highest_completed_stage"]), int(normalized["unlocked_stage"]) - 1)
	if int(normalized["highest_completed_stage"]) > 0:
		normalized["unlocked_stage"] = maxi(int(normalized["unlocked_stage"]), mini(GameBalance.MAX_STAGE_ID, int(normalized["highest_completed_stage"]) + 1))
	normalized["current_stage"] = mini(int(normalized["current_stage"]), int(normalized["unlocked_stage"]))
	normalized["stage_scores"] = _normalize_stage_scores(raw.get("stage_scores", normalized["stage_scores"]))
	normalized["stage_attempts"] = _normalize_stage_attempts(raw.get("stage_attempts", normalized["stage_attempts"]))

	var inventory_source: Variant = raw.get("inventory", normalized["inventory"])
	var inventory: Array = EquipmentSystem.normalize_inventory(inventory_source)
	if not raw.has("inventory"):
		inventory = _migrate_legacy_equipment(raw, inventory)
	normalized["inventory"] = inventory
	normalized["next_item_uid"] = maxi(_to_int(normalized["next_item_uid"], 1), _next_uid_after_inventory(inventory))
	normalized["equipped"] = _normalize_equipped(raw, inventory, normalized.get("equipped", {}))

	normalized["loot_pity"] = clampi(_to_int(normalized["loot_pity"], 0), 0, 4)
	normalized["total_victories"] = maxi(0, _to_int(normalized["total_victories"], 0))
	normalized["total_defeats"] = maxi(0, _to_int(normalized["total_defeats"], 0))
	normalized["highest_combo"] = maxi(0, _to_int(normalized["highest_combo"], 0))
	var correct_answers: int = maxi(0, _to_int(normalized["total_correct_answers"], 0))
	var mistakes: int = maxi(0, _to_int(normalized["total_mistakes"], 0))
	var question_count: int = maxi(0, _to_int(normalized["total_questions"], 0))
	question_count = maxi(question_count, correct_answers + mistakes)
	normalized["total_questions"] = question_count
	normalized["total_correct_answers"] = mini(correct_answers, question_count)
	normalized["total_mistakes"] = mini(mistakes, question_count - int(normalized["total_correct_answers"]))
	return normalized

func _normalize_completed_stages(raw_completed: Variant) -> Array[int]:
	var clean: Array[int] = []
	if not raw_completed is Array:
		return clean
	for stage_value: Variant in raw_completed:
		if not (stage_value is int or stage_value is float):
			continue
		var stage_id: int = int(stage_value)
		if stage_id < 1 or stage_id > GameBalance.MAX_STAGE_ID:
			continue
		if not clean.has(stage_id):
			clean.append(stage_id)
	clean.sort()
	# The high-water mark is authoritative; retain only recent explicit entries so
	# an effectively endless run does not create an endlessly growing JSON array.
	if clean.size() > 100:
		clean = clean.slice(clean.size() - 100)
	return clean

func _normalize_stage_scores(raw_scores: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not raw_scores is Dictionary:
		return clean
	for raw_key: Variant in raw_scores.keys():
		var stage_id: int = _to_int(raw_key, -1)
		if stage_id < GameBalance.STARTING_STAGE or stage_id > GameBalance.MAX_STAGE_ID:
			continue
		var raw_score: Variant = raw_scores[raw_key]
		if not raw_score is Dictionary:
			continue
		var score: Dictionary = raw_score
		var best_stars: int = clampi(_to_int(score.get("best_stars", score.get("stars", 0)), 0), 0, GameBalance.MAX_STAGE_STARS)
		if best_stars <= 0:
			continue
		clean[str(stage_id)] = {
			"best_stars": best_stars,
			"best_accuracy": clampf(float(score.get("best_accuracy", score.get("accuracy", 0.0))), 0.0, 1.0),
			"best_combo": maxi(0, _to_int(score.get("best_combo", 0), 0)),
			"clear_count": maxi(1, _to_int(score.get("clear_count", 1), 1)),
			"last_stars": clampi(_to_int(score.get("last_stars", best_stars), best_stars), 1, GameBalance.MAX_STAGE_STARS),
			"last_accuracy": clampf(float(score.get("last_accuracy", score.get("best_accuracy", 0.0))), 0.0, 1.0),
			"last_mistakes": maxi(0, _to_int(score.get("last_mistakes", 0), 0))
		}
	return _trim_stage_records(clean)

func _normalize_stage_attempts(raw_attempts: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not raw_attempts is Dictionary:
		return clean
	for raw_key: Variant in raw_attempts.keys():
		var stage_id: int = _to_int(raw_key, -1)
		if stage_id < GameBalance.STARTING_STAGE or stage_id > GameBalance.MAX_STAGE_ID:
			continue
		var attempts: int = maxi(0, _to_int(raw_attempts[raw_key], 0))
		if attempts > 0:
			clean[str(stage_id)] = attempts
	return _trim_stage_records(clean)

func _trim_stage_records(records: Dictionary) -> Dictionary:
	if records.size() <= GameBalance.MAX_PERSISTED_STAGE_RECORDS:
		return records
	var retained: Dictionary = {}
	var keys: Array = records.keys()
	keys.sort()
	# Keep every authored World 1 record so its stars remain visible when the
	# player browses back, then fill the remaining budget with the newest
	# endless records. Completion itself is not lost: highest_completed_stage
	# remains the authoritative sequential high-water mark.
	for raw_key: Variant in keys:
		var stage_id: int = _to_int(raw_key, -1)
		if stage_id >= 1 and stage_id <= GameBalance.STAGES_PER_CHAPTER:
			retained[str(stage_id)] = records[raw_key]
	var remaining: int = maxi(0, GameBalance.MAX_PERSISTED_STAGE_RECORDS - retained.size())
	for index: int in range(keys.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var key: String = str(keys[index])
		if retained.has(key):
			continue
		retained[key] = records[keys[index]]
		remaining -= 1
	var sorted_retained: Array = retained.keys()
	sorted_retained.sort()
	var result: Dictionary = {}
	for key: Variant in sorted_retained:
		result[str(key)] = retained[key]
	return result

func _migrate_legacy_equipment(raw: Dictionary, existing: Array) -> Array:
	var migrated: Array = existing.duplicate(true)
	var owned: Variant = raw.get("owned_equipment", [])
	if not owned is Array:
		return migrated
	var uid_counter: int = _next_uid_after_inventory(migrated)
	for legacy_id: Variant in owned:
		var template_id: String = str(legacy_id)
		if DataManager.get_equipment(template_id).is_empty():
			continue
		var already_owned: bool = false
		for raw_item: Variant in migrated:
			if raw_item is Dictionary and str(raw_item.get("template_id", "")) == template_id:
				already_owned = true
				break
		if already_owned:
			continue
		migrated.append(EquipmentSystem.create_instance(template_id, "item_%d" % uid_counter, 1, 0))
		uid_counter += 1
	return EquipmentSystem.normalize_inventory(migrated)

func _normalize_equipped(raw: Dictionary, inventory: Array, default_equipped: Variant) -> Dictionary:
	var equipped: Dictionary = {"weapon": "", "head": "", "body": ""}
	var source: Variant = raw.get("equipped", default_equipped)
	if source is Dictionary:
		for slot: String in EquipmentSystem.SLOTS:
			equipped[slot] = str(source.get(slot, ""))
	for slot: String in EquipmentSystem.SLOTS:
		var legacy_key: String = "equipped_%s" % slot
		if not raw.has("equipped") and raw.has(legacy_key):
			var legacy_template: String = str(raw.get(legacy_key, ""))
			for raw_item: Variant in inventory:
				if raw_item is Dictionary and str(raw_item.get("template_id", "")) == legacy_template:
					equipped[slot] = str(raw_item.get("uid", ""))
					break
		var uid: String = str(equipped.get(slot, ""))
		var item: Dictionary = EquipmentSystem.find_item(inventory, uid)
		var template: Dictionary = EquipmentSystem.get_item_template(item)
		if item.is_empty() or str(template.get("slot", "")) != slot:
			equipped[slot] = ""
	return equipped

func _next_uid_after_inventory(inventory: Array) -> int:
	var next_uid: int = 1
	for raw_item: Variant in inventory:
		if not raw_item is Dictionary:
			continue
		var uid: String = str(raw_item.get("uid", ""))
		if uid.begins_with("item_") and uid.substr(5).is_valid_int():
			next_uid = maxi(next_uid, int(uid.substr(5)) + 1)
	return next_uid

func _read_save_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	if parse_error != OK or not json.data is Dictionary:
		return {}
	return json.data

func _backup_path() -> String:
	return storage_path + ".bak"

func _absolute_path(path: String) -> String:
	# FileAccess accepts res:// and user:// paths, while the atomic DirAccess
	# operations above require filesystem paths. Keep test paths such as
	# /private/tmp/... unchanged.
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

func _to_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and str(value).is_valid_int():
		return int(str(value))
	return fallback
