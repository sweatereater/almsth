class_name SkillTreePanel
extends Control

const Loc := preload("res://scripts/localization/localization.gd")
const GameRules := preload("res://scripts/game/game_rules.gd")
const AbilitySystem := preload("res://scripts/game/skill_system.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const SkillTreeIconClass := preload("res://scripts/ui/skill_tree_icon.gd")

signal skill_selected(skill_id: String)
signal purchase_requested(skill_id: String)
signal stage_requested(stage_id: String)
signal loadout_requested(slot_id: String)

const COLOR_PANEL := Color("1c2330")
const COLOR_DEEP := Color("111720")
const COLOR_BORDER := Color("344258")
const COLOR_SOUL := Color("72d7cf")
const COLOR_TEXT := Color("e6e2d8")
const COLOR_MUTED := Color("8d98aa")
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.36)

const CARD_RECT := Rect2(16, 76, 1248, 570)
const SURFACE_RECT := Rect2(28, 202, 1224, 434)
const DETAIL_RECT := Rect2(46, 458, 1188, 162)
const TAB_X := [36.0, 278.0, 520.0, 762.0, 1004.0]
const TRACK_Y := [214.0, 294.0, 374.0]
const NODE_X := [150.0, 350.0, 550.0, 750.0]
const NODE_SIZE := Vector2(96, 76)
const STAGE_ORDER := ["skeleton", "zombie", "ghoul", "revenant", "almost_human"]
const STAGE_NAME_KEYS := {
	"skeleton": "SKILL_TAB_SKELETON",
	"zombie": "SKILL_TAB_ZOMBIE",
	"ghoul": "SKILL_TAB_GHOUL",
	"revenant": "SKILL_TAB_REVENANT",
	"almost_human": "SKILL_TAB_ALMOST_HUMAN",
}
const STAGE_BRANCHES := {
	"skeleton": [
		{"label": "SKILL_BRANCH_BONES", "nodes": ["strong_bones", "fundamentals", "skeleton_soon_1", "skeleton_soon_2"]},
		{"label": "SKILL_BRANCH_MAGIC", "nodes": ["magic_awakening", "magic_missile", "magic_missile_range", "magic_ricochet"]},
	],
	"zombie": [
		{"label": "SKILL_BRANCH_FLESH", "nodes": ["flesh_regeneration", "zombie_soon_1", "zombie_soon_2", "zombie_soon_3"]},
	],
	"ghoul": [
		{"label": "SKILL_BRANCH_MANEUVER", "nodes": ["dash", "ghoul_maneuver_soon"]},
		{"label": "SKILL_BRANCH_COMBAT", "nodes": ["double_attack", "ghoul_combat_soon"]},
		{"label": "SKILL_BRANCH_BODY", "nodes": ["stomach", "ears", "nervous_system"]},
	],
	"revenant": [
		{"label": "SKILL_BRANCH_SENSES", "nodes": ["sharp_vision", "revenant_soon_1", "revenant_soon_2", "revenant_soon_3"]},
	],
	"almost_human": [
		{"label": "SKILL_BRANCH_BASIC_ATTACK", "nodes": ["almost_double_strike"]},
		{"label": "SKILL_BRANCH_ABILITY", "nodes": ["circular_attack"]},
		{"label": "SKILL_BRANCH_APPEARANCE", "nodes": ["choose_appearance", "almost_soon_2"]},
	],
}

var state
var selected_stage := "skeleton"
var selected_node_id := "strong_bones"
var feedback := ""
var stage_buttons: Dictionary = {}
var node_buttons: Dictionary = {}
var node_stage: Dictionary = {}
var stage_controls: Dictionary = {}
var branch_labels: Dictionary = {}
var loadout_buttons: Dictionary = {}
var title_label: Label
var meta_label: Label
var detail_icon
var detail_title_label: Label
var detail_meta_label: Label
var detail_description_label: Label
var detail_stats_label: Label
var status_label: Label
var action_button: Button


func _ready() -> void:
	set_process_unhandled_key_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	refresh()


func _build_interface() -> void:
	title_label = _make_label(Rect2(36, 90, 300, 26), 20)
	meta_label = _make_label(Rect2(816, 92, 424, 22), 13)
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for index in range(STAGE_ORDER.size()):
		var stage_id: String = STAGE_ORDER[index]
		var tab := Ui.make_button(self, Vector2(TAB_X[index], 168), "", Vector2(236, 36))
		tab.name = "SkillStage_%s" % stage_id
		tab.toggle_mode = true
		tab.add_theme_font_size_override("font_size", 12)
		tab.pressed.connect(_on_stage_pressed.bind(stage_id))
		Ui.enable_keyboard_focus(tab)
		stage_buttons[stage_id] = tab

	for index in range(AbilitySystem.SLOT_ORDER.size()):
		var slot_id: String = AbilitySystem.SLOT_ORDER[index]
		var loadout := Ui.make_button(
			self, Vector2(36 + 164 * index, 124), "", Vector2(154, 36),
		)
		loadout.name = "AbilityLoadout_%s" % slot_id
		loadout.add_theme_font_size_override("font_size", 10)
		loadout.pressed.connect(_on_loadout_pressed.bind(slot_id))
		Ui.enable_keyboard_focus(loadout)
		loadout_buttons[slot_id] = loadout

	for stage_id in STAGE_ORDER:
		stage_controls[stage_id] = []
		branch_labels[stage_id] = []
		var branches: Array = STAGE_BRANCHES[stage_id]
		for branch_index in range(branches.size()):
			var branch: Dictionary = branches[branch_index]
			var branch_label := _make_label(
				Rect2(48, TRACK_Y[branch_index], 90, 76), 12,
			)
			branch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			branch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			branch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			branch_label.add_theme_color_override("font_color", COLOR_MUTED)
			branch_labels[stage_id].append(branch_label)
			for node_index in range(branch["nodes"].size()):
				var node_id := String(branch["nodes"][node_index])
				var node := SkillTreeIconClass.new()
				node.name = "SkillNode_%s" % node_id
				node.position = Vector2(NODE_X[node_index], TRACK_Y[branch_index])
				node.size = NODE_SIZE
				node.pressed.connect(_on_node_pressed.bind(node_id))
				add_child(node)
				node_buttons[node_id] = node
				node_stage[node_id] = stage_id
				stage_controls[stage_id].append(node)

	detail_icon = SkillTreeIconClass.new()
	detail_icon.name = "SelectedSkillIcon"
	detail_icon.position = Vector2(60, 472)
	detail_icon.size = Vector2(64, 64)
	detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail_icon)
	detail_icon.focus_mode = Control.FOCUS_NONE
	detail_title_label = _make_label(Rect2(138, 470, 680, 24), 18)
	detail_meta_label = _make_label(Rect2(138, 494, 680, 20), 12)
	detail_meta_label.add_theme_color_override("font_color", COLOR_MUTED)
	detail_description_label = _make_label(Rect2(138, 516, 680, 46), 12)
	detail_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description_label.add_theme_constant_override("line_spacing", 0)
	detail_stats_label = _make_label(Rect2(840, 470, 376, 88), 12)
	detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label = _make_label(Rect2(60, 568, 760, 42), 12)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", COLOR_SOUL)
	action_button = Ui.make_button(self, Vector2(840, 568), "", Vector2(376, 38))
	action_button.name = "SkillPurchaseAction"
	action_button.add_theme_font_size_override("font_size", 13)
	action_button.pressed.connect(_on_purchase_pressed)
	Ui.enable_keyboard_focus(action_button)


func _make_label(rect: Rect2, font_size: int) -> Label:
	var label := Ui.make_label(self, rect.position, rect.size, font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func set_context(state_value, stage_id: String, feedback_value := "") -> void:
	state = state_value
	selected_stage = stage_id if STAGE_BRANCHES.has(stage_id) else "skeleton"
	feedback = feedback_value
	if not _node_belongs_to_selected_stage(selected_node_id):
		selected_node_id = _first_node_for_stage(selected_stage)
	refresh()


func apply_locale() -> void:
	refresh()


func select_node(node_id: String) -> void:
	if not node_buttons.has(node_id):
		return
	selected_node_id = node_id
	feedback = ""
	refresh()


func focusable_controls() -> Array[Control]:
	var result: Array[Control] = []
	for stage_id in STAGE_ORDER:
		var tab: Button = stage_buttons.get(stage_id)
		if tab != null and tab.visible and not tab.disabled:
			result.append(tab)
	for slot_id in AbilitySystem.SLOT_ORDER:
		var loadout: Button = loadout_buttons.get(slot_id)
		if loadout != null and loadout.visible and not loadout.disabled:
			result.append(loadout)
	for node in stage_controls.get(selected_stage, []):
		if node.visible:
			result.append(node)
	if action_button != null and action_button.visible and not action_button.disabled:
		result.append(action_button)
	return result


func refresh() -> void:
	if not is_node_ready():
		return
	title_label.text = Loc.text("SKILLS_TITLE")
	meta_label.text = "%s   ·   %s" % [
		Loc.text("SKILL_SOULS", [_total_souls()]),
		Loc.text("SKILL_FREE_STATS", [_free_stats()]),
	]
	_refresh_tabs()
	_refresh_loadout()
	_refresh_branches()
	_refresh_details()
	queue_redraw()


func _refresh_tabs() -> void:
	for index in range(STAGE_ORDER.size()):
		var stage_id: String = STAGE_ORDER[index]
		var tab: Button = stage_buttons[stage_id]
		var unlocked: bool = state == null or bool(state.is_stage_unlocked(stage_id))
		tab.text = (
			Loc.text(STAGE_NAME_KEYS[stage_id])
			if unlocked
			else Loc.text("SKILL_TAB_LOCKED", [Loc.text(STAGE_NAME_KEYS[stage_id])])
		)
		tab.disabled = not unlocked
		var active := selected_stage == stage_id
		tab.button_pressed = active
		tab.position = Vector2(TAB_X[index], 164 if active else 168)
		tab.size = Vector2(236, 42 if active else 36)
		_apply_stage_tab_style(tab, active)
		Ui.fit_button_text(tab, 12, 8)
		if active:
			tab.move_to_front()


func _apply_stage_tab_style(tab: Button, active: bool) -> void:
	if active:
		var selected_style := StyleBoxFlat.new()
		selected_style.bg_color = COLOR_PANEL
		selected_style.border_color = COLOR_SOUL
		selected_style.border_width_left = 2
		selected_style.border_width_top = 2
		selected_style.border_width_right = 2
		selected_style.border_width_bottom = 0
		selected_style.corner_radius_top_left = 6
		selected_style.corner_radius_top_right = 6
		selected_style.corner_radius_bottom_left = 0
		selected_style.corner_radius_bottom_right = 0
		selected_style.content_margin_top = 5.0
		selected_style.content_margin_left = 8.0
		selected_style.content_margin_right = 8.0
		for state_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			tab.add_theme_stylebox_override(state_name, selected_style.duplicate())
		return
	var normal := Ui.make_button_style(Color("171c25"), COLOR_BORDER)
	var hover := Ui.make_button_style(Color("222b39"), Color("52647b"))
	var pressed := Ui.make_button_style(Color("20363b"), COLOR_SOUL, 2)
	tab.add_theme_stylebox_override("normal", normal)
	tab.add_theme_stylebox_override("hover", hover)
	tab.add_theme_stylebox_override("pressed", pressed)
	tab.add_theme_stylebox_override("hover_pressed", pressed.duplicate())
	tab.add_theme_stylebox_override("focus", pressed.duplicate())


func _refresh_loadout() -> void:
	for slot_id in AbilitySystem.SLOT_ORDER:
		var button: Button = loadout_buttons[slot_id]
		var ability_id := "" if state == null else String(state.get_slotted_ability(slot_id))
		button.text = "%s\n%s" % [
			Loc.text(_ability_slot_name_key(slot_id)),
			_ability_display_name(ability_id),
		]
		button.tooltip_text = Loc.text("ABILITY_ASSIGN_HINT")


func _refresh_branches() -> void:
	for stage_id in STAGE_ORDER:
		var visible_stage: bool = stage_id == selected_stage
		var labels: Array = branch_labels[stage_id]
		var branches: Array = STAGE_BRANCHES[stage_id]
		for index in range(labels.size()):
			var label: Label = labels[index]
			label.visible = visible_stage
			label.text = Loc.text(String(branches[index]["label"]))
		for node in stage_controls[stage_id]:
			node.visible = visible_stage
			if not visible_stage:
				continue
			var node_id: String = node.node_id if not node.node_id.is_empty() else _id_for_node(node)
			var presentation := _node_presentation(node_id)
			node.set_presentation(
				node_id,
				String(presentation["name"]),
				String(presentation["kind"]),
				String(presentation["state"]),
				node_id == selected_node_id,
				_can_purchase_node(node_id),
			)
			node.accessibility_description = _node_status(node_id)


func _id_for_node(node) -> String:
	for node_id in node_buttons:
		if node_buttons[node_id] == node:
			return String(node_id)
	return ""


func _refresh_details() -> void:
	if selected_node_id.is_empty() or not node_buttons.has(selected_node_id):
		selected_node_id = _first_node_for_stage(selected_stage)
	var presentation := _node_presentation(selected_node_id)
	detail_icon.set_presentation(
		selected_node_id,
		String(presentation["name"]),
		String(presentation["kind"]),
		String(presentation["state"]),
		false,
		_can_purchase_node(selected_node_id),
		true,
	)
	detail_title_label.text = String(presentation["name"])
	detail_meta_label.text = _detail_meta(selected_node_id)
	detail_description_label.text = _detail_description(selected_node_id)
	detail_stats_label.text = _detail_stats(selected_node_id)
	status_label.text = feedback if not feedback.is_empty() else _node_status(selected_node_id)
	action_button.text = _action_text(selected_node_id)
	action_button.disabled = not _can_purchase_selected()
	action_button.visible = true
	action_button.tooltip_text = status_label.text
	action_button.accessibility_name = "%s · %s" % [action_button.text, status_label.text]


func _node_presentation(node_id: String) -> Dictionary:
	if _is_placeholder(node_id):
		return {
			"name": Loc.text("SKILL_PLACEHOLDER_NAME"),
			"kind": "active",
			"state": "placeholder",
		}
	if node_id == "nervous_system":
		var owned := _intrinsic_owned()
		return {
			"name": Loc.text("FEATURE_NERVOUS_SYSTEM"),
			"kind": "intrinsic",
			"state": "intrinsic_owned" if owned else "intrinsic_locked",
		}
	if not GameRules.SKILLS.has(node_id):
		return {"name": node_id, "kind": "active", "state": "placeholder"}
	var rules: Dictionary = GameRules.SKILLS[node_id]
	var level := _skill_level(node_id)
	var max_level := int(rules["max_level"])
	var visual_state := "available"
	if level >= max_level:
		visual_state = "max"
	elif level > 0:
		visual_state = "learned"
	elif not _stage_unlocked(String(rules["stage"])) or not _prerequisites_met(node_id):
		visual_state = "locked"
	return {
		"name": Loc.text(String(rules["name"])),
		"kind": String(rules.get("kind", "passive")),
		"state": visual_state,
	}


func _detail_meta(node_id: String) -> String:
	if _is_placeholder(node_id):
		return "%s   ·   %s" % [Loc.text("SKILL_DETAIL_TYPE_PLACEHOLDER"), Loc.text("SKILL_DETAIL_LEVEL_NONE")]
	if node_id == "nervous_system":
		return "%s   ·   %s" % [Loc.text("SKILL_DETAIL_TYPE_INTRINSIC"), Loc.text("SKILL_DETAIL_LEVEL_INTRINSIC")]
	var rules: Dictionary = GameRules.SKILLS[node_id]
	var type_key := "SKILL_DETAIL_TYPE_ACTIVE" if rules.get("kind", "passive") == "active" else "SKILL_DETAIL_TYPE_PASSIVE"
	return "%s   ·   %s" % [
		Loc.text(type_key),
		Loc.text("SKILL_LEVEL", [_skill_level(node_id), int(rules["max_level"])]),
	]


func _detail_description(node_id: String) -> String:
	if _is_placeholder(node_id):
		return Loc.text("SKILL_PLACEHOLDER_DESC")
	if node_id == "nervous_system":
		return Loc.text("FEATURE_NERVOUS_SYSTEM_DESC")
	var rules: Dictionary = GameRules.SKILLS[node_id]
	var description := Loc.text("%s_DETAIL" % String(rules["name"]))
	var effect := Loc.text(String(rules["description"]))
	return "%s\n%s" % [
		Loc.text("SKILL_DETAIL_DESCRIPTION", [description]),
		Loc.text("SKILL_DETAIL_EFFECT", [effect]),
	]


func _detail_stats(node_id: String) -> String:
	if _is_placeholder(node_id) or node_id == "nervous_system":
		return "%s\n%s\n%s" % [
			Loc.text("SKILL_DETAIL_MANA", [0]),
			Loc.text("SKILL_DETAIL_COOLDOWN", [0]),
			Loc.text("SKILL_DETAIL_REQUIREMENT", [_requirement_text(node_id)]),
		]
	var rules: Dictionary = GameRules.SKILLS[node_id]
	var ability_id := String(rules.get("ability_id", ""))
	var mana := GameRules.MAGIC_MISSILE_MANA_COST if node_id == "magic_missile" else int(AbilitySystem.ability(ability_id).get("mana_cost", 0))
	var cooldown := AbilitySystem.base_cooldown(ability_id)
	var level := _skill_level(node_id)
	var cost := 0 if level >= int(rules["max_level"]) else GameRules.skill_cost(node_id, level)
	return "%s\n%s\n%s\n%s" % [
		Loc.text("SKILL_DETAIL_MANA", [mana]),
		Loc.text("SKILL_DETAIL_COOLDOWN", [cooldown]),
		Loc.text("SKILL_COST", [cost]) if cost > 0 else Loc.text("SKILL_MAX"),
		Loc.text("SKILL_DETAIL_REQUIREMENT", [_requirement_text(node_id)]),
	]


func _requirement_text(node_id: String) -> String:
	if _is_placeholder(node_id):
		return Loc.text("SKILL_DETAIL_NOT_APPLICABLE")
	if node_id == "nervous_system":
		return Loc.text("FEATURE_OWNED") if _intrinsic_owned() else Loc.text("FEATURE_FORM_LOCKED")
	var rules: Dictionary = GameRules.SKILLS[node_id]
	var requirements: Dictionary = rules["requires"]
	if requirements.is_empty():
		return Loc.text("SKILL_DETAIL_STAGE", [Loc.text(STAGE_NAME_KEYS[String(rules["stage"])])])
	var names := PackedStringArray()
	for required_id in requirements:
		names.append("%s %d" % [
			Loc.text(String(GameRules.SKILLS[required_id]["name"])),
			int(requirements[required_id]),
		])
	return Loc.text("SKILL_DETAIL_REQUIRES", [", ".join(names)])


func _node_status(node_id: String) -> String:
	if _is_placeholder(node_id):
		return Loc.text("SKILL_STATUS_PLACEHOLDER")
	if node_id == "nervous_system":
		return Loc.text("FEATURE_OWNED") if _intrinsic_owned() else Loc.text("FEATURE_FORM_LOCKED")
	var rules: Dictionary = GameRules.SKILLS[node_id]
	var level := _skill_level(node_id)
	if not _stage_unlocked(String(rules["stage"])):
		return Loc.text("SKILL_STAGE_LOCKED")
	if level >= int(rules["max_level"]):
		return Loc.text("SKILL_ALREADY_MAX")
	if not _prerequisites_met(node_id):
		return Loc.text("SKILL_NEEDS_PREVIOUS")
	var cost := GameRules.skill_cost(node_id, level)
	if _total_souls() < cost:
		return Loc.text("SKILL_NEEDS_SOULS", [cost])
	return Loc.text("SKILL_STATUS_UPGRADE_AVAILABLE" if level > 0 else "SKILL_STATUS_LEARN_AVAILABLE")


func _action_text(node_id: String) -> String:
	if _is_placeholder(node_id) or node_id == "nervous_system":
		return Loc.text("SKILL_ACTION_UNAVAILABLE")
	var rules: Dictionary = GameRules.SKILLS[node_id]
	var level := _skill_level(node_id)
	if level >= int(rules["max_level"]):
		return Loc.text("SKILL_ACTION_MAX")
	var cost := GameRules.skill_cost(node_id, level)
	return Loc.text("SKILL_ACTION_UPGRADE" if level > 0 else "SKILL_ACTION_LEARN", [cost])


func _can_purchase_selected() -> bool:
	return _can_purchase_node(selected_node_id)


func _can_purchase_node(node_id: String) -> bool:
	if state == null or not GameRules.SKILLS.has(node_id):
		return false
	var rules: Dictionary = GameRules.SKILLS[node_id]
	var level := _skill_level(node_id)
	return (
		_stage_unlocked(String(rules["stage"]))
		and level < int(rules["max_level"])
		and _prerequisites_met(node_id)
		and _total_souls() >= GameRules.skill_cost(node_id, level)
	)


func _prerequisites_met(skill_id: String) -> bool:
	if not GameRules.SKILLS.has(skill_id):
		return false
	for required_id in GameRules.SKILLS[skill_id]["requires"]:
		if _skill_level(String(required_id)) < int(GameRules.SKILLS[skill_id]["requires"][required_id]):
			return false
	return true


func _intrinsic_owned() -> bool:
	return state != null and GameRules.has_intrinsic_feature(state.current_form_id, "nervous_system")


func _stage_unlocked(stage_id: String) -> bool:
	return state == null or state.is_stage_unlocked(stage_id)


func _skill_level(skill_id: String) -> int:
	return 0 if state == null else state.get_skill_level(skill_id)


func _total_souls() -> int:
	return 0 if state == null else state.get_total_souls()


func _free_stats() -> int:
	return 0 if state == null else int(state.unspent_attribute_points)


func _is_placeholder(node_id: String) -> bool:
	return node_id.contains("soon")


func _node_belongs_to_selected_stage(node_id: String) -> bool:
	return node_stage.has(node_id) and String(node_stage[node_id]) == selected_stage


func _first_node_for_stage(stage_id: String) -> String:
	var branches: Array = STAGE_BRANCHES.get(stage_id, [])
	if branches.is_empty():
		return ""
	return String(branches[0]["nodes"][0])


func _ability_slot_name_key(slot_id: String) -> String:
	match slot_id:
		"attack": return "ABILITY_SLOT_ATTACK"
		"active_1": return "ABILITY_SLOT_ACTIVE_1"
		"active_2": return "ABILITY_SLOT_ACTIVE_2"
	return "ABILITY_SLOT_ACTIVE_3"


func _ability_display_name(ability_id: String) -> String:
	if ability_id.is_empty():
		return Loc.text("ABILITY_EMPTY")
	return Loc.text(String(AbilitySystem.ability(ability_id).get("name", ability_id)))


func _on_stage_pressed(stage_id: String) -> void:
	stage_requested.emit(stage_id)


func _on_loadout_pressed(slot_id: String) -> void:
	loadout_requested.emit(slot_id)


func _on_node_pressed(node_id: String) -> void:
	select_node(node_id)
	skill_selected.emit(node_id)


func _on_purchase_pressed() -> void:
	if GameRules.SKILLS.has(selected_node_id):
		purchase_requested.emit(selected_node_id)


func _draw() -> void:
	draw_rect(Rect2(CARD_RECT.position + Vector2(0, 5), CARD_RECT.size), COLOR_SHADOW)
	draw_rect(CARD_RECT, COLOR_PANEL)
	draw_rect(CARD_RECT, COLOR_BORDER, false, 2.0)
	draw_rect(SURFACE_RECT, COLOR_PANEL)
	draw_rect(SURFACE_RECT, COLOR_BORDER, false, 2.0)
	draw_rect(DETAIL_RECT, COLOR_DEEP)
	draw_rect(DETAIL_RECT, COLOR_BORDER, false, 1.0)
	_draw_connectors()


func _draw_connectors() -> void:
	var branches: Array = STAGE_BRANCHES.get(selected_stage, [])
	for branch_index in range(branches.size()):
		var nodes: Array = branches[branch_index]["nodes"]
		for index in range(nodes.size() - 1):
			var source_id := String(nodes[index])
			var target_id := String(nodes[index + 1])
			var from := Vector2(NODE_X[index] + NODE_SIZE.x, TRACK_Y[branch_index] + 20)
			var to := Vector2(NODE_X[index + 1], TRACK_Y[branch_index] + 20)
			var source_state := String(_node_presentation(source_id)["state"])
			var target_state := String(_node_presentation(target_id)["state"])
			var connector_style := connector_style_for_states(source_state, target_state)
			if connector_style == "learned":
				draw_line(from, to, COLOR_SOUL, 3.0, true)
			elif connector_style == "locked":
				draw_dashed_line(from, to, COLOR_BORDER, 2.0, 8.0, true)
			else:
				draw_line(from, to, COLOR_BORDER, 2.0, true)


static func connector_style_for_states(source_state: String, target_state: String) -> String:
	if target_state in ["placeholder", "locked", "intrinsic_locked"]:
		return "locked"
	if source_state in ["learned", "max", "intrinsic_owned"]:
		return "learned"
	if source_state in ["locked", "intrinsic_locked", "placeholder"]:
		return "locked"
	return "neutral"
