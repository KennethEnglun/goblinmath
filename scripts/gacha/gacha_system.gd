class_name GachaSystem
extends RefCounted

## Deterministic, data-driven helpers for local equipment summons and merging.
const DIRECT_RARITIES: Array[String] = ["common", "uncommon", "rare", "epic"]

static func pull_cost(count: int) -> int:
	var config: Dictionary = _config()
	if count == 1:
		return maxi(0, _safe_int(config.get("single_cost", GameBalance.GACHA_SINGLE_COST), GameBalance.GACHA_SINGLE_COST))
	if count == 10:
		return maxi(0, _safe_int(config.get("ten_cost", GameBalance.GACHA_TEN_COST), GameBalance.GACHA_TEN_COST))
	return 0

static func get_available_rarities(highest_completed_stage: int) -> Array[String]:
	var available_templates: Dictionary = _available_templates(highest_completed_stage)
	var result: Array[String] = []
	for rarity: String in _direct_rarities():
		if available_templates.has(rarity) and not (available_templates[rarity] as Array).is_empty():
			result.append(rarity)
	return result

static func roll(state: Dictionary, count: int, seed: int = 0) -> Dictionary:
	if count != 1 and count != 10:
		return {"success": false, "reason": "invalid_pull_count"}
	var cost: int = pull_cost(count)
	if cost <= 0:
		return {"success": false, "reason": "invalid_gacha_config"}
	if int(state.get("gems", 0)) < cost:
		return {"success": false, "reason": "not_enough_gems", "cost": cost}
	var highest_completed_stage: int = maxi(1, _safe_int(state.get("highest_completed_stage", 0), 0))
	var available_templates: Dictionary = _available_templates(highest_completed_stage)
	var available_rarities: Array[String] = get_available_rarities(highest_completed_stage)
	if available_rarities.is_empty():
		return {"success": false, "reason": "empty_gacha_pool", "cost": cost}

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	var results: Array = []
	for _index: int in range(count):
		results.append(_roll_item(rng, available_templates, available_rarities, highest_completed_stage))

	var guaranteed: bool = false
	if count == 10 and _has_uncommon_plus(available_rarities) and not _contains_uncommon_plus(results):
		var guaranteed_item: Dictionary = _roll_item(rng, available_templates, _uncommon_plus_rarities(available_rarities), highest_completed_stage)
		results[0] = guaranteed_item
		guaranteed = true
	return {
		"success": true,
		"cost": cost,
		"count": count,
		"items": results,
		"guaranteed": guaranteed,
		"available_rarities": available_rarities
	}

static func get_merge_target(template_id: String) -> String:
	return EquipmentSystem.merge_target(template_id)

static func validate_merge(items: Array, state: Dictionary) -> Dictionary:
	return EquipmentSystem.validate_merge_items(items, state)

static func _roll_item(rng: RandomNumberGenerator, templates_by_rarity: Dictionary, available_rarities: Array[String], acquired_stage: int) -> Dictionary:
	var rarity: String = _roll_rarity(rng, available_rarities)
	var pool: Array = templates_by_rarity.get(rarity, []) as Array
	if pool.is_empty():
		return {}
	var template: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return {
		"template_id": str(template.get("id", "")),
		"level": 1,
		"acquired_stage": acquired_stage,
		"rarity": rarity
	}

static func _roll_rarity(rng: RandomNumberGenerator, available_rarities: Array[String]) -> String:
	var weights: Dictionary = _config().get("rarity_weights", {}) if _config().get("rarity_weights", {}) is Dictionary else {}
	var total_weight: float = 0.0
	for rarity: String in available_rarities:
		total_weight += maxf(0.0, float(weights.get(rarity, 0.0)))
	if total_weight <= 0.0:
		return available_rarities[0] if not available_rarities.is_empty() else ""
	var selected: float = rng.randf() * total_weight
	for rarity: String in available_rarities:
		selected -= maxf(0.0, float(weights.get(rarity, 0.0)))
		if selected <= 0.0:
			return rarity
	return available_rarities.back()

static func _available_templates(highest_completed_stage: int) -> Dictionary:
	var result: Dictionary = {}
	var direct_rarities: Array[String] = _direct_rarities()
	for rarity: String in direct_rarities:
		result[rarity] = []
	var progress_stage: int = maxi(1, highest_completed_stage)
	for template: Dictionary in DataManager.get_all_equipment():
		var rarity: String = str(template.get("rarity", ""))
		if not direct_rarities.has(rarity):
			continue
		if not bool(template.get("gacha_enabled", true)):
			continue
		if int(template.get("min_stage", 1)) > progress_stage:
			continue
		var slot: String = str(template.get("slot", ""))
		if not EquipmentSystem.SLOTS.has(slot):
			continue
		(result[rarity] as Array).append(template)
	return result

static func _direct_rarities() -> Array[String]:
	var raw: Variant = _config().get("direct_rarities", DIRECT_RARITIES)
	var result: Array[String] = []
	if raw is Array:
		for rarity: Variant in raw:
			if DIRECT_RARITIES.has(str(rarity)) and not result.has(str(rarity)):
				result.append(str(rarity))
	return result if not result.is_empty() else DIRECT_RARITIES.duplicate()

static func _uncommon_plus_rarities(available_rarities: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for rarity: String in available_rarities:
		if DIRECT_RARITIES.find(rarity) >= DIRECT_RARITIES.find("uncommon"):
			result.append(rarity)
	return result

static func _has_uncommon_plus(available_rarities: Array[String]) -> bool:
	return not _uncommon_plus_rarities(available_rarities).is_empty()

static func _contains_uncommon_plus(results: Array) -> bool:
	for raw_result: Variant in results:
		if not raw_result is Dictionary:
			continue
		if DIRECT_RARITIES.find(str(raw_result.get("rarity", "common"))) >= DIRECT_RARITIES.find("uncommon"):
			return true
	return false

static func _config() -> Dictionary:
	var config: Dictionary = DataManager.get_gacha_config()
	return config if not config.is_empty() else {
		"single_cost": GameBalance.GACHA_SINGLE_COST,
		"ten_cost": GameBalance.GACHA_TEN_COST,
		"direct_rarities": DIRECT_RARITIES,
		"rarity_weights": {"common": 0.60, "uncommon": 0.28, "rare": 0.10, "epic": 0.02}
	}

static func _safe_int(value: Variant, fallback: int) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and str(value).is_valid_int():
		return int(str(value))
	return fallback
