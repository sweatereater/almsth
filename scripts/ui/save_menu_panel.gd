class_name SaveMenuPanel
extends Control

const Loc := preload("res://scripts/localization/localization.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")

signal continue_requested(slot_id: String)
signal resume_requested
signal new_game_requested
signal load_requested(slot_id: String)
signal delete_requested(slot_id: String)
signal settings_requested
signal exit_requested

const PAGE_SIZE := 6


class TrashButton:
	extends Button

	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var color := Color("aeb7c5")
		if is_pressed():
			color = Color("ff9a8f")
		elif is_hovered():
			color = Color("f2d8d4")
		var center := size * 0.5
		var left := center.x - 8.0
		var right := center.x + 8.0
		var top := center.y - 8.0
		var bottom := center.y + 10.0
		draw_line(Vector2(left, top), Vector2(right, top), color, 2.0, true)
		draw_line(Vector2(center.x - 4.0, top - 4.0), Vector2(center.x + 4.0, top - 4.0), color, 2.0, true)
		draw_line(Vector2(center.x - 3.0, top - 4.0), Vector2(center.x - 3.0, top), color, 2.0, true)
		draw_line(Vector2(left + 2.0, top + 3.0), Vector2(left + 4.0, bottom), color, 2.0, true)
		draw_line(Vector2(right - 2.0, top + 3.0), Vector2(right - 4.0, bottom), color, 2.0, true)
		draw_line(Vector2(left + 4.0, bottom), Vector2(right - 4.0, bottom), color, 2.0, true)
		if has_focus():
			var focus_color := Color("72d7cf")
			for corner in [
				[Vector2(4, 10), Vector2(4, 4), Vector2(10, 4)],
				[Vector2(size.x - 10, 4), Vector2(size.x - 4, 4), Vector2(size.x - 4, 10)],
				[Vector2(4, size.y - 10), Vector2(4, size.y - 4), Vector2(10, size.y - 4)],
				[Vector2(size.x - 10, size.y - 4), Vector2(size.x - 4, size.y - 4), Vector2(size.x - 4, size.y - 10)],
			]:
				draw_polyline(PackedVector2Array(corner), focus_color, 2.0, true)


class TrashGlyph:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var color := Color("ffaaa1")
		draw_line(Vector2(3, 6), Vector2(21, 6), color, 2.0, true)
		draw_line(Vector2(8, 2), Vector2(16, 2), color, 2.0, true)
		draw_line(Vector2(5, 9), Vector2(7, 22), color, 2.0, true)
		draw_line(Vector2(19, 9), Vector2(17, 22), color, 2.0, true)
		draw_line(Vector2(7, 22), Vector2(17, 22), color, 2.0, true)

var slots: Array[Dictionary] = []
var list_mode := false
var in_game_context := false
var new_game_confirmation_pending := false
var exit_confirmation_pending := false
var error_text := ""
var page := 0
var active_slot_id := ""
var delete_modal_open := false
var pending_delete_slot_id := ""
var pending_delete_metadata: Dictionary = {}
var pending_delete_origin_index := -1
var delete_request_emitted := false
var list_activation_blocked_until_ms := 0
var modal_mouse_release_pending := false

var title_label: Label
var subtitle_label: Label
var error_label: Label
var continue_button: Button
var new_game_button: Button
var load_button: Button
var settings_button: Button
var exit_button: Button
var back_button: Button
var empty_label: Label
var previous_button: Button
var next_button: Button
var page_label: Label
var slot_buttons: Array[Button] = []
var trash_buttons: Array[Button] = []
var delete_modal_layer: Control
var delete_modal_title: Label
var delete_modal_body: Label
var delete_no_button: Button
var delete_yes_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("0c1018fa")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var card := Panel.new()
	card.position = Vector2(330, 48)
	card.size = Vector2(620, 624)
	card.add_theme_stylebox_override("panel", Ui.make_panel_style(Color("53647b")))
	add_child(card)
	title_label = Ui.make_label(self, Vector2(370, 72), Vector2(540, 48), 30)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label = Ui.make_label(self, Vector2(380, 124), Vector2(520, 54), 15)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label = Ui.make_label(self, Vector2(380, 178), Vector2(520, 28), 13)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_color_override("font_color", Color("e27b72"))
	continue_button = Ui.make_button(self, Vector2(440, 220), "", Vector2(400, 50))
	new_game_button = Ui.make_button(self, Vector2(440, 278), "", Vector2(400, 50))
	load_button = Ui.make_button(self, Vector2(440, 336), "", Vector2(400, 50))
	settings_button = Ui.make_button(self, Vector2(440, 394), "", Vector2(400, 50))
	exit_button = Ui.make_button(self, Vector2(440, 452), "", Vector2(400, 50))
	previous_button = Ui.make_button(self, Vector2(380, 558), "", Vector2(140, 42))
	page_label = Ui.make_label(self, Vector2(524, 558), Vector2(232, 42), 14)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_button = Ui.make_button(self, Vector2(760, 558), "", Vector2(140, 42))
	back_button = Ui.make_button(self, Vector2(440, 610), "", Vector2(400, 42))
	continue_button.name = "Continue"
	new_game_button.name = "NewGame"
	load_button.name = "Load"
	settings_button.name = "Settings"
	exit_button.name = "Exit"
	back_button.name = "Back"
	for button in [continue_button, new_game_button, load_button, settings_button, exit_button, previous_button, next_button, back_button]:
		Ui.enable_keyboard_focus(button)
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	load_button.pressed.connect(show_load_list)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	exit_button.pressed.connect(_on_exit)
	previous_button.pressed.connect(_change_page.bind(-1))
	next_button.pressed.connect(_change_page.bind(1))
	back_button.pressed.connect(_on_back_pressed)
	empty_label = Ui.make_label(self, Vector2(390, 254), Vector2(500, 100), 17)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_delete_modal()
	refresh_locale()


func _build_delete_modal() -> void:
	delete_modal_layer = Control.new()
	delete_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delete_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_modal_layer.z_index = 50
	add_child(delete_modal_layer)
	var blocker := ColorRect.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.color = Color("080b12e8")
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_modal_layer.add_child(blocker)
	var modal_card := Panel.new()
	modal_card.position = Vector2(360, 220)
	modal_card.size = Vector2(560, 280)
	modal_card.add_theme_stylebox_override("panel", Ui.make_panel_style(Color("9d625f")))
	delete_modal_layer.add_child(modal_card)
	delete_modal_title = Ui.make_label(delete_modal_layer, Vector2(390, 242), Vector2(500, 38), 24)
	delete_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delete_modal_body = Ui.make_label(delete_modal_layer, Vector2(402, 278), Vector2(476, 148), 14)
	delete_modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delete_modal_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	delete_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_no_button = Ui.make_button(delete_modal_layer, Vector2(402, 430), "", Vector2(220, 48))
	delete_yes_button = Ui.make_button(delete_modal_layer, Vector2(658, 430), "", Vector2(220, 48))
	var yes_glyph := TrashGlyph.new()
	yes_glyph.position = Vector2(12, 11)
	yes_glyph.size = Vector2(24, 26)
	delete_yes_button.add_child(yes_glyph)
	Ui.enable_keyboard_focus(delete_no_button)
	Ui.enable_keyboard_focus(delete_yes_button)
	for state_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var background := Color("2b1b1d") if state_name == "normal" else Color("3a2225")
		var width := 3 if state_name == "focus" else 2
		delete_yes_button.add_theme_stylebox_override(
			state_name, Ui.make_button_style(background, Color("d96b65"), width),
		)
	delete_no_button.pressed.connect(_defer_cancel_delete_modal)
	delete_yes_button.pressed.connect(_confirm_delete_modal)
	delete_modal_layer.visible = false


func set_slots(value: Array[Dictionary]) -> void:
	slots.clear()
	for metadata in value:
		slots.append(metadata.duplicate(true))
	_clamp_page()
	_rebuild_slot_buttons()
	_refresh_state()


func set_active_slot_id(value: String) -> void:
	active_slot_id = value


func set_error(value: String) -> void:
	error_text = value
	_refresh_state()


func show_startup() -> void:
	show_menu(false)


func show_menu(from_game := false) -> void:
	_cancel_delete_modal(false)
	in_game_context = from_game
	list_mode = false
	page = 0
	new_game_confirmation_pending = false
	exit_confirmation_pending = false
	visible = true
	refresh_locale()
	if continue_button.disabled:
		new_game_button.call_deferred("grab_focus")
	else:
		continue_button.call_deferred("grab_focus")


func show_load_list() -> void:
	if slots.is_empty():
		return
	_cancel_delete_modal(false)
	list_mode = true
	page = 0
	_refresh_state()
	if not slot_buttons.is_empty():
		slot_buttons[0].call_deferred("grab_focus")


func close() -> void:
	_cancel_delete_modal(false)
	visible = false
	list_mode = false
	new_game_confirmation_pending = false
	exit_confirmation_pending = false


func refresh_locale() -> void:
	if delete_modal_open:
		_cancel_delete_modal(false)
	title_label.text = Loc.text("SAVE_MENU_TITLE")
	subtitle_label.text = Loc.text(
		"SAVE_MENU_LOAD_SUBTITLE" if list_mode
		else ("SAVE_MENU_EMPTY_SUBTITLE" if slots.is_empty() and not in_game_context else "SAVE_MENU_SUBTITLE")
	)
	continue_button.text = Loc.text(
		"SAVE_MENU_RESUME" if in_game_context else "SAVE_MENU_CONTINUE"
	)
	new_game_button.text = Loc.text(
		"BTN_NEW_GAME_CONFIRM" if new_game_confirmation_pending else "SAVE_MENU_NEW"
	)
	load_button.text = Loc.text("SAVE_MENU_LOAD")
	settings_button.text = Loc.text("SAVE_MENU_SETTINGS")
	exit_button.text = Loc.text(
		"BTN_EXIT_CONFIRM" if exit_confirmation_pending else "SAVE_MENU_EXIT"
	)
	previous_button.text = Loc.text("SAVE_MENU_PREVIOUS")
	next_button.text = Loc.text("SAVE_MENU_NEXT")
	back_button.text = Loc.text("SAVE_MENU_BACK")
	empty_label.text = Loc.text("SAVE_MENU_EMPTY")
	for button in [continue_button, new_game_button, load_button, settings_button, exit_button, back_button]:
		button.accessibility_name = button.text
	_rebuild_slot_buttons()
	_refresh_state()


func _rebuild_slot_buttons() -> void:
	for button in slot_buttons:
		button.queue_free()
	for button in trash_buttons:
		button.queue_free()
	slot_buttons.clear()
	trash_buttons.clear()
	_clamp_page()
	var start := page * PAGE_SIZE
	var visible_count := mini(PAGE_SIZE, maxi(slots.size() - start, 0))
	for local_index in range(visible_count):
		var metadata := slots[start + local_index]
		var row_y := 210 + local_index * 58
		var load_control := Ui.make_button(self, Vector2(380, row_y), "", Vector2(460, 52))
		load_control.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var character_name := String(metadata.get("character_name", "—"))
		var date_text := _local_time_text(int(metadata.get("updated_at", 0)))
		var metadata_text := Loc.text("SAVE_MENU_ROW_META", [
			date_text, int(metadata.get("lifetime_souls_earned", 0)),
		])
		var full_text := Loc.text("SAVE_MENU_ROW", [
			character_name, date_text, int(metadata.get("lifetime_souls_earned", 0)),
		])
		load_control.tooltip_text = full_text
		load_control.accessibility_name = full_text
		Ui.enable_keyboard_focus(load_control)
		load_control.pressed.connect(_on_slot_pressed.bind(String(metadata.get("slot_id", ""))))
		var name_label := Ui.make_label(load_control, Vector2(12, 4), Vector2(432, 22), 13)
		name_label.text = character_name
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var metadata_label := Ui.make_label(load_control, Vector2(12, 27), Vector2(432, 18), 11)
		metadata_label.text = metadata_text
		metadata_label.add_theme_color_override("font_color", Color("aeb7c5"))
		metadata_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_buttons.append(load_control)
		var trash := TrashButton.new()
		trash.position = Vector2(848, row_y)
		trash.size = Vector2(52, 52)
		trash.focus_mode = Control.FOCUS_ALL
		trash.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		trash.tooltip_text = Loc.text("SAVE_MENU_DELETE_TOOLTIP", [character_name])
		trash.accessibility_name = trash.tooltip_text
		trash.add_theme_stylebox_override("normal", Ui.make_button_style(Color("171c25"), Color("3b4555")))
		trash.add_theme_stylebox_override("hover", Ui.make_button_style(Color("2b2428"), Color("8a5a5a"), 2))
		trash.add_theme_stylebox_override("pressed", Ui.make_button_style(Color("3c2427"), Color("d96b65"), 2))
		trash.add_theme_stylebox_override("focus", Ui.make_button_style(Color("202a35"), Color("72d7cf"), 2))
		add_child(trash)
		trash.pressed.connect(_open_delete_modal.bind(start + local_index))
		trash_buttons.append(trash)
	_configure_focus()


func _refresh_state() -> void:
	if title_label == null:
		return
	subtitle_label.text = Loc.text(
		"SAVE_MENU_LOAD_SUBTITLE" if list_mode
		else ("SAVE_MENU_EMPTY_SUBTITLE" if slots.is_empty() and not in_game_context else "SAVE_MENU_SUBTITLE")
	)
	error_label.text = error_text
	error_label.visible = not error_text.is_empty()
	continue_button.visible = not list_mode
	new_game_button.visible = not list_mode
	load_button.visible = not list_mode
	settings_button.visible = not list_mode
	exit_button.visible = not list_mode
	continue_button.disabled = slots.is_empty() and not in_game_context
	load_button.disabled = slots.is_empty()
	back_button.visible = list_mode
	var page_count := _page_count()
	previous_button.visible = list_mode and page_count > 1
	next_button.visible = list_mode and page_count > 1
	page_label.visible = list_mode and page_count > 1
	previous_button.disabled = page <= 0
	next_button.disabled = page >= page_count - 1
	page_label.text = Loc.text("SAVE_MENU_PAGE", [page + 1, page_count])
	empty_label.visible = list_mode and slots.is_empty()
	for button in slot_buttons:
		button.visible = list_mode
	for button in trash_buttons:
		button.visible = list_mode
	_configure_focus()


func _configure_focus() -> void:
	if continue_button == null:
		return
	if not list_mode:
		var controls: Array[Control] = [continue_button, new_game_button, load_button, settings_button, exit_button]
		for index in range(controls.size()):
			controls[index].focus_neighbor_top = controls[(index - 1 + controls.size()) % controls.size()].get_path()
			controls[index].focus_neighbor_bottom = controls[(index + 1) % controls.size()].get_path()
		return
	for index in range(slot_buttons.size()):
		var load_control := slot_buttons[index]
		var trash := trash_buttons[index]
		load_control.focus_neighbor_right = trash.get_path()
		trash.focus_neighbor_left = load_control.get_path()
		var above_load: Control = slot_buttons[index - 1] if index > 0 else back_button
		var above_trash: Control = trash_buttons[index - 1] if index > 0 else back_button
		var below_load: Control = slot_buttons[index + 1] if index + 1 < slot_buttons.size() else _bottom_control(false)
		var below_trash: Control = trash_buttons[index + 1] if index + 1 < trash_buttons.size() else _bottom_control(true)
		load_control.focus_neighbor_top = above_load.get_path()
		trash.focus_neighbor_top = above_trash.get_path()
		load_control.focus_neighbor_bottom = below_load.get_path()
		trash.focus_neighbor_bottom = below_trash.get_path()


func _on_continue() -> void:
	if in_game_context:
		resume_requested.emit()
	elif not slots.is_empty():
		continue_requested.emit(String(slots[0].get("slot_id", "")))


func _on_new_game() -> void:
	if in_game_context and not new_game_confirmation_pending:
		new_game_confirmation_pending = true
		exit_confirmation_pending = false
		refresh_locale()
		return
	new_game_requested.emit()


func _on_exit() -> void:
	if not exit_confirmation_pending:
		exit_confirmation_pending = true
		new_game_confirmation_pending = false
		refresh_locale()
		return
	exit_requested.emit()


func _on_slot_pressed(slot_id: String) -> void:
	if Time.get_ticks_msec() < list_activation_blocked_until_ms:
		return
	load_requested.emit(slot_id)


func _open_delete_modal(global_index: int) -> void:
	if delete_modal_open or global_index < 0 or global_index >= slots.size():
		return
	pending_delete_origin_index = global_index
	pending_delete_metadata = slots[global_index].duplicate(true)
	pending_delete_slot_id = String(pending_delete_metadata.get("slot_id", ""))
	if pending_delete_slot_id.is_empty():
		return
	delete_request_emitted = false
	delete_modal_open = true
	delete_modal_layer.visible = true
	delete_modal_title.text = Loc.text("SAVE_MENU_DELETE_TITLE")
	var body := Loc.text("SAVE_MENU_DELETE_BODY", [
		String(pending_delete_metadata.get("character_name", "—")),
		_local_time_text(int(pending_delete_metadata.get("updated_at", 0))),
	])
	if pending_delete_slot_id == active_slot_id:
		body += "\n" + Loc.text("SAVE_MENU_DELETE_ACTIVE_WARNING")
	delete_modal_body.text = body
	delete_no_button.text = Loc.text("SAVE_MENU_DELETE_NO")
	delete_yes_button.text = Loc.text("SAVE_MENU_DELETE_YES")
	delete_no_button.accessibility_name = delete_no_button.text
	delete_yes_button.accessibility_name = delete_yes_button.text
	delete_no_button.focus_neighbor_left = delete_yes_button.get_path()
	delete_no_button.focus_neighbor_right = delete_yes_button.get_path()
	delete_yes_button.focus_neighbor_left = delete_no_button.get_path()
	delete_yes_button.focus_neighbor_right = delete_no_button.get_path()
	delete_no_button.call_deferred("grab_focus")


func _cancel_delete_modal(restore_focus := true) -> void:
	if not delete_modal_open:
		return
	var origin := pending_delete_origin_index
	delete_modal_open = false
	delete_modal_layer.visible = false
	pending_delete_slot_id = ""
	pending_delete_metadata.clear()
	pending_delete_origin_index = -1
	delete_request_emitted = false
	if restore_focus and list_mode and origin >= page * PAGE_SIZE:
		var local_index := origin - page * PAGE_SIZE
		if local_index >= 0 and local_index < trash_buttons.size():
			trash_buttons[local_index].call_deferred("grab_focus")


func _defer_cancel_delete_modal() -> void:
	# Keep the blocking layer alive until the current mouse/touch event has fully
	# propagated; hiding it inside Button.pressed can retarget an emulated release.
	list_activation_blocked_until_ms = Time.get_ticks_msec() + 350
	delete_no_button.disabled = true
	delete_yes_button.disabled = true
	_cancel_delete_modal_after_input()


func _cancel_delete_modal_after_input() -> void:
	# ScreenTouch may synthesize its mouse release a few frames after the touch
	# press. Keep the full-screen blocker through that complete sequence.
	for _frame in range(5):
		await get_tree().process_frame
	delete_no_button.disabled = false
	delete_yes_button.disabled = false
	_cancel_delete_modal()


func _confirm_delete_modal() -> void:
	if not delete_modal_open or delete_request_emitted or pending_delete_slot_id.is_empty():
		return
	delete_request_emitted = true
	list_activation_blocked_until_ms = Time.get_ticks_msec() + 350
	var requested_slot_id := pending_delete_slot_id
	delete_no_button.disabled = true
	delete_yes_button.disabled = true
	delete_requested.emit(requested_slot_id)


func complete_delete(result: Dictionary, refreshed_slots: Array[Dictionary], localized_error := "") -> void:
	var origin := pending_delete_origin_index
	var success := bool(result.get("ok", false))
	delete_modal_open = false
	delete_modal_layer.visible = false
	delete_no_button.disabled = false
	delete_yes_button.disabled = false
	pending_delete_slot_id = ""
	pending_delete_metadata.clear()
	pending_delete_origin_index = -1
	delete_request_emitted = false
	error_text = "" if success else localized_error
	slots.clear()
	for metadata in refreshed_slots:
		slots.append(metadata.duplicate(true))
	var focus_index := mini(maxi(origin, 0), slots.size() - 1) if not slots.is_empty() else -1
	page = focus_index / PAGE_SIZE if focus_index >= 0 else 0
	_clamp_page()
	_rebuild_slot_buttons()
	_refresh_state()
	if focus_index >= 0:
		var local_index := focus_index - page * PAGE_SIZE
		if success and local_index < slot_buttons.size():
			slot_buttons[local_index].call_deferred("grab_focus")
		elif local_index < trash_buttons.size():
			trash_buttons[local_index].call_deferred("grab_focus")
	else:
		back_button.call_deferred("grab_focus")


func _on_back_pressed() -> void:
	show_menu(in_game_context)


func _change_page(direction: int) -> void:
	page = clampi(page + direction, 0, _page_count() - 1)
	_rebuild_slot_buttons()
	_refresh_state()
	if not slot_buttons.is_empty():
		slot_buttons[0].call_deferred("grab_focus")


func _page_count() -> int:
	return maxi(1, ceili(float(slots.size()) / float(PAGE_SIZE)))


func _clamp_page() -> void:
	page = clampi(page, 0, _page_count() - 1)


func _unhandled_input(event: InputEvent) -> void:
	if handle_input(event):
		get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventScreenTouch:
		return _handle_screen_touch(event)
	if event is InputEventMouseButton:
		if modal_mouse_release_pending and not event.pressed:
			modal_mouse_release_pending = false
			return true
		if delete_modal_open:
			if event.pressed:
				modal_mouse_release_pending = true
				list_activation_blocked_until_ms = Time.get_ticks_msec() + 350
				if delete_no_button.get_global_rect().has_point(event.position):
					_cancel_delete_modal()
				elif delete_yes_button.get_global_rect().has_point(event.position):
					_confirm_delete_modal()
			return true
	if delete_modal_open:
		# Let motion reach the real controls for hover treatment. Button presses are
		# hit-tested above so their matching release cannot be retargeted after the
		# modal closes.
		if event is InputEventMouseMotion:
			return false
		if _event_pressed(event, "ui_cancel"):
			_cancel_delete_modal()
			return true
		if _event_pressed(event, "ui_left") or _event_pressed(event, "ui_right"):
			var focused := get_viewport().gui_get_focus_owner()
			(delete_yes_button if focused == delete_no_button else delete_no_button).grab_focus()
			return true
		if _event_pressed(event, "ui_up") or _event_pressed(event, "ui_down"):
			delete_no_button.grab_focus()
			return true
		if _event_pressed(event, "ui_accept"):
			var focused := get_viewport().gui_get_focus_owner()
			if focused == delete_yes_button:
				_confirm_delete_modal()
			else:
				_cancel_delete_modal()
			return true
		return true
	if list_mode and _event_pressed(event, "ui_cancel"):
		show_menu(in_game_context)
		return true
	if not list_mode and in_game_context and (
		_event_pressed(event, "ui_cancel") or _event_pressed(event, "game_menu")
	):
		resume_requested.emit()
		return true
	if list_mode and (_event_pressed(event, "ui_left") or _event_pressed(event, "ui_right")):
		var focused := get_viewport().gui_get_focus_owner()
		var load_index := slot_buttons.find(focused)
		var trash_index := trash_buttons.find(focused)
		if load_index >= 0:
			trash_buttons[load_index].grab_focus()
			return true
		if trash_index >= 0:
			slot_buttons[trash_index].grab_focus()
			return true
	var direction := 0
	if _event_pressed(event, "ui_down"):
		direction = 1
	elif _event_pressed(event, "ui_up"):
		direction = -1
	if direction != 0:
		if list_mode and _move_list_focus(direction):
			return true
		var controls := _current_focus_controls()
		if not controls.is_empty():
			var current := controls.find(get_viewport().gui_get_focus_owner())
			controls[(current + direction + controls.size()) % controls.size()].grab_focus()
			return true
	if _event_pressed(event, "ui_accept"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and _current_focus_controls().has(focused):
			focused.pressed.emit()
			return true
	return false


func _handle_screen_touch(event: InputEventScreenTouch) -> bool:
	# Main routes touch here before Godot's mouse emulation. Consume both phases so
	# the release can never be retargeted to the list after a modal closes.
	if not event.pressed:
		return true
	if delete_modal_open:
		if delete_no_button.get_global_rect().has_point(event.position):
			_cancel_delete_modal()
		elif delete_yes_button.get_global_rect().has_point(event.position):
			_confirm_delete_modal()
		return true
	if list_mode:
		for index in range(trash_buttons.size()):
			if trash_buttons[index].get_global_rect().has_point(event.position):
				_open_delete_modal(page * PAGE_SIZE + index)
				return true
			if slot_buttons[index].get_global_rect().has_point(event.position):
				_on_slot_pressed(String(slots[page * PAGE_SIZE + index].get("slot_id", "")))
				return true
		if previous_button.visible and previous_button.get_global_rect().has_point(event.position):
			_change_page(-1)
		elif next_button.visible and next_button.get_global_rect().has_point(event.position):
			_change_page(1)
		elif back_button.get_global_rect().has_point(event.position):
			_on_back_pressed()
		return true
	for button in [continue_button, new_game_button, load_button, settings_button, exit_button]:
		if button.visible and not button.disabled and button.get_global_rect().has_point(event.position):
			button.pressed.emit()
			return true
	return true


func _event_pressed(event: InputEvent, action: String) -> bool:
	return (
		event.is_action_pressed(action)
		or (
			event is InputEventAction
			and event.action == action
			and event.pressed
		)
	)


func _current_focus_controls() -> Array[Control]:
	var result: Array[Control] = []
	if list_mode:
		result.append_array(slot_buttons)
		result.append_array(trash_buttons)
		if previous_button.visible and not previous_button.disabled:
			result.append(previous_button)
		if next_button.visible and not next_button.disabled:
			result.append(next_button)
		result.append(back_button)
	else:
		if not continue_button.disabled:
			result.append(continue_button)
		result.append(new_game_button)
		if not load_button.disabled:
			result.append(load_button)
		result.append(settings_button)
		result.append(exit_button)
	return result


func _bottom_control(trash_column: bool) -> Control:
	if trash_column and next_button.visible and not next_button.disabled:
		return next_button
	if not trash_column and previous_button.visible and not previous_button.disabled:
		return previous_button
	if next_button.visible and not next_button.disabled:
		return next_button
	if previous_button.visible and not previous_button.disabled:
		return previous_button
	return back_button


func _move_list_focus(direction: int) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	var load_index := slot_buttons.find(focused)
	var trash_index := trash_buttons.find(focused)
	if load_index >= 0:
		if direction < 0:
			(back_button if load_index == 0 else slot_buttons[load_index - 1]).grab_focus()
		else:
			(_bottom_control(false) if load_index + 1 >= slot_buttons.size() else slot_buttons[load_index + 1]).grab_focus()
		return true
	if trash_index >= 0:
		if direction < 0:
			(back_button if trash_index == 0 else trash_buttons[trash_index - 1]).grab_focus()
		else:
			(_bottom_control(true) if trash_index + 1 >= trash_buttons.size() else trash_buttons[trash_index + 1]).grab_focus()
		return true
	if focused == previous_button or focused == next_button:
		if direction < 0 and not slot_buttons.is_empty():
			(slot_buttons[-1] if focused == previous_button else trash_buttons[-1]).grab_focus()
		else:
			back_button.grab_focus()
		return true
	if focused == back_button and direction < 0:
		_bottom_control(false).grab_focus()
		return true
	return false


func _local_time_text(timestamp: int) -> String:
	if timestamp <= 0:
		return Loc.text("SAVE_MENU_UNKNOWN_DATE")
	var zone: Dictionary = Time.get_time_zone_from_system()
	var local_timestamp := timestamp + int(zone.get("bias", 0)) * 60
	var value := Time.get_datetime_dict_from_unix_time(local_timestamp)
	return "%02d.%02d.%04d  %02d:%02d" % [value.day, value.month, value.year, value.hour, value.minute]
