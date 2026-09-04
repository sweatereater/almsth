class_name InventoryPanel
extends Control

const Loc := preload("res://scripts/localization/localization.gd")
const Rules := preload("res://scripts/game/game_rules.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")
const MarkOverlayClass := preload("res://scripts/ui/inventory_mark_overlay.gd")

signal equip_requested
signal unequip_requested
signal dismantle_requested
signal dismantle_all_requested
signal upgrade_requested
signal bind_requested
signal close_requested
signal presentation_changed
signal mark_changed

enum Mode { CHARACTER, CRUSHER, WHETSTONE, RITUAL }

const SLOT_ORDER: Array[String] = Rules.EQUIPMENT_SLOT_ORDER
const PAGE_SIZE := 6
const SERVICE_PAGE_SIZE := 3
const PANEL_SIZE := Vector2(1110, 243)
const ROW_SIZE := Vector2(620, 48)
const CHARACTER_PANEL_SIZE := Vector2(549, 546)
const CHARACTER_CARD_SIZE := Vector2(270, 84)
const CHARACTER_ROW_SIZE := CHARACTER_CARD_SIZE
const CHARACTER_FILTER_ROWS := [6]
const CHARACTER_FILTER_ORDER: Array[String] = [
	"all", "weapons", "offhand", "armor", "accessories", "backpack",
]
const CHARACTER_FILTER_CATEGORIES := {
	"all": [],
	"weapons": ["weapon"],
	"offhand": ["offhand"],
	"armor": ["head", "body", "hands", "legs", "feet"],
	"accessories": ["talisman", "ring"],
	"backpack": ["back"],
}
const CHARACTER_FILTER_NAME_KEYS := {
	"all": "INVENTORY_FILTER_ALL",
	"weapons": "INVENTORY_FILTER_WEAPONS",
	"offhand": "INVENTORY_FILTER_OFFHAND",
	"armor": "INVENTORY_FILTER_ARMOR",
	"accessories": "INVENTORY_FILTER_ACCESSORIES",
	"backpack": "INVENTORY_FILTER_BACKPACK",
}

var mode: int = Mode.CHARACTER
var run_state: RunState = RunState.new()
var at_base := false
var filter_id := "all"
var page := 0
var selected_key := ""
var selected_source := ""
var selected_slot := ""
var destination_slot := ""
var feedback := ""
var dismantle_all_confirmation_pending := false
var entries: Array[Dictionary] = []
var refresh_generation := 0
var selection_generation := -1
var selection_fingerprint := ""

var filter_buttons: Dictionary = {}
var row_buttons: Array[Button] = []
var row_icons: Array[TextureRect] = []
var row_name_labels: Array[Label] = []
var row_property_labels: Array[Label] = []
var row_mark_overlays: Array[Control] = []
var selected_detail_label: Label
var equipped_detail_label: Label
var mode_title_label: Label
var close_button: Button
var page_label: Label
var previous_button: Button
var next_button: Button
var equip_button: Button
var dismantle_button: Button
var dismantle_all_button: Button
var upgrade_button: Button
var keep_button: Button
var salvage_mark_button: Button
var marked_only_button: Button
var marked_only := false
var keep_confirmation_key := ""


static func available_filter_order() -> Array[String]:
	return CHARACTER_FILTER_ORDER.duplicate()


static func service_filter_order() -> Array[String]:
	var result: Array[String] = ["all"]
	result.append_array(Rules.EQUIPMENT_CATEGORY_ORDER)
	return result


static func filter_for_category(category: String) -> String:
	for group_id in CHARACTER_FILTER_ORDER:
		if group_id != "all" and CHARACTER_FILTER_CATEGORIES[group_id].has(category):
			return group_id
	return "all"


func _active_filter_order() -> Array[String]:
	return available_filter_order() if mode == Mode.CHARACTER else service_filter_order()


func _current_page_size() -> int:
	return PAGE_SIZE if mode == Mode.CHARACTER else SERVICE_PAGE_SIZE


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()


func _ready() -> void:
	theme = ThemeController.theme_for(Palette.WARM_ARCHIVE)
	apply_locale()
	refresh()


func bind_state(value: RunState, base_context: bool) -> void:
	run_state = value
	at_base = base_context
	refresh()


func set_mode(value: int) -> void:
	var changed := mode != value
	mode = value
	if changed:
		filter_id = "weapon" if mode == Mode.WHETSTONE else "all"
		clear_navigation_state()
	_apply_mode_layout()
	refresh()


func set_filter(value: String) -> void:
	var accepted := value if _active_filter_order().has(value) else "all"
	if mode == Mode.WHETSTONE:
		accepted = "weapon"
	if filter_id == accepted:
		return
	filter_id = accepted
	clear_navigation_state()
	refresh()
	presentation_changed.emit()


func select_visible_index(index: int) -> void:
	if index < 0 or index >= row_buttons.size():
		return
	var row := row_buttons[index]
	if int(row.get_meta("refresh_generation", -1)) != refresh_generation:
		return
	keep_confirmation_key = ""
	var absolute_index := page * _current_page_size() + index
	if absolute_index < 0 or absolute_index >= entries.size():
		return
	var entry: Dictionary = entries[absolute_index]
	if String(row.get_meta("identity", "")) != _entry_identity(entry):
		return
	selected_key = String(entry.get("key", ""))
	selected_source = String(entry.get("source", "inventory"))
	selected_slot = String(entry.get("slot", "")) if selected_source == "equipped" else ""
	if selected_source == "equipped":
		destination_slot = selected_slot
	elif not Rules.compatible_slots(selected_key).has(destination_slot):
		destination_slot = ""
	dismantle_all_confirmation_pending = false
	keep_confirmation_key = ""
	feedback = ""
	refresh()
	presentation_changed.emit()


func select_item(item_key: String, source := "inventory", equipped_slot := "") -> void:
	keep_confirmation_key = ""
	if mode == Mode.CHARACTER and source == "inventory":
		var group := filter_for_category(Rules.item_category(item_key))
		if filter_id != "all" and filter_id != group:
			filter_id = group
	selected_key = item_key
	selected_source = source
	selected_slot = equipped_slot if source == "equipped" else ""
	destination_slot = equipped_slot if source == "equipped" else ""
	dismantle_all_confirmation_pending = false
	refresh()
	presentation_changed.emit()


func select_equipment_slot(slot: String, unlocked: bool) -> void:
	filter_id = filter_for_category(Rules.slot_category(slot))
	page = 0
	selected_slot = slot
	destination_slot = slot
	selected_source = "equipped"
	selected_key = String(run_state.loadout.get(slot, "")) if run_state != null else ""
	if Rules.is_item_permanent(selected_key):
		filter_id = "all"
	if not unlocked:
		selected_source = "locked"
	dismantle_all_confirmation_pending = false
	feedback = ""
	refresh()
	presentation_changed.emit()


func change_page(direction: int) -> void:
	var page_count := maxi(1, ceili(entries.size() / float(_current_page_size())))
	page = clampi(page + direction, 0, page_count - 1)
	selected_key = ""
	selected_source = ""
	selected_slot = ""
	destination_slot = ""
	dismantle_all_confirmation_pending = false
	feedback = ""
	refresh()
	presentation_changed.emit()


func clear_navigation_state() -> void:
	page = 0
	selected_key = ""
	selected_source = ""
	selected_slot = ""
	destination_slot = ""
	dismantle_all_confirmation_pending = false
	feedback = ""


func cancel_confirmation() -> void:
	if not dismantle_all_confirmation_pending and keep_confirmation_key.is_empty():
		return
	dismantle_all_confirmation_pending = false
	keep_confirmation_key = ""
	feedback = ""
	refresh()
	presentation_changed.emit()


func set_feedback(value: String) -> void:
	feedback = value
	refresh()


func set_confirmation_pending(value: bool) -> void:
	dismantle_all_confirmation_pending = value
	refresh()
	presentation_changed.emit()


func selected_item_key() -> String:
	return selected_key


func selected_equipped_slot() -> String:
	return selected_slot if selected_source == "equipped" else ""


func selected_destination_slot() -> String:
	return destination_slot


func selected_item_source() -> String:
	return selected_source


func apply_locale() -> void:
	if not is_node_ready():
		return
	for current_filter in filter_buttons:
		var button: Button = filter_buttons[current_filter]
		button.text = Loc.text(String(
			CHARACTER_FILTER_NAME_KEYS.get(
				current_filter,
				Rules.EQUIPMENT_CATEGORY_NAMES.get(current_filter, "INVENTORY_FILTER_ALL"),
			)
		))
	previous_button.tooltip_text = Loc.text("INVENTORY_PREVIOUS_PAGE")
	next_button.tooltip_text = Loc.text("INVENTORY_NEXT_PAGE")
	var close_description := Loc.text("INVENTORY_CLOSE_SERVICE")
	close_button.tooltip_text = close_description
	close_button.set_meta("accessible_name", close_description)
	for property_data in close_button.get_property_list():
		if String(property_data.get("name", "")) == "accessibility_name":
			close_button.set("accessibility_name", close_description)
			break
	for mark_overlay in row_mark_overlays:
		mark_overlay.refresh_locale()
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	refresh_generation += 1
	_apply_mode_layout()
	entries = build_entries(run_state, mode, filter_id)
	_sanitize_selection()
	_refresh_filters()
	_refresh_rows()
	_refresh_actions()
	_refresh_details()
	_refresh_focus_graph()
	selection_generation = refresh_generation if not selected_key.is_empty() else -1
	selection_fingerprint = _selection_fingerprint()
	queue_redraw()


func grab_initial_focus() -> void:
	var available := _focusable_controls()
	if available.is_empty():
		return
	var preferred: Control = _selected_row_button()
	if preferred == null:
		preferred = row_buttons[0] if row_buttons[0].visible else available[0]
	preferred.grab_focus()


func focus_selected_card() -> void:
	var selected_row := _selected_row_button()
	if selected_row != null and selected_row.visible:
		selected_row.grab_focus()


func validated_selected_identity() -> Dictionary:
	if selected_key.is_empty():
		return {}
	if selection_generation != refresh_generation:
		_clear_invalid_selection()
		return {}
	if selection_fingerprint != _selection_fingerprint():
		_clear_invalid_selection()
		return {}
	var identity := {
		"key": selected_key,
		"source": selected_source,
		"slot": selected_slot if selected_source == "equipped" else "",
		"generation": refresh_generation,
	}
	for entry in entries:
		if _entry_identity(entry) == _identity_string(identity):
			return identity
	# Character equipment is selected through the mannequin rather than entries.
	if selected_source in ["equipped", "locked"]:
		return identity
	_clear_invalid_selection()
	return {}


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventScreenTouch and event.pressed and mode == Mode.CHARACTER:
		for mark_overlay in row_mark_overlays:
			var action: String = mark_overlay.action_at_global_position(event.position)
			if not action.is_empty():
				# Consume even a disabled Keep->Salvage touch so it cannot fall
				# through and select the card underneath.
				mark_overlay.activate_action(action)
				return true
	if (
		event is InputEventScreenTouch
		and event.pressed
		and close_button.visible
		and Rect2(close_button.global_position, close_button.size).has_point(event.position)
	):
		close_requested.emit()
		return true
	if event is InputEventKey and (not event.pressed or event.echo):
		return false
	if event is InputEventJoypadButton and not event.pressed:
		return false
	var physical_gamepad_cancel: bool = (
		event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_B
	)
	if (
		event.is_action_pressed("game_menu")
		or event.is_action_pressed("ui_cancel")
		or physical_gamepad_cancel
	):
		if dismantle_all_confirmation_pending or not keep_confirmation_key.is_empty():
			cancel_confirmation()
		else:
			close_requested.emit()
		return true
	var direction := ""
	if (
		event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("move_up")
	):
		direction = "left" if (
			event.is_action_pressed("ui_left") or event.is_action_pressed("move_left")
		) else "top"
	elif (
		event.is_action_pressed("ui_right")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("move_down")
	):
		direction = "right" if (
			event.is_action_pressed("ui_right") or event.is_action_pressed("move_right")
		) else "bottom"
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: direction = "left"
			JOY_BUTTON_DPAD_RIGHT: direction = "right"
			JOY_BUTTON_DPAD_UP: direction = "top"
			JOY_BUTTON_DPAD_DOWN: direction = "bottom"
	if not direction.is_empty():
		if mode == Mode.CHARACTER:
			_move_focus_direction(direction)
		else:
			_move_focus(-1 if direction in ["left", "top"] else 1)
		return true
	var physical_gamepad_accept: bool = (
		event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_A
	)
	if (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("interact")
		or physical_gamepad_accept
	):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and _focusable_controls().has(focused):
			for mark_overlay in row_mark_overlays:
				if mark_overlay.owns_action_button(focused):
					mark_overlay.activate_button(focused)
					return true
			focused.pressed.emit()
			return true
	return false


static func build_entries(state: RunState, panel_mode: int, active_filter: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null:
		return result
	var effective_filter := "weapon" if panel_mode == Mode.WHETSTONE else active_filter
	for raw_key in state.inventory.keys():
		var item_key := String(raw_key)
		var rules := Rules.item_rules(item_key)
		var category := Rules.item_category(item_key)
		if (
			rules.is_empty()
			or not Rules.is_item_movable(item_key)
			or not _category_matches_filter(category, panel_mode, effective_filter)
		):
			continue
		result.append({
			"key": item_key,
			"source": "inventory",
			"slot": "",
			"category": category,
			"count": int(state.inventory.get(item_key, 0)),
		})
	if panel_mode == Mode.WHETSTONE or panel_mode == Mode.RITUAL:
		var equipped_slots: Array = ["right_hand"] if panel_mode == Mode.WHETSTONE else state.loadout.keys()
		for equipped_slot in equipped_slots:
			var equipped_key := String(state.loadout.get(equipped_slot, ""))
			if equipped_key.is_empty() or not Rules.is_item_movable(equipped_key):
				continue
			var equipped_rules := Rules.item_rules(equipped_key)
			var equipped_category := Rules.item_category(equipped_key)
			if not _category_matches_filter(equipped_category, panel_mode, effective_filter):
				continue
			result.append({
				"key": equipped_key,
				"source": "equipped",
				"slot": equipped_slot,
				"category": equipped_category,
				"count": 1,
			})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var slot_a := Rules.EQUIPMENT_CATEGORY_ORDER.find(String(a.get("category", "")))
		var slot_b := Rules.EQUIPMENT_CATEGORY_ORDER.find(String(b.get("category", "")))
		if slot_a != slot_b:
			return slot_a < slot_b
		var key_a := String(a.get("key", ""))
		var key_b := String(b.get("key", ""))
		if key_a != key_b:
			return key_a < key_b
		return String(a.get("source", "")) > String(b.get("source", ""))
	)
	return result


static func _category_matches_filter(category: String, panel_mode: int, active_filter: String) -> bool:
	if active_filter == "all":
		return true
	if panel_mode == Mode.CHARACTER:
		return CHARACTER_FILTER_CATEGORIES.get(active_filter, []).has(category)
	return category == active_filter


static func display_name(item_key: String) -> String:
	var rules := Rules.item_rules(item_key)
	if rules.is_empty():
		return Loc.text("MSG_UNKNOWN_ITEM")
	var result := Loc.text(String(rules["name"]))
	var level := Rules.item_upgrade_level(item_key)
	if level > 0:
		result += " +%d" % level
	return result


static func primary_stats(item_key: String) -> PackedStringArray:
	var rules := Rules.item_rules(item_key)
	var category := Rules.item_category(item_key)
	var level := Rules.item_upgrade_level(item_key) if Rules.is_weapon(item_key) else 0
	match category:
		"weapon":
			if Rules.weapon_attack_type(item_key) == "ranged":
				return PackedStringArray([
					"%s %d" % [Loc.text("PARAM_RANGED_DAMAGE"), int(rules.get("ranged_damage", 0)) + level],
					"%s %d" % [Loc.text("PARAM_ACCURACY"), int(rules.get("accuracy", 0)) + level],
					"%s %d" % [Loc.text("PARAM_RANGED_RANGE"), Rules.weapon_range(item_key)],
				])
			return PackedStringArray([
				"%s %d" % [Loc.text("PARAM_DAMAGE"), int(rules.get("damage", 0)) + level],
				"%s %d" % [Loc.text("PARAM_ACCURACY"), int(rules.get("accuracy", 0)) + level],
			])
		"body", "offhand", "feet", "legs", "head", "back":
			return _nonzero_primary(rules, ["max_hp", "dodge", "regeneration", "mana", "spell_power", "accuracy", "vision", "preparation"])
		"hands":
			return _nonzero_primary(rules, ["max_hp", "accuracy"])
		"talisman":
			return _nonzero_primary(rules, ["mana", "spell_power", "soul_bonus"])
		"ring":
			return _nonzero_primary(rules, ["max_hp", "mana", "spell_power", "accuracy", "dodge"])
	return PackedStringArray()


static func full_details(item_key: String, count: int, source: String, equipped_slot := "") -> String:
	var rules := Rules.item_rules(item_key)
	if rules.is_empty():
		return Loc.text("INVENTORY_EMPTY")
	var lines := PackedStringArray([display_name(item_key)])
	lines.append(Loc.text("INVENTORY_SOURCE_%s" % source.to_upper()))
	var slot_name_key := String(Rules.SLOT_NAMES.get(equipped_slot, ""))
	if slot_name_key.is_empty():
		slot_name_key = String(Rules.EQUIPMENT_CATEGORY_NAMES.get(
			Rules.item_category(item_key), "CATEGORY_WEAPON",
		))
	lines.append(Loc.text("INVENTORY_SLOT_LINE", [
		Loc.text(slot_name_key),
	]))
	var level := Rules.item_upgrade_level(item_key)
	if level > 0:
		lines.append(Loc.text("INVENTORY_LEVEL", [level]))
	if count > 1:
		lines.append(Loc.text("INVENTORY_COUNT", [count]))
	if Rules.is_item_bound(item_key):
		lines.append(Loc.text("INVENTORY_BOUND_STATUS"))
	if Rules.is_weapon(item_key):
		lines.append(Loc.text("INVENTORY_WEAPON_CLASS", [
			Loc.text(_weapon_class_key(item_key)),
		]))
	if Rules.is_item_permanent(item_key):
		var description_key := String(rules.get("description", ""))
		if not description_key.is_empty():
			var description := Loc.text(description_key)
			if not lines.has(description):
				lines.append(description)
		var locked_line := Loc.text("INVENTORY_PERMANENT_LOCKED")
		if not lines.has(locked_line):
			lines.append(locked_line)
	for stat_line in _all_nonzero_stats(item_key):
		lines.append(stat_line)
	if Rules.base_item_id(item_key) == "expedition_backpack":
		lines.append(Loc.text("INVENTORY_BACKPACK_REMOVAL"))
	elif Rules.base_item_id(item_key) == "gravediggers_lamp":
		lines.append(Loc.text("INVENTORY_LAMP_HEARING"))
	if int(rules.get("soul_level_bonus", 0)) != 0:
		var soul_level_line := Loc.text("INVENTORY_SOUL_LEVEL_BONUS", [int(rules["soul_level_bonus"])])
		if not lines.has(soul_level_line):
			lines.append(soul_level_line)
	var salvage: Dictionary = rules.get("salvage", {})
	if not Rules.is_item_permanent(item_key):
		lines.append(Loc.text("INVENTORY_SALVAGE", [
			int(salvage.get("wood", 0)),
			int(salvage.get("stone", 0)),
			int(salvage.get("cloth", 0)),
		]))
	return "\n".join(lines)


static func _nonzero_primary(rules: Dictionary, fields: Array[String]) -> PackedStringArray:
	var result := PackedStringArray()
	for field in fields:
		var value := int(rules.get(field, 0))
		if value != 0:
			result.append("%s %s%d" % [_stat_name(field), "+" if value > 0 else "", value])
	return result


static func _all_nonzero_stats(item_key: String) -> PackedStringArray:
	var rules := Rules.item_rules(item_key)
	var result := PackedStringArray()
	var weapon_level := Rules.item_upgrade_level(item_key) if Rules.is_weapon(item_key) else 0
	for field in ["damage", "ranged_damage", "accuracy", "max_hp", "dodge", "mana", "spell_power", "soul_bonus", "regeneration", "vision", "preparation"]:
		var value := int(rules.get(field, 0))
		if field == "accuracy":
			value += weapon_level
		elif field == "damage" and Rules.weapon_attack_type(item_key) == "melee":
			value += weapon_level
		elif field == "ranged_damage" and Rules.weapon_attack_type(item_key) == "ranged":
			value += weapon_level
		if value != 0:
			result.append("%s: %s%d" % [_stat_name(field), "+" if value > 0 else "", value])
	if Rules.weapon_attack_type(item_key) == "ranged":
		result.append("%s: %d" % [Loc.text("PARAM_RANGED_RANGE"), Rules.weapon_range(item_key)])
	return result


static func _weapon_class_key(item_key: String) -> String:
	if Rules.weapon_attack_type(item_key) == "ranged" and Rules.weapon_grip(item_key) == "two_handed":
		return "WEAPON_CLASS_RANGED_TWO_HANDED"
	if Rules.weapon_grip(item_key) == "two_handed":
		return "WEAPON_CLASS_TWO_HANDED"
	return "WEAPON_CLASS_ONE_HANDED"


static func _stat_name(field: String) -> String:
	match field:
		"damage": return Loc.text("PARAM_DAMAGE")
		"ranged_damage": return Loc.text("PARAM_RANGED_DAMAGE")
		"accuracy": return Loc.text("PARAM_ACCURACY")
		"max_hp": return Loc.text("PARAM_HP")
		"dodge": return Loc.text("PARAM_DODGE")
		"mana": return Loc.text("PARAM_MANA")
		"spell_power": return Loc.text("PARAM_SPELL_POWER")
		"soul_bonus": return Loc.text("INVENTORY_SOUL_BONUS")
		"regeneration": return Loc.text("PARAM_REGENERATION")
		"vision": return Loc.text("PARAM_VISION")
		"preparation": return Loc.text("PARAM_PREPARATION")
	return field


func _build_interface() -> void:
	var filter_order := available_filter_order()
	for service_filter in service_filter_order():
		if not filter_order.has(service_filter):
			filter_order.append(service_filter)
	for index in range(filter_order.size()):
		var current_filter := filter_order[index]
		var button := Ui.make_button(self, Vector2(index * 56, 0), "", Vector2(53, 42))
		button.name = "Filter_%s" % current_filter
		button.theme_type_variation = "CompactButton"
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 12)
		Ui.enable_keyboard_focus(button)
		button.pressed.connect(set_filter.bind(current_filter))
		filter_buttons[current_filter] = button
	mode_title_label = Ui.make_label(self, Vector2(625, 2), Vector2(433, 38), 16)
	mode_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_button = Ui.make_button(self, Vector2(1068, 0), "×", Vector2(42, 42))
	close_button.name = "CloseServiceButton"
	close_button.add_theme_font_size_override("font_size", 22)
	Ui.enable_keyboard_focus(close_button)
	close_button.pressed.connect(func(): close_requested.emit())
	for index in range(PAGE_SIZE):
		var row := Ui.make_button(self, Vector2(0, 46 + index * 52), "", ROW_SIZE)
		row.name = "InventoryRow%d" % index
		row.toggle_mode = true
		row.text = ""
		row.tooltip_text = ""
		Ui.enable_keyboard_focus(row)
		row.pressed.connect(select_visible_index.bind(index))
		row_buttons.append(row)
		var icon := TextureRect.new()
		icon.position = Vector2(6, 20)
		icon.size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		row_icons.append(icon)
		var name_label := Ui.make_label(row, Vector2(56, 5), Vector2(198, 20), 14)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row_name_labels.append(name_label)
		var property_label := Ui.make_label(row, Vector2(56, 28), Vector2(204, 50), 12)
		property_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		property_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		property_label.add_theme_constant_override("line_spacing", -2)
		row_property_labels.append(property_label)
		var mark_overlay := MarkOverlayClass.new()
		mark_overlay.position = Vector2(246, 3)
		mark_overlay.size = Vector2(20, 20)
		mark_overlay.visible = false
		mark_overlay.mark_requested.connect(_on_card_mark_requested.bind(index))
		row.add_child(mark_overlay)
		row_mark_overlays.append(mark_overlay)
	selected_detail_label = Ui.make_label(self, Vector2(643, 52), Vector2(210, 134), 12)
	selected_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_detail_label.add_theme_constant_override("line_spacing", -2)
	equipped_detail_label = Ui.make_label(self, Vector2(880, 52), Vector2(218, 134), 12)
	equipped_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipped_detail_label.add_theme_constant_override("line_spacing", -2)
	previous_button = Ui.make_button(self, Vector2(0, 202), "‹", Vector2(48, 42))
	previous_button.add_theme_font_size_override("font_size", 16)
	Ui.enable_keyboard_focus(previous_button)
	previous_button.pressed.connect(change_page.bind(-1))
	page_label = Ui.make_label(self, Vector2(55, 206), Vector2(510, 34), 13)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_button = Ui.make_button(self, Vector2(572, 202), "›", Vector2(48, 42))
	next_button.add_theme_font_size_override("font_size", 16)
	Ui.enable_keyboard_focus(next_button)
	next_button.pressed.connect(change_page.bind(1))
	equip_button = _action_button(Vector2(635, 198), Vector2(112, 42), 12)
	equip_button.pressed.connect(_emit_equip_action)
	dismantle_button = _action_button(Vector2(753, 198), Vector2(112, 42), 12)
	dismantle_button.pressed.connect(_emit_selected_action.bind("dismantle"))
	dismantle_all_button = _action_button(Vector2(871, 198), Vector2(112, 42), 12)
	dismantle_all_button.pressed.connect(func(): dismantle_all_requested.emit())
	upgrade_button = _action_button(Vector2(989, 198), Vector2(121, 42), 12)
	upgrade_button.pressed.connect(_emit_upgrade_action)
	keep_button = _action_button(Vector2.ZERO, Vector2(130, 44), 12)
	keep_button.toggle_mode = true
	keep_button.pressed.connect(_toggle_mark.bind("keep"))
	salvage_mark_button = _action_button(Vector2.ZERO, Vector2(150, 44), 12)
	salvage_mark_button.toggle_mode = true
	salvage_mark_button.pressed.connect(_toggle_mark.bind("salvage"))
	marked_only_button = _action_button(Vector2.ZERO, Vector2(174, 44), 12)
	marked_only_button.toggle_mode = true
	marked_only_button.pressed.connect(func():
		marked_only = not marked_only
		cancel_confirmation()
		refresh()
		presentation_changed.emit()
	)
	_apply_mode_layout()


func _toggle_mark(mark: String) -> void:
	if validated_selected_identity().is_empty():
		refresh()
		return
	var previous := run_state.item_mark(selected_key, selected_source, selected_slot)
	if previous == "keep" and mark == "salvage":
		return
	if run_state.set_item_mark(
		selected_key,
		"" if previous == mark else mark,
		selected_source,
		selected_slot,
	):
		keep_confirmation_key = ""
		cancel_confirmation()
		refresh()
		mark_changed.emit()


func _on_card_mark_requested(
	requested_mark: String,
	identity: Dictionary,
	generation: int,
	row_index: int,
) -> void:
	if (
		mode != Mode.CHARACTER
		or requested_mark not in ["keep", "salvage"]
		or generation != refresh_generation
		or row_index < 0
		or row_index >= row_buttons.size()
	):
		return
	var row := row_buttons[row_index]
	if (
		not row.visible
		or int(row.get_meta("refresh_generation", -1)) != generation
		or String(row.get_meta("identity", "")) != _identity_string(identity)
	):
		return
	var absolute_index := page * _current_page_size() + row_index
	if absolute_index < 0 or absolute_index >= entries.size():
		return
	var entry: Dictionary = entries[absolute_index]
	if _entry_identity(entry) != _identity_string(identity):
		return
	var item_key := String(identity.get("key", ""))
	var source := String(identity.get("source", ""))
	var slot := String(identity.get("slot", ""))
	var previous := run_state.item_mark(item_key, source, slot)
	# The asymmetric rule is deliberate: Salvage promotes directly to Keep,
	# while Keep must first be toggled off before Salvage is accepted.
	if previous == "keep" and requested_mark == "salvage":
		return
	var next_mark := "" if previous == requested_mark else requested_mark
	if not run_state.set_item_mark(item_key, next_mark, source, slot):
		return
	keep_confirmation_key = ""
	dismantle_all_confirmation_pending = false
	feedback = ""
	refresh()
	mark_changed.emit()


func _emit_equip_action() -> void:
	if validated_selected_identity().is_empty():
		refresh()
		return
	if selected_source == "equipped":
		unequip_requested.emit()
	else:
		equip_requested.emit()


func _emit_upgrade_action() -> void:
	if validated_selected_identity().is_empty():
		refresh()
		return
	if mode == Mode.RITUAL:
		bind_requested.emit()
	else:
		upgrade_requested.emit()


func _emit_selected_action(action_id: String) -> void:
	if validated_selected_identity().is_empty():
		refresh()
		return
	if action_id == "dismantle":
		dismantle_requested.emit()


func _apply_mode_layout() -> void:
	if filter_buttons.is_empty():
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if mode == Mode.CHARACTER else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	for child in get_children():
		if child is Button:
			SheetSurface.apply_button(child, mode == Mode.CHARACTER, child.theme_type_variation == "CompactButton")
	if mode == Mode.CHARACTER:
		custom_minimum_size = CHARACTER_PANEL_SIZE
		size = CHARACTER_PANEL_SIZE
		_layout_character_filters()
		mode_title_label.visible = false
		for index in range(PAGE_SIZE):
			var row := row_buttons[index]
			var column := index % 2
			var card_row := index / 2
			row.position = Vector2(column * 279, 48 + card_row * 88)
			row.size = CHARACTER_CARD_SIZE
			_layout_card_children(index, true)
		selected_detail_label.position = Vector2(7, 360)
		selected_detail_label.size = Vector2(255, 74)
		equipped_detail_label.position = Vector2(287, 360)
		equipped_detail_label.size = Vector2(255, 74)
		previous_button.position = Vector2(0, 316)
		previous_button.size = Vector2(48, 34)
		page_label.position = Vector2(54, 316)
		page_label.size = Vector2(441, 34)
		next_button.position = Vector2(501, 316)
		next_button.size = Vector2(48, 34)
		_layout_character_action_buttons()
		return
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	for index in range(service_filter_order().size()):
		var current_filter := service_filter_order()[index]
		var filter_button: Button = filter_buttons[current_filter]
		filter_button.position = Vector2(index * 56, 0)
		filter_button.size = Vector2(53, 42)
		filter_button.add_theme_font_size_override("font_size", 12)
	mode_title_label.position = Vector2(625, 2)
	mode_title_label.size = Vector2(433, 38)
	mode_title_label.visible = false
	for index in range(PAGE_SIZE):
		var row := row_buttons[index]
		row.position = Vector2(0, 46 + index * 52)
		row.size = ROW_SIZE
		_layout_card_children(index, false)
	selected_detail_label.position = Vector2(643, 52)
	selected_detail_label.size = Vector2(210, 134)
	equipped_detail_label.position = Vector2(880, 52)
	equipped_detail_label.size = Vector2(218, 134)
	previous_button.position = Vector2(0, 202)
	previous_button.size = Vector2(48, 42)
	page_label.position = Vector2(55, 206)
	page_label.size = Vector2(510, 34)
	next_button.position = Vector2(572, 202)
	next_button.size = Vector2(48, 42)


func _layout_character_filters() -> void:
	var filter_order := available_filter_order()
	var gap := 3.0
	var width := (CHARACTER_PANEL_SIZE.x - gap * (filter_order.size() - 1)) / filter_order.size()
	for index in range(filter_order.size()):
		var button: Button = filter_buttons[filter_order[index]]
		button.position = Vector2(index * (width + gap), 0)
		button.size = Vector2(width, 40)
		button.add_theme_font_size_override("font_size", 12)
		Ui.fit_button_text(button, 12, 12)


func _layout_card_children(index: int, character_layout: bool) -> void:
	var icon := row_icons[index]
	var name_label := row_name_labels[index]
	var property_label := row_property_labels[index]
	var mark_overlay := row_mark_overlays[index]
	if character_layout:
		icon.position = Vector2(6, 20)
		icon.size = Vector2(44, 44)
		name_label.position = Vector2(56, 5)
		name_label.size = Vector2(146, 20)
		property_label.position = Vector2(56, 30)
		property_label.size = Vector2(204, 48)
		mark_overlay.position = Vector2(208, 2)
		mark_overlay.size = MarkOverlayClass.INTERACTIVE_SIZE
	else:
		icon.position = Vector2(4, 2)
		icon.size = Vector2(44, 44)
		name_label.position = Vector2(58, 2)
		name_label.size = Vector2(552, 20)
		property_label.position = Vector2(58, 23)
		property_label.size = Vector2(552, 22)
		mark_overlay.position = Vector2(594, 3)
		mark_overlay.size = MarkOverlayClass.PASSIVE_SIZE


func _layout_character_action_buttons() -> void:
	var primary: Array[Button] = []
	for button in [equip_button, dismantle_button, dismantle_all_button, upgrade_button]:
		if button.visible:
			primary.append(button)
	var gap := 6.0
	if not primary.is_empty():
		var width := (CHARACTER_PANEL_SIZE.x - gap * (primary.size() - 1)) / primary.size()
		for index in range(primary.size()):
			primary[index].position = Vector2(index * (width + gap), 444)
			primary[index].size = Vector2(width, 42)
	if marked_only_button.visible:
		marked_only_button.position = Vector2(0, 492)
		marked_only_button.size = Vector2(CHARACTER_PANEL_SIZE.x, 44)


func _action_button(position_value: Vector2, size_value: Vector2, font_size: int) -> Button:
	var button := Ui.make_button(self, position_value, "", size_value)
	button.add_theme_font_size_override("font_size", font_size)
	Ui.enable_keyboard_focus(button)
	return button


func _sanitize_selection() -> void:
	var page_size := _current_page_size()
	var page_count := maxi(1, ceili(entries.size() / float(page_size)))
	page = clampi(page, 0, page_count - 1)
	if selected_source == "inventory" and int(run_state.inventory.get(selected_key, 0)) <= 0:
		_clear_invalid_selection()
	elif selected_source == "equipped" and String(run_state.loadout.get(selected_slot, "")) != selected_key:
		_clear_invalid_selection()
	if not destination_slot.is_empty() and not Rules.EQUIPMENT_SLOTS.has(destination_slot):
		destination_slot = ""
	if selected_source == "inventory":
		var found_index := -1
		for index in range(entries.size()):
			var entry: Dictionary = entries[index]
			if String(entry.get("key", "")) == selected_key and String(entry.get("source", "")) == "inventory":
				found_index = index
				break
		if found_index < 0:
			_clear_invalid_selection()
		else:
			page = found_index / page_size


func _refresh_filters() -> void:
	var active_filters := _active_filter_order()
	for current_filter in filter_buttons:
		var button: Button = filter_buttons[current_filter]
		button.visible = active_filters.has(current_filter) and (
			mode != Mode.WHETSTONE or current_filter == "weapon"
		)
		button.button_pressed = current_filter == filter_id


func _refresh_rows() -> void:
	var page_size := _current_page_size()
	var page_count := maxi(1, ceili(entries.size() / float(page_size)))
	for index in range(PAGE_SIZE):
		var absolute_index := page * page_size + index
		var button := row_buttons[index]
		if index >= page_size or absolute_index >= entries.size():
			button.visible = false
			button.remove_meta("identity")
			button.set_meta("refresh_generation", refresh_generation)
			row_mark_overlays[index].configure("", {}, refresh_generation, false)
			continue
		var entry: Dictionary = entries[absolute_index]
		var item_key := String(entry["key"])
		var source := String(entry["source"])
		var properties := PackedStringArray()
		properties.append("×%d" % int(entry["count"]))
		if mode == Mode.WHETSTONE or mode == Mode.RITUAL:
			properties.append(Loc.text("INVENTORY_SOURCE_%s" % source.to_upper()))
		var mark := run_state.item_mark(item_key, source, String(entry.get("slot", "")))
		if Rules.is_item_bound(item_key):
			properties.append(Loc.text("INVENTORY_BOUND_SHORT"))
		for stat in primary_stats(item_key):
			properties.append(stat)
		button.visible = true
		button.set_meta("identity", _entry_identity(entry))
		button.set_meta("refresh_generation", refresh_generation)
		var icon_path := String(Rules.item_rules(item_key).get("icon", ""))
		row_icons[index].texture = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
		row_name_labels[index].text = display_name(item_key)
		row_property_labels[index].text = " · ".join(properties)
		row_mark_overlays[index].configure(
			mark,
			{
				"key": item_key,
				"source": source,
				"slot": String(entry.get("slot", "")),
			},
			refresh_generation,
			mode == Mode.CHARACTER,
		)
		var full_text := full_details(item_key, int(entry["count"]), source, String(entry.get("slot", "")))
		button.tooltip_text = full_text
		button.accessibility_name = full_text.replace("\n", ". ")
		button.button_pressed = (
			item_key == selected_key
			and source == selected_source
			and (source != "equipped" or String(entry.get("slot", "")) == selected_slot)
		)
	page_label.text = (
		Loc.text("INVENTORY_EMPTY_FILTER")
		if entries.is_empty()
		else Loc.text("INVENTORY_PAGE", [page + 1, page_count])
	)
	previous_button.disabled = page <= 0
	next_button.disabled = page >= page_count - 1


func _refresh_details() -> void:
	mode_title_label.text = _mode_title()
	var selected_text := Loc.text("INVENTORY_SELECTED_PANEL") + "\n"
	var equipped_text := Loc.text("INVENTORY_EQUIPPED_PANEL") + "\n"
	if selected_source == "locked":
		selected_text += Loc.text("INVENTORY_SLOT_LOCKED")
	elif selected_key.is_empty():
		selected_text += Loc.text("INVENTORY_EMPTY")
	else:
		var count := int(run_state.inventory.get(selected_key, 1)) if selected_source == "inventory" else 1
		selected_text += full_details(selected_key, count, selected_source, selected_slot)
		if mode == Mode.WHETSTONE and Rules.is_weapon(selected_key):
			selected_text += "\n" + _upgrade_offer_text(selected_key)
		elif mode == Mode.RITUAL:
			selected_text += "\n" + Loc.text("INVENTORY_BIND_EXPLANATION")
	var comparison_slot := destination_slot
	if comparison_slot.is_empty() and not selected_key.is_empty():
		comparison_slot = Rules.default_equip_slot(
			selected_key, run_state.current_form_id, run_state.loadout,
		)
		if comparison_slot.is_empty():
			var compatible_slots := Rules.compatible_slots(selected_key)
			if not compatible_slots.is_empty():
				comparison_slot = compatible_slots[0]
	if comparison_slot.is_empty() and not selected_slot.is_empty():
		comparison_slot = selected_slot
	if comparison_slot.is_empty():
		equipped_text += Loc.text("INVENTORY_EMPTY")
	elif not Rules.is_slot_unlocked(run_state.current_form_id, comparison_slot):
		equipped_text += Loc.text("INVENTORY_SLOT_LOCKED")
	else:
		var equipped_key := String(run_state.loadout.get(comparison_slot, ""))
		equipped_text += (
			Loc.text("INVENTORY_EMPTY")
			if equipped_key.is_empty()
			else full_details(equipped_key, 1, "equipped", comparison_slot)
		)
	if not feedback.is_empty():
		selected_text += "\n" + feedback
	selected_detail_label.text = selected_text
	equipped_detail_label.text = equipped_text
	selected_detail_label.tooltip_text = selected_text
	selected_detail_label.accessibility_name = selected_text.replace("\n", ". ")
	equipped_detail_label.tooltip_text = equipped_text
	equipped_detail_label.accessibility_name = equipped_text.replace("\n", ". ")


func _refresh_actions() -> void:
	var has_item := not selected_key.is_empty() and not Rules.item_rules(selected_key).is_empty()
	var mark := run_state.item_mark(selected_key, selected_source, selected_slot)
	keep_button.text = "▣  " + Loc.text("INVENTORY_MARK_KEEP")
	salvage_mark_button.text = "⚔  " + Loc.text("INVENTORY_MARK_SALVAGE")
	marked_only_button.text = Loc.text("INVENTORY_MARKED_ONLY")
	keep_button.button_pressed = mark == "keep"
	salvage_mark_button.button_pressed = mark == "salvage"
	marked_only_button.button_pressed = marked_only
	keep_button.disabled = not has_item or not Rules.is_item_movable(selected_key)
	salvage_mark_button.disabled = keep_button.disabled or mark == "keep"
	keep_button.visible = mode != Mode.CHARACTER
	salvage_mark_button.visible = mode != Mode.CHARACTER
	marked_only_button.visible = mode == Mode.CRUSHER or (mode == Mode.CHARACTER and at_base)
	keep_button.position = Vector2(635, 6)
	salvage_mark_button.position = Vector2(741, 6)
	marked_only_button.position = Vector2(869, 6)
	keep_button.size = Vector2(100, 28)
	salvage_mark_button.size = Vector2(115, 28)
	marked_only_button.size = Vector2(189, 28)
	var inventory_item := has_item and selected_source == "inventory"
	var equipped_item := has_item and selected_source == "equipped"
	var rules := Rules.item_rules(selected_key)
	var permanent := has_item and Rules.is_item_permanent(selected_key)
	upgrade_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	var is_weapon := Rules.is_weapon(selected_key)
	var level := Rules.item_upgrade_level(selected_key) if has_item else 0
	var crusher_ready := at_base and bool(run_state.camp_upgrades.get("crusher", false))
	var whetstone_ready := at_base and bool(run_state.camp_upgrades.get("whetstone", false))
	var ritual_ready := at_base and bool(run_state.camp_upgrades.get("ritual_table", false))
	close_button.visible = mode != Mode.CHARACTER
	match mode:
		Mode.CRUSHER:
			dismantle_button.position = Vector2(635, 198)
			dismantle_button.size = Vector2(225, 42)
			dismantle_all_button.position = Vector2(872, 198)
			dismantle_all_button.size = Vector2(238, 42)
		Mode.WHETSTONE:
			upgrade_button.position = Vector2(635, 198)
			upgrade_button.size = Vector2(475, 42)
		Mode.RITUAL:
			upgrade_button.position = Vector2(635, 198)
			upgrade_button.size = Vector2(475, 42)
		_:
			equip_button.position = Vector2(0, 472)
			equip_button.size = Vector2(130, 42)
			dismantle_button.position = Vector2(139, 472)
			dismantle_button.size = Vector2(130, 42)
			dismantle_all_button.position = Vector2(278, 472)
			dismantle_all_button.size = Vector2(130, 42)
			upgrade_button.position = Vector2(417, 472)
			upgrade_button.size = Vector2(132, 42)
	equip_button.visible = mode == Mode.CHARACTER
	dismantle_button.visible = (mode == Mode.CHARACTER and crusher_ready) or mode == Mode.CRUSHER
	dismantle_all_button.visible = (mode == Mode.CHARACTER and crusher_ready) or mode == Mode.CRUSHER
	upgrade_button.visible = (
		(mode == Mode.CHARACTER and whetstone_ready)
		or mode == Mode.WHETSTONE
		or mode == Mode.RITUAL
	)
	if mode == Mode.CHARACTER:
		_layout_character_action_buttons()
	equip_button.text = Loc.text("INVENTORY_UNEQUIP" if equipped_item else "INVENTORY_EQUIP")
	equip_button.disabled = not has_item or selected_source == "locked" or permanent
	equip_button.tooltip_text = Loc.text("INVENTORY_PERMANENT_LOCKED") if permanent else ""
	equip_button.accessibility_name = equip_button.tooltip_text if permanent else equip_button.text
	dismantle_button.text = Loc.text("INVENTORY_KEEP_CONFIRM_BUTTON" if keep_confirmation_key == selected_key and not selected_key.is_empty() else "INVENTORY_DISMANTLE")
	dismantle_button.disabled = not inventory_item or not crusher_ready or Rules.is_item_bound(selected_key) or permanent
	dismantle_button.tooltip_text = Loc.text("INVENTORY_PERMANENT_LOCKED") if permanent else ""
	dismantle_button.accessibility_name = dismantle_button.tooltip_text if permanent else dismantle_button.text
	dismantle_all_button.text = Loc.text(
		"INVENTORY_DISMANTLE_ALL_CONFIRM_BUTTON"
		if dismantle_all_confirmation_pending
		else "INVENTORY_DISMANTLE_ALL"
	)
	dismantle_all_button.disabled = (
		entries.is_empty()
		or not crusher_ready
		or run_state.count_unbound_inventory_items(marked_only) <= 0
	)
	if mode == Mode.RITUAL:
		var already_bound := has_item and Rules.is_item_bound(selected_key)
		upgrade_button.disabled = permanent or not ritual_ready or not run_state.can_bind_item(
			selected_key,
			selected_source,
			selected_slot,
		)
		upgrade_button.text = Loc.text("INVENTORY_PERMANENT_LOCKED") if permanent else (
			Loc.text("INVENTORY_BIND_ALREADY")
			if already_bound
			else Loc.text("INVENTORY_BIND_ACTION", [Rules.ITEM_BINDING_SOUL_COST])
		)
		upgrade_button.tooltip_text = Loc.text("INVENTORY_PERMANENT_LOCKED") if permanent else (
			Loc.text("INVENTORY_BIND_ALREADY_DESC")
			if already_bound
			else Loc.text("INVENTORY_BIND_TOOLTIP", [Rules.ITEM_BINDING_SOUL_COST])
		)
		if permanent:
			upgrade_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_button.accessibility_name = upgrade_button.tooltip_text if permanent else upgrade_button.text
		return
	if permanent:
		upgrade_button.disabled = true
		upgrade_button.text = Loc.text("INVENTORY_PERMANENT_LOCKED")
		upgrade_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_button.tooltip_text = Loc.text("INVENTORY_PERMANENT_LOCKED")
		upgrade_button.accessibility_name = upgrade_button.tooltip_text
		return
	upgrade_button.disabled = permanent or not (
		whetstone_ready and has_item and is_weapon and level < 3 and run_state.can_afford_weapon_upgrade()
	)
	if not has_item or not is_weapon:
		upgrade_button.text = Loc.text("INVENTORY_UPGRADE_SELECT_SHORT")
	elif level >= 3:
		upgrade_button.text = Loc.text("INVENTORY_UPGRADE_MAX")
	elif mode == Mode.WHETSTONE and not run_state.can_afford_weapon_upgrade():
		upgrade_button.text = Loc.text("INVENTORY_REASON_RESOURCES")
	else:
		upgrade_button.text = (
			Loc.text("INVENTORY_UPGRADE")
			if mode == Mode.CHARACTER
			else Loc.text("INVENTORY_UPGRADE_CHANCE_COST", [
			level + 1,
			roundi(float(Rules.WEAPON_UPGRADE_CHANCES[level + 1]) * 100.0),
			Rules.WEAPON_UPGRADE_COST["stone"],
			Rules.WEAPON_UPGRADE_COST["wood"],
			Rules.WEAPON_UPGRADE_COST["cloth"],
			])
		)
	upgrade_button.tooltip_text = (
		_upgrade_offer_text(selected_key)
		if has_item and is_weapon
		else Loc.text("INVENTORY_UPGRADE_WEAPON_ONLY")
	)


func _upgrade_offer_text(item_key: String) -> String:
	var level := Rules.item_upgrade_level(item_key)
	if level >= 3:
		return Loc.text("INVENTORY_REASON_MAX")
	var offer := Loc.text("INVENTORY_UPGRADE_CHANCE_COST", [
		level + 1,
		roundi(float(Rules.WEAPON_UPGRADE_CHANCES[level + 1]) * 100.0),
		Rules.WEAPON_UPGRADE_COST["stone"],
		Rules.WEAPON_UPGRADE_COST["wood"],
		Rules.WEAPON_UPGRADE_COST["cloth"],
	])
	if not run_state.can_afford_weapon_upgrade():
		offer += " · " + Loc.text("INVENTORY_REASON_RESOURCES")
	return offer


func _mode_title() -> String:
	match mode:
		Mode.CRUSHER: return Loc.text("INVENTORY_SERVICE_CRUSHER")
		Mode.WHETSTONE: return Loc.text("INVENTORY_SERVICE_WHETSTONE")
		Mode.RITUAL: return Loc.text("INVENTORY_SERVICE_RITUAL")
	return Loc.text("CHARACTER_TAB_INVENTORY")


func _entry_identity(entry: Dictionary) -> String:
	return "%s|%s|%s" % [
		String(entry.get("key", "")),
		String(entry.get("source", "")),
		String(entry.get("slot", "")),
	]


func _identity_string(identity: Dictionary) -> String:
	return "%s|%s|%s" % [
		String(identity.get("key", "")),
		String(identity.get("source", "")),
		String(identity.get("slot", "")),
	]


func _selection_fingerprint() -> String:
	if selected_key.is_empty() or run_state == null:
		return ""
	var count := 0
	var resolved_key := selected_key
	if selected_source == "inventory":
		count = int(run_state.inventory.get(selected_key, 0))
	elif selected_source in ["equipped", "locked"]:
		resolved_key = String(run_state.loadout.get(selected_slot, ""))
		count = 1 if resolved_key == selected_key else 0
	return "%s|%s|%s|%d|%s" % [
		resolved_key,
		selected_source,
		selected_slot,
		count,
		run_state.item_mark(selected_key, selected_source, selected_slot),
	]


func _clear_invalid_selection() -> void:
	selected_key = ""
	selected_source = ""
	selected_slot = ""
	destination_slot = ""
	selection_generation = -1
	selection_fingerprint = ""


func _selected_row_button() -> Button:
	if selected_key.is_empty():
		return null
	var identity := _identity_string({
		"key": selected_key,
		"source": selected_source,
		"slot": selected_slot if selected_source == "equipped" else "",
	})
	for button in row_buttons:
		if button.visible and String(button.get_meta("identity", "")) == identity:
			return button
	return null


func _focusable_controls() -> Array[Control]:
	var result: Array[Control] = []
	for current_filter in _active_filter_order():
		var filter_button: Button = filter_buttons[current_filter]
		if filter_button.visible and not filter_button.disabled:
			result.append(filter_button)
	for row_index in range(row_buttons.size()):
		var row := row_buttons[row_index]
		if row.visible and not row.disabled:
			result.append(row)
			if mode == Mode.CHARACTER:
				var mark_overlay = row_mark_overlays[row_index]
				for mark_button in mark_overlay.action_buttons():
					if mark_button.visible and not mark_button.disabled:
						result.append(mark_button)
	for control in [previous_button, next_button, equip_button, dismantle_button, dismantle_all_button, upgrade_button, keep_button, salvage_mark_button, marked_only_button, close_button]:
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
		control.focus_neighbor_top = available[(index - 1 + available.size()) % available.size()].get_path()
		control.focus_neighbor_left = control.focus_neighbor_top
		control.focus_neighbor_bottom = available[(index + 1) % available.size()].get_path()
		control.focus_neighbor_right = control.focus_neighbor_bottom


func _move_focus(step: int) -> void:
	var available := _focusable_controls()
	if available.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var current_index := available.find(focused)
	if current_index < 0:
		available[0].grab_focus()
		return
	available[(current_index + step + available.size()) % available.size()].grab_focus()


func _move_focus_direction(direction: String) -> void:
	var available := _focusable_controls()
	if available.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not available.has(focused):
		available[0].grab_focus()
		return
	var target_path := NodePath()
	match direction:
		"left": target_path = focused.focus_neighbor_left
		"right": target_path = focused.focus_neighbor_right
		"top": target_path = focused.focus_neighbor_top
		"bottom": target_path = focused.focus_neighbor_bottom
	var target: Control = null
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Control
	if target != null and target.visible and not (target is BaseButton and target.disabled):
		target.grab_focus()
		return
	_move_focus(-1 if direction in ["left", "top"] else 1)


func _draw() -> void:
	if mode == Mode.CHARACTER:
		SheetSurface.draw_panel(self, Rect2(Vector2.ZERO, size), false)
		for rect in [Rect2(0, 354, 269, 86), Rect2(280, 354, 269, 86)]:
			SheetSurface.draw_panel(self, rect, false)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(Palette.WARM_ARCHIVE, "panel"))
	draw_rect(Rect2(Vector2.ZERO, size), Palette.color(Palette.WARM_ARCHIVE, "neutral_border"), false, 2.0)
	var detail_rects := (
		[Rect2(Vector2(0, 354), Vector2(269, 86)), Rect2(Vector2(280, 354), Vector2(269, 86))]
		if mode == Mode.CHARACTER
		else [Rect2(Vector2(635, 46), Vector2(225, 146)), Rect2(Vector2(872, 46), Vector2(238, 146))]
	)
	for rect in detail_rects:
		draw_rect(rect, Palette.color(Palette.WARM_ARCHIVE, "inset"))
		draw_rect(rect, Palette.color(Palette.WARM_ARCHIVE, "neutral_border"), false, 2.0)

const SheetSurface := preload("res://scripts/ui/character_sheet_surface.gd")
