class_name EquipmentSystem
extends RefCounted

## Pure helpers for item instances, equipment stats, drops, upgrades, and selling.
const SLOTS: Array[String] = ["weapon", "head", "body"]
const FLAT_STATS: Array[String] = ["attack", "max_hp", "defense", "luck"]
const PERCENT_STATS: Array[String] = ["exp_bonus", "coin_bonus"]
const RARITY_ORDER: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const DROP_RARITIES: Array[String] = ["common", "uncommon", "rare", "epic"]
const MAX_EXACT_UPGRADE_REBUILD_LEVEL: int = 100_000
const MAX_SAFE_COIN_TOTAL: int = 9_000_000_000_000_000_000

static func starter_item() -> Dictionary:
	return create_instance("twig_club", "item_1", 1, 0)

static func create_instance(template_id: String, uid: String, item_level: int = 1, acquired_stage: int = 1, upgrade_coins_spent: int = 0) -> Dictionary:
	if uid.is_empty() or DataManager.get_equipment(template_id).is_empty():
		return {}
	return {
		"uid": uid,
		"template_id": template_id,
		"level": maxi(1, item_level),
		"acquired_stage": maxi(0, acquired_stage),
		"upgrade_coins_spent": maxi(0, upgrade_coins_spent)
	}

static func normalize_item(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var item: Dictionary = raw
	var uid: String = str(item.get("uid", "")).strip_edges()
	var template_id: String = str(item.get("template_id", "")).strip_edges()
	if uid.is_empty() or DataManager.get_equipment(template_id).is_empty():
		return {}
	var item_level: int = clampi(_safe_int(item.get("level", 1), 1), 1, 2_000_000_000)
	var acquired_stage: int = clampi(_safe_int(item.get("acquired_stage", 0), 0), 0, GameBalance.MAX_STAGE_ID)
	var template: Dictionary = DataManager.get_equipment(template_id)
	var rarity: String = str(template.get("rarity", "common"))
	var raw_spent: Variant = item.get("upgrade_coins_spent", null)
	var spent: int = upgrade_coins_spent_for_level(item_level, rarity)
	if raw_spent is int or raw_spent is float:
		spent = maxi(0, int(raw_spent))
	return create_instance(
		template_id,
		uid,
		item_level,
		acquired_stage,
		spent
	)

static func normalize_inventory(raw_inventory: Variant) -> Array:
	var clean: Array = []
	var seen_uids: Dictionary = {}
	if not raw_inventory is Array:
		return clean
	for raw_item: Variant in raw_inventory:
		var item: Dictionary = normalize_item(raw_item)
		if item.is_empty():
			continue
		var uid: String = str(item.get("uid", ""))
		if seen_uids.has(uid):
			continue
		seen_uids[uid] = true
		clean.append(item)
	return clean

static func get_item_template(item: Dictionary) -> Dictionary:
	return DataManager.get_equipment(str(item.get("template_id", "")))

static func get_equipment_sprite_path(template_id: String) -> String:
	var template: Dictionary = DataManager.get_equipment(template_id)
	if template.is_empty():
		return ""
	var generated_sprite: String = str(template.get("generated_sprite", ""))
	return generated_sprite if not generated_sprite.is_empty() and ResourceLoader.exists(generated_sprite) else ""

static func get_item_stats(item: Dictionary) -> Dictionary:
	var result: Dictionary = _empty_stats()
	var template: Dictionary = get_item_template(item)
	if template.is_empty():
		return result
	var base_stats: Variant = template.get("base_stats", {})
	if not base_stats is Dictionary:
		return result
	var rarity: String = str(template.get("rarity", "common"))
	var item_level: int = maxi(1, int(item.get("level", 1)))
	for stat: String in FLAT_STATS:
		result[stat] = GameBalance.equipment_stat_value(float(base_stats.get(stat, 0.0)), item_level, rarity)
	for stat: String in PERCENT_STATS:
		var base_value: float = float(base_stats.get(stat, 0.0))
		var level_multiplier: float = 1.0 + minf(1.5, float(item_level - 1) * 0.025)
		result[stat] = clampf(base_value * GameBalance.rarity_multiplier(rarity) * level_multiplier, 0.0, 0.75)
	return result

static func aggregate_equipped_stats(state: Dictionary) -> Dictionary:
	var result: Dictionary = _empty_stats()
	var inventory: Array = state.get("inventory", []) if state.get("inventory", []) is Array else []
	var equipped: Dictionary = state.get("equipped", {}) if state.get("equipped", {}) is Dictionary else {}
	var seen_uids: Dictionary = {}
	for slot: String in SLOTS:
		var uid: String = str(equipped.get(slot, ""))
		if uid.is_empty() or seen_uids.has(uid):
			continue
		var item: Dictionary = find_item(inventory, uid)
		var template: Dictionary = get_item_template(item)
		if item.is_empty() or str(template.get("slot", "")) != slot:
			continue
		seen_uids[uid] = true
		var stats: Dictionary = get_item_stats(item)
		for stat: String in FLAT_STATS:
			result[stat] = int(result.get(stat, 0)) + int(stats.get(stat, 0))
		for stat: String in PERCENT_STATS:
			result[stat] = float(result.get(stat, 0.0)) + float(stats.get(stat, 0.0))
	result["exp_bonus"] = clampf(float(result["exp_bonus"]), 0.0, 1.5)
	result["coin_bonus"] = clampf(float(result["coin_bonus"]), 0.0, 1.5)
	return result

static func find_item(inventory: Array, uid: String) -> Dictionary:
	for raw_item: Variant in inventory:
		if raw_item is Dictionary and str(raw_item.get("uid", "")) == uid:
			return raw_item
	return {}

static func find_item_index(inventory: Array, uid: String) -> int:
	for index: int in range(inventory.size()):
		var raw_item: Variant = inventory[index]
		if raw_item is Dictionary and str(raw_item.get("uid", "")) == uid:
			return index
	return -1

static func is_equipped(state: Dictionary, uid: String) -> bool:
	var equipped: Variant = state.get("equipped", {})
	if not equipped is Dictionary:
		return false
	return equipped.values().has(uid)

static func upgrade_cost(item: Dictionary) -> int:
	var template: Dictionary = get_item_template(item)
	if template.is_empty():
		return 0
	return GameBalance.equipment_upgrade_cost(int(item.get("level", 1)), str(template.get("rarity", "common")))

static func get_upgrade_coins_spent(item: Dictionary) -> int:
	var raw_spent: Variant = item.get("upgrade_coins_spent", null)
	if raw_spent is int or raw_spent is float:
		return maxi(0, int(raw_spent))
	var template: Dictionary = get_item_template(item)
	if template.is_empty():
		return 0
	return upgrade_coins_spent_for_level(int(item.get("level", 1)), str(template.get("rarity", "common")))

static func upgrade_coins_spent_for_level(item_level: int, rarity: String) -> int:
	var target_level: int = maxi(1, item_level)
	if target_level <= 1:
		return 0
	var exact_end: int = mini(target_level, MAX_EXACT_UPGRADE_REBUILD_LEVEL)
	var total: int = 0
	for level: int in range(1, exact_end):
		total = mini(MAX_SAFE_COIN_TOTAL, total + GameBalance.equipment_upgrade_cost(level, rarity))
	if target_level <= MAX_EXACT_UPGRADE_REBUILD_LEVEL or total >= MAX_SAFE_COIN_TOTAL:
		return total
	# Legacy saves normally contain modest levels. Keep malformed extreme levels
	# bounded while still returning a deterministic estimate instead of looping
	# billions of times during save normalization.
	var rarity_cost: float = GameBalance.rarity_multiplier(rarity)
	var lower: float = float(exact_end - 1)
	var upper: float = float(target_level - 1)
	var estimated_tail: float = 18.0 * rarity_cost * (pow(upper, 2.35) - pow(lower, 2.35)) / 2.35
	if estimated_tail >= float(MAX_SAFE_COIN_TOTAL - total):
		return MAX_SAFE_COIN_TOTAL
	return total + maxi(0, int(round(estimated_tail)))

static func sell_value(item: Dictionary) -> int:
	var template: Dictionary = get_item_template(item)
	if template.is_empty():
		return 0
	return GameBalance.equipment_sell_value(int(item.get("level", 1)), str(template.get("rarity", "common")))

static func roll_drop(stage_id: int, luck: int, victory_serial: int, pity: int, guaranteed: bool = false) -> Dictionary:
	var safe_stage: int = clampi(stage_id, 1, GameBalance.MAX_STAGE_ID)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _drop_seed(safe_stage, victory_serial, pity)
	var drop_chance: float = clampf(0.22 + (float(maxi(0, luck)) * 0.003) + (float(maxi(0, pity)) * 0.18), 0.22, 0.92)
	if not guaranteed and rng.randf() > drop_chance:
		return {}

	var chapter: int = GameBalance.chapter_for_stage(safe_stage)
	var progression_bonus: float = minf(0.18, float(chapter - 1) * 0.004)
	var luck_bonus: float = minf(0.15, float(maxi(0, luck)) * 0.002)
	var rarity_roll: float = rng.randf()
	var rarity: String = "common"
	var epic_chance: float = 0.015 + progression_bonus * 0.35 + luck_bonus * 0.4
	var rare_chance: float = 0.10 + progression_bonus + luck_bonus
	var uncommon_chance: float = 0.28 + progression_bonus
	if rarity_roll < epic_chance:
		rarity = "epic"
	elif rarity_roll < epic_chance + rare_chance:
		rarity = "rare"
	elif rarity_roll < epic_chance + rare_chance + uncommon_chance:
		rarity = "uncommon"

	var pool: Array = _templates_for_drop(safe_stage, rarity)
	if pool.is_empty():
		for fallback_rarity: String in DROP_RARITIES:
			pool = _templates_for_drop(safe_stage, fallback_rarity)
			if not pool.is_empty():
				break
	if pool.is_empty():
		return {}
	var template: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var drop_level: int = maxi(1, int(floor(float(safe_stage - 1) / 5.0)) + 1)
	return {
		"template_id": str(template.get("id", "")),
		"level": drop_level,
		"acquired_stage": safe_stage
	}

static func describe_item(item: Dictionary) -> String:
	var template: Dictionary = get_item_template(item)
	if template.is_empty():
		return "未知裝備"
	return "%s  Lv.%d" % [str(template.get("name_zh", template.get("name", "裝備"))), int(item.get("level", 1))]

static func rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color("#e5a53a")
		"epic":
			return Color("#b06bd6")
		"rare":
			return Color("#5f8ed6")
		"uncommon":
			return Color("#5da975")
		_:
			return Color("#8c7770")

static func merge_target(template_id: String) -> String:
	var template: Dictionary = DataManager.get_equipment(template_id)
	if template.is_empty():
		return ""
	var target_id: String = str(template.get("merge_to", ""))
	if target_id.is_empty():
		return ""
	var target: Dictionary = DataManager.get_equipment(target_id)
	if target.is_empty():
		push_warning("Equipment merge target is invalid: %s -> %s" % [template_id, target_id])
		return ""
	if str(target.get("slot", "")) != str(template.get("slot", "")):
		return ""
	if RARITY_ORDER.find(str(target.get("rarity", ""))) != RARITY_ORDER.find(str(template.get("rarity", ""))) + 1:
		return ""
	return target_id

static func validate_merge_items(items: Array, state: Dictionary) -> Dictionary:
	if items.size() != 3:
		return {"success": false, "reason": "requires_three_items"}
	var first_template_id: String = ""
	var first_rarity: String = ""
	var seen_uids: Dictionary = {}
	for raw_item: Variant in items:
		if not raw_item is Dictionary:
			return {"success": false, "reason": "invalid_item"}
		var item: Dictionary = raw_item
		var uid: String = str(item.get("uid", ""))
		var template_id: String = str(item.get("template_id", ""))
		if uid.is_empty() or seen_uids.has(uid):
			return {"success": false, "reason": "duplicate_item"}
		seen_uids[uid] = true
		var template: Dictionary = DataManager.get_equipment(template_id)
		if template.is_empty():
			return {"success": false, "reason": "invalid_template"}
		if not SLOTS.has(str(template.get("slot", ""))):
			return {"success": false, "reason": "invalid_slot"}
		if int(item.get("level", 1)) < 1:
			return {"success": false, "reason": "invalid_level"}
		if first_template_id.is_empty():
			first_template_id = template_id
			first_rarity = str(template.get("rarity", "common"))
		elif template_id != first_template_id:
			return {"success": false, "reason": "templates_must_match"}
		elif str(template.get("rarity", "common")) != first_rarity:
			return {"success": false, "reason": "rarities_must_match"}
	var target_id: String = merge_target(first_template_id)
	if target_id.is_empty():
		return {"success": false, "reason": "max_rarity"}
	return {"success": true, "template_id": first_template_id, "target_id": target_id}

static func plan_auto_merge(inventory: Array, state: Dictionary) -> Dictionary:
	## Builds a deterministic, side-effect-free chain of all currently possible
	## merges. Internal fields are attached only to duplicated working items and
	## never leave this helper in the returned persistent item data.
	var working: Array = []
	var seen_uids: Dictionary = {}
	for raw_item: Variant in inventory:
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = (raw_item as Dictionary).duplicate(true)
		var uid: String = str(item.get("uid", ""))
		if uid.is_empty() or seen_uids.has(uid):
			continue
		seen_uids[uid] = true
		item["_auto_created"] = false
		item["_auto_equipped_slot"] = _equipped_slot(state, uid)
		working.append(item)

	var steps: Array = []
	var consumed_uids: Array[String] = []
	var consumed_seen: Dictionary = {}
	var refund_coins: int = 0
	var output_serial: int = 0
	while true:
		var candidate_templates: Array[String] = _auto_merge_candidate_templates(working)
		if candidate_templates.is_empty():
			break
		candidate_templates.sort_custom(func(a: String, b: String) -> bool:
			return _merge_template_precedes(a, b)
		)
		var source_template_id: String = candidate_templates[0]
		var target_id: String = merge_target(source_template_id)
		if target_id.is_empty():
			break

		var materials: Array = []
		for raw_working_item: Variant in working:
			if raw_working_item is Dictionary and str((raw_working_item as Dictionary).get("template_id", "")) == source_template_id:
				materials.append((raw_working_item as Dictionary))
		materials.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_equipped: bool = not str(a.get("_auto_equipped_slot", "")).is_empty()
			var b_equipped: bool = not str(b.get("_auto_equipped_slot", "")).is_empty()
			if a_equipped != b_equipped:
				return not a_equipped
			var a_level: int = int(a.get("level", 1))
			var b_level: int = int(b.get("level", 1))
			if a_level != b_level:
				return a_level < b_level
			return str(a.get("uid", "")) < str(b.get("uid", ""))
		)
		if materials.size() < 3:
			break
		var selected: Array = materials.slice(0, 3)
		var selected_tokens: Dictionary = {}
		var material_uids: Array[String] = []
		var equipped_slot: String = ""
		var step_refund: int = 0
		for raw_selected_item: Variant in selected:
			var selected_item: Dictionary = raw_selected_item as Dictionary
			var selected_uid: String = str(selected_item.get("uid", ""))
			selected_tokens[selected_uid] = true
			material_uids.append(selected_uid)
			var selected_equipped_slot: String = str(selected_item.get("_auto_equipped_slot", ""))
			if equipped_slot.is_empty() and not selected_equipped_slot.is_empty():
				equipped_slot = selected_equipped_slot
			if not bool(selected_item.get("_auto_created", false)):
				if not consumed_seen.has(selected_uid):
					consumed_seen[selected_uid] = true
					consumed_uids.append(selected_uid)
				step_refund += get_upgrade_coins_spent(selected_item)
		refund_coins += step_refund

		var remaining: Array = []
		for raw_working_item: Variant in working:
			if raw_working_item is Dictionary and not selected_tokens.has(str((raw_working_item as Dictionary).get("uid", ""))):
				remaining.append(raw_working_item)
		working = remaining

		var output_token: String = "__auto_output_%d" % output_serial
		output_serial += 1
		var output_item: Dictionary = create_instance(target_id, output_token, 1, 0)
		if output_item.is_empty():
			break
		output_item["_auto_created"] = true
		output_item["_auto_equipped_slot"] = equipped_slot
		working.append(output_item)
		steps.append({
			"step_index": steps.size() + 1,
			"source_template_id": source_template_id,
			"target_id": target_id,
			"material_uids": material_uids,
			"output_token": output_token,
			"equipped_slot": equipped_slot,
			"refund_coins": step_refund
		})

	var final_outputs: Array = []
	var equipped_replacements: Dictionary = {}
	for raw_working_item: Variant in working:
		if not raw_working_item is Dictionary or not bool((raw_working_item as Dictionary).get("_auto_created", false)):
			continue
		var final_item: Dictionary = raw_working_item as Dictionary
		var final_token: String = str(final_item.get("uid", ""))
		var final_slot: String = str(final_item.get("_auto_equipped_slot", ""))
		final_outputs.append({
			"output_token": final_token,
			"template_id": str(final_item.get("template_id", "")),
			"equipped_slot": final_slot
		})
		if not final_slot.is_empty():
			equipped_replacements[final_slot] = final_token

	return {
		"success": true,
		"has_plan": not steps.is_empty(),
		"steps": steps,
		"consumed_uids": consumed_uids,
		"final_outputs": final_outputs,
		"equipped_replacements": equipped_replacements,
		"refund_coins": refund_coins,
		"merge_count": steps.size(),
		"consumed_count": consumed_uids.size(),
		"output_count": final_outputs.size()
	}

static func _auto_merge_candidate_templates(working: Array) -> Array[String]:
	var counts: Dictionary = {}
	for raw_item: Variant in working:
		if not raw_item is Dictionary:
			continue
		var template_id: String = str((raw_item as Dictionary).get("template_id", ""))
		if merge_target(template_id).is_empty():
			continue
		counts[template_id] = int(counts.get(template_id, 0)) + 1
	var result: Array[String] = []
	for raw_template_id: Variant in counts.keys():
		if int(counts[raw_template_id]) >= 3:
			result.append(str(raw_template_id))
	return result

static func _merge_template_precedes(a: String, b: String) -> bool:
	var a_template: Dictionary = DataManager.get_equipment(a)
	var b_template: Dictionary = DataManager.get_equipment(b)
	var a_rarity: int = RARITY_ORDER.find(str(a_template.get("rarity", "common")))
	var b_rarity: int = RARITY_ORDER.find(str(b_template.get("rarity", "common")))
	if a_rarity != b_rarity:
		return a_rarity < b_rarity
	var a_slot: int = SLOTS.find(str(a_template.get("slot", "weapon")))
	var b_slot: int = SLOTS.find(str(b_template.get("slot", "weapon")))
	if a_slot != b_slot:
		return a_slot < b_slot
	return a < b

static func _equipped_slot(state: Dictionary, uid: String) -> String:
	var equipped: Variant = state.get("equipped", {})
	if not equipped is Dictionary:
		return ""
	for slot: String in SLOTS:
		if str((equipped as Dictionary).get(slot, "")) == uid:
			return slot
	return ""

static func _templates_for_drop(stage_id: int, rarity: String) -> Array:
	var result: Array = []
	for template: Dictionary in DataManager.get_all_equipment():
		if str(template.get("rarity", "common")) != rarity:
			continue
		if int(template.get("min_stage", 1)) > stage_id:
			continue
		if not SLOTS.has(str(template.get("slot", ""))):
			continue
		result.append(template)
	return result

static func _drop_seed(stage_id: int, victory_serial: int, pity: int) -> int:
	var seed_value: int = (int(stage_id) * 1_103_515_245) + (maxi(0, victory_serial) * 12_345) + (maxi(0, pity) * 97_531) + 7_919
	return absi(seed_value)

static func _empty_stats() -> Dictionary:
	return {
		"attack": 0,
		"max_hp": 0,
		"defense": 0,
		"luck": 0,
		"exp_bonus": 0.0,
		"coin_bonus": 0.0
	}

static func _safe_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	return fallback
