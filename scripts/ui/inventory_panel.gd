class_name InventoryPanel
extends Control

const Loc := preload("res://scripts/localization/localization.gd")
const Rules := preload("res://scripts/game/game_rules.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const SlotIcon := preload("res://scripts/ui/inventory_slot_icon.gd")

signal equip_requested
signal unequip_requested
signal dismantle_requested
signal dismantle_all_requested
signal upgrade_requested
signal bind_requested
signal close_requested
signal presentation_changed

enum Mode { CHARACTER, CRUSHER, WHETSTONE, RITUAL }

const SLOT_ORDER: Array[String] = [
	"weapon", "charm", "armor", "hands", "relic", "offhand",
]
const FILTER_ORDER: Array[String] = [
	"all", "weapon", "charm", "armor", "hands", "relic", "offhand",
]
const PAGE_SIZE := 3
const PANEL_SIZE := Vector2(1110, 243)
const ROW_SIZE := Vector2(620, 48)

var mode: int = Mode.CHARACTER
var run_state: RunState = RunState.new()
var at_base := false
var filter_id := "all"
var page := 0
var selected_key := ""
var selected_source := ""
var selected_slot := ""
var feedback := ""
var dismantle_all_confirmation_pending := false
var entries: Array[Dictionary] = []

var filter_buttons: Dictionary = {}
var row_buttons: Array[Button] = []
var row_icons: Array[InventorySlotIcon] = []
var selected_detail_label: Label
var equipped_detail_label: Label
var mode_title_label: Label
var page_label: Label
var previous_button: Button
var next_button: Button
var equip_button: Button
var dismantle_button: Button
var dismantle_all_button: Button
var upgrade_button: Button


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()


func _ready() -> void:
	apply_locale()
	refresh()


func bind_state(value: RunState, base_context: bool) -> void:
	run_state = value
	at_base = base_context
	refresh()


func set_mode(value: int) -> void:
	if mode == value:
		return
	mode = value
	filter_id = "weapon" if mode == Mode.WHETSTONE else "all"
	clear_navigation_state()
	refresh()


func set_filter(value: String) -> void:
	var accepted := value if FILTER_ORDER.has(value) else "all"
	if mode == Mode.WHETSTONE:
		accepted = "weapon"
	if filter_id == accepted:
		return
	filter_id = accepted
	clear_navigation_state()
	refresh()
	presentation_changed.emit()


func select_visible_index(index: int) -> void:
	var absolute_index := page * PAGE_SIZE + index
	if absolute_index < 0 or absolute_index >= entries.size():
		return
	var entry: Dictionary = entries[absolute_index]
	selected_key = String(entry.get("key", ""))
	selected_source = String(entry.get("source", "inventory"))
	selected_slot = String(entry.get("slot", "")) if selected_source == "equipped" else ""
	dismantle_all_confirmation_pending = false
	feedback = ""
	refresh()
	presentation_changed.emit()


func select_item(item_key: String, source := "inventory", equipped_slot := "") -> void:
	selected_key = item_key
	selected_source = source
	selected_slot = equipped_slot
	dismantle_all_confirmation_pending = false
	refresh()
	presentation_changed.emit()


func select_equipment_slot(slot: String, unlocked: bool) -> void:
	filter_id = slot if FILTER_ORDER.has(slot) else "all"
	page = 0
	selected_slot = slot
	selected_source = "equipped"
	selected_key = String(run_state.loadout.get(slot, "")) if run_state != null else ""
	if not unlocked:
		selected_source = "locked"
	dismantle_all_confirmation_pending = false
	feedback = ""
	refresh()
	presentation_changed.emit()


func change_page(direction: int) -> void:
	var page_count := maxi(1, ceili(entries.size() / float(PAGE_SIZE)))
	page = clampi(page + direction, 0, page_count - 1)
	selected_key = ""
	selected_source = ""
	selected_slot = ""
	dismantle_all_confirmation_pending = false
	feedback = ""
	refresh()
	presentation_changed.emit()


func clear_navigation_state() -> void:
	page = 0
	selected_key = ""
	selected_source = ""
	selected_slot = ""
	dismantle_all_confirmation_pending = false
	feedback = ""


func cancel_confirmation() -> void:
	if not dismantle_all_confirmation_pending:
		return
	dismantle_all_confirmation_pending = false
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


func selected_item_source() -> String:
	return selected_source


func apply_locale() -> void:
	if not is_node_ready():
		return
	for current_filter in FILTER_ORDER:
		var button: Button = filter_buttons[current_filter]
		button.text = (
			Loc.text("INVENTORY_FILTER_ALL")
			if current_filter == "all"
			else Loc.text(String(Rules.SLOT_NAMES[current_filter]))
		)
	previous_button.tooltip_text = Loc.text("INVENTORY_PREVIOUS_PAGE")
	next_button.tooltip_text = Loc.text("INVENTORY_NEXT_PAGE")
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	entries = build_entries(run_state, mode, filter_id)
	_sanitize_selection()
	_refresh_filters()
	_refresh_rows()
	_refresh_actions()
	_refresh_details()
	_refresh_focus_graph()
	queue_redraw()


func grab_initial_focus() -> void:
	var available := _focusable_controls()
	if available.is_empty():
		return
	var preferred: Control = row_buttons[0] if row_buttons[0].visible else available[0]
	preferred.grab_focus()


func handle_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed("game_menu") or event.is_action_pressed("ui_cancel"):
		if dismantle_all_confirmation_pending:
			cancel_confirmation()
		else:
			close_requested.emit()
		return true
	var step := 0
	if (
		event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("move_up")
	):
		step = -1
	elif (
		event.is_action_pressed("ui_right")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("move_right")
		or event.is_action_pressed("move_down")
	):
		step = 1
	if step != 0:
		_move_focus(step)
		return true
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and _focusable_controls().has(focused):
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
		var slot := String(rules.get("slot", ""))
		if rules.is_empty() or (effective_filter != "all" and slot != effective_filter):
			continue
		result.append({
			"key": item_key,
			"source": "inventory",
			"slot": slot,
			"count": int(state.inventory.get(item_key, 0)),
		})
	if panel_mode == Mode.WHETSTONE or panel_mode == Mode.RITUAL:
		var equipped_slots: Array = ["weapon"] if panel_mode == Mode.WHETSTONE else state.loadout.keys()
		for equipped_slot in equipped_slots:
			var equipped_key := String(state.loadout.get(equipped_slot, ""))
			if equipped_key.is_empty():
				continue
			var equipped_rules := Rules.item_rules(equipped_key)
			var equipped_item_slot := String(equipped_rules.get("slot", equipped_slot))
			if effective_filter != "all" and equipped_item_slot != effective_filter:
				continue
			result.append({
				"key": equipped_key,
				"source": "equipped",
				"slot": equipped_item_slot,
				"count": 1,
			})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var slot_a := SLOT_ORDER.find(String(a.get("slot", "")))
		var slot_b := SLOT_ORDER.find(String(b.get("slot", "")))
		if slot_a != slot_b:
			return slot_a < slot_b
		var key_a := String(a.get("key", ""))
		var key_b := String(b.get("key", ""))
		if key_a != key_b:
			return key_a < key_b
		return String(a.get("source", "")) > String(b.get("source", ""))
	)
	return result


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
	var slot := String(rules.get("slot", ""))
	var level := Rules.item_upgrade_level(item_key) if slot == "weapon" else 0
	match slot:
		"weapon":
			if Rules.weapon_type(item_key) == "ranged":
				return PackedStringArray([
					"%s %d" % [Loc.text("PARAM_RANGED_DAMAGE"), int(rules.get("ranged_damage", 0)) + level],
					"%s %d" % [Loc.text("PARAM_ACCURACY"), int(rules.get("accuracy", 0)) + level],
					"%s %d" % [Loc.text("PARAM_RANGED_RANGE"), Rules.weapon_range(item_key)],
				])
			return PackedStringArray([
				"%s %d" % [Loc.text("PARAM_DAMAGE"), int(rules.get("damage", 0)) + level],
				"%s %d" % [Loc.text("PARAM_ACCURACY"), int(rules.get("accuracy", 0)) + level],
			])
		"armor", "offhand":
			return _nonzero_primary(rules, ["max_hp", "dodge", "regeneration"])
		"hands":
			return _nonzero_primary(rules, ["max_hp", "accuracy"])
		"charm":
			return _nonzero_primary(rules, ["mana", "spell_power", "soul_bonus"])
		"relic":
			return _nonzero_primary(rules, ["max_hp", "mana", "spell_power"])
	return PackedStringArray()


static func full_details(item_key: String, count: int, source: String) -> String:
	var rules := Rules.item_rules(item_key)
	if rules.is_empty():
		return Loc.text("INVENTORY_EMPTY")
	var lines := PackedStringArray([display_name(item_key)])
	lines.append(Loc.text("INVENTORY_SOURCE_%s" % source.to_upper()))
	lines.append(Loc.text("INVENTORY_SLOT_LINE", [
		Loc.text(String(Rules.SLOT_NAMES[String(rules.get("slot", "weapon"))])),
	]))
	var level := Rules.item_upgrade_level(item_key)
	if level > 0:
		lines.append(Loc.text("INVENTORY_LEVEL", [level]))
	if count > 1:
		lines.append(Loc.text("INVENTORY_COUNT", [count]))
	if Rules.is_item_bound(item_key):
		lines.append(Loc.text("INVENTORY_BOUND_STATUS"))
	for stat_line in _all_nonzero_stats(item_key):
		lines.append(stat_line)
	var salvage: Dictionary = rules.get("salvage", {})
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
	var weapon_level := Rules.item_upgrade_level(item_key) if rules.get("slot", "") == "weapon" else 0
	for field in ["damage", "ranged_damage", "accuracy", "max_hp", "dodge", "mana", "spell_power", "soul_bonus", "regeneration"]:
		var value := int(rules.get(field, 0))
		if field == "accuracy":
			value += weapon_level
		elif field == "damage" and Rules.weapon_type(item_key) == "melee":
			value += weapon_level
		elif field == "ranged_damage" and Rules.weapon_type(item_key) == "ranged":
			value += weapon_level
		if value != 0:
			result.append("%s: %s%d" % [_stat_name(field), "+" if value > 0 else "", value])
	if Rules.weapon_type(item_key) == "ranged":
		result.append("%s: %d" % [Loc.text("PARAM_RANGED_RANGE"), Rules.weapon_range(item_key)])
	return result


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
	return field


func _build_interface() -> void:
	for index in range(FILTER_ORDER.size()):
		var current_filter := FILTER_ORDER[index]
		var button := Ui.make_button(self, Vector2(index * 88, 0), "", Vector2(84, 42))
		button.name = "Filter_%s" % current_filter
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 10)
		Ui.enable_keyboard_focus(button)
		button.pressed.connect(set_filter.bind(current_filter))
		filter_buttons[current_filter] = button
	mode_title_label = Ui.make_label(self, Vector2(625, 2), Vector2(485, 38), 16)
	mode_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index in range(PAGE_SIZE):
		var row := Ui.make_button(self, Vector2(0, 46 + index * 52), "", ROW_SIZE)
		row.name = "InventoryRow%d" % index
		row.toggle_mode = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 12)
		row.autowrap_mode = TextServer.AUTOWRAP_OFF
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var style: StyleBoxFlat = row.get_theme_stylebox(style_name).duplicate()
			style.content_margin_left = 58.0
			row.add_theme_stylebox_override(style_name, style)
		Ui.enable_keyboard_focus(row)
		row.pressed.connect(select_visible_index.bind(index))
		row_buttons.append(row)
		var icon := SlotIcon.new()
		icon.position = row.position + Vector2(3, 2)
		icon.size = Vector2(44, 44)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		row_icons.append(icon)
	selected_detail_label = Ui.make_label(self, Vector2(643, 52), Vector2(210, 134), 11)
	selected_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_detail_label.add_theme_constant_override("line_spacing", -2)
	equipped_detail_label = Ui.make_label(self, Vector2(880, 52), Vector2(218, 134), 11)
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
	equip_button = _action_button(Vector2(635, 198), Vector2(112, 42), 10)
	equip_button.pressed.connect(func():
		if selected_source == "equipped": unequip_requested.emit()
		else: equip_requested.emit()
	)
	dismantle_button = _action_button(Vector2(753, 198), Vector2(112, 42), 10)
	dismantle_button.pressed.connect(func(): dismantle_requested.emit())
	dismantle_all_button = _action_button(Vector2(871, 198), Vector2(112, 42), 9)
	dismantle_all_button.pressed.connect(func(): dismantle_all_requested.emit())
	upgrade_button = _action_button(Vector2(989, 198), Vector2(121, 42), 9)
	upgrade_button.pressed.connect(func():
		if mode == Mode.RITUAL:
			bind_requested.emit()
		else:
			upgrade_requested.emit()
	)


func _action_button(position_value: Vector2, size_value: Vector2, font_size: int) -> Button:
	var button := Ui.make_button(self, position_value, "", size_value)
	button.add_theme_font_size_override("font_size", font_size)
	Ui.enable_keyboard_focus(button)
	return button


func _sanitize_selection() -> void:
	var page_count := maxi(1, ceili(entries.size() / float(PAGE_SIZE)))
	page = clampi(page, 0, page_count - 1)
	if selected_source == "inventory" and int(run_state.inventory.get(selected_key, 0)) <= 0:
		selected_key = ""
		selected_source = ""
		selected_slot = ""
	elif selected_source == "equipped" and String(run_state.loadout.get(selected_slot, "")) != selected_key:
		selected_key = String(run_state.loadout.get(selected_slot, ""))
	if selected_source == "inventory":
		var found := false
		for entry in entries:
			if String(entry.get("key", "")) == selected_key and String(entry.get("source", "")) == "inventory":
				found = true
				break
		if not found:
			selected_key = ""
			selected_source = ""


func _refresh_filters() -> void:
	for current_filter in FILTER_ORDER:
		var button: Button = filter_buttons[current_filter]
		button.visible = mode != Mode.WHETSTONE or current_filter == "weapon"
		button.button_pressed = current_filter == filter_id


func _refresh_rows() -> void:
	var page_count := maxi(1, ceili(entries.size() / float(PAGE_SIZE)))
	for index in range(PAGE_SIZE):
		var absolute_index := page * PAGE_SIZE + index
		var button := row_buttons[index]
		if absolute_index >= entries.size():
			button.visible = false
			row_icons[index].visible = false
			continue
		var entry: Dictionary = entries[absolute_index]
		var item_key := String(entry["key"])
		var source := String(entry["source"])
		var source_text := ""
		if mode == Mode.WHETSTONE or mode == Mode.RITUAL:
			source_text = " · %s" % Loc.text("INVENTORY_SOURCE_%s" % source.to_upper())
		if Rules.is_item_bound(item_key):
			source_text += " · %s" % Loc.text("INVENTORY_BOUND_SHORT")
		button.visible = true
		row_icons[index].visible = true
		row_icons[index].set_slot(String(entry.get("slot", "")))
		button.text = "%s  ×%d%s\n%s" % [
			display_name(item_key), int(entry["count"]), source_text,
			" · ".join(primary_stats(item_key)),
		]
		button.button_pressed = item_key == selected_key and source == selected_source
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
		selected_text += full_details(selected_key, count, selected_source)
		if mode == Mode.WHETSTONE and Rules.item_rules(selected_key).get("slot", "") == "weapon":
			selected_text += "\n" + _upgrade_offer_text(selected_key)
		elif mode == Mode.RITUAL:
			selected_text += "\n" + Loc.text("INVENTORY_BIND_EXPLANATION")
	var comparison_slot := ""
	if not selected_key.is_empty():
		comparison_slot = String(Rules.item_rules(selected_key).get("slot", ""))
	elif not selected_slot.is_empty():
		comparison_slot = selected_slot
	if comparison_slot.is_empty():
		equipped_text += Loc.text("INVENTORY_EMPTY")
	elif not run_state.get_form()["slots"].has(comparison_slot):
		equipped_text += Loc.text("INVENTORY_SLOT_LOCKED")
	else:
		var equipped_key := String(run_state.loadout.get(comparison_slot, ""))
		equipped_text += (
			Loc.text("INVENTORY_EMPTY")
			if equipped_key.is_empty()
			else full_details(equipped_key, 1, "equipped")
		)
	if not feedback.is_empty():
		selected_text += "\n" + feedback
	selected_detail_label.text = selected_text
	equipped_detail_label.text = equipped_text


func _refresh_actions() -> void:
	var has_item := not selected_key.is_empty() and not Rules.item_rules(selected_key).is_empty()
	var inventory_item := has_item and selected_source == "inventory"
	var equipped_item := has_item and selected_source == "equipped"
	var rules := Rules.item_rules(selected_key)
	var is_weapon: bool = String(rules.get("slot", "")) == "weapon"
	var level := Rules.item_upgrade_level(selected_key) if has_item else 0
	var crusher_ready := at_base and bool(run_state.camp_upgrades.get("crusher", false))
	var whetstone_ready := at_base and bool(run_state.camp_upgrades.get("whetstone", false))
	var ritual_ready := at_base and bool(run_state.camp_upgrades.get("ritual_table", false))
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
			equip_button.position = Vector2(635, 198)
			equip_button.size = Vector2(112, 42)
			dismantle_button.position = Vector2(753, 198)
			dismantle_button.size = Vector2(112, 42)
			dismantle_all_button.position = Vector2(871, 198)
			dismantle_all_button.size = Vector2(112, 42)
			upgrade_button.position = Vector2(989, 198)
			upgrade_button.size = Vector2(121, 42)
	equip_button.visible = mode == Mode.CHARACTER
	dismantle_button.visible = (mode == Mode.CHARACTER and crusher_ready) or mode == Mode.CRUSHER
	dismantle_all_button.visible = (mode == Mode.CHARACTER and crusher_ready) or mode == Mode.CRUSHER
	upgrade_button.visible = (
		(mode == Mode.CHARACTER and whetstone_ready)
		or mode == Mode.WHETSTONE
		or mode == Mode.RITUAL
	)
	equip_button.text = Loc.text("INVENTORY_UNEQUIP" if equipped_item else "INVENTORY_EQUIP")
	equip_button.disabled = not has_item or selected_source == "locked"
	dismantle_button.text = Loc.text("INVENTORY_DISMANTLE")
	dismantle_button.disabled = not inventory_item or not crusher_ready or Rules.is_item_bound(selected_key)
	dismantle_all_button.text = Loc.text(
		"INVENTORY_DISMANTLE_ALL_CONFIRM_BUTTON"
		if dismantle_all_confirmation_pending
		else "INVENTORY_DISMANTLE_ALL"
	)
	dismantle_all_button.disabled = not crusher_ready or run_state.count_unbound_inventory_items() <= 0
	if mode == Mode.RITUAL:
		var already_bound := has_item and Rules.is_item_bound(selected_key)
		upgrade_button.disabled = not ritual_ready or not run_state.can_bind_item(
			selected_key,
			selected_source,
			selected_slot,
		)
		upgrade_button.text = (
			Loc.text("INVENTORY_BIND_ALREADY")
			if already_bound
			else Loc.text("INVENTORY_BIND_ACTION", [Rules.ITEM_BINDING_SOUL_COST])
		)
		upgrade_button.tooltip_text = (
			Loc.text("INVENTORY_BIND_ALREADY_DESC")
			if already_bound
			else Loc.text("INVENTORY_BIND_TOOLTIP", [Rules.ITEM_BINDING_SOUL_COST])
		)
		return
	upgrade_button.disabled = not (
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


func _focusable_controls() -> Array[Control]:
	var result: Array[Control] = []
	for current_filter in FILTER_ORDER:
		var filter_button: Button = filter_buttons[current_filter]
		if filter_button.visible and not filter_button.disabled:
			result.append(filter_button)
	for row in row_buttons:
		if row.visible and not row.disabled:
			result.append(row)
	for control in [previous_button, next_button, equip_button, dismantle_button, dismantle_all_button, upgrade_button]:
		if control.visible and not control.disabled:
			result.append(control)
	return result


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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1c2330"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("354052"), false, 2.0)
	for rect in [Rect2(Vector2(635, 46), Vector2(225, 146)), Rect2(Vector2(872, 46), Vector2(238, 146))]:
		draw_rect(rect, Color("171d27"))
		draw_rect(rect, Color("354052"), false, 2.0)
