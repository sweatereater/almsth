class_name AppearanceChoicePanel
extends Control

const Loc := preload("res://scripts/localization/localization.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")

signal appearance_confirmed(form_id: String)
signal canceled

var state: RunState
var available_forms: Array[String] = []
var selected_index := 0

var title_label: Label
var summary_label: Label
var hint_label: Label
var form_buttons: Array[Button] = []
var confirm_button: Button
var cancel_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("0c1018f2")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var card := Panel.new()
	card.position = Vector2(330, 72)
	card.size = Vector2(620, 576)
	card.add_theme_stylebox_override("panel", Ui.make_panel_style(Color("647a89")))
	add_child(card)
	title_label = Ui.make_label(self, Vector2(370, 98), Vector2(540, 46), 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label = Ui.make_label(self, Vector2(380, 148), Vector2(520, 62), 16)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label = Ui.make_label(self, Vector2(380, 214), Vector2(520, 58), 14)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in range(GameRules.FORM_ORDER.size()):
		var button := Ui.make_button(self, Vector2(410, 280 + index * 52), "", Vector2(460, 46))
		button.name = "Appearance%d" % index
		button.toggle_mode = true
		button.pressed.connect(_select_index.bind(index))
		Ui.enable_keyboard_focus(button)
		form_buttons.append(button)
	confirm_button = Ui.make_button(self, Vector2(390, 548), "", Vector2(238, 50))
	cancel_button = Ui.make_button(self, Vector2(652, 548), "", Vector2(238, 50))
	Ui.enable_keyboard_focus(confirm_button)
	Ui.enable_keyboard_focus(cancel_button)
	confirm_button.pressed.connect(_confirm)
	cancel_button.pressed.connect(func() -> void: canceled.emit())
	apply_locale()


func open_for(run_state: RunState) -> void:
	state = run_state
	available_forms = state.available_display_form_ids()
	selected_index = maxi(0, available_forms.find(state.get_display_form_id()))
	visible = true
	_refresh()
	if not available_forms.is_empty():
		form_buttons[selected_index].call_deferred("grab_focus")


func close() -> void:
	visible = false
	state = null


func apply_locale() -> void:
	if title_label == null:
		return
	title_label.text = Loc.text("APPEARANCE_TITLE")
	hint_label.text = Loc.text("APPEARANCE_COSMETIC_HINT")
	confirm_button.text = Loc.text("APPEARANCE_CONFIRM")
	cancel_button.text = Loc.text("APPEARANCE_CANCEL")
	_refresh()


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if (
		_pressed(event, "ui_cancel") or _pressed(event, "game_menu")
		or event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
		or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
	):
		canceled.emit()
		return true
	var direction := 0
	if _pressed(event, "ui_down") or _pressed(event, "ui_right") or _pressed(event, "move_down") or _pressed(event, "move_right"):
		direction = 1
	elif _pressed(event, "ui_up") or _pressed(event, "ui_left") or _pressed(event, "move_up") or _pressed(event, "move_left"):
		direction = -1
	if direction != 0 and not available_forms.is_empty():
		_select_index(posmod(selected_index + direction, available_forms.size()))
		form_buttons[selected_index].grab_focus()
		return true
	if (
		_pressed(event, "ui_accept") or _pressed(event, "interact")
		or event is InputEventKey and event.pressed
		and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		or event is InputEventJoypadButton and event.pressed
		and event.button_index == JOY_BUTTON_A
	):
		_confirm()
		return true
	return false


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventScreenTouch or not event.pressed:
		return
	for index in range(available_forms.size()):
		if form_buttons[index].get_global_rect().has_point(event.position):
			_select_index(index)
			get_viewport().set_input_as_handled()
			return
	if confirm_button.get_global_rect().has_point(event.position):
		_confirm()
		get_viewport().set_input_as_handled()
		return
	if cancel_button.get_global_rect().has_point(event.position):
		canceled.emit()
		get_viewport().set_input_as_handled()


func _pressed(event: InputEvent, action: String) -> bool:
	return event.is_action_pressed(action) or (
		event is InputEventAction and event.action == action and event.pressed
	)


func _select_index(index: int) -> void:
	if index < 0 or index >= available_forms.size():
		return
	selected_index = index
	_refresh()


func _confirm() -> void:
	if selected_index < 0 or selected_index >= available_forms.size():
		return
	appearance_confirmed.emit(available_forms[selected_index])


func _refresh() -> void:
	if title_label == null:
		return
	for index in range(form_buttons.size()):
		var available := index < available_forms.size()
		var button := form_buttons[index]
		button.visible = available
		if not available:
			continue
		var form_id := available_forms[index]
		button.text = Loc.text(String(GameRules.FORMS[form_id]["name"]))
		button.button_pressed = index == selected_index
	var actual_name := "—"
	var selected_name := "—"
	if state != null:
		actual_name = Loc.text(String(GameRules.FORMS[state.current_form_id]["name"]))
	if selected_index >= 0 and selected_index < available_forms.size():
		selected_name = Loc.text(String(GameRules.FORMS[available_forms[selected_index]]["name"]))
	summary_label.text = Loc.text("APPEARANCE_SUMMARY", [actual_name, selected_name])
	confirm_button.disabled = available_forms.is_empty()
	_configure_focus()


func _configure_focus() -> void:
	var controls: Array[Control] = []
	for index in range(available_forms.size()):
		controls.append(form_buttons[index])
	controls.append(confirm_button)
	controls.append(cancel_button)
	for index in range(controls.size()):
		controls[index].focus_neighbor_top = controls[(index - 1 + controls.size()) % controls.size()].get_path()
		controls[index].focus_neighbor_bottom = controls[(index + 1) % controls.size()].get_path()
