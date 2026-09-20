extends Node

## Language state and translation-table access for Traditional Chinese, English,
## and Japanese. The UI is code-built, so screens rebuild on language change;
## every string resolves through the shared i18n table.

signal language_changed(language: String)

const LANGUAGE_ZH_TW: String = "zh_tw"
const LANGUAGE_EN: String = "en"
const LANGUAGE_JA: String = "ja"
const LANGUAGES: Array[String] = [LANGUAGE_ZH_TW, LANGUAGE_EN, LANGUAGE_JA]
const DEFAULT_LANGUAGE: String = LANGUAGE_ZH_TW
const I18N_PATH: String = "res://data/i18n.json"

var _table: Dictionary = {}

func _ready() -> void:
	_table = _load_table()

func get_language() -> String:
	var stored: String = str(GameManager.player_state.get("language", DEFAULT_LANGUAGE))
	return stored if LANGUAGES.has(stored) else DEFAULT_LANGUAGE

func set_language(language: String) -> bool:
	if not LANGUAGES.has(language):
		return false
	if get_language() == language:
		return true
	GameManager.player_state["language"] = language
	GameManager.commit_state()
	language_changed.emit(language)
	return true

func cycle_language() -> String:
	var index: int = LANGUAGES.find(get_language())
	var next_language: String = LANGUAGES[(index + 1) % LANGUAGES.size()]
	set_language(next_language)
	return next_language

func language_name(language: String) -> String:
	# Each language name is rendered with that language's own font so the
	# current CJK font never has to cover glyphs from another script.
	match language:
		LANGUAGE_EN:
			return "English"
		LANGUAGE_JA:
			return "日本語"
		_:
			return "繁體中文"

func current_language_name() -> String:
	return language_name(get_language())

func t(key: String) -> String:
	var entry: Dictionary = _entry(key)
	var field: String = _field_for_language(get_language())
	if entry.has(field) and not str(entry[field]).is_empty():
		return str(entry[field])
	if entry.has("en") and not str(entry["en"]).is_empty():
		return str(entry["en"])
	if entry.has("zh") and not str(entry["zh"]).is_empty():
		return str(entry["zh"])
	return key

func _field_for_language(language: String) -> String:
	match language:
		LANGUAGE_EN:
			return "en"
		LANGUAGE_JA:
			return "ja"
		_:
			return "zh"

func tf(key: String, args: Array = []) -> String:
	var template: String = t(key)
	if args.is_empty():
		return template
	return template % args

## Returns [primary, secondary] for the active language. In zh_tw mode the pair
## reproduces the original dual-language layout exactly; en/ja render a single
## primary line so foreign-language strings never overflow their two-line slots.
## When args is non-empty both lines are formatted with it (extra args in a
## template without placeholders are ignored by GDScript formatting).
func pair(key: String, args: Array = []) -> Array:
	var entry: Dictionary = _entry(key)
	var language: String = get_language()
	var zh: String = str(entry.get("zh", ""))
	var zh2: String = str(entry.get("zh2", str(entry.get("en", ""))))
	var en: String = str(entry.get("en", ""))
	var ja: String = str(entry.get("ja", ""))
	var en_first: bool = bool(entry.get("en_first", false))
	var primary: String
	var secondary: String
	if language == LANGUAGE_EN:
		primary = en
		secondary = ""
	elif language == LANGUAGE_JA:
		primary = ja if not ja.is_empty() else en
		secondary = ""
	elif en_first:
		primary = en
		secondary = zh
	elif not zh2.is_empty() and zh2 != zh:
		primary = zh
		secondary = zh2
	else:
		primary = zh
		secondary = en
	if not args.is_empty():
		# GDScript formatting demands an exact argument count, so only lines
		# that actually contain placeholders are formatted.
		if primary.contains("%"):
			primary = primary % args
		if secondary.contains("%"):
			secondary = secondary % args
	return [primary, secondary]

## Picks a data-driven display name per language: name_zh / name / name_ja.
func pick(data: Dictionary) -> String:
	match get_language():
		LANGUAGE_JA:
			var ja_name: String = str(data.get("name_ja", ""))
			if not ja_name.is_empty():
				return ja_name
			return str(data.get("name", data.get("name_zh", "")))
		LANGUAGE_EN:
			return str(data.get("name", data.get("name_zh", "")))
		_:
			return str(data.get("name_zh", data.get("name", "")))

func _entry(key: String) -> Dictionary:
	var raw: Variant = _table.get(key, {})
	return raw if raw is Dictionary else {}

func _load_table() -> Dictionary:
	if not FileAccess.file_exists(I18N_PATH):
		push_error("i18n table missing: %s" % I18N_PATH)
		return {}
	var file: FileAccess = FileAccess.open(I18N_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(file.get_as_text())
	if parse_error != OK or not json.data is Dictionary:
		push_error("i18n table is invalid: %s" % I18N_PATH)
		return {}
	return json.data
