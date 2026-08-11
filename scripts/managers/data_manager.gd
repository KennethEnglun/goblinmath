extends Node

## Loads authored content and deterministically generates stages beyond World 1.
const STAGES_PATH: String = "res://data/stages.json"
const MONSTERS_PATH: String = "res://data/monsters.json"
const EQUIPMENT_PATH: String = "res://data/equipment.json"
const GACHA_PATH: String = "res://data/gacha.json"

const MAP_POSITIONS: Array[Vector2i] = [
	Vector2i(500, 4250),
	Vector2i(760, 3800),
	Vector2i(320, 3350),
	Vector2i(740, 2960),
	Vector2i(300, 2570),
	Vector2i(760, 2150),
	Vector2i(350, 1700),
	Vector2i(760, 1200),
	Vector2i(280, 730),
	Vector2i(540, 280)
]
const NORMAL_MONSTER_IDS: Array[String] = [
	"green_blob", "mushroom", "pollen_puff", "sakura_sprite", "star_puff"
]
const ENDLESS_STAGE_NAMES: Array[String] = [
	"晨露入口", "蒲公英小徑", "蜜桃溪畔", "櫻風入口", "莓果樹洞",
	"花瓣練習場", "雲朵岔路", "月芽坡", "星光山徑", "星冠試煉"
]

var stages: Dictionary = {}
var monsters: Dictionary = {}
var equipment: Dictionary = {}
var gacha_config: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	stages = _index_by_id(_load_json_array(STAGES_PATH), true)
	monsters = _index_by_id(_load_json_array(MONSTERS_PATH), false)
	equipment = _index_by_id(_load_json_array(EQUIPMENT_PATH), false)
	gacha_config = _load_json_dictionary(GACHA_PATH)

func get_stage(stage_id: int) -> Dictionary:
	if stage_id < GameBalance.STARTING_STAGE or stage_id > GameBalance.MAX_STAGE_ID:
		return {}
	if stages.has(stage_id):
		return _copy_or_empty(stages.get(stage_id, {}))
	if stage_id > _last_authored_stage_id():
		return _generate_endless_stage(stage_id)
	return {}

func get_stages_for_world(world_id: int) -> Array:
	return get_stages_for_chapter(world_id)

func get_stages_for_chapter(chapter: int) -> Array:
	var safe_chapter: int = maxi(1, chapter)
	var first_stage: int = GameBalance.first_stage_for_chapter(safe_chapter)
	var result: Array = []
	for offset: int in range(GameBalance.STAGES_PER_CHAPTER):
		var stage_id: int = first_stage + offset
		var stage: Dictionary = get_stage(stage_id)
		if not stage.is_empty():
			result.append(stage)
	return result

func get_stages_for_page(page: int) -> Array:
	return get_stages_for_chapter(page)

func get_next_stage_id(stage_id: int) -> int:
	if get_stage(stage_id).is_empty() or stage_id >= GameBalance.MAX_STAGE_ID:
		return -1
	return stage_id + 1

func get_monster(monster_id: String) -> Dictionary:
	return _copy_or_empty(monsters.get(monster_id, {}))

func get_equipment(equipment_id: String) -> Dictionary:
	return _copy_or_empty(equipment.get(equipment_id, {}))

func get_all_equipment() -> Array:
	var ids: Array = equipment.keys()
	ids.sort()
	var result: Array = []
	for equipment_id: Variant in ids:
		var item: Dictionary = get_equipment(str(equipment_id))
		if not item.is_empty():
			result.append(item)
	return result

func get_gacha_config() -> Dictionary:
	return _copy_or_empty(gacha_config)

func _generate_endless_stage(stage_id: int) -> Dictionary:
	var chapter: int = GameBalance.chapter_for_stage(stage_id)
	var slot: int = GameBalance.slot_for_stage(stage_id)
	var is_boss: bool = GameBalance.is_boss_stage(stage_id)
	var zone: String = _zone_for_slot(slot)
	var question_types: Array[String] = _question_types_for_stage(chapter, slot)
	# Endless progression should stay challenging without silently turning a
	# primary-school mental-math game into large-number written arithmetic.
	var addition_max: int = mini(99, 20 + (chapter * 10))
	var multiplication_max: int = mini(12, 5 + int(floor(float(chapter) / 2.0)))
	var monster_id: String = "crown_slime_boss" if is_boss else NORMAL_MONSTER_IDS[posmod(stage_id + chapter, NORMAL_MONSTER_IDS.size())]
	var map_position: Vector2i = MAP_POSITIONS[slot - 1]
	return {
		"id": stage_id,
		"world": chapter,
		"chapter": chapter,
		"zone": zone,
		"name": "Chapter %d Stage %d" % [chapter, slot],
		"name_zh": "第%d章・%s" % [chapter, ENDLESS_STAGE_NAMES[slot - 1]],
		"question_types": question_types,
		"min_number": 1,
		"max_number": addition_max,
		"operation_ranges": {
			"addition": {"min": 1, "max": addition_max},
			"subtraction": {"min": 1, "max": addition_max},
			"multiplication": {"min": 1, "max": multiplication_max},
			"division": {"min": 1, "max": multiplication_max}
		},
		"monster_id": monster_id,
		"monster_hp": GameBalance.generated_monster_hp(stage_id, is_boss),
		"monster_attack": GameBalance.generated_monster_attack(stage_id, is_boss),
		"reward_exp": GameBalance.generated_reward_exp(stage_id, is_boss),
		"reward_coin": GameBalance.generated_reward_coin(stage_id, is_boss),
		"map_position": [map_position.x, map_position.y],
		"is_boss": is_boss,
		"is_endless": true
	}

func _question_types_for_stage(chapter: int, slot: int) -> Array[String]:
	if chapter == 2:
		if slot <= 3:
			return ["addition", "subtraction"]
		if slot <= 6:
			return ["multiplication"]
		if slot <= 8:
			return ["division"]
		return ["addition", "subtraction", "multiplication", "division"]
	match slot:
		1, 2:
			return ["addition", "subtraction"]
		3, 4:
			return ["multiplication"]
		5, 6:
			return ["division"]
		_:
			return ["addition", "subtraction", "multiplication", "division"]

func _zone_for_slot(slot: int) -> String:
	if slot <= 3:
		return "flower_meadow"
	if slot <= 7:
		return "sakura_woods"
	return "starlight_hill"

func _last_authored_stage_id() -> int:
	var ids: Array = stages.keys()
	if ids.is_empty():
		return 0
	ids.sort()
	return int(ids.back())

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("Data file does not exist: %s" % path)
		return []

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open data file: %s" % path)
		return []

	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error != OK or not json.data is Array:
		push_error("Data file must contain a valid array: %s" % path)
		return []
	return json.data

func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Gacha data file does not exist: %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open gacha data file: %s" % path)
		return {}
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error != OK or not json.data is Dictionary:
		push_warning("Gacha data file must contain a valid object: %s" % path)
		return {}
	return json.data

func _index_by_id(items: Array, numeric_id: bool) -> Dictionary:
	var indexed: Dictionary = {}
	for item_variant: Variant in items:
		if not item_variant is Dictionary:
			push_warning("Ignoring non-object data entry")
			continue
		var item: Dictionary = item_variant
		if not item.has("id"):
			push_warning("Ignoring data entry without an id")
			continue
		var key: Variant = int(item["id"]) if numeric_id else str(item["id"])
		indexed[key] = item
	return indexed

func _copy_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}
