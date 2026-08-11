class_name QuestionGenerator
extends RefCounted

## Generates valid arithmetic questions entirely from authored/generated stage data.
const RECENT_QUESTION_LIMIT: int = 4
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var recent_question_texts: Array[String] = []

func _init() -> void:
	rng.randomize()

func set_seed(value: int) -> void:
	rng.seed = value
	recent_question_texts.clear()

func generate(stage_data: Dictionary) -> Dictionary:
	var raw_types: Variant = stage_data.get("question_types", ["addition"])
	var types: Array = raw_types if raw_types is Array else ["addition"]
	if types.is_empty():
		types = ["addition"]
	var selected_type: String = str(types[rng.randi_range(0, types.size() - 1)])
	if not ["addition", "subtraction", "multiplication", "division"].has(selected_type):
		selected_type = "addition"
	var number_range: Vector2i = _range_for_type(stage_data, selected_type)

	var question: Dictionary = {}
	# Keep a short memory so a child does not see the same arithmetic prompt in
	# consecutive turns. Tiny authored ranges can still repeat after all valid
	# combinations have been exhausted.
	for attempt: int in range(8):
		match selected_type:
			"subtraction":
				question = _make_subtraction(number_range.x, number_range.y)
			"multiplication":
				question = _make_multiplication(number_range.x, number_range.y)
			"division":
				question = _make_division(number_range.x, number_range.y)
			_:
				question = _make_addition(number_range.x, number_range.y)
		if not recent_question_texts.has(str(question.get("question_text", ""))) or attempt == 7:
			break
	if not str(question.get("question_text", "")).is_empty():
		recent_question_texts.push_front(str(question.get("question_text", "")))
		if recent_question_texts.size() > RECENT_QUESTION_LIMIT:
			recent_question_texts.pop_back()
	return question

func _range_for_type(stage_data: Dictionary, question_type: String) -> Vector2i:
	var min_number: int = maxi(1, int(stage_data.get("min_number", 1)))
	var max_number: int = maxi(min_number, int(stage_data.get("max_number", 10)))
	var operation_ranges: Variant = stage_data.get("operation_ranges", {})
	if operation_ranges is Dictionary:
		var typed_range: Variant = operation_ranges.get(question_type, {})
		if typed_range is Dictionary:
			min_number = maxi(1, int(typed_range.get("min", min_number)))
			max_number = maxi(min_number, int(typed_range.get("max", max_number)))
	return Vector2i(min_number, max_number)

func _make_addition(min_number: int, max_number: int) -> Dictionary:
	var left: int = rng.randi_range(min_number, max_number)
	var right: int = rng.randi_range(min_number, max_number)
	return _question("%d + %d" % [left, right], left + right, "addition")

func _make_subtraction(min_number: int, max_number: int) -> Dictionary:
	var left: int = rng.randi_range(min_number, max_number)
	var right: int = rng.randi_range(min_number, max_number)
	if right > left:
		var swap_value: int = left
		left = right
		right = swap_value
	return _question("%d - %d" % [left, right], left - right, "subtraction")

func _make_multiplication(min_number: int, max_number: int) -> Dictionary:
	var left: int = rng.randi_range(min_number, max_number)
	var right: int = rng.randi_range(min_number, max_number)
	return _question("%d × %d" % [left, right], left * right, "multiplication")

func _make_division(min_number: int, max_number: int) -> Dictionary:
	var divisor: int = rng.randi_range(maxi(1, min_number), max_number)
	var quotient: int = rng.randi_range(min_number, max_number)
	var dividend: int = divisor * quotient
	return _question("%d ÷ %d" % [dividend, divisor], quotient, "division")

func _question(text: String, answer: int, question_type: String) -> Dictionary:
	return {
		"question_text": text,
		"answer": answer,
		"type": question_type
	}
