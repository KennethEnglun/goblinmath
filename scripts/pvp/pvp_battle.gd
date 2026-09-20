extends Control

## PvP battle view. Pure presentation + input: every rule (timing, damage,
## round flow) is decided by the server and arrives through PvpNetwork.

const LOBBY_SCENE_PATH: String = "res://scenes/pvp/pvp_lobby.tscn"
const HP_MAX: int = GameBalance.PVP_BASE_HP

var opponent_name_label: Label
var opponent_hp_bar: ProgressBar
var opponent_combo_label: Label
var opponent_sprite: TextureRect
var player_hp_bar: ProgressBar
var player_combo_label: Label
var timer_bar: ProgressBar
var timer_label: Label
var question_label: Label
var input_label: Label
var feedback_label: Label
var countdown_label: Label
var overlay_dim: ColorRect
var overlay_label: Label
var result_panel: Panel
var result_label: Label
var result_reward_label: Label
var result_back_button: Button
var leave_button: Button
var keypad_buttons: Array[Button] = []

var current_index: int = -1
var input_text: String = ""
var answered: bool = false
var timer_remaining: float = 0.0
var timer_total: float = 1.0
var timer_running: bool = false
var _feedback_tween: Tween

func _ready() -> void:
	UITheme.add_gradient_background(self, Color("#bfeaf5"), Color("#fff9ec"))
	_build_ui()
	_wire_network_signals()
	var payload: Dictionary = PvpNetwork.match_payload
	if payload.is_empty():
		# Scene opened outside a real match (e.g. preview); stay exitable.
		question_label.text = LanguageManager.t("pvp.no_match")
		return
	_apply_match_payload(payload)

func _process(delta: float) -> void:
	if not timer_running:
		return
	timer_remaining = maxf(0.0, timer_remaining - delta)
	timer_bar.value = timer_remaining
	timer_label.text = str(int(ceil(timer_remaining)))
	if timer_remaining <= 0.0:
		timer_running = false

# ------------------------------------------------------------------
# UI construction
# ------------------------------------------------------------------

func _build_ui() -> void:
	var safe: MarginContainer = UITheme.make_safe_margin(self, 36)
	safe.name = "SafeArea"
	add_child(safe)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 14)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(content)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 16)
	content.add_child(header)

	leave_button = Button.new()
	leave_button.name = "LeaveButton"
	leave_button.text = "✕"
	leave_button.custom_minimum_size = Vector2(96, 96)
	leave_button.focus_mode = Control.FOCUS_NONE
	leave_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	leave_button.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	leave_button.add_theme_font_size_override("font_size", 44)
	leave_button.add_theme_color_override("font_color", UITheme.INK)
	for state: String in ["normal", "hover", "pressed"]:
		leave_button.add_theme_stylebox_override(state, UITheme.rounded_style(Color(1, 0.97, 0.92, 0.95), Color("#e4c9a6"), 24, 3))
	leave_button.pressed.connect(_on_leave_pressed)
	header.add_child(leave_button)

	var title: Label = UITheme.make_tr_label("pvp.battle_title", 46, UITheme.INK, UITheme.FontRole.BOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	content.add_child(_make_fighter_panel(true))

	var center: VBoxContainer = VBoxContainer.new()
	center.name = "Center"
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	content.add_child(center)

	var timer_row: HBoxContainer = HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 12)
	center.add_child(timer_row)
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.custom_minimum_size = Vector2(90, 44)
	timer_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	timer_label.add_theme_font_size_override("font_size", 38)
	timer_label.add_theme_color_override("font_color", UITheme.INK)
	timer_label.text = "-"
	timer_row.add_child(timer_label)
	timer_bar = ProgressBar.new()
	timer_bar.name = "TimerBar"
	timer_bar.min_value = 0.0
	timer_bar.max_value = float(GameBalance.PVP_QUESTION_SECONDS)
	timer_bar.value = 0.0
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(0, 30)
	timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_bar.add_theme_stylebox_override("background", UITheme.rounded_style(Color(0.35, 0.2, 0.2, 0.25), Color.TRANSPARENT, 12, 0))
	timer_bar.add_theme_stylebox_override("fill", UITheme.rounded_style(UITheme.ORANGE, Color.TRANSPARENT, 12, 0))
	timer_row.add_child(timer_bar)

	var question_panel: Panel = UITheme.make_panel(Color(1, 0.98, 0.94, 0.98), Color("#f3d88a"), 36, 5)
	question_panel.name = "QuestionPanel"
	question_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(question_panel)

	var question_margin: MarginContainer = MarginContainer.new()
	for margin: String in ["margin_left", "margin_right"]:
		question_margin.add_theme_constant_override(margin, 30)
	for margin: String in ["margin_top", "margin_bottom"]:
		question_margin.add_theme_constant_override(margin, 20)
	question_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	question_panel.add_child(question_margin)

	var question_box: VBoxContainer = VBoxContainer.new()
	question_box.alignment = BoxContainer.ALIGNMENT_CENTER
	question_box.add_theme_constant_override("separation", 8)
	question_margin.add_child(question_box)

	question_label = Label.new()
	question_label.name = "QuestionLabel"
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	question_label.add_theme_font_size_override("font_size", 96)
	question_label.add_theme_color_override("font_color", UITheme.INK)
	question_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	question_box.add_child(question_label)

	input_label = Label.new()
	input_label.name = "InputLabel"
	input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	input_label.add_theme_font_size_override("font_size", 84)
	input_label.add_theme_color_override("font_color", UITheme.MINT_DARK)
	input_label.text = "_"
	question_box.add_child(input_label)

	feedback_label = Label.new()
	feedback_label.name = "FeedbackLabel"
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	feedback_label.add_theme_font_size_override("font_size", 44)
	feedback_label.add_theme_color_override("font_color", UITheme.MINT_DARK)
	feedback_label.text = " "
	center.add_child(feedback_label)

	content.add_child(_make_fighter_panel(false))

	var keypad: GridContainer = GridContainer.new()
	keypad.name = "Keypad"
	keypad.columns = 3
	keypad.add_theme_constant_override("h_separation", 16)
	keypad.add_theme_constant_override("v_separation", 14)
	content.add_child(keypad)

	var layout: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]
	for value: String in layout:
		var button: Button = UITheme.make_key_button(value, UITheme.YELLOW if value != "OK" else UITheme.GREEN, Vector2(0, 128))
		button.name = "Key_%s" % value
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_key_pressed.bind(value))
		keypad.add_child(button)
		keypad_buttons.append(button)

	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	countdown_label.add_theme_font_size_override("font_size", 220)
	countdown_label.add_theme_color_override("font_color", UITheme.INK)
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label.text = ""
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(countdown_label)

	overlay_dim = ColorRect.new()
	overlay_dim.name = "OverlayDim"
	overlay_dim.color = Color(0.1, 0.05, 0.08, 0.55)
	overlay_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_dim.visible = false
	add_child(overlay_dim)

	overlay_label = Label.new()
	overlay_label.name = "OverlayLabel"
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	overlay_label.add_theme_font_size_override("font_size", 54)
	overlay_label.add_theme_color_override("font_color", Color.WHITE)
	overlay_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_dim.add_child(overlay_label)

	result_panel = UITheme.make_panel(Color(1, 0.97, 0.92, 0.99), Color("#d7a45d"), 40, 6)
	result_panel.name = "ResultPanel"
	result_panel.anchor_left = 0.08
	result_panel.anchor_right = 0.92
	result_panel.anchor_top = 0.3
	result_panel.anchor_bottom = 0.62
	result_panel.visible = false
	add_child(result_panel)

	var result_box: VBoxContainer = VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 20)
	result_panel.add_child(result_box)

	result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	result_label.add_theme_font_size_override("font_size", 84)
	result_label.add_theme_color_override("font_color", UITheme.INK)
	result_box.add_child(result_label)

	result_reward_label = Label.new()
	result_reward_label.name = "ResultRewardLabel"
	result_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_reward_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BODY))
	result_reward_label.add_theme_font_size_override("font_size", 44)
	result_reward_label.add_theme_color_override("font_color", UITheme.MUTED_INK)
	result_box.add_child(result_reward_label)

	result_back_button = UITheme.make_tr_button("pvp.back_lobby", UITheme.YELLOW, Vector2(0, 120))
	result_back_button.name = "ResultBackButton"
	result_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result_back_button.custom_minimum_size = Vector2(420, 120)
	result_back_button.pressed.connect(_on_leave_pressed)
	result_box.add_child(result_back_button)

func _make_fighter_panel(is_opponent: bool) -> Panel:
	var panel: Panel = UITheme.make_panel(Color(1, 0.97, 0.92, 0.95), Color("#f3d88a"), 30, 4)
	panel.name = "OpponentPanel" if is_opponent else "PlayerPanel"
	panel.custom_minimum_size = Vector2(0, 190)
	var panel_margin: MarginContainer = MarginContainer.new()
	for margin: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		panel_margin.add_theme_constant_override(margin, 20)
	panel_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(panel_margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel_margin.add_child(row)

	var sprite: TextureRect = TextureRect.new()
	sprite.name = "FighterSprite"
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(150, 150)
	sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sprite)

	var info: VBoxContainer = VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label: Label = Label.new()
	name_label.name = "FighterName"
	name_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.add_theme_color_override("font_color", UITheme.INK)
	name_label.clip_text = true
	info.add_child(name_label)

	var hp_bar: ProgressBar = ProgressBar.new()
	hp_bar.name = "FighterHp"
	hp_bar.min_value = 0.0
	hp_bar.max_value = float(HP_MAX)
	hp_bar.value = float(HP_MAX)
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 40)
	hp_bar.add_theme_stylebox_override("background", UITheme.rounded_style(Color(0.35, 0.2, 0.2, 0.22), Color("#e4c9a6"), 16, 2))
	hp_bar.add_theme_stylebox_override("fill", UITheme.rounded_style(UITheme.GREEN, Color.TRANSPARENT, 16, 0))
	info.add_child(hp_bar)

	var combo_label: Label = Label.new()
	combo_label.name = "FighterCombo"
	combo_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BODY))
	combo_label.add_theme_font_size_override("font_size", 28)
	combo_label.add_theme_color_override("font_color", UITheme.MUTED_INK)
	combo_label.text = " "
	info.add_child(combo_label)

	if is_opponent:
		opponent_sprite = sprite
		opponent_name_label = name_label
		opponent_hp_bar = hp_bar
		opponent_combo_label = combo_label
	else:
		sprite.texture = load(GameManager.get_character_sprite_path())
		name_label.text = PvpNetwork.get_display_name()
		player_hp_bar = hp_bar
		player_combo_label = combo_label
	return panel

# ------------------------------------------------------------------
# Network wiring
# ------------------------------------------------------------------

func _wire_network_signals() -> void:
	PvpNetwork.countdown_tick.connect(_on_countdown_tick)
	PvpNetwork.question_received.connect(_on_question_received)
	PvpNetwork.round_resolved.connect(_on_round_resolved)
	PvpNetwork.match_ended.connect(_on_match_ended)
	PvpNetwork.opponent_reconnecting.connect(_on_opponent_reconnecting)
	PvpNetwork.opponent_resumed.connect(_on_opponent_resumed)
	PvpNetwork.connection_lost.connect(_on_connection_lost)

func _apply_match_payload(payload: Dictionary) -> void:
	opponent_name_label.text = str(payload.get("opponent_name", ""))
	var character_id: String = str(payload.get("opponent_char", ""))
	var character: Dictionary = DataManager.get_character(character_id)
	var sprite_path: String = str(character.get("sprite", ""))
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		opponent_sprite.texture = load(sprite_path)
	set_hp(opponent_hp_bar, int(payload.get("opponent_hp", HP_MAX)))
	set_hp(player_hp_bar, int(payload.get("hp", HP_MAX)))
	_set_combo(opponent_combo_label, 0)
	_set_combo(player_combo_label, 0)
	if not bool(payload.get("resumed", false)):
		countdown_label.text = str(PvpNetwork.COUNTDOWN_START)

func set_hp(bar: ProgressBar, value: int) -> void:
	var clamped: int = clampi(value, 0, HP_MAX)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "value", float(clamped), 0.35)

func _set_combo(label: Label, combo: int) -> void:
	if combo <= 1:
		label.text = " "
	else:
		label.text = LanguageManager.tf("pvp.combo", [combo])

# ------------------------------------------------------------------
# Signal handlers
# ------------------------------------------------------------------

func _on_countdown_tick(value: int) -> void:
	question_label.text = ""
	countdown_label.text = str(value)

func _on_question_received(index: int, text: String, seconds: int) -> void:
	countdown_label.text = ""
	current_index = index
	question_label.text = text
	input_text = ""
	input_label.text = "_"
	answered = false
	feedback_label.text = " "
	timer_total = float(maxi(seconds, 1))
	timer_remaining = timer_total
	timer_bar.max_value = timer_total
	timer_bar.value = timer_remaining
	timer_running = true
	_set_keypad_enabled(true)

func _on_round_resolved(payload: Dictionary) -> void:
	set_hp(player_hp_bar, int(payload.get("hp_you", HP_MAX)))
	set_hp(opponent_hp_bar, int(payload.get("hp_opp", HP_MAX)))
	_set_combo(player_combo_label, int(payload.get("combo_you", 0)))
	_set_combo(opponent_combo_label, int(payload.get("combo_opp", 0)))
	if bool(payload.get("you_correct", false)):
		feedback_label.text = LanguageManager.t("pvp.correct")
		feedback_label.add_theme_color_override("font_color", UITheme.MINT_DARK)
		AudioManager.play_sfx("answer_correct")
	else:
		feedback_label.text = LanguageManager.t("pvp.wrong")
		feedback_label.add_theme_color_override("font_color", UITheme.RED)
		AudioManager.play_sfx("answer_wrong")
	_flash_feedback()

func _flash_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	feedback_label.modulate.a = 1.0
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(0.9)
	_feedback_tween.tween_property(feedback_label, "modulate:a", 0.25, 0.3)

func _on_match_ended(payload: Dictionary) -> void:
	timer_running = false
	countdown_label.text = ""
	overlay_dim.visible = false
	_set_keypad_enabled(false)
	var draw: bool = bool(payload.get("draw", false))
	var win: bool = bool(payload.get("win", false))
	if draw:
		result_label.text = LanguageManager.t("pvp.draw")
	elif win:
		result_label.text = LanguageManager.t("pvp.victory")
	else:
		result_label.text = LanguageManager.t("pvp.defeat")
	result_reward_label.text = LanguageManager.tf("pvp.reward", [int(payload.get("reward_coins", 0))])
	result_panel.visible = true
	if win:
		AudioManager.play_sfx("victory")
	elif not draw:
		AudioManager.play_sfx("defeat")

func _on_opponent_reconnecting(seconds_left: int) -> void:
	result_panel.visible = false
	overlay_label.text = LanguageManager.tf("pvp.opp_reconnecting", [seconds_left])
	overlay_dim.visible = true

func _on_opponent_resumed() -> void:
	overlay_dim.visible = false

func _on_connection_lost() -> void:
	result_panel.visible = false
	overlay_label.text = LanguageManager.t("pvp.self_reconnecting")
	overlay_dim.visible = true

# ------------------------------------------------------------------
# Input
# ------------------------------------------------------------------

func _on_key_pressed(value: String) -> void:
	AudioManager.play_sfx("button_click")
	if answered:
		return
	match value:
		"C":
			input_text = ""
		"OK":
			_submit_answer()
		_:
			if input_text.length() < 3:
				input_text += value
	input_label.text = input_text if not input_text.is_empty() else "_"

func _submit_answer() -> void:
	if answered or input_text.is_empty() or current_index < 0:
		return
	answered = true
	_set_keypad_enabled(false)
	timer_running = false
	PvpNetwork.submit_answer(current_index, int(input_text))

func _set_keypad_enabled(enabled: bool) -> void:
	for button in keypad_buttons:
		button.disabled = not enabled

func _on_leave_pressed() -> void:
	AudioManager.play_sfx("button_click")
	PvpNetwork.leave_match()
	get_tree().change_scene_to_file.call_deferred(LOBBY_SCENE_PATH)
