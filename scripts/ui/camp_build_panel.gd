class_name CampBuildPanel
extends Control

const Loc := preload("res://scripts/localization/localization.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")

signal build_requested(upgrade_id: String)
signal closed

## Fixed 1280x720 geometry is intentional: project stretch keeps the modal usable at
## 960x540, while the ScrollContainer makes the twelfth revealed row reachable.
const CARD_RECT := Rect2(238, 42, 804, 636)
const SCROLL_RECT := Rect2(270, 112, 740, 492)

var run_state: RunState
var title_label: Label
var close_button: Button
var scroll: ScrollContainer
var rows_box: VBoxContainer
var rows: Dictionary = {}
var row_order: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeController.theme_for(Palette.WARM_ARCHIVE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	_build()
	visible = false


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Palette.OVERLAY_SCRIM
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var card := Panel.new()
	card.position = CARD_RECT.position
	card.size = CARD_RECT.size
	card.add_theme_stylebox_override(
		"panel", Ui.semantic_style(Palette.WARM_ARCHIVE, "panel", "normal")
	)
	add_child(card)
	title_label = Ui.make_label(self, Vector2(278, 58), Vector2(562, 42), 28)
	Ui.apply_heading(title_label, 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close_button = Ui.make_button(self, Vector2(850, 58), "", Vector2(160, 42))
	close_button.add_theme_font_size_override("font_size", 14)
	Ui.enable_keyboard_focus(close_button)
	close_button.pressed.connect(close)
	scroll = ScrollContainer.new()
	scroll.position = SCROLL_RECT.position
	scroll.size = SCROLL_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)
	rows_box = VBoxContainer.new()
	rows_box.custom_minimum_size = Vector2(SCROLL_RECT.size.x - 18, 0)
	rows_box.add_theme_constant_override("separation", 8)
	scroll.add_child(rows_box)
	apply_locale()


func open_for(state: RunState) -> void:
	run_state = state
	visible = true
	refresh()


func _restore_focus(preferred_upgrade_id := "", prefer_close := false) -> void:
	if not visible or not is_inside_tree():
		return
	if prefer_close:
		close_button.grab_focus()
		return
	var preferred_index := row_order.find(preferred_upgrade_id)
	if preferred_index < 0:
		preferred_index = 0
	for offset in range(row_order.size()):
		var upgrade_id := row_order[(preferred_index + offset) % row_order.size()]
		var button: Button = rows[upgrade_id].button
		if not button.disabled:
			button.grab_focus()
			return
	close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func apply_locale() -> void:
	if title_label == null:
		return
	title_label.text = Loc.text("CAMP_BUILD_TITLE")
	close_button.text = Loc.text("CAMP_BUILD_CLOSE")
	close_button.accessibility_name = close_button.text
	if visible:
		refresh()


func refresh(preferred_upgrade_id := "") -> void:
	if rows_box == null or run_state == null:
		return
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var prefer_close := focus_owner == close_button
	if preferred_upgrade_id.is_empty():
		for upgrade_id in rows:
			if rows[upgrade_id].button == focus_owner:
				preferred_upgrade_id = upgrade_id
				break
	for child in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()
	rows.clear()
	row_order.clear()
	var focus_buttons: Array[Button] = []
	for upgrade_id in GameRules.CAMP_DRAW_ORDER:
		if not run_state.is_camp_upgrade_revealed(upgrade_id):
			continue
		var rules: Dictionary = GameRules.CAMP_UPGRADES[upgrade_id]
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 112)
		row.add_theme_stylebox_override(
			"panel", Ui.semantic_style(Palette.WARM_ARCHIVE, "inset_panel", "normal")
		)
		rows_box.add_child(row)
		var horizontal := HBoxContainer.new()
		horizontal.add_theme_constant_override("separation", 12)
		row.add_child(horizontal)
		var details := Label.new()
		details.custom_minimum_size = Vector2(548, 104)
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		details.add_theme_font_size_override("font_size", 14)
		details.add_theme_color_override("font_color", Ui.COLOR_TEXT)
		details.text = _row_text(upgrade_id, rules)
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		horizontal.add_child(details)
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 54)
		button.text = (
			Loc.text("CAMP_BUILD_STATUS_BUILT")
			if bool(run_state.camp_upgrades.get(upgrade_id, false))
			else Loc.text("CAMP_BUILD_ACTION")
		)
		button.disabled = not run_state.can_build_camp_upgrade(upgrade_id)
		button.tooltip_text = Loc.text("CAMP_" + upgrade_id.to_upper() + "_DESC")
		button.accessibility_name = "%s. %s" % [Loc.text(String(rules.name)), button.tooltip_text]
		button.add_theme_font_size_override("font_size", 14)
		Ui.enable_keyboard_focus(button)
		button.pressed.connect(func() -> void: build_requested.emit(upgrade_id))
		horizontal.add_child(button)
		rows[upgrade_id] = {"panel": row, "label": details, "button": button}
		row_order.append(upgrade_id)
		if not button.disabled:
			focus_buttons.append(button)
	for index in range(focus_buttons.size()):
		var button := focus_buttons[index]
		var previous: Button = close_button if index == 0 else focus_buttons[index - 1]
		var next: Button = close_button if index + 1 == focus_buttons.size() else focus_buttons[index + 1]
		button.focus_neighbor_top = previous.get_path()
		button.focus_neighbor_bottom = next.get_path()
	close_button.focus_neighbor_bottom = (
		focus_buttons[0].get_path() if not focus_buttons.is_empty() else close_button.get_path()
	)
	close_button.focus_neighbor_top = (
		focus_buttons[-1].get_path() if not focus_buttons.is_empty() else close_button.get_path()
	)
	if visible:
		call_deferred("_restore_focus", preferred_upgrade_id, prefer_close)


func _row_text(upgrade_id: String, rules: Dictionary) -> String:
	var status := Loc.text("CAMP_BUILD_STATUS_BUILT") if bool(run_state.camp_upgrades.get(upgrade_id, false)) else ""
	if status.is_empty():
		for requirement in rules.get("requires", []):
			if not bool(run_state.camp_upgrades.get(String(requirement), false)):
				status = Loc.text("CAMP_BUILD_STATUS_REQUIRES", [
					Loc.text(String(GameRules.CAMP_UPGRADES[String(requirement)].name)),
				])
				break
	if status.is_empty():
		status = Loc.text(
			"CAMP_BUILD_STATUS_AVAILABLE"
			if run_state.can_build_camp_upgrade(upgrade_id)
			else "CAMP_BUILD_STATUS_INSUFFICIENT"
		)
	return "%s\n%s\n%s · %s" % [
		Loc.text(String(rules.name)),
		Loc.text("CAMP_" + upgrade_id.to_upper() + "_DESC"),
		Loc.text("CAMP_BUILD_PRICE", [_price_text(rules)]),
		status,
	]


func _price_text(rules: Dictionary) -> String:
	var cost: Dictionary = rules.get("cost", {})
	var parts := PackedStringArray()
	for resource_id in ["wood", "stone", "cloth"]:
		if int(cost.get(resource_id, 0)) > 0:
			parts.append("%s %d" % [Loc.text("RESOURCE_" + resource_id.to_upper()), int(cost[resource_id])])
	if int(rules.get("banked_souls", 0)) > 0:
		parts.append("%s %d" % [Loc.text("RESOURCE_BANKED_SOULS"), int(rules.banked_souls)])
	if int(rules.get("minotaur_tail", 0)) > 0:
		parts.append("%s %d" % [Loc.text("RESOURCE_MINOTAUR_TAIL"), int(rules.minotaur_tail)])
	if parts.is_empty():
		return Loc.text("CAMP_BUILD_FREE")
	return " · ".join(parts)


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	var physical_cancel: bool = (
		event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_B
	)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu") or physical_cancel:
		close()
		return true
	var physical_accept: bool = (
		event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_A
	)
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or physical_accept:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and focused.is_visible_in_tree() and not focused.disabled:
			focused.pressed.emit()
			return true
	# GUI input owns pointer/touch. The full-screen STOP shade blocks click-through
	# while row and Close buttons remain ordinary full-brightness controls.
	return false
