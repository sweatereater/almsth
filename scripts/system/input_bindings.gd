class_name InputBindings
extends RefCounted

## Owns the stable gameplay action names and their serializable keyboard/gamepad
## events. UI code may inspect and replace bindings without knowing InputMap details.

const DEVICE_KEYBOARD := "keyboard"
const DEVICE_GAMEPAD := "gamepad"

const GAMEPLAY_ACTIONS := [
	"move_up", "move_down", "move_left", "move_right",
	"attack", "cast_spell", "wait_turn", "auto_explore", "camp", "ascend_floor", "interact",
	"character_sheet", "game_menu",
]

const ACTION_LABEL_KEYS := {
	"move_up": "INPUT_ACTION_MOVE_UP",
	"move_down": "INPUT_ACTION_MOVE_DOWN",
	"move_left": "INPUT_ACTION_MOVE_LEFT",
	"move_right": "INPUT_ACTION_MOVE_RIGHT",
	"attack": "INPUT_ACTION_ATTACK",
	"cast_spell": "INPUT_ACTION_CAST_SPELL",
	"wait_turn": "INPUT_ACTION_WAIT",
	"auto_explore": "INPUT_ACTION_AUTO_EXPLORE",
	"camp": "INPUT_ACTION_CAMP",
	"ascend_floor": "INPUT_ACTION_ASCEND",
	"interact": "INPUT_ACTION_INTERACT",
	"character_sheet": "INPUT_ACTION_CHARACTER",
	"game_menu": "INPUT_ACTION_MENU",
}


static func ensure_defaults() -> void:
	for action in GAMEPLAY_ACTIONS:
		_ensure_action(action, _default_bindings_for(action))


static func reset_to_defaults() -> void:
	for action in GAMEPLAY_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.45)
		InputMap.action_erase_events(action)
		for event in _default_bindings_for(action):
			InputMap.action_add_event(action, event)


static func action_direction_from_event(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("move_up"):
		return Vector2i.UP
	if event.is_action_pressed("move_down"):
		return Vector2i.DOWN
	if event.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if event.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


static func action_direction_released(event: InputEvent) -> Vector2i:
	if event.is_action_released("move_up"):
		return Vector2i.UP
	if event.is_action_released("move_down"):
		return Vector2i.DOWN
	if event.is_action_released("move_left"):
		return Vector2i.LEFT
	if event.is_action_released("move_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


static func export_bindings() -> Dictionary:
	var result: Dictionary = {}
	for action in GAMEPLAY_ACTIONS:
		var serialized_events: Array = []
		for event in InputMap.action_get_events(action):
			var serialized := _serialize_event(event)
			if not serialized.is_empty():
				serialized_events.append(serialized)
		result[action] = serialized_events
	return result


static func import_bindings(data: Dictionary) -> void:
	var legacy_evolution_binding := data.has("evolve_form")
	for action in GAMEPLAY_ACTIONS:
		if not data.has(action) or not data[action] is Array or data[action].is_empty():
			continue
		var restored_events: Array[InputEvent] = []
		for serialized in data[action]:
			if not serialized is Dictionary:
				continue
			var event := _deserialize_event(serialized)
			if event != null:
				restored_events.append(event)
		# A malformed action must not erase working defaults from an otherwise
		# readable old settings file.
		if restored_events.is_empty():
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.45)
		InputMap.action_erase_events(action)
		for event in restored_events:
			InputMap.action_add_event(action, event)
	# Very old settings used E on a removed evolution action. Migrate only those
	# files; current remaps are allowed to move E away from the character sheet.
	if legacy_evolution_binding:
		_ensure_key_binding("character_sheet", KEY_E)


static func get_device_events(action: String, device: String) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if not GAMEPLAY_ACTIONS.has(action) or not InputMap.has_action(action):
		return result
	for event in InputMap.action_get_events(action):
		if event_device(event) == device:
			result.append(event)
	return result


static func event_device(event: InputEvent) -> String:
	if event is InputEventKey:
		return DEVICE_KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return DEVICE_GAMEPAD
	return ""


static func normalize_binding_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return null
		if event.keycode == KEY_NONE and event.physical_keycode == KEY_NONE:
			return null
		var normalized_key := InputEventKey.new()
		normalized_key.keycode = event.keycode
		normalized_key.physical_keycode = event.physical_keycode
		normalized_key.shift_pressed = event.shift_pressed
		normalized_key.ctrl_pressed = event.ctrl_pressed
		normalized_key.alt_pressed = event.alt_pressed
		normalized_key.meta_pressed = event.meta_pressed
		normalized_key.pressed = true
		return normalized_key
	if event is InputEventJoypadButton:
		if not event.pressed:
			return null
		var normalized_button := _joy_button(event.button_index)
		normalized_button.pressed = true
		return normalized_button
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.7:
			return null
		return _joy_axis(event.axis, -1.0 if event.axis_value < 0.0 else 1.0)
	return null


static func find_conflicts(action: String, event: InputEvent) -> Array[String]:
	var normalized := normalize_binding_event(event)
	if normalized == null:
		return []
	return _find_conflicts_normalized(action, normalized)


static func _find_conflicts_normalized(action: String, event: InputEvent) -> Array[String]:
	var conflicts: Array[String] = []
	for candidate_action in GAMEPLAY_ACTIONS:
		if candidate_action == action or not InputMap.has_action(candidate_action):
			continue
		for assigned_event in InputMap.action_get_events(candidate_action):
			if events_equivalent(event, assigned_event):
				conflicts.append(candidate_action)
				break
	return conflicts


static func replace_device_binding(
	action: String,
	event: InputEvent,
	resolve_conflicts := false,
) -> Dictionary:
	if not GAMEPLAY_ACTIONS.has(action) or not InputMap.has_action(action):
		return {"ok": false, "reason": "unknown_action", "conflicts": []}
	var normalized := normalize_binding_event(event)
	if normalized == null:
		return {"ok": false, "reason": "unsupported_event", "conflicts": []}
	var device := event_device(normalized)
	var conflicts := _find_conflicts_normalized(action, normalized)
	if not conflicts.is_empty() and not resolve_conflicts:
		return {"ok": false, "reason": "conflict", "conflicts": conflicts}
	if resolve_conflicts:
		for conflict_action in conflicts:
			_remove_equivalent_binding(conflict_action, normalized)
	_remove_device_bindings(action, device)
	InputMap.action_add_event(action, _event_for_input_map(normalized))
	return {
		"ok": true,
		"reason": "",
		"conflicts": conflicts,
		"device": device,
	}


static func events_equivalent(first: InputEvent, second: InputEvent) -> bool:
	if event_device(first) != event_device(second):
		return false
	if first is InputEventKey and second is InputEventKey:
		return (
			_effective_keycode(first) == _effective_keycode(second)
			and first.shift_pressed == second.shift_pressed
			and first.ctrl_pressed == second.ctrl_pressed
			and first.alt_pressed == second.alt_pressed
			and first.meta_pressed == second.meta_pressed
		)
	if first is InputEventJoypadButton and second is InputEventJoypadButton:
		return first.button_index == second.button_index
	if first is InputEventJoypadMotion and second is InputEventJoypadMotion:
		return (
			first.axis == second.axis
			and signf(first.axis_value) == signf(second.axis_value)
		)
	return false


static func replace_primary_keyboard_binding(action: String, keycode: Key) -> bool:
	if not GAMEPLAY_ACTIONS.has(action) or not InputMap.has_action(action):
		return false
	var retained: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if not event is InputEventKey:
			retained.append(event)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, _key(keycode))
	for event in retained:
		InputMap.action_add_event(action, event)
	return true


static func _default_bindings_for(action: String) -> Array[InputEvent]:
	match action:
		"move_up":
			return [
				_key(KEY_W, true), _key(KEY_UP), _joy_button(JOY_BUTTON_DPAD_UP),
				_joy_axis(JOY_AXIS_LEFT_Y, -1.0),
			]
		"move_down":
			return [
				_key(KEY_S, true), _key(KEY_DOWN), _joy_button(JOY_BUTTON_DPAD_DOWN),
				_joy_axis(JOY_AXIS_LEFT_Y, 1.0),
			]
		"move_left":
			return [
				_key(KEY_A, true), _key(KEY_LEFT), _joy_button(JOY_BUTTON_DPAD_LEFT),
				_joy_axis(JOY_AXIS_LEFT_X, -1.0),
			]
		"move_right":
			return [
				_key(KEY_D, true), _key(KEY_RIGHT), _joy_button(JOY_BUTTON_DPAD_RIGHT),
				_joy_axis(JOY_AXIS_LEFT_X, 1.0),
			]
		"wait_turn":
			return [_key(KEY_T), _joy_button(JOY_BUTTON_Y)]
		"auto_explore":
			return [_key(KEY_X), _joy_button(JOY_BUTTON_LEFT_STICK)]
		"attack":
			return [_key(KEY_F), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)]
		"cast_spell":
			return [_key(KEY_Q), _joy_button(JOY_BUTTON_X)]
		"camp":
			return [_key(KEY_R), _joy_button(JOY_BUTTON_B)]
		"ascend_floor":
			return [_key(KEY_G), _joy_button(JOY_BUTTON_LEFT_SHOULDER)]
		"interact":
			return [_key(KEY_SPACE), _key(KEY_ENTER), _joy_button(JOY_BUTTON_A)]
		"character_sheet":
			return [_key(KEY_E), _key(KEY_C), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)]
		"game_menu":
			return [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_START)]
	return []


static func _ensure_action(action: String, defaults: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.45)
	if not InputMap.action_get_events(action).is_empty():
		return
	for event in defaults:
		InputMap.action_add_event(action, event)


static func _ensure_key_binding(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.45)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and _effective_keycode(event) == keycode:
			return
	InputMap.action_add_event(action, _key(keycode))


static func _remove_device_bindings(action: String, device: String) -> void:
	for event in InputMap.action_get_events(action):
		if event_device(event) == device:
			InputMap.action_erase_event(action, event)


static func _remove_equivalent_binding(action: String, target: InputEvent) -> void:
	for event in InputMap.action_get_events(action):
		if events_equivalent(event, target):
			InputMap.action_erase_event(action, event)


static func _event_for_input_map(event: InputEvent) -> InputEvent:
	var stored := event.duplicate() as InputEvent
	if stored is InputEventKey or stored is InputEventJoypadButton:
		stored.pressed = false
	return stored


static func _effective_keycode(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


static func _key(keycode: Key, physical := false) -> InputEventKey:
	var event := InputEventKey.new()
	if physical:
		event.physical_keycode = keycode
	else:
		event.keycode = keycode
	return event


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


static func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"type": "key",
			"keycode": int(event.keycode),
			"physical_keycode": int(event.physical_keycode),
			"shift": event.shift_pressed,
			"ctrl": event.ctrl_pressed,
			"alt": event.alt_pressed,
			"meta": event.meta_pressed,
		}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": int(event.button_index)}
	if event is InputEventJoypadMotion:
		return {
			"type": "joy_axis",
			"axis": int(event.axis),
			"value": -1.0 if event.axis_value < 0.0 else 1.0,
		}
	return {}


static func _deserialize_event(data: Dictionary) -> InputEvent:
	match String(data.get("type", "")):
		"key":
			var keycode := int(data.get("keycode", 0)) as Key
			var physical_keycode := int(data.get("physical_keycode", 0)) as Key
			if keycode == KEY_NONE and physical_keycode == KEY_NONE:
				return null
			var event := InputEventKey.new()
			event.keycode = keycode
			event.physical_keycode = physical_keycode
			event.shift_pressed = bool(data.get("shift", false))
			event.ctrl_pressed = bool(data.get("ctrl", false))
			event.alt_pressed = bool(data.get("alt", false))
			event.meta_pressed = bool(data.get("meta", false))
			return event
		"joy_button":
			var button := int(data.get("button", -1))
			if button < 0 or button >= JOY_BUTTON_MAX:
				return null
			return _joy_button(button as JoyButton)
		"joy_axis":
			var axis := int(data.get("axis", -1))
			var value := float(data.get("value", 0.0))
			if axis < 0 or axis >= JOY_AXIS_MAX or is_zero_approx(value):
				return null
			return _joy_axis(axis as JoyAxis, -1.0 if value < 0.0 else 1.0)
	return null
