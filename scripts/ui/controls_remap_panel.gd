class_name ControlsRemapPanel
extends Control

signal close_requested
signal bindings_changed

const Loc := preload("res://scripts/localization/localization.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")

const ROW_START_Y := 136.0
const ROW_HEIGHT := 32.0

var title_label: Label
var subtitle_label: Label
var action_header_label: Label
var keyboard_header_label: Label
var gamepad_header_label: Label
var status_label: Label
var action_name_labels: Dictionary = {}
var keyboard_buttons: Dictionary = {}
var gamepad_buttons: Dictionary = {}
var reset_button: Button
var back_button: Button

var capture_action := ""
var capture_device := ""
var pending_event: InputEvent
var pending_conflicts: Array[String] = []
var reset_confirmation := false


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	apply_locale()
	visible = false


func set_open(value: bool) -> void:
	visible = value
	if not value:
		_cancel_capture(false)
		reset_confirmation = false
		return
	reset_confirmation = false
	_cancel_capture(false)
	refresh_bindings()
	apply_locale()
	var first_button: Button = keyboard_buttons.get(InputProfile.GAMEPLAY_ACTIONS[0])
	if first_button != null:
		first_button.grab_focus()


func apply_locale() -> void:
	if title_label == null:
		return
	title_label.text = Loc.text("CONTROLS_TITLE")
	subtitle_label.text = Loc.text("CONTROLS_SUBTITLE")
	action_header_label.text = Loc.text("CONTROLS_ACTION_HEADER")
	keyboard_header_label.text = Loc.text("CONTROLS_KEYBOARD_HEADER")
	gamepad_header_label.text = Loc.text("CONTROLS_GAMEPAD_HEADER")
	for action in InputProfile.GAMEPLAY_ACTIONS:
		action_name_labels[action].text = Loc.text(
			String(InputProfile.ACTION_LABEL_KEYS[action])
		)
	reset_button.text = Loc.text(
		"CONTROLS_RESET_CONFIRM" if reset_confirmation else "CONTROLS_RESET"
	)
	back_button.text = Loc.text("CONTROLS_BACK")
	_refresh_status()
	refresh_bindings()


func refresh_bindings() -> void:
	if keyboard_buttons.is_empty():
		return
	for action in InputProfile.GAMEPLAY_ACTIONS:
		var keyboard_button: Button = keyboard_buttons[action]
		var gamepad_button: Button = gamepad_buttons[action]
		keyboard_button.text = _binding_text(action, InputProfile.DEVICE_KEYBOARD)
		gamepad_button.text = _binding_text(action, InputProfile.DEVICE_GAMEPAD)
		Ui.fit_button_text(keyboard_button, 14, 10)
		Ui.fit_button_text(gamepad_button, 14, 10)


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and event.echo:
		return not capture_action.is_empty()

	if reset_confirmation and _is_cancel_event(event):
		reset_confirmation = false
		reset_button.text = Loc.text("CONTROLS_RESET")
		status_label.text = Loc.text("CONTROLS_CANCELLED")
		reset_button.grab_focus()
		return true

	if not capture_action.is_empty():
		if _is_cancel_event(event):
			_cancel_capture(true)
			return true
		if pending_event != null:
			if _is_confirm_event(event):
				_apply_pending_conflict()
			return _is_keyboard_or_gamepad_event(event)

		var normalized := InputProfile.normalize_binding_event(event)
		if normalized == null:
			return _is_keyboard_or_gamepad_event(event)
		if InputProfile.event_device(normalized) != capture_device:
			status_label.text = Loc.text("CONTROLS_WRONG_DEVICE", [
				Loc.text(
					"CONTROLS_KEYBOARD_HEADER"
					if capture_device == InputProfile.DEVICE_KEYBOARD
					else "CONTROLS_GAMEPAD_HEADER"
				),
			])
			return true
		var result := InputProfile.replace_device_binding(capture_action, normalized)
		if String(result.get("reason", "")) == "conflict":
			pending_event = normalized
			pending_conflicts.assign(result.get("conflicts", []))
			_refresh_status()
			return true
		if bool(result.get("ok", false)):
			_finish_capture(true)
		return true

	if _is_confirm_event(event):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and is_ancestor_of(focused):
			focused.pressed.emit()
			return true
	if _is_cancel_event(event):
		close_requested.emit()
		return true
	return false


func _build_interface() -> void:
	var overlay := ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color("0c1118f7")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var card := Panel.new()
	card.position = Vector2(70, 24)
	card.size = Vector2(1140, 672)
	card.add_theme_stylebox_override("panel", Ui.make_panel_style(Color("52647b")))
	add_child(card)

	title_label = Ui.make_label(self, Vector2(110, 42), Vector2(1060, 42), 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label = Ui.make_label(self, Vector2(120, 82), Vector2(1040, 36), 15)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	action_header_label = _make_header(Vector2(120, 114), Vector2(280, 24))
	keyboard_header_label = _make_header(Vector2(420, 114), Vector2(330, 24))
	gamepad_header_label = _make_header(Vector2(770, 114), Vector2(330, 24))

	for index in range(InputProfile.GAMEPLAY_ACTIONS.size()):
		var action: String = InputProfile.GAMEPLAY_ACTIONS[index]
		var row_y := ROW_START_Y + index * ROW_HEIGHT
		var action_label := Ui.make_label(self, Vector2(120, row_y), Vector2(280, 27), 14)
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_name_labels[action] = action_label

		var keyboard_button := Ui.make_button(
			self,
			Vector2(420, row_y),
			"",
			Vector2(330, 27),
		)
		keyboard_button.name = "Keyboard_%s" % action
		keyboard_button.pressed.connect(
			_begin_capture.bind(action, InputProfile.DEVICE_KEYBOARD, keyboard_button)
		)
		Ui.enable_keyboard_focus(keyboard_button)
		keyboard_buttons[action] = keyboard_button

		var gamepad_button := Ui.make_button(
			self,
			Vector2(770, row_y),
			"",
			Vector2(330, 27),
		)
		gamepad_button.name = "Gamepad_%s" % action
		gamepad_button.pressed.connect(
			_begin_capture.bind(action, InputProfile.DEVICE_GAMEPAD, gamepad_button)
		)
		Ui.enable_keyboard_focus(gamepad_button)
		gamepad_buttons[action] = gamepad_button

	status_label = Ui.make_label(self, Vector2(120, 574), Vector2(1040, 42), 14)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("d4ad62"))

	reset_button = Ui.make_button(self, Vector2(250, 628), "", Vector2(360, 44))
	reset_button.name = "ResetControls"
	reset_button.pressed.connect(_on_reset_pressed)
	Ui.enable_keyboard_focus(reset_button)
	back_button = Ui.make_button(self, Vector2(670, 628), "", Vector2(360, 44))
	back_button.name = "BackFromControls"
	back_button.pressed.connect(_on_back_pressed)
	Ui.enable_keyboard_focus(back_button)
	_configure_focus_navigation()


func _make_header(position_value: Vector2, size_value: Vector2) -> Label:
	var label := Ui.make_label(self, position_value, size_value, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("72d7cf"))
	return label


func _configure_focus_navigation() -> void:
	var actions: Array = InputProfile.GAMEPLAY_ACTIONS
	for index in range(actions.size()):
		var action: String = actions[index]
		var keyboard_button: Button = keyboard_buttons[action]
		var gamepad_button: Button = gamepad_buttons[action]
		var previous_action: String = actions[index - 1] if index > 0 else actions[-1]
		var next_action: String = actions[index + 1] if index < actions.size() - 1 else actions[0]
		keyboard_button.focus_neighbor_left = gamepad_button.get_path()
		keyboard_button.focus_neighbor_right = gamepad_button.get_path()
		gamepad_button.focus_neighbor_left = keyboard_button.get_path()
		gamepad_button.focus_neighbor_right = keyboard_button.get_path()
		keyboard_button.focus_neighbor_top = keyboard_buttons[previous_action].get_path()
		gamepad_button.focus_neighbor_top = gamepad_buttons[previous_action].get_path()
		if index < actions.size() - 1:
			keyboard_button.focus_neighbor_bottom = keyboard_buttons[next_action].get_path()
			gamepad_button.focus_neighbor_bottom = gamepad_buttons[next_action].get_path()
		else:
			keyboard_button.focus_neighbor_bottom = reset_button.get_path()
			gamepad_button.focus_neighbor_bottom = back_button.get_path()
	reset_button.focus_neighbor_top = keyboard_buttons[actions[-1]].get_path()
	reset_button.focus_neighbor_left = back_button.get_path()
	reset_button.focus_neighbor_right = back_button.get_path()
	reset_button.focus_neighbor_bottom = keyboard_buttons[actions[0]].get_path()
	back_button.focus_neighbor_top = gamepad_buttons[actions[-1]].get_path()
	back_button.focus_neighbor_left = reset_button.get_path()
	back_button.focus_neighbor_right = reset_button.get_path()
	back_button.focus_neighbor_bottom = gamepad_buttons[actions[0]].get_path()


func _begin_capture(action: String, device: String, source_button: Button) -> void:
	reset_confirmation = false
	reset_button.text = Loc.text("CONTROLS_RESET")
	capture_action = action
	capture_device = device
	pending_event = null
	pending_conflicts.clear()
	source_button.grab_focus()
	_refresh_status()


func _apply_pending_conflict() -> void:
	var result := InputProfile.replace_device_binding(capture_action, pending_event, true)
	if bool(result.get("ok", false)):
		_finish_capture(true)


func _finish_capture(changed: bool) -> void:
	var changed_action := capture_action
	var changed_event := pending_event
	if changed_event == null:
		var events := InputProfile.get_device_events(changed_action, capture_device)
		if not events.is_empty():
			changed_event = events[0]
	capture_action = ""
	capture_device = ""
	pending_event = null
	pending_conflicts.clear()
	refresh_bindings()
	if changed:
		status_label.text = Loc.text("CONTROLS_APPLIED", [
			_event_text(changed_event),
			Loc.text(String(InputProfile.ACTION_LABEL_KEYS[changed_action])),
		])
		bindings_changed.emit()


func _cancel_capture(show_feedback: bool) -> void:
	var action := capture_action
	var device := capture_device
	capture_action = ""
	capture_device = ""
	pending_event = null
	pending_conflicts.clear()
	if show_feedback and status_label != null:
		status_label.text = Loc.text("CONTROLS_CANCELLED")
	if not action.is_empty():
		var button: Button = (
			keyboard_buttons[action]
			if device == InputProfile.DEVICE_KEYBOARD
			else gamepad_buttons[action]
		)
		button.grab_focus()


func _on_reset_pressed() -> void:
	if not reset_confirmation:
		_cancel_capture(false)
		reset_confirmation = true
		reset_button.text = Loc.text("CONTROLS_RESET_CONFIRM")
		status_label.text = Loc.text("CONTROLS_RESET_WARNING")
		return
	InputProfile.reset_to_defaults()
	reset_confirmation = false
	reset_button.text = Loc.text("CONTROLS_RESET")
	refresh_bindings()
	status_label.text = Loc.text("CONTROLS_RESET_DONE")
	reset_button.grab_focus()
	bindings_changed.emit()


func _on_back_pressed() -> void:
	if not capture_action.is_empty():
		_cancel_capture(true)
		return
	close_requested.emit()


func _refresh_status() -> void:
	if status_label == null:
		return
	if reset_confirmation:
		status_label.text = Loc.text("CONTROLS_RESET_WARNING")
		return
	if not capture_action.is_empty():
		if pending_event != null:
			var conflict_names: Array[String] = []
			for action in pending_conflicts:
				conflict_names.append(Loc.text(String(InputProfile.ACTION_LABEL_KEYS[action])))
			status_label.text = Loc.text("CONTROLS_CONFLICT", [
				_event_text(pending_event),
				", ".join(conflict_names),
			])
			return
		status_label.text = Loc.text(
			"CONTROLS_WAIT_KEYBOARD"
			if capture_device == InputProfile.DEVICE_KEYBOARD
			else "CONTROLS_WAIT_GAMEPAD"
		)
		return
	status_label.text = Loc.text("CONTROLS_NAV_HINT")


func _binding_text(action: String, device: String) -> String:
	var names: Array[String] = []
	for event in InputProfile.get_device_events(action, device):
		names.append(_event_text(event))
	return Loc.text("CONTROLS_NOT_ASSIGNED") if names.is_empty() else " / ".join(names)


func _event_text(event: InputEvent) -> String:
	if event == null:
		return Loc.text("CONTROLS_NOT_ASSIGNED")
	if event is InputEventKey:
		var keycode: Key = (
			event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		)
		var key_name := _key_name(keycode)
		var modifiers: Array[String] = []
		if event.ctrl_pressed:
			modifiers.append("Ctrl")
		if event.alt_pressed:
			modifiers.append("Alt")
		if event.shift_pressed:
			modifiers.append("Shift")
		if event.meta_pressed:
			modifiers.append("Meta")
		modifiers.append(key_name)
		return "+".join(modifiers)
	if event is InputEventJoypadButton:
		return _joy_button_name(event.button_index)
	if event is InputEventJoypadMotion:
		return _joy_axis_name(event.axis, event.axis_value)
	return Loc.text("CONTROLS_NOT_ASSIGNED")


func _key_name(keycode: Key) -> String:
	match keycode:
		KEY_SPACE:
			return Loc.text("INPUT_KEY_SPACE")
		KEY_ENTER, KEY_KP_ENTER:
			return Loc.text("INPUT_KEY_ENTER")
		KEY_ESCAPE:
			return Loc.text("INPUT_KEY_ESCAPE")
		KEY_TAB:
			return Loc.text("INPUT_KEY_TAB")
		KEY_BACKSPACE:
			return Loc.text("INPUT_KEY_BACKSPACE")
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
	return OS.get_keycode_string(keycode)


func _joy_button_name(button: JoyButton) -> String:
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_BACK:
			return Loc.text("INPUT_PAD_BACK")
		JOY_BUTTON_START:
			return Loc.text("INPUT_PAD_START")
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_DPAD_UP:
			return Loc.text("INPUT_DPAD_DIRECTION", ["↑"])
		JOY_BUTTON_DPAD_DOWN:
			return Loc.text("INPUT_DPAD_DIRECTION", ["↓"])
		JOY_BUTTON_DPAD_LEFT:
			return Loc.text("INPUT_DPAD_DIRECTION", ["←"])
		JOY_BUTTON_DPAD_RIGHT:
			return Loc.text("INPUT_DPAD_DIRECTION", ["→"])
	return Loc.text("INPUT_PAD_BUTTON", [int(button) + 1])


func _joy_axis_name(axis: JoyAxis, value: float) -> String:
	var direction := "−" if value < 0.0 else "+"
	match axis:
		JOY_AXIS_LEFT_X:
			return Loc.text("INPUT_LEFT_STICK_DIRECTION", ["←" if value < 0.0 else "→"])
		JOY_AXIS_LEFT_Y:
			return Loc.text("INPUT_LEFT_STICK_DIRECTION", ["↑" if value < 0.0 else "↓"])
		JOY_AXIS_RIGHT_X:
			return Loc.text("INPUT_RIGHT_STICK_DIRECTION", ["←" if value < 0.0 else "→"])
		JOY_AXIS_RIGHT_Y:
			return Loc.text("INPUT_RIGHT_STICK_DIRECTION", ["↑" if value < 0.0 else "↓"])
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return Loc.text("INPUT_PAD_AXIS", [int(axis) + 1, direction])


func _is_cancel_event(event: InputEvent) -> bool:
	return (
		(
			event is InputEventKey
			and event.pressed
			and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)
		)
		or (
			event is InputEventJoypadButton
			and event.pressed
			and event.button_index == JOY_BUTTON_B
		)
		or event.is_action_pressed("ui_cancel")
	)


func _is_confirm_event(event: InputEvent) -> bool:
	return (
		(
			event is InputEventKey
			and event.pressed
			and (
				event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
				or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			)
		)
		or (
			event is InputEventJoypadButton
			and event.pressed
			and event.button_index == JOY_BUTTON_A
		)
		or event.is_action_pressed("ui_accept")
	)


func _is_keyboard_or_gamepad_event(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		or event is InputEventJoypadButton
		or event is InputEventJoypadMotion
	)
