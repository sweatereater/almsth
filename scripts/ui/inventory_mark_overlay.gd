class_name InventoryMarkOverlay
extends Control

## Two code-drawn, independently focusable card-corner mark controls. The
## silhouettes and selected/focus geometry augment color so Keep and Salvage
## remain distinguishable without color perception.

signal mark_requested(mark: String, identity: Dictionary, generation: int)

const Loc := preload("res://scripts/localization/localization.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")

const ACTION_SIZE := Vector2(28, 28)
const ACTION_GAP := 2.0
const INTERACTIVE_SIZE := Vector2(ACTION_SIZE.x * 2.0 + ACTION_GAP, ACTION_SIZE.y)
const PASSIVE_SIZE := Vector2(20, 20)

var mark := ""
var bound_identity: Dictionary = {}
var bound_generation := -1
var interactive := false
var keep_button: Button
var salvage_button: Button

var _armed_action := ""
var _armed_identity: Dictionary = {}
var _armed_generation := -1


func _init() -> void:
	custom_minimum_size = Vector2.ZERO
	size = PASSIVE_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	_build_action_buttons()


func _ready() -> void:
	refresh_locale()
	_apply_button_state()


func configure(
	value: String,
	identity: Dictionary,
	generation: int,
	interactive_value: bool,
) -> void:
	mark = value if value in ["keep", "salvage"] else ""
	bound_identity = identity.duplicate(true)
	bound_generation = generation
	interactive = interactive_value and not bound_identity.is_empty()
	custom_minimum_size = INTERACTIVE_SIZE if interactive else Vector2.ZERO
	size = INTERACTIVE_SIZE if interactive else PASSIVE_SIZE
	visible = interactive or not mark.is_empty()
	mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	_apply_button_state()
	refresh_locale()
	queue_redraw()


func set_mark(value: String) -> void:
	configure(value, {}, -1, false)


func refresh_locale() -> void:
	if keep_button == null or salvage_button == null:
		return
	_set_accessible_copy(keep_button, Loc.text("INVENTORY_MARK_KEEP"))
	_set_accessible_copy(salvage_button, Loc.text("INVENTORY_MARK_SALVAGE"))


func action_buttons() -> Array[Button]:
	return [keep_button, salvage_button]


func owns_action_button(control: Control) -> bool:
	return control == keep_button or control == salvage_button


func action_at_global_position(global_point: Vector2) -> String:
	if not interactive or not visible:
		return ""
	if keep_button.visible and keep_button.get_global_rect().has_point(global_point):
		return "keep"
	if salvage_button.visible and salvage_button.get_global_rect().has_point(global_point):
		return "salvage"
	return ""


func activate_button(button: Button) -> bool:
	if button == keep_button:
		return activate_action("keep")
	if button == salvage_button:
		return activate_action("salvage")
	return false


func activate_action(action: String) -> bool:
	var button := _button_for_action(action)
	if not interactive or button == null or button.disabled:
		return false
	mark_requested.emit(action, bound_identity.duplicate(true), bound_generation)
	return true


func _build_action_buttons() -> void:
	var empty_style := StyleBoxEmpty.new()
	for action in ["keep", "salvage"]:
		var button := Button.new()
		button.name = "KeepMark" if action == "keep" else "SalvageMark"
		button.position = Vector2.ZERO if action == "keep" else Vector2(ACTION_SIZE.x + ACTION_GAP, 0)
		button.size = ACTION_SIZE
		button.custom_minimum_size = ACTION_SIZE
		button.text = ""
		button.flat = true
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty_style)
		button.button_down.connect(_arm_action.bind(action))
		button.pressed.connect(_emit_armed_or_current.bind(action))
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		button.focus_entered.connect(queue_redraw)
		button.focus_exited.connect(queue_redraw)
		add_child(button)
		if action == "keep":
			keep_button = button
		else:
			salvage_button = button


func _apply_button_state() -> void:
	if keep_button == null or salvage_button == null:
		return
	for button in [keep_button, salvage_button]:
		button.visible = interactive
		button.disabled = not interactive
	keep_button.disabled = not interactive
	# Keep is deliberately sticky: it must be removed explicitly before the
	# Salvage control becomes actionable.
	salvage_button.disabled = not interactive or mark == "keep"
	keep_button.set_pressed_no_signal(mark == "keep")
	salvage_button.set_pressed_no_signal(mark == "salvage")
	if not interactive:
		keep_button.release_focus()
		salvage_button.release_focus()


func _arm_action(action: String) -> void:
	_armed_action = action
	_armed_identity = bound_identity.duplicate(true)
	_armed_generation = bound_generation


func _emit_armed_or_current(action: String) -> void:
	var request_identity := bound_identity.duplicate(true)
	var request_generation := bound_generation
	if _armed_action == action:
		request_identity = _armed_identity.duplicate(true)
		request_generation = _armed_generation
	_armed_action = ""
	_armed_identity.clear()
	_armed_generation = -1
	mark_requested.emit(action, request_identity, request_generation)


func _button_for_action(action: String) -> Button:
	if action == "keep":
		return keep_button
	if action == "salvage":
		return salvage_button
	return null


func _set_accessible_copy(button: Button, copy: String) -> void:
	button.tooltip_text = copy
	button.accessibility_name = copy
	button.accessibility_description = copy


func _draw() -> void:
	if interactive:
		_draw_action(Rect2(Vector2.ZERO, ACTION_SIZE), "keep", keep_button)
		_draw_action(
			Rect2(Vector2(ACTION_SIZE.x + ACTION_GAP, 0), ACTION_SIZE),
			"salvage",
			salvage_button,
		)
		return
	if mark.is_empty():
		return
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	if mark == "keep":
		_draw_lock(center, Palette.color(Palette.WARM_ARCHIVE, "soul"))
	else:
		_draw_broken_sword(center, Palette.color(Palette.WARM_ARCHIVE, "danger"))


func _draw_action(rect: Rect2, action: String, button: Button) -> void:
	var active := mark == action
	var surface := Palette.color(
		Palette.WARM_ARCHIVE,
		"selected_fill" if active else "inset",
	)
	if button.is_hovered() and not button.disabled:
		surface = Palette.color(Palette.WARM_ARCHIVE, "raised")
	draw_rect(rect, surface)
	draw_rect(
		rect.grow(-1.0),
		Palette.color(Palette.WARM_ARCHIVE, "disabled" if button.disabled else "neutral_border"),
		false,
		2.0 if active else 1.0,
	)
	var icon_color := Palette.color(
		Palette.WARM_ARCHIVE,
		"disabled" if button.disabled else ("soul" if action == "keep" else "danger"),
	)
	var center := rect.get_center()
	if action == "keep":
		_draw_lock(center, icon_color)
	else:
		_draw_broken_sword(center, icon_color)
	# This short lower rail is a non-color selected cue distinct from the icon.
	if active:
		draw_line(
			Vector2(rect.position.x + 5.0, rect.end.y - 3.0),
			Vector2(rect.end.x - 5.0, rect.end.y - 3.0),
			icon_color,
			2.0,
			true,
		)
	# Focus is outside the selected rail/border, so both states coexist.
	if button.has_focus():
		draw_rect(
			rect.grow(2.0),
			Palette.color(Palette.WARM_ARCHIVE, "focus"),
			false,
			2.0,
		)


func _draw_lock(center: Vector2, color: Color) -> void:
	var body := Rect2(center + Vector2(-7, -1), Vector2(14, 11))
	draw_rect(body, Color(Palette.color(Palette.WARM_ARCHIVE, "inset"), 0.94))
	draw_rect(body, color, false, 2.2)
	draw_arc(center + Vector2(0, -1), 5.5, PI, TAU, 18, color, 2.2, true)
	draw_circle(center + Vector2(0, 4), 1.6, color)


func _draw_broken_sword(center: Vector2, color: Color) -> void:
	# Two separated blade fragments make the broken state readable at card scale.
	draw_line(center + Vector2(-8, 8), center + Vector2(-1, 1), color, 3.0, true)
	draw_line(center + Vector2(2, -2), center + Vector2(8, -8), color, 3.0, true)
	draw_line(center + Vector2(-8, 5), center + Vector2(-5, 8), color, 2.0, true)
	draw_line(center + Vector2(-10, 3), center + Vector2(-4, 9), color, 2.0, true)
	draw_polyline(PackedVector2Array([
		center + Vector2(1, -5), center + Vector2(5, -1), center + Vector2(9, -9),
	]), color, 2.0, true)
	draw_line(center + Vector2(-2, -4), center + Vector2(4, 2), color, 2.0, true)
