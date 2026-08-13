class_name GameBalance
extends RefCounted

## Central formulas for a progression loop that can continue past authored content.
const BASE_HEARTS: int = 3
const MAX_DISPLAY_HEARTS: int = 12
const BASE_MAX_HP: int = 30
const BASE_ATTACK: int = 10
const BASE_DEFENSE: int = 0
const BASE_LUCK: int = 0
const BASE_LEVEL: int = 1
const BASE_EXP: int = 0
const BASE_COINS: int = 0
const BASE_GEMS: int = 300
const STARTING_STAGE: int = 1
const DEFAULT_CHARACTER_ID: String = "sprout_goblin"

const STAGES_PER_CHAPTER: int = 10
# A practical guard against corrupt saves while remaining effectively endless.
const MAX_STAGE_ID: int = 2_000_000_000
# Kept as a compatibility sentinel for older callers. Inventory normalization
# no longer enforces a fixed capacity; the character UI displays an infinity
# marker instead.
const INVENTORY_CAPACITY: int = -1
# Keep endless-run metadata bounded so a long local save remains small and
# reliable. Authored World 1 records are retained separately during cleanup.
const MAX_PERSISTED_STAGE_RECORDS: int = 128
const REPLAY_REWARD_MULTIPLIER: float = 0.5
const MAX_STAGE_STARS: int = 3

# The auto-attack clock is intentionally generous at the start and tightens
# gradually. The hard floor keeps late endless stages tense without making a
# World 1 child solve mixed arithmetic under an overly short timer.
const BASE_ENEMY_ATTACK_INTERVAL: float = 7.0
const MIN_ENEMY_ATTACK_INTERVAL: float = 2.8
const ENEMY_ATTACK_INTERVAL_DECAY: float = 0.975
# Bosses create a readable pressure spike without turning World 1 into a
# reaction-time test. The following normal chapter stage returns to the
# continuous curve, giving children a small recovery beat after a boss.
const BOSS_ATTACK_INTERVAL_MULTIPLIER: float = 0.92

const LEVEL_ATTACK_GAIN: int = 2
const LEVEL_HP_GAIN: int = 4
const LEVEL_STAT_POINT_GAIN: int = 1

const COMBO_2_MULTIPLIER: float = 1.1
const COMBO_5_MULTIPLIER: float = 1.25
const COMBO_10_MULTIPLIER: float = 1.5

const FIRST_CLEAR_GEM_REWARD: int = 30
const AD_GEM_REWARD: int = 100
const GACHA_SINGLE_COST: int = 100
const GACHA_TEN_COST: int = 1000

const RARITY_MULTIPLIERS: Dictionary = {
	"common": 1.0,
	"uncommon": 1.22,
	"rare": 1.52,
	"epic": 1.9,
	"legendary": 2.35
}

static func combo_multiplier(combo: int) -> float:
	if combo >= 10:
		return COMBO_10_MULTIPLIER
	if combo >= 5:
		return COMBO_5_MULTIPLIER
	if combo >= 2:
		return COMBO_2_MULTIPLIER
	return 1.0

static func calculate_damage(attack: int, combo: int) -> int:
	var raw_damage: float = float(maxi(1, attack)) * combo_multiplier(combo)
	return maxi(1, int(floor(raw_damage)))

static func stage_stars(mistakes: int) -> int:
	# Every clear earns at least one star. A clean run earns three, while two
	# mistakes still leave a meaningful two-star result for younger players.
	var safe_mistakes: int = maxi(0, mistakes)
	if safe_mistakes == 0:
		return MAX_STAGE_STARS
	if safe_mistakes <= 2:
		return 2
	return 1

static func reward_multiplier_for_clear(first_clear: bool) -> float:
	return 1.0 if first_clear else REPLAY_REWARD_MULTIPLIER

static func required_exp(level: int) -> int:
	var safe_level: int = maxi(1, level)
	return maxi(100, int(round(70.0 + 42.0 * pow(float(safe_level), 1.12))))

static func chapter_for_stage(stage_id: int) -> int:
	return maxi(1, int(floor(float(maxi(1, stage_id) - 1) / float(STAGES_PER_CHAPTER))) + 1)

static func slot_for_stage(stage_id: int) -> int:
	return posmod(maxi(1, stage_id) - 1, STAGES_PER_CHAPTER) + 1

static func first_stage_for_chapter(chapter: int) -> int:
	return ((maxi(1, chapter) - 1) * STAGES_PER_CHAPTER) + 1

static func is_boss_stage(stage_id: int) -> bool:
	return slot_for_stage(stage_id) == STAGES_PER_CHAPTER

static func generated_monster_hp(stage_id: int, is_boss: bool = false) -> int:
	var safe_stage: int = clampi(stage_id, 1, MAX_STAGE_ID)
	# Authored Stage 10 has 72 HP. Endless content starts from that power band
	# and grows by stage so the chapter transition is readable and fair.
	var endless_step: float = float(maxi(0, safe_stage - 10))
	var hp: float = 72.0 + (endless_step * 10.0) + (2.0 * pow(endless_step, 1.1))
	if is_boss:
		# A small boss bump is deliberately smaller than the next stage's normal
		# growth, preventing a post-boss HP regression.
		hp += 8.0
	return maxi(1, int(round(hp)))

static func generated_monster_attack(stage_id: int, _is_boss: bool = false) -> int:
	var safe_stage: int = clampi(stage_id, 1, MAX_STAGE_ID)
	# Keep the generated curve continuous with the authored World 1 curve:
	# Stage 10 is 20 ATK, so the first endless stage must not fall back to 16.
	# Bosses get their extra pressure from HP and a faster timer. Keeping ATK on
	# one continuous line prevents the normal stage after a boss from becoming
	# unexpectedly weaker.
	var attack: int = 10 + safe_stage
	return maxi(1, attack)

static func enemy_attack_interval(stage_id: int, is_boss: bool = false) -> float:
	var safe_stage: int = clampi(stage_id, 1, MAX_STAGE_ID)
	var interval: float = BASE_ENEMY_ATTACK_INTERVAL * pow(ENEMY_ATTACK_INTERVAL_DECAY, float(safe_stage - 1))
	if is_boss:
		interval *= BOSS_ATTACK_INTERVAL_MULTIPLIER
	return clampf(interval, MIN_ENEMY_ATTACK_INTERVAL, BASE_ENEMY_ATTACK_INTERVAL)

static func generated_reward_exp(stage_id: int, is_boss: bool = false) -> int:
	var reward: int = 30 + (clampi(stage_id, 1, MAX_STAGE_ID) * 12)
	return reward * 2 if is_boss else reward

static func generated_reward_coin(stage_id: int, is_boss: bool = false) -> int:
	var reward: int = 8 + (clampi(stage_id, 1, MAX_STAGE_ID) * 3)
	return int(ceil(float(reward) * 1.75)) if is_boss else reward

static func rarity_multiplier(rarity: String) -> float:
	return float(RARITY_MULTIPLIERS.get(rarity, 1.0))

static func equipment_stat_value(base_value: float, item_level: int, rarity: String) -> int:
	if base_value <= 0.0:
		return 0
	var level_multiplier: float = 1.0 + (float(maxi(1, item_level) - 1) * 0.12)
	return maxi(1, int(round(base_value * level_multiplier * rarity_multiplier(rarity))))

static func equipment_upgrade_cost(item_level: int, rarity: String) -> int:
	var rarity_cost: float = rarity_multiplier(rarity)
	return maxi(10, int(round(18.0 * pow(float(maxi(1, item_level)), 1.35) * rarity_cost)))

static func equipment_sell_value(item_level: int, rarity: String) -> int:
	return maxi(5, int(round(float(equipment_upgrade_cost(item_level, rarity)) * 0.45)))

static func damage_taken(monster_attack: int, defense: int) -> int:
	var safe_attack: int = maxi(1, monster_attack)
	# Armor can never erase the learning consequence of a wrong answer. The 25%
	# floor prevents all-defense builds from becoming invulnerable in late chapters.
	var mitigation_floor: int = maxi(1, int(ceil(float(safe_attack) * 0.25)))
	return maxi(mitigation_floor, safe_attack - maxi(0, defense))
