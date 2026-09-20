extends Control

## Answer correctly to attack; wrong answers let the monster strike back.
const MAX_ANSWER_DIGITS: int = 6
const BATTLE_BACKGROUND_BY_ZONE: Dictionary = {
	"flower_meadow": "res://assets/ui/battle/battle_flower_meadow_bg_v1.png",
	"sakura_woods": "res://assets/ui/battle/battle_sakura_woods_bg_v1.png",
	"starlight_hill": "res://assets/ui/battle/battle_starlight_hill_bg_v1.png"
}
const AMBIENT_EFFECT_PATH: String = "res://assets/ui/battle/battle_ambient_effects_v1.png"
const START_EFFECT_FALLBACK_PATH: String = "res://assets/ui/start/start_effects_v2.png"
const GROUND_GLOW_PATH: String = "res://assets/ui/battle/battle_ground_glow_v1.png"
const HIT_EFFECT_PATH: String = "res://assets/ui/battle/battle_hit_effect_v1.png"
const MISS_EFFECT_PATH: String = "res://assets/ui/battle/battle_miss_effect_v1.png"
const ANSWER_PANEL_PATH: String = "res://assets/ui/battle/battle_answer_panel_v1.png"
const KEY_BUTTON_SKIN_PATH: String = "res://assets/ui/battle/battle_key_button_skin_v1.png"
const RESULT_PANEL_PATH: String = "res://assets/ui/battle/battle_result_panel_v1.png"
const HEART_ICON_PATH: String = "res://assets/ui/battle/battle_heart_icon_v1.png"
const DIAMOND_ICON_PATH: String = "res://assets/ui/gacha/gacha_diamond_icon_v1.png"
var stage_data: Dictionary = {}
var monster_data: Dictionary = {}
var question_generator: QuestionGenerator
var current_question: Dictionary = {}
var question_index: int = 0
var answer_text: String = ""
var player_hp: int = GameBalance.BASE_MAX_HP
var player_max_hp: int = GameBalance.BASE_MAX_HP
var monster_hp: int = 0
var monster_attack: int = 1
var combo: int = 0
var highest_combo: int = 0
var correct_answers: int = 0
var mistake_count: int = 0
var input_locked: bool = false
var enemy_attack_timer: Timer
var enemy_attack_interval: float = 0.0
var enemy_auto_attack_count: int = 0
var enemy_attack_in_progress: bool = false
var battle_suspended: bool = false
var battle_paused: bool = false

var battle_background_layer: TextureRect
var battle_ambient_layer: TextureRect
var battle_ground_layer: TextureRect
var battle_fx_layer: Control
var battle_hud_layer: Control
var battle_pause_layer: Control
var battle_result_layer: Control
var battle_keypad_layer: GridContainer
var content: VBoxContainer
var actor_stage: Control
var player_sprite: TextureRect
var monster_sprite: TextureRect
var monster_hp_bar: ProgressBar
var monster_hp_text: Label
var enemy_attack_label: Label
var enemy_attack_panel: Panel
var question_label: Label
var answer_label: Label
var hearts_label: Label
var heart_icons_container: HBoxContainer
var heart_icons: Array[TextureRect] = []
var level_label: Label
var battle_pause_button: Button
var combo_label: Label
var feedback_panel: Panel
var feedback_label: Label
var keypad_buttons: Array[Button] = []

func _ready() -> void:
	var stage_id: int = int(GameManager.player_state.get("current_stage", 1))
	stage_data = DataManager.get_stage(stage_id)
	if stage_data.is_empty():
		push_warning("Battle received an invalid stage. Returning to map.")
		GameManager.go_to_world_map()
		return
	monster_data = DataManager.get_monster(str(stage_data.get("monster_id", "green_blob")))
	if monster_data.is_empty():
		push_warning("Battle received an invalid monster. Returning to map.")
		GameManager.go_to_world_map()
		return
	question_generator = QuestionGenerator.new()
	player_max_hp = GameManager.get_max_hp()
	player_hp = player_max_hp
	monster_hp = _get_monster_max_hp()
	monster_attack = _get_monster_attack()
	enemy_attack_interval = GameBalance.enemy_attack_interval(stage_id, bool(stage_data.get("is_boss", false)))
	_build_screen()
	_load_next_question()
	_start_enemy_attack_timer()

func _build_screen() -> void:
	var authored_background_available: bool = _add_battle_background()
	if not authored_background_available:
		UITheme.add_gradient_background(self, Color("#b8e8f3"), Color("#ffd2df"))
		_add_battle_decorations()
	_add_battle_ambient()
	_add_battle_ground()
	battle_fx_layer = _make_full_layer("BattleFxLayer", Control.MOUSE_FILTER_IGNORE)
	battle_hud_layer = _make_full_layer("BattleHudLayer", Control.MOUSE_FILTER_PASS)
	var safe: MarginContainer = UITheme.make_safe_margin(battle_hud_layer, 46)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(content)

	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 112)
	content.add_child(top_bar)
	var health_status: HBoxContainer = HBoxContainer.new()
	health_status.name = "HealthStatus"
	health_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_status.add_theme_constant_override("separation", 12)
	health_status.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_bar.add_child(health_status)
	hearts_label = UITheme.make_label("HP %d / %d" % [player_hp, player_max_hp], 31, Color("#8c2946"))
	hearts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hearts_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	health_status.add_child(hearts_label)
	heart_icons_container = HBoxContainer.new()
	heart_icons_container.name = "HeartIcons"
	heart_icons_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart_icons_container.add_theme_constant_override("separation", 3)
	heart_icons_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	health_status.add_child(heart_icons_container)
	if ResourceLoader.exists(HEART_ICON_PATH):
		for _index: int in range(GameManager.get_player_hearts()):
			var heart_icon: TextureRect = _make_sprite(HEART_ICON_PATH, Vector2(36, 36))
			heart_icon.name = "HeartIcon%d" % _index
			heart_icon.custom_minimum_size = Vector2(36, 36)
			heart_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			heart_icons_container.add_child(heart_icon)
			heart_icons.append(heart_icon)
	level_label = UITheme.make_label("LV.1\nATK 10  DEF 0", 24, UITheme.INK)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.custom_minimum_size = Vector2(180, 0)
	top_bar.add_child(level_label)
	battle_pause_button = UITheme.make_tr_button("battle.pause", Color("#d9edf0"), Vector2(140, 96))
	battle_pause_button.name = "BattlePauseButton"
	battle_pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	battle_pause_button.pressed.connect(_on_pause_pressed)
	top_bar.add_child(battle_pause_button)

	var stage_id: int = int(stage_data.get("id", 1))
	var stage_display_name: String = LanguageManager.pick(stage_data)
	var battle_badge: VBoxContainer = UITheme.make_trf_en_dual("battle.stage_badge", [stage_id], 29, 17, UITheme.INK)
	if LanguageManager.get_language() == LanguageManager.LANGUAGE_ZH_TW:
		# The original zh_tw layout shows the authored stage name under the badge.
		var badge_secondary: Label = battle_badge.get_node_or_null("SecondaryLabel") as Label
		if badge_secondary != null:
			badge_secondary.text = stage_display_name
	battle_badge.custom_minimum_size = Vector2(0, 70)
	content.add_child(battle_badge)

	actor_stage = Control.new()
	actor_stage.name = "BattleActorLayer"
	actor_stage.custom_minimum_size = Vector2(0, 346)
	actor_stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actor_stage.clip_contents = true
	content.add_child(actor_stage)
	player_sprite = _make_sprite(_get_player_sprite_path(), Vector2(230, 230))
	monster_sprite = _make_sprite(_get_monster_sprite_path(), Vector2(310, 310))
	actor_stage.add_child(player_sprite)
	actor_stage.add_child(monster_sprite)
	player_sprite.position = Vector2(55, 86)
	monster_sprite.position = Vector2(580, 10)

	var monster_name: VBoxContainer = _make_monster_badge()
	monster_name.custom_minimum_size = Vector2(0, 72)
	content.add_child(monster_name)
	monster_hp_bar = ProgressBar.new()
	monster_hp_bar.max_value = monster_hp
	monster_hp_bar.value = monster_hp
	monster_hp_bar.show_percentage = false
	monster_hp_bar.custom_minimum_size = Vector2(0, 34)
	monster_hp_bar.add_theme_stylebox_override("background", UITheme.rounded_style(Color("#fff2ed"), Color("#74433e"), 16, 4))
	monster_hp_bar.add_theme_stylebox_override("fill", UITheme.rounded_style(Color("#ef7a91"), Color.TRANSPARENT, 16, 0))
	content.add_child(monster_hp_bar)
	monster_hp_text = UITheme.make_label("HP %d / %d" % [monster_hp, monster_hp], 19, UITheme.MUTED_INK)
	monster_hp_text.custom_minimum_size = Vector2(0, 34)
	content.add_child(monster_hp_text)
	enemy_attack_panel = UITheme.make_panel(Color(1.0, 0.96, 0.90, 0.78), Color("#d9b36a"), 18, 2)
	enemy_attack_panel.name = "EnemyAttackStatusPanel"
	enemy_attack_panel.custom_minimum_size = Vector2(0, 46)
	enemy_attack_panel.add_theme_stylebox_override("panel", _status_style(Color(1.0, 0.96, 0.90, 0.78), Color("#d9b36a"), 2))
	enemy_attack_label = UITheme.make_label("", 18, UITheme.MUTED_INK)
	enemy_attack_label.name = "EnemyAttackCountdown"
	enemy_attack_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enemy_attack_label.offset_left = 12.0
	enemy_attack_label.offset_right = -12.0
	enemy_attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_attack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_attack_panel.add_child(enemy_attack_label)
	content.add_child(enemy_attack_panel)

	question_label = UITheme.make_label("", 76, UITheme.INK)
	question_label.custom_minimum_size = Vector2(0, 132)
	content.add_child(question_label)

	var answer_panel: Panel = UITheme.make_panel(Color(1, 0.98, 0.93, 0.95), Color("#74433e"), 32, 5)
	UITheme.apply_texture_panel_skin(answer_panel, ANSWER_PANEL_PATH, 38)
	answer_panel.custom_minimum_size = Vector2(0, 122)
	content.add_child(answer_panel)
	answer_label = UITheme.make_label("—", 54, UITheme.INK)
	answer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	answer_panel.add_child(answer_label)

	combo_label = UITheme.make_label("", 25, UITheme.ORANGE)
	combo_label.custom_minimum_size = Vector2(0, 48)
	content.add_child(combo_label)
	feedback_panel = UITheme.make_panel(Color.TRANSPARENT, Color.TRANSPARENT, 20, 0)
	feedback_panel.name = "BattleFeedbackPanel"
	feedback_panel.custom_minimum_size = Vector2(0, 72)
	feedback_panel.add_theme_stylebox_override("panel", _status_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	feedback_label = UITheme.make_label("", 21, UITheme.MUTED_INK)
	feedback_label.name = "BattleFeedbackLabel"
	feedback_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback_label.offset_left = 18.0
	feedback_label.offset_right = -18.0
	feedback_label.offset_top = 6.0
	feedback_label.offset_bottom = -6.0
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_panel.add_child(feedback_label)
	content.add_child(feedback_panel)

	var keypad: GridContainer = GridContainer.new()
	keypad.name = "BattleKeypadLayer"
	battle_keypad_layer = keypad
	keypad.columns = 3
	keypad.add_theme_constant_override("h_separation", 14)
	keypad.add_theme_constant_override("v_separation", 14)
	keypad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keypad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(keypad)
	var keys: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "✓"]
	for key: String in keys:
		var key_color: Color = UITheme.PINK
		if key == "✓":
			key_color = UITheme.GREEN
		elif key == "0" or key == "4" or key == "5" or key == "6" or key == "7" or key == "8" or key == "9":
			key_color = UITheme.YELLOW
		var button: Button = UITheme.make_key_button(key, key_color)
		UITheme.apply_texture_button_skin(button, KEY_BUTTON_SKIN_PATH, key_color, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		keypad.add_child(button)
		keypad_buttons.append(button)
		if key == "⌫":
			button.pressed.connect(_on_backspace_pressed)
		elif key == "✓":
			button.pressed.connect(_on_submit_pressed)
		else:
			button.pressed.connect(_on_digit_pressed.bind(key))

	_update_hearts()
	_update_level()
	move_child(battle_fx_layer, get_child_count() - 1)

func _make_monster_badge() -> VBoxContainer:
	var english_name: String = str(monster_data.get("name", "Green Blob"))
	var local_name: String = LanguageManager.pick(monster_data)
	match LanguageManager.get_language():
		LanguageManager.LANGUAGE_ZH_TW:
			return UITheme.make_pair_stack(english_name, "%s  ·  ATK %d" % [local_name, monster_attack], 28, 17, UITheme.INK, false)
		LanguageManager.LANGUAGE_JA:
			return UITheme.make_pair_stack("%s  ·  こうげき %d" % [local_name, monster_attack], "", 28, 17, UITheme.INK, false)
		_:
			return UITheme.make_pair_stack("%s  ·  ATK %d" % [english_name, monster_attack], "", 28, 17, UITheme.INK, false)

func _make_full_layer(layer_name: String, filter: Control.MouseFilter) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = filter
	add_child(layer)
	return layer

func _status_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = UITheme.rounded_style(background, border, 20, border_width)
	style.shadow_color = Color.TRANSPARENT
	style.shadow_size = 0
	return style

func _start_enemy_attack_timer() -> void:
	enemy_attack_timer = Timer.new()
	enemy_attack_timer.name = "EnemyAttackTimer"
	enemy_attack_timer.wait_time = enemy_attack_interval
	enemy_attack_timer.one_shot = false
	enemy_attack_timer.timeout.connect(_on_enemy_attack_timer_timeout)
	add_child(enemy_attack_timer)
	enemy_attack_timer.start()
	_update_enemy_attack_countdown()

func _process(_delta: float) -> void:
	_update_enemy_attack_countdown()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		battle_suspended = true
		if enemy_attack_timer != null:
			enemy_attack_timer.stop()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		battle_suspended = false
		_start_enemy_attack_clock()

func _start_enemy_attack_clock() -> void:
	if enemy_attack_timer == null or battle_suspended or battle_paused or input_locked or battle_result_layer != null or player_hp <= 0:
		return
	enemy_attack_timer.start()
	_update_enemy_attack_countdown()

func _update_enemy_attack_countdown() -> void:
	if enemy_attack_label == null:
		return
	if battle_result_layer != null or player_hp <= 0:
		enemy_attack_label.text = ""
		return
	if battle_paused:
		enemy_attack_label.text = LanguageManager.t("battle.countdown_paused")
		enemy_attack_label.add_theme_color_override("font_color", UITheme.MUTED_INK)
		return
	if battle_suspended:
		enemy_attack_label.text = LanguageManager.t("battle.countdown_suspended")
		enemy_attack_label.add_theme_color_override("font_color", UITheme.MUTED_INK)
		return
	if enemy_attack_in_progress:
		enemy_attack_label.text = LanguageManager.t("battle.enemy_attacking")
		enemy_attack_label.add_theme_color_override("font_color", UITheme.RED.darkened(0.1))
		return
	if enemy_attack_timer == null:
		return
	var seconds_left: int = maxi(1, int(ceil(enemy_attack_timer.time_left)))
	var incoming_damage: int = GameManager.calculate_incoming_damage(monster_attack)
	enemy_attack_label.text = LanguageManager.tf("battle.auto_attack_countdown", [seconds_left, incoming_damage])
	var countdown_color: Color = UITheme.RED if seconds_left <= 2 else UITheme.MUTED_INK
	enemy_attack_label.add_theme_color_override("font_color", countdown_color)

func _add_battle_background() -> bool:
	battle_background_layer = TextureRect.new()
	battle_background_layer.name = "BattleBackgroundLayer"
	battle_background_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battle_background_layer.stretch_mode = TextureRect.STRETCH_SCALE
	battle_background_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_background_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battle_background_layer)
	move_child(battle_background_layer, 0)
	var zone: String = str(stage_data.get("zone", "flower_meadow"))
	var background_path: String = str(BATTLE_BACKGROUND_BY_ZONE.get(zone, BATTLE_BACKGROUND_BY_ZONE["flower_meadow"]))
	if not ResourceLoader.exists(background_path):
		return false
	battle_background_layer.texture = load(background_path)
	return battle_background_layer.texture != null

func _add_battle_ambient() -> void:
	battle_ambient_layer = TextureRect.new()
	battle_ambient_layer.name = "BattleAmbientLayer"
	battle_ambient_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battle_ambient_layer.stretch_mode = TextureRect.STRETCH_SCALE
	battle_ambient_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_ambient_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ambient_path: String = AMBIENT_EFFECT_PATH
	if str(stage_data.get("zone", "")) == "starlight_hill" and ResourceLoader.exists(START_EFFECT_FALLBACK_PATH):
		ambient_path = START_EFFECT_FALLBACK_PATH
	if ResourceLoader.exists(ambient_path):
		battle_ambient_layer.texture = load(ambient_path)
	battle_ambient_layer.modulate = Color(1.0, 1.0, 1.0, 0.42)
	add_child(battle_ambient_layer)

func _add_battle_ground() -> void:
	battle_ground_layer = TextureRect.new()
	battle_ground_layer.name = "BattleGroundLayer"
	battle_ground_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battle_ground_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	battle_ground_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_ground_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(GROUND_GLOW_PATH):
		battle_ground_layer.texture = load(GROUND_GLOW_PATH)
		battle_ground_layer.modulate = Color(1.0, 1.0, 1.0, 0.56)
	add_child(battle_ground_layer)

func _get_player_sprite_path() -> String:
	return GameManager.get_character_sprite_path()

func _make_sprite(path: String, sprite_size: Vector2) -> TextureRect:
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = load(path)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = sprite_size
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite

func _get_monster_sprite_path() -> String:
	var generated_path: String = str(monster_data.get("generated_sprite", ""))
	if not generated_path.is_empty() and ResourceLoader.exists(generated_path):
		return generated_path
	var fallback_path: String = str(monster_data.get("sprite", "res://assets/monsters/green_blob.svg"))
	if ResourceLoader.exists(fallback_path):
		return fallback_path
	push_warning("Missing monster sprite for '%s'; using green blob fallback." % str(monster_data.get("id", "unknown")))
	return "res://assets/monsters/green_blob.svg"

func _load_next_question() -> void:
	if input_locked:
		return
	answer_text = ""
	answer_label.text = "—"
	_set_feedback("", UITheme.MUTED_INK, Color.TRANSPARENT, Color.TRANSPARENT, 0)
	var scripted_question: Variant = stage_data.get("scripted_first_question", {})
	if question_index == 0 and scripted_question is Dictionary and scripted_question.has("question_text") and scripted_question.has("answer"):
		current_question = scripted_question.duplicate(true)
	else:
		current_question = question_generator.generate(stage_data)
	question_index += 1
	question_label.text = str(current_question.get("question_text", "5 + 3"))
	_update_combo()

func _on_digit_pressed(value: String) -> void:
	if input_locked or answer_text.length() >= MAX_ANSWER_DIGITS:
		return
	# Zero is normally blocked as a leading digit, but subtraction can fairly
	# generate an answer of exactly 0. That answer must remain enterable.
	if answer_text.is_empty() and value == "0" and int(current_question.get("answer", -1)) != 0:
		return
	AudioManager.play_sfx("button_click")
	answer_text += value
	answer_label.text = answer_text

func _on_backspace_pressed() -> void:
	if input_locked or answer_text.is_empty():
		return
	AudioManager.play_sfx("button_click")
	answer_text = answer_text.left(answer_text.length() - 1)
	answer_label.text = answer_text if not answer_text.is_empty() else "—"

func _on_submit_pressed() -> void:
	if input_locked or answer_text.is_empty():
		return
	AudioManager.play_sfx("button_click")
	input_locked = true
	_set_keypad_disabled(true)
	var submitted_answer: int = int(answer_text)
	var expected_answer: int = int(current_question.get("answer", -1))
	if submitted_answer == expected_answer:
		_resolve_correct()
	else:
		_resolve_wrong()

func _resolve_correct() -> void:
	combo += 1
	correct_answers += 1
	highest_combo = maxi(highest_combo, combo)
	var damage: int = GameManager.calculate_damage(combo)
	monster_hp = maxi(0, monster_hp - damage)
	monster_hp_bar.value = monster_hp
	monster_hp_text.text = "HP %d / %d" % [monster_hp, _get_monster_max_hp()]
	_set_feedback(LanguageManager.t("battle.correct"), UITheme.GREEN.darkened(0.35), Color("#eff9db"), Color("#94c67e"), 2)
	_update_combo()
	_show_damage_number(damage)
	_spawn_battle_effect(HIT_EFFECT_PATH, monster_sprite.get_global_rect().get_center(), Vector2(270, 270), 0.46)
	_flash(Color(0.65, 1, 0.72, 0.38))
	_play_attack_animation()
	await get_tree().create_timer(0.48).timeout
	if monster_hp <= 0:
		_show_victory()
	else:
		input_locked = false
		_set_keypad_disabled(false)
		_load_next_question()
		_start_enemy_attack_clock()

func _resolve_wrong() -> void:
	combo = 0
	mistake_count += 1
	var incoming_damage: int = GameManager.calculate_incoming_damage(monster_attack)
	player_hp = maxi(0, player_hp - incoming_damage)
	_set_feedback(LanguageManager.tf("battle.wrong", [incoming_damage]), UITheme.RED.darkened(0.15), Color("#fff0ef"), Color("#e89aa0"), 2)
	_update_combo()
	_update_hearts()
	_spawn_battle_effect(MISS_EFFECT_PATH, player_sprite.get_global_rect().get_center(), Vector2(210, 210), 0.42)
	_flash(Color(1, 0.47, 0.54, 0.3))
	_play_monster_attack_animation()
	await get_tree().create_timer(0.48).timeout
	if player_hp <= 0:
		_show_defeat()
	else:
		input_locked = false
		_set_keypad_disabled(false)
		_load_next_question()
		_start_enemy_attack_clock()

func _on_enemy_attack_timer_timeout() -> void:
	# A timeout that lands during answer feedback is ignored rather than
	# interrupting the child mid-input. The regular timer keeps the next window
	# predictable and the countdown makes the threat visible.
	if input_locked or battle_paused or player_hp <= 0 or battle_result_layer != null:
		return
	input_locked = true
	enemy_attack_in_progress = true
	enemy_attack_timer.stop()
	_set_keypad_disabled(true)
	var incoming_damage: int = GameManager.calculate_incoming_damage(monster_attack)
	player_hp = maxi(0, player_hp - incoming_damage)
	enemy_auto_attack_count += 1
	_set_feedback(LanguageManager.tf("battle.auto_attack_hit", [incoming_damage]), UITheme.RED.darkened(0.1), Color("#fff0ef"), Color("#e89aa0"), 2)
	_update_hearts()
	_show_player_damage_number(incoming_damage)
	_spawn_battle_effect(MISS_EFFECT_PATH, player_sprite.get_global_rect().get_center(), Vector2(210, 210), 0.42)
	_flash(Color(1, 0.28, 0.38, 0.34))
	_play_monster_attack_animation()
	await get_tree().create_timer(0.48).timeout
	enemy_attack_in_progress = false
	if player_hp <= 0:
		_show_defeat()
	else:
		input_locked = false
		_set_keypad_disabled(false)
		_start_enemy_attack_clock()

func _on_pause_pressed() -> void:
	if battle_paused or input_locked or battle_result_layer != null or player_hp <= 0:
		return
	AudioManager.play_sfx("button_click")
	battle_paused = true
	input_locked = true
	if enemy_attack_timer != null:
		enemy_attack_timer.stop()
	_set_keypad_disabled(true)
	if battle_pause_button != null:
		battle_pause_button.disabled = true
	_update_enemy_attack_countdown()
	_show_pause_overlay()

func _show_pause_overlay() -> void:
	if battle_pause_layer != null:
		return
	battle_pause_layer = Control.new()
	battle_pause_layer.name = "BattlePauseLayer"
	battle_pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(battle_pause_layer)

	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.18, 0.12, 0.16, 0.52)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_pause_layer.add_child(overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_pause_layer.add_child(center)
	var card: Panel = UITheme.make_panel(Color("#fff8e9"), Color("#f4d271"), 42, 6)
	UITheme.apply_texture_panel_skin(card, RESULT_PANEL_PATH, 48)
	card.custom_minimum_size = Vector2(760, 520)
	center.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 42)
	card.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)
	stack.add_child(UITheme.make_tr_en_dual("battle.pause_overlay", 56, 29, UITheme.INK))
	stack.add_child(UITheme.make_tr_label("battle.pause_overlay_hint", 25, UITheme.MUTED_INK))
	var resume_button: Button = UITheme.make_tr_button("battle.resume", UITheme.GREEN, Vector2(0, 112))
	resume_button.name = "ResumeBattleButton"
	resume_button.pressed.connect(_on_resume_pressed)
	stack.add_child(resume_button)
	var map_button: Button = UITheme.make_tr_button("battle.pause_map", Color("#d9edf0"), Vector2(0, 100))
	map_button.name = "PauseMapButton"
	map_button.pressed.connect(_on_pause_map_pressed)
	stack.add_child(map_button)

func _on_resume_pressed() -> void:
	if not battle_paused or battle_result_layer != null:
		return
	AudioManager.play_sfx("button_click")
	battle_paused = false
	input_locked = false
	if battle_pause_layer != null:
		battle_pause_layer.queue_free()
		battle_pause_layer = null
	if battle_pause_button != null:
		battle_pause_button.disabled = false
	_set_keypad_disabled(false)
	_start_enemy_attack_clock()
	_update_enemy_attack_countdown()

func _on_pause_map_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_world_map()

func _play_attack_animation() -> void:
	var player_origin: Vector2 = player_sprite.position
	var monster_origin: Vector2 = monster_sprite.position
	var target: Vector2 = Vector2(actor_stage.size.x * 0.48, player_origin.y - 12)
	var tween: Tween = create_tween().set_parallel(false)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_sprite, "position", target, 0.16)
	tween.tween_property(monster_sprite, "rotation", deg_to_rad(-6.0), 0.05)
	tween.tween_property(monster_sprite, "rotation", deg_to_rad(6.0), 0.07)
	tween.tween_property(monster_sprite, "rotation", 0.0, 0.05)
	tween.tween_property(player_sprite, "position", player_origin, 0.18)
	if monster_hp <= 0:
		var defeat_tween: Tween = create_tween().set_parallel(true)
		defeat_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		defeat_tween.tween_property(monster_sprite, "scale", Vector2(0.1, 0.1), 0.38)
		defeat_tween.tween_property(monster_sprite, "modulate:a", 0.0, 0.38)
	else:
		monster_sprite.position = monster_origin

func _play_monster_attack_animation() -> void:
	var monster_origin: Vector2 = monster_sprite.position
	var player_origin: Vector2 = player_sprite.position
	var tween: Tween = create_tween().set_parallel(false)
	tween.tween_property(monster_sprite, "position", monster_origin + Vector2(-32, 0), 0.12)
	tween.tween_property(player_sprite, "rotation", deg_to_rad(-5.0), 0.05)
	tween.tween_property(player_sprite, "rotation", deg_to_rad(5.0), 0.08)
	tween.tween_property(player_sprite, "rotation", 0.0, 0.05)
	tween.tween_property(monster_sprite, "position", monster_origin, 0.14)
	player_sprite.position = player_origin

func _show_damage_number(damage: int) -> void:
	var damage_label: Label = UITheme.make_label("-%d" % damage, 42, UITheme.RED)
	damage_label.position = monster_sprite.position + Vector2(120, 28)
	damage_label.size = Vector2(180, 70)
	actor_stage.add_child(damage_label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 72, 0.55)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(damage_label.queue_free)

func _show_player_damage_number(damage: int) -> void:
	var damage_label: Label = UITheme.make_label("-%d" % damage, 42, UITheme.RED)
	damage_label.position = player_sprite.position + Vector2(35, 20)
	damage_label.size = Vector2(180, 70)
	actor_stage.add_child(damage_label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 72, 0.55)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(damage_label.queue_free)

func _flash(color: Color) -> void:
	var flash: ColorRect = ColorRect.new()
	flash.color = color
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flash_parent: Control = battle_fx_layer if battle_fx_layer != null else self
	flash_parent.add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)

func _spawn_battle_effect(texture_path: String, center: Vector2, effect_size: Vector2, duration: float) -> void:
	if battle_fx_layer == null or not ResourceLoader.exists(texture_path):
		return
	var effect: TextureRect = TextureRect.new()
	effect.name = "BattleTransientEffect"
	effect.texture = load(texture_path)
	effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	effect.size = effect_size
	effect.position = center - effect_size * 0.5
	effect.pivot_offset = effect_size * 0.5
	effect.modulate = Color(1.0, 1.0, 1.0, 0.94)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_fx_layer.add_child(effect)
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(effect, "scale", Vector2(1.08, 1.08), duration * 0.45)
	tween.tween_property(effect, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(effect.queue_free)

func _update_hearts() -> void:
	var total_hearts: int = GameManager.get_player_hearts()
	var filled_hearts: int = clampi(int(floor(float(player_hp) / 10.0)), 0, total_hearts)
	var has_partial_heart: bool = player_hp > 0 and (player_hp % 10) != 0 and filled_hearts < total_hearts
	if heart_icons.is_empty():
		var heart_display: String = "♥".repeat(filled_hearts)
		if has_partial_heart:
			heart_display += "◐"
		heart_display += "♡".repeat(maxi(0, total_hearts - filled_hearts - (1 if has_partial_heart else 0)))
		hearts_label.text = "HP %d / %d  %s" % [player_hp, player_max_hp, heart_display]
		return
	for index: int in range(heart_icons.size()):
		var heart_icon: TextureRect = heart_icons[index]
		if index < filled_hearts:
			heart_icon.modulate = Color.WHITE
		elif index == filled_hearts and has_partial_heart:
			heart_icon.modulate = Color(1.0, 0.72, 0.78, 0.76)
		else:
			heart_icon.modulate = Color(0.62, 0.54, 0.56, 0.40)
	hearts_label.text = "HP %d / %d" % [player_hp, player_max_hp]

func _set_feedback(text_value: String, text_color: Color, background: Color, border: Color, border_width: int) -> void:
	if feedback_label == null:
		return
	feedback_label.text = text_value
	feedback_label.add_theme_color_override("font_color", text_color)
	if feedback_panel != null:
		feedback_panel.add_theme_stylebox_override("panel", _status_style(background, border, border_width))

func _update_level() -> void:
	level_label.text = "LV.%d\nATK %d  DEF %d" % [GameManager.get_level(), GameManager.get_attack(), GameManager.get_defense()]

func _update_combo() -> void:
	if combo <= 0:
		combo_label.text = ""
	else:
		combo_label.text = LanguageManager.tf("battle.combo", [combo])

func _set_keypad_disabled(disabled: bool) -> void:
	for button: Button in keypad_buttons:
		button.disabled = disabled

func _show_victory() -> void:
	if battle_result_layer != null:
		return
	input_locked = true
	if enemy_attack_timer != null:
		enemy_attack_timer.stop()
	enemy_attack_in_progress = false
	_set_keypad_disabled(true)
	var exp_reward: int = int(stage_data.get("reward_exp", monster_data.get("reward_exp", 20)))
	var coin_reward: int = int(stage_data.get("reward_coin", monster_data.get("reward_coin", 10)))
	var result: Dictionary = GameManager.apply_victory(exp_reward, coin_reward, {
		"highest_combo": highest_combo,
		"correct_answers": correct_answers,
		"mistakes": mistake_count,
		"total_answers": correct_answers + mistake_count,
		"auto_attacks": enemy_auto_attack_count
	})
	_show_result_panel(true, result)

func _show_defeat() -> void:
	if battle_result_layer != null:
		return
	input_locked = true
	if enemy_attack_timer != null:
		enemy_attack_timer.stop()
	enemy_attack_in_progress = false
	_set_keypad_disabled(true)
	GameManager.apply_defeat({
		"highest_combo": highest_combo,
		"correct_answers": correct_answers,
		"mistakes": mistake_count,
		"total_answers": correct_answers + mistake_count,
		"auto_attacks": enemy_auto_attack_count
	})
	_show_result_panel(false, {})

func _show_result_panel(victory: bool, result: Dictionary) -> void:
	battle_result_layer = Control.new()
	battle_result_layer.name = "BattleResultLayer"
	battle_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(battle_result_layer)
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.18, 0.12, 0.16, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_result_layer.add_child(overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_result_layer.add_child(center)
	var card: Panel = UITheme.make_panel(Color("#fff8e9"), Color("#f4d271"), 46, 7)
	UITheme.apply_texture_panel_skin(card, RESULT_PANEL_PATH, 54)
	card.custom_minimum_size = Vector2(850, 860 if victory else 610)
	center.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 55)
	margin.add_theme_constant_override("margin_right", 55)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 64)
	card.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)

	if victory:
		var title: VBoxContainer = UITheme.make_tr_en_dual("battle.victory", 62, 30, UITheme.INK)
		stack.add_child(title)
		if int(result.get("levels_gained", 0)) > 0:
			var level_up: Panel = UITheme.make_panel(Color("#ffe190"), Color("#d99555"), 30, 4)
			level_up.custom_minimum_size = Vector2(0, 170)
			stack.add_child(level_up)
			var level_stack: VBoxContainer = UITheme.make_trf_en_dual("battle.level_up", [int(result.get("new_level", GameManager.get_level()))], 45, 24, UITheme.INK)
			level_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			level_up.add_child(level_stack)
		var rewards: VBoxContainer = VBoxContainer.new()
		rewards.alignment = BoxContainer.ALIGNMENT_CENTER
		rewards.add_theme_constant_override("separation", 8)
		stack.add_child(rewards)
		var stars: int = clampi(int(result.get("best_stars", result.get("stars", 1))), 1, GameBalance.MAX_STAGE_STARS)
		var star_text: String = "★".repeat(stars) + "☆".repeat(GameBalance.MAX_STAGE_STARS - stars)
		rewards.add_child(UITheme.make_trf_label("battle.stage_rating", [star_text], 34, UITheme.ORANGE))
		rewards.add_child(UITheme.make_trf_label("battle.reward_exp", [int(result.get("exp", 0))], 32, UITheme.MUTED_INK))
		rewards.add_child(UITheme.make_trf_label("battle.reward_coins", [int(result.get("coins", 0))], 32, UITheme.MUTED_INK))
		if int(result.get("gems", 0)) > 0:
			rewards.add_child(_make_reward_line(LanguageManager.tf("battle.reward_gems", [int(result.get("gems", 0))]), 32, Color("#c58d2a"), DIAMOND_ICON_PATH))
		rewards.add_child(UITheme.make_trf_label("battle.accuracy", [int(round(float(result.get("accuracy", 1.0)) * 100.0)), int(result.get("mistakes", 0))], 22, UITheme.MUTED_INK))
		if enemy_auto_attack_count > 0:
			rewards.add_child(UITheme.make_trf_label("battle.auto_hits", [enemy_auto_attack_count], 21, UITheme.RED.darkened(0.15)))
		if not bool(result.get("first_clear", true)):
			rewards.add_child(UITheme.make_tr_label("battle.replay_reward", 20, UITheme.MUTED_INK))
		if bool(result.get("world_complete", false)):
			rewards.add_child(UITheme.make_tr_label("battle.world_complete", 24, UITheme.MINT_DARK))
		elif bool(result.get("chapter_complete", false)):
			rewards.add_child(UITheme.make_trf_label("battle.chapter_complete", [GameBalance.chapter_for_stage(int(stage_data.get("id", 1)))], 24, UITheme.MINT_DARK))
		elif int(result.get("stage_unlocked", -1)) > 0:
			var unlocked_stage: int = int(result.get("stage_unlocked", -1))
			rewards.add_child(UITheme.make_trf_label("battle.stage_unlocked", [unlocked_stage], 22, UITheme.MINT_DARK))
		else:
			rewards.add_child(UITheme.make_tr_label("battle.stage_done", 22, UITheme.MINT_DARK))
		var continue_button: Button = UITheme.make_tr_button("battle.continue", UITheme.YELLOW, Vector2(0, 124))
		continue_button.name = "ContinueBattleButton"
		continue_button.pressed.connect(_on_continue_pressed)
		stack.add_child(continue_button)
	else:
		stack.add_child(UITheme.make_tr_en_dual("battle.defeat", 58, 28, UITheme.INK))
		stack.add_child(UITheme.make_tr_label("battle.defeat_hint", 26, UITheme.MUTED_INK))
		stack.add_child(UITheme.make_trf_label("battle.auto_attacks_hint", [enemy_auto_attack_count], 21, UITheme.RED.darkened(0.15)))
		# A retry is a fresh battle entry, so it costs the same stamina as the
		# original run. With no stamina left the player can still return to the
		# map (and watch an ad there) instead of being stuck on this panel.
		var retry_needs_stamina: bool = GameManager.get_stamina() < GameBalance.STAMINA_PER_STAGE
		var retry_button: Button = UITheme.make_tr_button("battle.retry_needs_stamina" if retry_needs_stamina else "battle.retry", UITheme.YELLOW, Vector2(0, 120))
		retry_button.name = "RetryBattleButton"
		retry_button.pressed.connect(_on_retry_pressed)
		retry_button.disabled = retry_needs_stamina
		stack.add_child(retry_button)
		var map_button: Button = UITheme.make_tr_button("battle.defeat_map", Color("#d9edf0"), Vector2(0, 100))
		map_button.name = "DefeatMapButton"
		map_button.pressed.connect(_on_map_pressed)
		stack.add_child(map_button)
		# Level and chapter rewards can all appear in the same result.
	card.custom_minimum_size.y = maxf(card.custom_minimum_size.y, stack.get_combined_minimum_size().y + 128.0)

func _make_reward_line(text_value: String, font_size: int, color: Color, icon_path: String = "") -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "RewardLine"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, maxf(44.0, float(font_size) + 12.0))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon: TextureRect = _make_sprite(icon_path, Vector2(34, 34))
		icon.name = "RewardIcon"
		icon.custom_minimum_size = Vector2(34, 34)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	row.add_child(UITheme.make_label(text_value, font_size, color))
	return row

func _on_continue_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_world_map()

func _on_retry_pressed() -> void:
	AudioManager.play_sfx("button_click")
	if GameManager.get_stamina() < GameBalance.STAMINA_PER_STAGE:
		GameManager.go_to_world_map()
		return
	GameManager.start_stage(int(GameManager.player_state.get("current_stage", 1)))

func _on_map_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_world_map()

func _add_battle_decorations() -> void:
	_add_soft_shape(Vector2(-80, 300), Vector2(360, 190), Color(1, 1, 1, 0.3), 150)
	_add_soft_shape(Vector2(820, 220), Vector2(330, 150), Color(1, 1, 1, 0.26), 140)
	_add_soft_shape(Vector2(-100, 1700), Vector2(380, 250), Color("#f4b9cf"), 160)
	_add_soft_shape(Vector2(820, 1650), Vector2(350, 270), Color("#f6c3d0"), 170)

func _get_monster_max_hp() -> int:
	return maxi(1, int(stage_data.get("monster_hp", monster_data.get("max_hp", 30))))

func _get_monster_attack() -> int:
	if stage_data.has("monster_attack"):
		return maxi(1, int(stage_data.get("monster_attack", 1)))
	# Authored World 1 monsters used one-heart damage; ten HP preserves the
	# original three-mistake beginner rhythm with the new numeric HP system.
	return maxi(1, int(monster_data.get("attack", 1)) * 10)

func _add_soft_shape(at: Vector2, shape_size: Vector2, color: Color, radius: int) -> void:
	var shape: Panel = Panel.new()
	shape.position = at
	shape.size = shape_size
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.add_theme_stylebox_override("panel", UITheme.rounded_style(color, Color.TRANSPARENT, radius, 0))
	add_child(shape)
