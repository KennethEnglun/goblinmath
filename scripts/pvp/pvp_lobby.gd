extends Control

## PvP lobby: nickname, quick match, and room codes. All state comes from
## PvpNetwork signals; the scene itself holds no match logic.

const BATTLE_SCENE_PATH: String = "res://scenes/pvp/pvp_battle.tscn"

var status_label: Label
var room_code_label: Label
var nickname_edit: LineEdit
var room_code_edit: LineEdit
var quick_button: Button
var create_button: Button
var join_button: Button
var cancel_button: Button
var toast_label: Label
var _toast_tween: Tween

func _ready() -> void:
	UITheme.add_gradient_background(self, Color("#f7c9d7"), Color("#fff2df"))
	_build_ui()
	_wire_network_signals()
	if not PvpNetwork.is_online():
		PvpNetwork.connect_to_server()
	_refresh_for_state(PvpNetwork.client_state)

func _build_ui() -> void:
	var safe: MarginContainer = UITheme.make_safe_margin(self, 42)
	safe.name = "SafeArea"
	add_child(safe)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 22)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(content)

	content.add_child(UITheme.make_spacer(20))

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 18)
	content.add_child(header)

	var back_button: Button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "‹"
	back_button.custom_minimum_size = Vector2(104, 104)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	back_button.add_theme_font_size_override("font_size", 52)
	back_button.add_theme_color_override("font_color", UITheme.INK)
	for state: String in ["normal", "hover", "pressed"]:
		back_button.add_theme_stylebox_override(state, UITheme.rounded_style(Color(1, 0.97, 0.92, 0.95), Color("#e4c9a6"), 28, 3))
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var title: Label = UITheme.make_tr_label("pvp.title", 58, UITheme.INK, UITheme.FontRole.BOLD)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	content.add_child(UITheme.make_spacer(8))

	status_label = UITheme.make_tr_label("pvp.connecting", 34, UITheme.MUTED_INK)
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)

	room_code_label = Label.new()
	room_code_label.name = "RoomCodeLabel"
	room_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_code_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	room_code_label.add_theme_font_size_override("font_size", 46)
	room_code_label.add_theme_color_override("font_color", UITheme.MINT_DARK)
	room_code_label.visible = false
	content.add_child(room_code_label)

	var name_panel: Panel = UITheme.make_panel(Color(1, 0.97, 0.92, 0.95), Color("#f3d88a"), 30, 4)
	name_panel.name = "NamePanel"
	name_panel.custom_minimum_size = Vector2(0, 268)
	var name_margin: MarginContainer = MarginContainer.new()
	for margin: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		name_margin.add_theme_constant_override(margin, 26)
	name_panel.add_child(name_margin)
	name_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name_box: VBoxContainer = VBoxContainer.new()
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	name_box.add_theme_constant_override("separation", 12)
	name_margin.add_child(name_box)
	var name_title: Label = UITheme.make_tr_label("pvp.nickname", 30, UITheme.MUTED_INK)
	name_box.add_child(name_title)
	nickname_edit = LineEdit.new()
	nickname_edit.name = "NicknameEdit"
	nickname_edit.custom_minimum_size = Vector2(0, 100)
	nickname_edit.max_length = 16
	nickname_edit.text = PvpNetwork.get_display_name()
	nickname_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname_edit.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	nickname_edit.add_theme_font_size_override("font_size", 42)
	nickname_edit.add_theme_color_override("font_color", UITheme.INK)
	nickname_edit.add_theme_stylebox_override("normal", UITheme.rounded_style(Color.WHITE, Color("#e4c9a6"), 20, 3))
	nickname_edit.add_theme_stylebox_override("focus", UITheme.rounded_style(Color.WHITE, Color("#d7a45d"), 20, 4))
	nickname_edit.text_changed.connect(_on_nickname_changed)
	name_box.add_child(nickname_edit)
	content.add_child(name_panel)

	quick_button = UITheme.make_tr_button("pvp.quick_match", UITheme.YELLOW, Vector2(0, 150))
	quick_button.name = "QuickMatchButton"
	quick_button.pressed.connect(_on_quick_pressed)
	content.add_child(quick_button)

	var room_row: HBoxContainer = HBoxContainer.new()
	room_row.name = "RoomRow"
	room_row.add_theme_constant_override("separation", 18)
	content.add_child(room_row)

	create_button = UITheme.make_tr_button("pvp.create_room", UITheme.MINT, Vector2(0, 150))
	create_button.name = "CreateRoomButton"
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_button.pressed.connect(_on_create_pressed)
	room_row.add_child(create_button)

	join_button = UITheme.make_tr_button("pvp.join", UITheme.SKY, Vector2(0, 150))
	join_button.name = "JoinRoomButton"
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_button.pressed.connect(_on_join_pressed)
	room_row.add_child(join_button)

	var code_edit: LineEdit = LineEdit.new()
	code_edit.name = "RoomCodeEdit"
	code_edit.custom_minimum_size = Vector2(0, 108)
	code_edit.max_length = 4
	code_edit.placeholder_text = LanguageManager.t("pvp.room_code_hint")
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	code_edit.add_theme_font_size_override("font_size", 48)
	code_edit.add_theme_color_override("font_color", UITheme.INK)
	code_edit.add_theme_stylebox_override("normal", UITheme.rounded_style(Color.WHITE, Color("#e4c9a6"), 20, 3))
	code_edit.add_theme_stylebox_override("focus", UITheme.rounded_style(Color.WHITE, Color("#d7a45d"), 20, 4))
	code_edit.text_changed.connect(_on_code_edited)
	content.add_child(code_edit)
	room_code_edit = code_edit

	cancel_button = UITheme.make_tr_button("pvp.cancel", UITheme.RED, Vector2(0, 124))
	cancel_button.name = "CancelButton"
	cancel_button.visible = false
	cancel_button.pressed.connect(_on_cancel_pressed)
	content.add_child(cancel_button)

	var stamina_note: Label = UITheme.make_trf_label("pvp.stamina_cost", [GameBalance.STAMINA_PER_STAGE], 28, UITheme.MUTED_INK)
	stamina_note.name = "StaminaNote"
	stamina_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(stamina_note)

	var bottom_spacer: Control = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bottom_spacer)

	toast_label = Label.new()
	toast_label.name = "ToastLabel"
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_override("font", UITheme.shared_font(UITheme.FontRole.BOLD))
	toast_label.add_theme_font_size_override("font_size", 36)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_stylebox_override("normal", UITheme.rounded_style(Color("#ef6e7f"), Color.TRANSPARENT, 24, 0))
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.anchor_left = 0.08
	toast_label.anchor_right = 0.92
	toast_label.anchor_top = 0.74
	toast_label.anchor_bottom = 0.86
	toast_label.offset_top = 0.0
	toast_label.offset_bottom = 0.0
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.visible = false
	add_child(toast_label)

func _wire_network_signals() -> void:
	PvpNetwork.pvp_state_changed.connect(_refresh_for_state)
	PvpNetwork.pvp_error.connect(_on_pvp_error)
	PvpNetwork.room_created.connect(_on_room_created)
	PvpNetwork.match_found.connect(_on_match_found)
	PvpNetwork.match_ended.connect(_on_match_ended)

func _refresh_for_state(state: String) -> void:
	var lobby_ready: bool = state == PvpProtocol.STATE_CONNECTED
	var waiting: bool = state == PvpProtocol.STATE_QUEUED or state == PvpProtocol.STATE_ROOM_WAITING
	quick_button.disabled = not lobby_ready
	create_button.disabled = not lobby_ready
	join_button.disabled = not lobby_ready
	cancel_button.visible = waiting
	room_code_label.visible = false
	match state:
		PvpProtocol.STATE_OFFLINE, PvpProtocol.STATE_CONNECTING:
			status_label.text = LanguageManager.t("pvp.connecting")
		PvpProtocol.STATE_CONNECTED:
			status_label.text = LanguageManager.t("pvp.connected")
		PvpProtocol.STATE_QUEUED:
			status_label.text = LanguageManager.t("pvp.queued")
		PvpProtocol.STATE_ROOM_WAITING:
			status_label.text = LanguageManager.t("pvp.room_waiting")
		_:
			status_label.text = LanguageManager.t("pvp.connected")

func _on_room_created(code: String) -> void:
	room_code_label.text = LanguageManager.tf("pvp.your_room", [code])
	room_code_label.visible = true

func _on_nickname_changed(value: String) -> void:
	var cleaned: String = PvpNetwork.set_display_name(value)
	if cleaned != value:
		var caret: int = nickname_edit.caret_column
		nickname_edit.text = cleaned
		nickname_edit.caret_column = caret

func _on_code_edited(value: String) -> void:
	var upper: String = value.to_upper()
	if upper != value:
		var caret: int = room_code_edit.caret_column
		room_code_edit.text = upper
		room_code_edit.caret_column = caret

func _on_quick_pressed() -> void:
	AudioManager.play_sfx("button_click")
	PvpNetwork.join_queue()

func _on_create_pressed() -> void:
	AudioManager.play_sfx("button_click")
	PvpNetwork.create_room()

func _on_join_pressed() -> void:
	AudioManager.play_sfx("button_click")
	PvpNetwork.join_room(room_code_edit.text)

func _on_cancel_pressed() -> void:
	AudioManager.play_sfx("button_click")
	PvpNetwork.cancel_matching()

func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_click")
	PvpNetwork.disconnect_from_server()
	GameManager.go_to_main_menu()

func _on_match_found(_payload: Dictionary) -> void:
	get_tree().change_scene_to_file.call_deferred(BATTLE_SCENE_PATH)

func _on_match_ended(payload: Dictionary) -> void:
	# Only reachable from the lobby when a rejoin window expired before the
	# battle scene ever opened.
	_show_toast(LanguageManager.t("pvp.error_%s" % str(payload.get("reason", "disconnected"))))

func _on_pvp_error(code: String) -> void:
	_show_toast(LanguageManager.t("pvp.error_%s" % code))

func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: toast_label.visible = false)
