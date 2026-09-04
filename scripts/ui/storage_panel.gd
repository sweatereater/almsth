class_name StoragePanel
extends Control

const Loc := preload("res://scripts/localization/localization.gd")
const Rules := preload("res://scripts/game/game_rules.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")
const InventoryPanelClass := preload("res://scripts/ui/inventory_panel.gd")

signal transfer_one_requested(source: String, item_key: String)
signal transfer_all_requested(source: String, item_key: String, count: int)
signal closed

const PAGE_SIZE := 6
const CARD_RECT := Rect2(32, 24, 1216, 672)
const INVENTORY_ROWS_ORIGIN := Vector2(64, 186)
const STORAGE_ROWS_ORIGIN := Vector2(746, 186)
const ROW_SIZE := Vector2(438, 50)
const ROW_STEP := 54.0

var run_state: RunState
var filter_id := "all"
var inventory_page := 0
var storage_page := 0
var selected_source := ""
var selected_key := ""
var feedback := ""
var entries_by_source := {"inventory": [], "storage": []}

var title_label: Label
var inventory_heading: Label
var storage_heading: Label
var instruction_label: Label
var feedback_label: Label
var close_button: Button
var filter_buttons: Dictionary = {}
var inventory_rows: Array[Button] = []
var storage_rows: Array[Button] = []
var inventory_icons: Array[TextureRect] = []
var storage_icons: Array[TextureRect] = []
var inventory_empty_label: Label
var storage_empty_label: Label
var inventory_previous_button: Button
var inventory_next_button: Button
var inventory_page_label: Label
var storage_previous_button: Button
var storage_next_button: Button
var storage_page_label: Label
var move_to_storage_button: Button
var move_to_inventory_button: Button
var activation_in_progress := false


static func available_filter_order() -> Array[String]:
	var result: Array[String] = ["all"]
	result.append_array(Rules.EQUIPMENT_CATEGORY_ORDER)
	return result


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeController.theme_for(Palette.WARM_ARCHIVE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 85
	_build_interface()
	visible = false


func open_for(state: RunState) -> void:
	run_state = state
	filter_id = "all"
	inventory_page = 0
	storage_page = 0
	selected_source = ""
	selected_key = ""
	feedback = ""
	activation_in_progress = false
	visible = true
	refresh()
	call_deferred("grab_initial_focus")


func close() -> void:
	if not visible:
		return
	visible = false
	activation_in_progress = false
	closed.emit()


func bind_state(state: RunState) -> void:
	run_state = state
	refresh()


func set_feedback(value: String) -> void:
	feedback = value
	refresh()


func selected_item_source() -> String:
	return selected_source


func selected_item_key() -> String:
	return selected_key


func after_successful_transfer(source: String, item_key: String) -> void:
	var destination := "storage" if source == "inventory" else "inventory"
	var source_dictionary: Dictionary = (
		run_state.inventory if run_state != null and source == "inventory"
		else run_state.storage if run_state != null
		else {}
	)
	var destination_dictionary: Dictionary = (
		run_state.inventory if run_state != null and destination == "inventory"
		else run_state.storage if run_state != null
		else {}
	)
	if int(source_dictionary.get(item_key, 0)) > 0:
		selected_source = source
		selected_key = item_key
	elif int(destination_dictionary.get(item_key, 0)) > 0:
		selected_source = destination
		selected_key = item_key
	else:
		selected_source = ""
		selected_key = ""
	refresh()
	_ensure_selected_page_visible()
	refresh()


func apply_locale() -> void:
	if title_label == null:
		return
	title_label.text = Loc.text("STORAGE_TITLE")
	inventory_heading.text = Loc.text("STORAGE_PLAYER_INVENTORY")
	storage_heading.text = Loc.text("STORAGE_HEADING")
	instruction_label.text = Loc.text("STORAGE_INSTRUCTIONS")
	close_button.text = Loc.text("STORAGE_CLOSE")
	close_button.tooltip_text = Loc.text("STORAGE_CLOSE_TOOLTIP")
	close_button.accessibility_name = close_button.tooltip_text
	move_to_storage_button.text = Loc.text("STORAGE_MOVE_ALL_RIGHT")
	move_to_storage_button.tooltip_text = Loc.text("STORAGE_MOVE_ALL_TO_STORAGE")
	move_to_storage_button.accessibility_name = move_to_storage_button.tooltip_text
	move_to_inventory_button.text = Loc.text("STORAGE_MOVE_ALL_LEFT")
	move_to_inventory_button.tooltip_text = Loc.text("STORAGE_MOVE_ALL_TO_INVENTORY")
	move_to_inventory_button.accessibility_name = move_to_inventory_button.tooltip_text
	inventory_previous_button.tooltip_text = Loc.text("INVENTORY_PREVIOUS_PAGE")
	inventory_next_button.tooltip_text = Loc.text("INVENTORY_NEXT_PAGE")
	storage_previous_button.tooltip_text = Loc.text("INVENTORY_PREVIOUS_PAGE")
	storage_next_button.tooltip_text = Loc.text("INVENTORY_NEXT_PAGE")
	inventory_previous_button.accessibility_name = inventory_previous_button.tooltip_text
	inventory_next_button.accessibility_name = inventory_next_button.tooltip_text
	storage_previous_button.accessibility_name = storage_previous_button.tooltip_text
	storage_next_button.accessibility_name = storage_next_button.tooltip_text
	for current_filter in available_filter_order():
		var button: Button = filter_buttons[current_filter]
		var full_label := (
			Loc.text("INVENTORY_FILTER_ALL")
			if current_filter == "all"
			else Loc.text(String(Rules.EQUIPMENT_CATEGORY_NAMES[current_filter]))
		)
		button.text = Loc.text("SLOT_OFFHAND") if current_filter == "offhand" else full_label
		button.tooltip_text = Loc.text("STORAGE_FILTER_TOOLTIP", [full_label])
		button.accessibility_name = button.tooltip_text
	if visible:
		refresh()


func refresh() -> void:
	if title_label == null:
		return
	entries_by_source = {
		"inventory": build_entries(run_state, "inventory", filter_id),
		"storage": build_entries(run_state, "storage", filter_id),
	}
	_sanitize_selection()
	_refresh_filters()
	_refresh_side("inventory")
	_refresh_side("storage")
	_refresh_actions()
	_refresh_focus_graph()
	feedback_label.text = feedback
	feedback_label.visible = not feedback.is_empty()
	queue_redraw()


static func build_entries(state: RunState, source: String, active_filter: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null or source not in ["inventory", "storage"]:
		return result
	var stacks: Dictionary = state.inventory if source == "inventory" else state.storage
	var marks: Dictionary = state.inventory_marks if source == "inventory" else state.storage_marks
	for raw_key in stacks.keys():
		var item_key := String(raw_key)
		var category := Rules.item_category(item_key)
		if (
			not Rules.is_item_movable(item_key)
			or Rules.is_item_permanent(item_key)
			or (active_filter != "all" and category != active_filter)
		):
			continue
		result.append({
			"key": item_key,
			"source": source,
			"category": category,
			"count": int(stacks.get(item_key, 0)),
			"mark": String(marks.get(item_key, "")),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var category_a := Rules.EQUIPMENT_CATEGORY_ORDER.find(String(a.get("category", "")))
		var category_b := Rules.EQUIPMENT_CATEGORY_ORDER.find(String(b.get("category", "")))
		if category_a != category_b:
			return category_a < category_b
		return String(a.get("key", "")) < String(b.get("key", ""))
	)
	return result


func grab_initial_focus() -> void:
	if not visible:
		return
	var preferred: Button
	if not entries_by_source.inventory.is_empty():
		preferred = inventory_rows[0]
	elif not entries_by_source.storage.is_empty():
		preferred = storage_rows[0]
	else:
		preferred = filter_buttons["all"]
	if preferred != null and preferred.visible and not preferred.disabled:
		preferred.grab_focus()


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if (
		event is InputEventScreenTouch
		and event.pressed
		and Rect2(close_button.global_position, close_button.size).has_point(event.position)
	):
		close()
		return true
	if event is InputEventKey and (not event.pressed or event.echo):
		return false
	if event is InputEventJoypadButton and not event.pressed:
		return false
	var physical_cancel: bool = (
		event is InputEventJoypadButton
		and event.button_index == JOY_BUTTON_B
	)
	if event.is_action_pressed("game_menu") or event.is_action_pressed("ui_cancel") or physical_cancel:
		close()
		return true
	var physical_accept: bool = (
		event is InputEventJoypadButton
		and event.button_index == JOY_BUTTON_A
	)
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or physical_accept:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and _focusable_controls().has(focused) and not focused.disabled:
			focused.pressed.emit()
			return true
	# Godot's GUI focus navigation owns keyboard arrows and the D-pad. The
	# explicit neighbor graph below traps that navigation inside this modal.
	return false


func _build_interface() -> void:
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
	for list_rect in [Rect2(52, 174, 462, 394), Rect2(734, 174, 462, 394)]:
		var list_panel := Panel.new()
		list_panel.position = list_rect.position
		list_panel.size = list_rect.size
		list_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list_panel.add_theme_stylebox_override(
			"panel", Ui.semantic_style(Palette.WARM_ARCHIVE, "inset_panel", "normal"),
		)
		add_child(list_panel)
	title_label = Ui.make_label(self, Vector2(64, 42), Vector2(872, 42), 28)
	Ui.apply_heading(title_label, 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close_button = Ui.make_button(self, Vector2(1040, 42), "", Vector2(176, 42))
	close_button.name = "StorageCloseButton"
	close_button.add_theme_font_size_override("font_size", 14)
	Ui.enable_keyboard_focus(close_button)
	close_button.pressed.connect(close)
	var filters := available_filter_order()
	var filter_width := 1048.0 / float(filters.size())
	for index in range(filters.size()):
		var current_filter := filters[index]
		var button := Ui.make_button(
			self,
			Vector2(64.0 + index * filter_width, 96),
			"",
			Vector2(filter_width - 4.0, 38),
		)
		button.name = "StorageFilter_%s" % current_filter
		button.toggle_mode = true
		button.theme_type_variation = "CompactButton"
		button.add_theme_font_size_override("font_size", 12)
		Ui.enable_keyboard_focus(button)
		button.pressed.connect(_set_filter.bind(current_filter))
		filter_buttons[current_filter] = button
	inventory_heading = Ui.make_label(self, Vector2(64, 142), Vector2(438, 38), 20)
	inventory_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage_heading = Ui.make_label(self, Vector2(746, 142), Vector2(438, 38), 20)
	storage_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for source in ["inventory", "storage"]:
		var origin: Vector2 = INVENTORY_ROWS_ORIGIN if source == "inventory" else STORAGE_ROWS_ORIGIN
		var rows: Array[Button] = inventory_rows if source == "inventory" else storage_rows
		var icons: Array[TextureRect] = inventory_icons if source == "inventory" else storage_icons
		for index in range(PAGE_SIZE):
			var row := Ui.make_button(self, origin + Vector2(0, index * ROW_STEP), "", ROW_SIZE)
			row.name = "%sStorageRow%d" % [source.capitalize(), index]
			row.toggle_mode = true
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.add_theme_font_size_override("font_size", 12)
			row.autowrap_mode = TextServer.AUTOWRAP_OFF
			for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var style: StyleBoxFlat = row.get_theme_stylebox(style_name).duplicate()
				style.content_margin_left = 54.0
				row.add_theme_stylebox_override(style_name, style)
			Ui.enable_keyboard_focus(row)
			row.focus_entered.connect(_select_visible_index.bind(source, index, false))
			row.pressed.connect(_select_visible_index.bind(source, index, true))
			rows.append(row)
			var icon := TextureRect.new()
			icon.position = row.position + Vector2(4, 3)
			icon.size = Vector2(44, 44)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(icon)
			icons.append(icon)
	inventory_empty_label = Ui.make_label(self, Vector2(64, 302), Vector2(438, 70), 16)
	inventory_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	storage_empty_label = Ui.make_label(self, Vector2(746, 302), Vector2(438, 70), 16)
	storage_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	move_to_storage_button = Ui.make_button(self, Vector2(544, 276), "", Vector2(160, 54))
	move_to_storage_button.name = "MoveAllToStorageButton"
	move_to_storage_button.add_theme_font_size_override("font_size", 14)
	Ui.enable_keyboard_focus(move_to_storage_button)
	move_to_storage_button.pressed.connect(_request_all.bind("inventory"))
	move_to_inventory_button = Ui.make_button(self, Vector2(544, 344), "", Vector2(160, 54))
	move_to_inventory_button.name = "MoveAllToInventoryButton"
	move_to_inventory_button.add_theme_font_size_override("font_size", 14)
	Ui.enable_keyboard_focus(move_to_inventory_button)
	move_to_inventory_button.pressed.connect(_request_all.bind("storage"))
	inventory_previous_button = Ui.make_button(self, Vector2(64, 516), "‹", Vector2(52, 40))
	inventory_previous_button.name = "InventoryPreviousPage"
	inventory_previous_button.add_theme_font_size_override("font_size", 16)
	Ui.enable_keyboard_focus(inventory_previous_button)
	inventory_previous_button.pressed.connect(_change_page.bind("inventory", -1))
	inventory_page_label = Ui.make_label(self, Vector2(122, 518), Vector2(322, 36), 14)
	inventory_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_next_button = Ui.make_button(self, Vector2(450, 516), "›", Vector2(52, 40))
	inventory_next_button.name = "InventoryNextPage"
	inventory_next_button.add_theme_font_size_override("font_size", 16)
	Ui.enable_keyboard_focus(inventory_next_button)
	inventory_next_button.pressed.connect(_change_page.bind("inventory", 1))
	storage_previous_button = Ui.make_button(self, Vector2(746, 516), "‹", Vector2(52, 40))
	storage_previous_button.name = "StoragePreviousPage"
	storage_previous_button.add_theme_font_size_override("font_size", 16)
	Ui.enable_keyboard_focus(storage_previous_button)
	storage_previous_button.pressed.connect(_change_page.bind("storage", -1))
	storage_page_label = Ui.make_label(self, Vector2(804, 518), Vector2(322, 36), 14)
	storage_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage_next_button = Ui.make_button(self, Vector2(1132, 516), "›", Vector2(52, 40))
	storage_next_button.name = "StorageNextPage"
	storage_next_button.add_theme_font_size_override("font_size", 16)
	Ui.enable_keyboard_focus(storage_next_button)
	storage_next_button.pressed.connect(_change_page.bind("storage", 1))
	instruction_label = Ui.make_label(self, Vector2(64, 572), Vector2(1120, 34), 14)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.theme_type_variation = "SecondaryLabel"
	feedback_label = Ui.make_label(self, Vector2(64, 612), Vector2(1120, 50), 14)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_locale()


func _set_filter(value: String) -> void:
	if not available_filter_order().has(value) or filter_id == value:
		return
	filter_id = value
	inventory_page = 0
	storage_page = 0
	selected_source = ""
	selected_key = ""
	feedback = ""
	refresh()


func _change_page(source: String, direction: int) -> void:
	var entries: Array = entries_by_source[source]
	var page_count := maxi(1, ceili(entries.size() / float(PAGE_SIZE)))
	if source == "inventory":
		inventory_page = clampi(inventory_page + direction, 0, page_count - 1)
	else:
		storage_page = clampi(storage_page + direction, 0, page_count - 1)
	selected_source = ""
	selected_key = ""
	feedback = ""
	refresh()


func _select_visible_index(source: String, index: int, activate: bool) -> void:
	if activation_in_progress:
		return
	var page_value := inventory_page if source == "inventory" else storage_page
	var entries: Array = entries_by_source[source]
	var absolute_index := page_value * PAGE_SIZE + index
	if absolute_index < 0 or absolute_index >= entries.size():
		return
	var entry: Dictionary = entries[absolute_index]
	selected_source = source
	selected_key = String(entry.key)
	feedback = ""
	refresh()
	if activate:
		activation_in_progress = true
		transfer_one_requested.emit(source, selected_key)
		call_deferred("_release_activation_guard")


func _request_all(source: String) -> void:
	if activation_in_progress or source != selected_source or selected_key.is_empty():
		return
	var stacks: Dictionary = run_state.inventory if source == "inventory" else run_state.storage
	var count := int(stacks.get(selected_key, 0))
	if count <= 0:
		return
	activation_in_progress = true
	transfer_all_requested.emit(source, selected_key, count)
	call_deferred("_release_activation_guard")


func _release_activation_guard() -> void:
	activation_in_progress = false


func _sanitize_selection() -> void:
	if selected_source not in ["inventory", "storage"] or selected_key.is_empty():
		selected_source = ""
		selected_key = ""
		return
	var stacks: Dictionary = (
		run_state.inventory if run_state != null and selected_source == "inventory"
		else run_state.storage if run_state != null
		else {}
	)
	if int(stacks.get(selected_key, 0)) <= 0:
		var destination := "storage" if selected_source == "inventory" else "inventory"
		var destination_stacks: Dictionary = (
			run_state.inventory if run_state != null and destination == "inventory"
			else run_state.storage if run_state != null
			else {}
		)
		if int(destination_stacks.get(selected_key, 0)) > 0:
			selected_source = destination
		else:
			selected_source = ""
			selected_key = ""
			return
	var visible_entries: Array = entries_by_source[selected_source]
	for entry in visible_entries:
		if String(entry.key) == selected_key:
			return
	selected_source = ""
	selected_key = ""


func _ensure_selected_page_visible() -> void:
	if selected_source not in ["inventory", "storage"] or selected_key.is_empty():
		return
	var entries: Array = entries_by_source[selected_source]
	for index in range(entries.size()):
		if String(entries[index].key) == selected_key:
			if selected_source == "inventory":
				inventory_page = floori(index / float(PAGE_SIZE))
			else:
				storage_page = floori(index / float(PAGE_SIZE))
			return


func _refresh_filters() -> void:
	for current_filter in available_filter_order():
		filter_buttons[current_filter].button_pressed = current_filter == filter_id


func _refresh_side(source: String) -> void:
	var entries: Array = entries_by_source[source]
	var page_value := inventory_page if source == "inventory" else storage_page
	var page_count := maxi(1, ceili(entries.size() / float(PAGE_SIZE)))
	page_value = clampi(page_value, 0, page_count - 1)
	if source == "inventory":
		inventory_page = page_value
	else:
		storage_page = page_value
	var rows := inventory_rows if source == "inventory" else storage_rows
	var icons := inventory_icons if source == "inventory" else storage_icons
	for index in range(PAGE_SIZE):
		var absolute_index := page_value * PAGE_SIZE + index
		var button: Button = rows[index]
		var icon: TextureRect = icons[index]
		if absolute_index >= entries.size():
			button.visible = false
			icon.visible = false
			continue
		var entry: Dictionary = entries[absolute_index]
		var item_key := String(entry.key)
		var mark := String(entry.mark)
		var qualifiers := PackedStringArray()
		if not mark.is_empty():
			qualifiers.append(Loc.text("INVENTORY_MARK_" + mark.to_upper()))
		if Rules.is_item_bound(item_key):
			qualifiers.append(Loc.text("INVENTORY_BOUND_SHORT"))
		var stats := " · ".join(InventoryPanelClass.primary_stats(item_key))
		var suffix := (" · " + " · ".join(qualifiers)) if not qualifiers.is_empty() else ""
		button.text = "%s  ×%d%s%s" % [
			InventoryPanelClass.display_name(item_key), int(entry.count), suffix,
			("\n" + stats) if not stats.is_empty() else "",
		]
		button.button_pressed = selected_source == source and selected_key == item_key
		button.visible = true
		button.tooltip_text = Loc.text("STORAGE_MOVE_ONE_TOOLTIP", [
			InventoryPanelClass.display_name(item_key),
			Loc.text("STORAGE_HEADING" if source == "inventory" else "STORAGE_PLAYER_INVENTORY"),
		])
		button.accessibility_name = "%s. %s" % [button.text.replace("\n", ". "), button.tooltip_text]
		var icon_path := String(Rules.item_rules(item_key).get("icon", ""))
		icon.texture = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
		icon.visible = true
	var empty_label := inventory_empty_label if source == "inventory" else storage_empty_label
	empty_label.text = Loc.text("STORAGE_EMPTY_FILTER" if filter_id != "all" else (
		"STORAGE_INVENTORY_EMPTY" if source == "inventory" else "STORAGE_EMPTY"
	))
	empty_label.visible = entries.is_empty()
	var previous := inventory_previous_button if source == "inventory" else storage_previous_button
	var next := inventory_next_button if source == "inventory" else storage_next_button
	var page_label := inventory_page_label if source == "inventory" else storage_page_label
	previous.disabled = page_value <= 0
	next.disabled = page_value >= page_count - 1
	page_label.text = Loc.text("INVENTORY_PAGE", [page_value + 1, page_count])


func _refresh_actions() -> void:
	var inventory_selected := selected_source == "inventory" and not selected_key.is_empty()
	var storage_selected := selected_source == "storage" and not selected_key.is_empty()
	move_to_storage_button.disabled = not inventory_selected
	move_to_inventory_button.disabled = not storage_selected
	if move_to_storage_button.disabled:
		move_to_storage_button.tooltip_text = Loc.text("STORAGE_SELECT_INVENTORY_STACK")
	else:
		move_to_storage_button.tooltip_text = Loc.text("STORAGE_MOVE_ALL_TO_STORAGE")
	if move_to_inventory_button.disabled:
		move_to_inventory_button.tooltip_text = Loc.text("STORAGE_SELECT_STORAGE_STACK")
	else:
		move_to_inventory_button.tooltip_text = Loc.text("STORAGE_MOVE_ALL_TO_INVENTORY")
	move_to_storage_button.accessibility_name = move_to_storage_button.tooltip_text
	move_to_inventory_button.accessibility_name = move_to_inventory_button.tooltip_text


func _focusable_controls() -> Array[Control]:
	var result: Array[Control] = []
	for current_filter in available_filter_order():
		var filter_button: Button = filter_buttons[current_filter]
		if filter_button.visible and not filter_button.disabled:
			result.append(filter_button)
	for index in range(PAGE_SIZE):
		if inventory_rows[index].visible:
			result.append(inventory_rows[index])
		if storage_rows[index].visible:
			result.append(storage_rows[index])
	for control in [
		inventory_previous_button, inventory_next_button,
		move_to_storage_button, move_to_inventory_button,
		storage_previous_button, storage_next_button, close_button,
	]:
		if control.visible and not control.disabled:
			result.append(control)
	return result


func focusable_controls() -> Array[Control]:
	return _focusable_controls()


func _refresh_focus_graph() -> void:
	var available := _focusable_controls()
	if available.is_empty():
		return
	for index in range(available.size()):
		var control := available[index]
		var previous := available[(index - 1 + available.size()) % available.size()]
		var next := available[(index + 1) % available.size()]
		control.focus_neighbor_top = previous.get_path()
		control.focus_neighbor_left = previous.get_path()
		control.focus_neighbor_bottom = next.get_path()
		control.focus_neighbor_right = next.get_path()
