extends Control

const Loc := preload("res://scripts/localization/localization.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")
const SaveSystem := preload("res://scripts/system/persistence.gd")
const StoreBridge := preload("res://scripts/platform/store_gateway.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const ControlsPanel := preload("res://scripts/ui/controls_remap_panel.gd")
const InventoryPanelClass := preload("res://scripts/ui/inventory_panel.gd")
const SaveMenuPanelClass := preload("res://scripts/ui/save_menu_panel.gd")
const AppearanceChoicePanelClass := preload("res://scripts/ui/appearance_choice_panel.gd")
const AudioManagerClass := preload("res://scripts/audio/audio_manager.gd")
const DungeonViewportClass := preload("res://scripts/ui/dungeon_viewport.gd")
const StatusStripClass := preload("res://scripts/ui/status_strip.gd")
const BaseMaterialResourceStripClass := preload("res://scripts/ui/base_material_resource_strip.gd")
const InventorySlotIconClass := preload("res://scripts/ui/inventory_slot_icon.gd")
const SkillTreePanelClass := preload("res://scripts/ui/skill_tree_panel.gd")
const CharacterSheetLayout := preload("res://scripts/ui/character_sheet_layout.gd")
const BaseLayout := preload("res://scripts/ui/base_layout.gd")
const PresentationSettings := preload("res://scripts/system/presentation_settings.gd")
const GridNavigation := preload("res://scripts/world/grid_navigation.gd")
const BossFloor90 := preload("res://scripts/world/fixed_floor_90.gd")
const AbilitySystem := preload("res://scripts/game/skill_system.gd")
const CombatSystem := preload("res://scripts/game/combat_system.gd")
const HearingContactSystemClass := preload("res://scripts/game/hearing_contact_system.gd")

enum Screen { NAME_CREATION, STAT_CREATION, STORY, BASE, DUNGEON, CHARACTER, VICTORY, STARTUP }

const CAMP_ART: Texture2D = Renderer.CAMP_ART
const INTRO_ART: Array[Texture2D] = Renderer.INTRO_ART
const DEATH_ART: Texture2D = Renderer.DEATH_ART
const SKELETON_EQUIPMENT_ART: Texture2D = Renderer.SKELETON_EQUIPMENT_ART
const DUNGEON_FLOOR_TEXTURE: Texture2D = Renderer.DUNGEON_FLOOR_TEXTURE
const DUNGEON_WALL_TEXTURE: Texture2D = Renderer.DUNGEON_WALL_TEXTURE
const DUNGEON_CHEST_SPRITE: Texture2D = Renderer.DUNGEON_CHEST_SPRITE
const PLAYER_SKELETON_SPRITE: Texture2D = Renderer.PLAYER_SKELETON_SPRITE
const ENEMY_SPRITES := Renderer.ENEMY_SPRITES

const BOARD_ORIGIN := Renderer.BOARD_ORIGIN
const CELL_SIZE := Renderer.CELL_SIZE
const DUNGEON_VIEW_RECT := Renderer.DUNGEON_VIEW_RECT
const BASE_TITLE_RECT := Rect2(28, 20, 470, 48)
const BASE_RESOURCE_STRIP_RECT := Rect2(520, 18, 288, 44)
const BASE_SOUL_ICON_RECT := Rect2(520, 29, 22, 22)
const BASE_SOULS_RECT := Rect2(546, 18, 80, 44)
const BASE_MATERIALS_RECT := Rect2(638, 18, 170, 44)
const BASE_IMAGE_RECT := BaseLayout.IMAGE_RECT
const BASE_SIDEBAR_RECT := BaseLayout.SIDEBAR_RECT
const BASE_STATUS_RECT := BaseLayout.STATUS_RECT
const CARDINAL_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const MOVE_REPEAT_INITIAL_DELAY := 0.28
const MOVE_REPEAT_INTERVAL := 0.11
const AUTO_STEP_DELAY := MOVE_REPEAT_INTERVAL * 2.5
const WAIT_TURN_OPTIONS := [1, 10, 100]
const MAGIC_TRACE_DURATION := Renderer.MAGIC_TRACE_DURATION
const PROJECTILE_TRACE_DURATION := Renderer.PROJECTILE_TRACE_DURATION
const PLAYER_VISION_RADIUS := GameRules.PLAYER_VISION_BASE_RADIUS
const DEFAULT_INSPECTION_RADIUS := 6
const MIN_INSPECTION_RADIUS := 1
const MAX_INSPECTION_RADIUS := 12
const DEFAULT_BACKGROUND_VOLUME := AudioManagerClass.DEFAULT_BACKGROUND_VOLUME
const DEFAULT_ACTIONS_VOLUME := AudioManagerClass.DEFAULT_ACTIONS_VOLUME
const HIT_FLASH_DURATION := 0.18
const LETHAL_AFTERIMAGE_DURATION := 0.22

const COLOR_BACKGROUND := Renderer.COLOR_BACKGROUND
const COLOR_PANEL := Renderer.COLOR_PANEL
const COLOR_PANEL_BORDER := Renderer.COLOR_PANEL_BORDER
const COLOR_FLOOR_A := Renderer.COLOR_FLOOR_A
const COLOR_FLOOR_B := Renderer.COLOR_FLOOR_B
const COLOR_WALL := Renderer.COLOR_WALL
const COLOR_WALL_INNER := Renderer.COLOR_WALL_INNER
const COLOR_TEXT := Renderer.COLOR_TEXT
const COLOR_MUTED := Renderer.COLOR_MUTED
const COLOR_SOUL := Renderer.COLOR_SOUL
const COLOR_DANGER := Renderer.COLOR_DANGER
const COLOR_GOLD := Renderer.COLOR_GOLD
const COLOR_PLAYER_RING := Renderer.COLOR_PLAYER_RING
const COLOR_PANEL_SHADOW := Renderer.COLOR_PANEL_SHADOW

var state := RunState.new()
var generator := FloorGenerator.new()
var rng := RandomNumberGenerator.new()
var screen := Screen.NAME_CREATION
var previous_screen := Screen.BASE
var floor_data: Dictionary = {}
var player_pos := Vector2i.ZERO
var message := ""
var action_history: Array[String] = []
var pending_attributes := GameRules.default_attributes()
var free_attribute_points := GameRules.STARTING_FREE_ATTRIBUTE_POINTS
var held_direction := Vector2i.ZERO
var movement_repeat_timer := 0.0
var auto_travel_active := false
var auto_explore_active := false
var automatic_action_generation := 0
var auto_step_delay_override := -1.0
var wait_turn_count := 1
var inspection_radius := DEFAULT_INSPECTION_RADIUS
var inspected_target: Dictionary = {}
var magic_traces: Array[Dictionary] = []
var projectile_traces: Array[Dictionary] = []
var enemy_hit_flashes: Dictionary = {}
var player_hit_flash_remaining := 0.0
var lethal_hit_afterimages: Array[Dictionary] = []
var incoming_ranged_attack_this_turn := false
var hearing_contacts := HearingContactSystemClass.new()
var hidden_attack_heard_this_enemy_phase := false
var ability_targeting_id := ""
var ability_target_cells: Array[Vector2i] = []
var ability_unavailable_cells: Dictionary = {}
var ability_target_cursor := Vector2i(-1, -1)
var settings_open := false
var main_menu_open := false
var settings_return_to_main_menu := false
var dungeon_cell_size := PresentationSettings.DEFAULT_CELL_SIZE
var auto_movement_speed_percent := PresentationSettings.DEFAULT_AUTO_MOVEMENT_SPEED_PERCENT
var fullscreen_enabled := false
var audio_muted := false
var background_volume := DEFAULT_BACKGROUND_VOLUME
var actions_volume := DEFAULT_ACTIONS_VOLUME
var audio_manager: AudioManager
var store_gateway: RefCounted
var story_kind := ""
var story_index := 0
var story_completion_message := ""
var active_save_slot_id := ""
var active_save_detached_by_delete := false
var active_save_detached_can_resave := false
var save_policy_overwrite := true
var save_slots_directory := SaveSystem.SAVES_DIR
var legacy_save_path := SaveSystem.SAVE_PATH
var save_time_provider := Callable()
var save_id_factory := Callable()
var save_fault_injector := Callable()
var save_delete_fault_injector := Callable()
var last_save_error := ""
var exit_request_hook := Callable()

@export var persistence_enabled := true
@export var audio_playback_enabled := true

var title_label: Label
var dungeon_viewport: Control
var souls_label: Label
var soul_icon: TextureRect
var stats_label: Label
var sidebar_progress_label: Label
var status_strip: Control
var equipment_label: Label
var camp_upgrades_label: Label
var material_resources_strip: Control
var inspection_label: Label
var message_label: RichTextLabel
var hint_label: Label
var start_button: Button
var attack_button: Button
var spell_button: Button
var active_2_button: Button
var active_3_button: Button
var hotbar_ability_buttons: Dictionary = {}
var hotbar_cooldown_badges: Dictionary = {}
var character_action_button: Button
var interact_button: Button
var wait_button: Button
var wait_count_button: Button
var auto_explore_button: Button
var camp_button: Button
var upgrade_button: Button
var build_crusher_button: Button
var build_whetstone_button: Button
var build_ritual_table_button: Button
var crusher_object_button: Button
var whetstone_object_button: Button
var ritual_table_object_button: Button
var character_button: Button
var language_button: Button
var menu_button: Button
var close_character_button: Button
var name_prompt_label: Label
var name_input: LineEdit
var name_confirm_button: Button
var save_policy_checkbox: CheckButton
var save_policy_hint_label: Label
var creation_points_label: Label
var creation_preview_label: Label
var creation_confirm_button: Button
var attribute_name_labels: Dictionary = {}
var attribute_value_labels: Dictionary = {}
var creation_controls: Array[Control] = []
var character_primary_label: Label
var character_attribute_row_labels: Dictionary = {}
var character_derived_label: Label
var character_equipment_label: Label
var character_soul_level_label: Label
var character_status_strip: Control
var character_equipment_buttons: Dictionary = {}
var character_equipment_glyphs: Dictionary = {}
var character_controls: Array[Control] = []
var character_common_controls: Array[Control] = []
var character_inventory_controls: Array[Control] = []
var character_attribute_points_label: Label
var character_cheat_stats_button: Button
var character_attribute_spend_buttons: Dictionary = {}
var skills_title_label: Label
var skills_meta_label: Label
var skills_status_label: Label
var skeleton_tab_button: Button
var zombie_tab_button: Button
var revenant_tab_button: Button
var ghoul_tab_button: Button
var almost_human_tab_button: Button
var skill_node_buttons: Dictionary = {}
var ability_loadout_buttons: Dictionary = {}
var skill_tree_panel
var skills_panel_controls: Array[Control] = []
var skeleton_skill_controls: Array[Control] = []
var zombie_skill_controls: Array[Control] = []
var revenant_skill_controls: Array[Control] = []
var ghoul_skill_controls: Array[Control] = []
var almost_human_skill_controls: Array[Control] = []
var selected_skill_stage := "skeleton"
var skill_feedback := ""
var character_panel_mode := "skills"
var character_return_focus: Control
var skills_mode_button: Button
var inventory_mode_button: Button
var inventory_controls: Array[Control] = []
var inventory_stack_buttons: Array[Button] = []
var inventory_detail_label: Label
var inventory_prev_button: Button
var inventory_page_label: Label
var inventory_next_button: Button
var inventory_equip_button: Button
var inventory_dismantle_button: Button
var inventory_dismantle_all_button: Button
var inventory_upgrade_button: Button
var selected_inventory_key := ""
var selected_equipment_slot := ""
var inventory_page := 0
var inventory_feedback := ""
var dismantle_all_confirmation_pending := false
var inventory_panel: InventoryPanel
var inventory_service_mode := ""
var settings_title_label: Label
var settings_radius_label: Label
var settings_description_label: Label
var settings_input_label: Label
var settings_minus_button: Button
var settings_plus_button: Button
var settings_zoom_button: Button
var settings_auto_movement_speed_button: Button
var settings_sound_button: Button
var settings_background_label: Label
var settings_background_slider: HSlider
var settings_actions_label: Label
var settings_actions_slider: HSlider
var settings_touch_slider: HSlider
var settings_touch_index := -1
var settings_display_button: Button
var settings_controls_button: Button
var settings_new_game_button: Button
var settings_exit_button: Button
var settings_close_button: Button
var settings_controls: Array[Control] = []
var controls_remap_panel: ControlsPanel
var controls_remap_open := false
var new_game_confirmation_pending := false
var exit_confirmation_pending := false
var expedition_choice_open := false
var expedition_choice_title_label: Label
var expedition_choice_description_label: Label
var expedition_rope_button: Button
var expedition_beginning_button: Button
var expedition_cancel_button: Button
var expedition_choice_controls: Array[Control] = []
var cradle_confirmation_open := false
var cradle_confirmation_title_label: Label
var cradle_confirmation_description_label: Label
var cradle_confirmation_confirm_button: Button
var cradle_confirmation_cancel_button: Button
var cradle_confirmation_controls: Array[Control] = []
var boss_warning_open := false
var boss_warning_title_label: Label
var boss_warning_description_label: Label
var boss_warning_confirm_button: Button
var boss_warning_cancel_button: Button
var boss_warning_controls: Array[Control] = []
var story_shade: ColorRect
var story_caption_label: Label
var story_click_button: Button
var story_controls: Array[Control] = []
var save_menu_panel: Control
var appearance_choice_panel: Control


func _ready() -> void:
	Loc.initialize_from_system()
	InputProfile.ensure_defaults()
	_load_user_settings()
	_setup_audio_manager()
	store_gateway = StoreBridge.new()
	store_gateway.configure_for_current_build()
	store_gateway.initialize()
	rng.randomize()
	_build_interface()
	_apply_locale()
	if persistence_enabled:
		var import_result := SaveSystem.import_legacy_once(
			legacy_save_path, save_slots_directory, _save_timestamp(), save_id_factory,
		)
		if not bool(import_result.get("ok", false)):
			last_save_error = Loc.text("MSG_SAVE_FAILED", [int(import_result.get("error", ERR_CANT_CREATE))])
		_show_startup()
	else:
		_show_name_creation()


func _build_interface() -> void:
	dungeon_viewport = DungeonViewportClass.new()
	dungeon_viewport.name = "DungeonViewport"
	dungeon_viewport.visible = false
	dungeon_viewport.world_cell_pressed.connect(_handle_board_cell)
	add_child(dungeon_viewport)
	dungeon_viewport.set_cell_size(dungeon_cell_size)

	title_label = _make_label(Vector2(28, 20), Vector2(790, 48), 28)
	title_label.text = "ALMSTH"

	souls_label = _make_label(Vector2(28, 56), Vector2(620, 24), 16)
	souls_label.add_theme_color_override("font_color", COLOR_GOLD)
	souls_label.mouse_filter = Control.MOUSE_FILTER_PASS
	soul_icon = TextureRect.new()
	soul_icon.texture = Renderer.SOUL_ICON_TEXTURE
	soul_icon.position = Vector2(1080, 22)
	soul_icon.size = Vector2(22, 22)
	soul_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	soul_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	soul_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soul_icon.visible = false
	add_child(soul_icon)

	stats_label = _make_label(Vector2(846, 78), Vector2(400, 56), 17)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	sidebar_progress_label = _make_label(Vector2(846, 222), Vector2(400, 106), 15)
	sidebar_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_strip = StatusStripClass.new()
	status_strip.name = "StatusStrip"
	status_strip.position = Renderer.DUNGEON_STATUS_RECT.position
	status_strip.size = Renderer.DUNGEON_STATUS_RECT.size
	status_strip.visible = false
	add_child(status_strip)

	equipment_label = _make_label(Vector2(846, 338), Vector2(400, 142), 14)
	equipment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_label.add_theme_constant_override("line_spacing", -1)

	camp_upgrades_label = _make_label(Vector2(846, 324), Vector2(400, 140), 15)
	camp_upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	material_resources_strip = BaseMaterialResourceStripClass.new()
	material_resources_strip.name = "BaseMaterialResources"
	material_resources_strip.position = BASE_MATERIALS_RECT.position
	material_resources_strip.size = BASE_MATERIALS_RECT.size
	material_resources_strip.visible = false
	add_child(material_resources_strip)

	inspection_label = _make_label(Vector2(860, 508), Vector2(372, 164), 16)
	inspection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	hint_label = _make_label(Vector2(28, 558), Vector2(790, 34), 16)
	hint_label.modulate = COLOR_MUTED

	message_label = RichTextLabel.new()
	message_label.position = Vector2(28, 602)
	message_label.size = Vector2(790, 106)
	message_label.bbcode_enabled = true
	message_label.fit_content = false
	message_label.scroll_active = false
	message_label.clip_contents = true
	message_label.add_theme_font_size_override("normal_font_size", 16)
	message_label.add_theme_constant_override("line_separation", -2)
	add_child(message_label)

	start_button = _make_button(Vector2(846, 470), "", Vector2(400, 46))
	start_button.pressed.connect(_on_start_pressed)

	attack_button = _make_button(Vector2(28, 558), "", Vector2(90, 36))
	attack_button.add_theme_font_size_override("font_size", 11)
	attack_button.pressed.connect(_on_attack_pressed)
	hotbar_ability_buttons["attack"] = attack_button

	spell_button = _make_button(Vector2(120, 558), "", Vector2(94, 36))
	spell_button.add_theme_font_size_override("font_size", 11)
	spell_button.pressed.connect(_on_spell_pressed)
	hotbar_ability_buttons["active_1"] = spell_button

	active_2_button = _make_button(Vector2(216, 558), "", Vector2(90, 36))
	active_2_button.add_theme_font_size_override("font_size", 11)
	active_2_button.pressed.connect(_on_ability_slot_pressed.bind("active_2"))
	hotbar_ability_buttons["active_2"] = active_2_button

	active_3_button = _make_button(Vector2(308, 558), "", Vector2(90, 36))
	active_3_button.add_theme_font_size_override("font_size", 11)
	active_3_button.pressed.connect(_on_ability_slot_pressed.bind("active_3"))
	hotbar_ability_buttons["active_3"] = active_3_button
	for slot_id in AbilitySystem.SLOT_ORDER:
		_add_hotbar_cooldown_badge(slot_id, hotbar_ability_buttons[slot_id])

	character_action_button = _make_button(Vector2(666, 558), "", Vector2(74, 36))
	character_action_button.add_theme_font_size_override("font_size", 11)
	character_action_button.pressed.connect(_show_character)

	interact_button = _make_button(Vector2(742, 558), "", Vector2(76, 36))
	interact_button.add_theme_font_size_override("font_size", 11)
	interact_button.pressed.connect(_on_primary_action_pressed)

	wait_button = _make_button(Vector2(400, 558), "", Vector2(100, 36))
	wait_button.add_theme_font_size_override("font_size", 11)
	wait_button.pressed.connect(_on_wait_pressed)

	wait_count_button = _make_button(Vector2(502, 558), "›", Vector2(26, 36))
	wait_count_button.add_theme_font_size_override("font_size", 15)
	wait_count_button.pressed.connect(_cycle_wait_turn_count)

	auto_explore_button = _make_button(Vector2(530, 558), "", Vector2(72, 36))
	auto_explore_button.add_theme_font_size_override("font_size", 11)
	auto_explore_button.pressed.connect(_on_auto_explore_pressed)

	camp_button = _make_button(Vector2(604, 558), "", Vector2(60, 36))
	camp_button.add_theme_font_size_override("font_size", 11)
	camp_button.pressed.connect(_on_camp_pressed)

	build_crusher_button = _make_button(Vector2(846, 520), "", Vector2(400, 38))
	build_crusher_button.add_theme_font_size_override("font_size", 15)
	build_crusher_button.pressed.connect(_on_build_camp_upgrade.bind("crusher"))

	build_whetstone_button = _make_button(Vector2(846, 561), "", Vector2(400, 38))
	build_whetstone_button.add_theme_font_size_override("font_size", 15)
	build_whetstone_button.pressed.connect(_on_build_camp_upgrade.bind("whetstone"))

	build_ritual_table_button = _make_button(Vector2(846, 602), "", Vector2(400, 38))
	build_ritual_table_button.add_theme_font_size_override("font_size", 15)
	build_ritual_table_button.pressed.connect(_on_build_camp_upgrade.bind("ritual_table"))

	crusher_object_button = _make_camp_object_button(
		BaseLayout.station_hitbox_rect("crusher").position,
		BaseLayout.station_hitbox_rect("crusher").size,
		"crusher",
	)
	whetstone_object_button = _make_camp_object_button(
		BaseLayout.station_hitbox_rect("whetstone").position,
		BaseLayout.station_hitbox_rect("whetstone").size,
		"whetstone",
	)
	ritual_table_object_button = _make_camp_object_button(
		BaseLayout.station_hitbox_rect("ritual_table").position,
		BaseLayout.station_hitbox_rect("ritual_table").size,
		"ritual_table",
	)

	upgrade_button = _make_button(Vector2(846, 643), "", Vector2(400, 38))
	upgrade_button.add_theme_font_size_override("font_size", 15)
	upgrade_button.pressed.connect(_on_upgrade_pressed)

	character_button = _make_button(Vector2(828, 14), "", Vector2(302, 42))
	character_button.pressed.connect(_show_character)

	menu_button = _make_button(Vector2(1140, 14), "", Vector2(106, 42))
	menu_button.pressed.connect(_open_main_menu)

	_build_creation_interface()
	_build_character_interface()
	_build_settings_interface()
	_build_controls_remap_interface()
	_build_expedition_choice_interface()
	_build_cradle_confirmation_interface()
	_build_boss_warning_interface()
	_build_story_interface()
	_build_save_menu_interface()
	_build_appearance_choice_interface()


func _make_label(position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
	return Ui.make_label(self, position_value, size_value, font_size)


func _make_button(
	position_value: Vector2,
	text_value: String,
	size_value: Vector2 = Vector2(400, 54)
) -> Button:
	return Ui.make_button(self, position_value, text_value, size_value)


func _add_hotbar_cooldown_badge(slot_id: String, button: Button) -> void:
	var badge := Label.new()
	badge.name = "CooldownBadge_%s" % slot_id
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -25.0
	badge.offset_top = 2.0
	badge.offset_right = -3.0
	badge.offset_bottom = 20.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.focus_mode = Control.FOCUS_ALL
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color("fff1bf"))
	badge.add_theme_stylebox_override(
		"normal", Ui.make_button_style(Color("593f25"), COLOR_GOLD, 1),
	)
	badge.visible = false
	button.add_child(badge)
	hotbar_cooldown_badges[slot_id] = badge


func _make_camp_object_button(
	position_value: Vector2,
	size_value: Vector2,
	upgrade_id: String,
) -> Button:
	var button := _make_button(position_value, "", size_value)
	button.add_theme_font_size_override("font_size", 15)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.enable_keyboard_focus(button)
	button.add_theme_stylebox_override(
		"normal", Ui.make_button_style(Color(0.02, 0.025, 0.035, 0.48), Color(0.2, 0.25, 0.31, 0.72), 1)
	)
	button.add_theme_stylebox_override(
		"hover", Ui.make_button_style(Color(0.08, 0.12, 0.15, 0.72), COLOR_SOUL, 2)
	)
	button.pressed.connect(_open_inventory_service.bind(upgrade_id))
	button.visible = false
	return button


func _fit_button_text(button: Button, preferred_size: int, minimum_size := 10) -> void:
	Ui.fit_button_text(button, preferred_size, minimum_size)


func _fit_single_line_label(label: Label, preferred_size: int, minimum_size := 7) -> void:
	var fitted_size := preferred_size
	var font := label.get_theme_font("font")
	while (
		fitted_size > minimum_size
		and font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size,
		).x > label.size.x
	):
		fitted_size -= 1
	label.add_theme_font_size_override("font_size", fitted_size)


func _fit_localized_button_text() -> void:
	_fit_button_text(start_button, 18, 12)
	_fit_button_text(character_button, 18, 12)
	_fit_button_text(menu_button, 18, 13)
	_fit_button_text(name_confirm_button, 18, 12)
	_fit_button_text(creation_confirm_button, 18, 12)
	_fit_button_text(skills_mode_button, 18, 12)
	_fit_button_text(inventory_mode_button, 18, 12)
	_fit_button_text(skeleton_tab_button, 18, 11)
	_fit_button_text(zombie_tab_button, 18, 11)
	_fit_button_text(ghoul_tab_button, 18, 9)
	_fit_button_text(revenant_tab_button, 18, 11)
	_fit_button_text(almost_human_tab_button, 18, 8)
	_fit_button_text(inventory_equip_button, 14, 10)
	_fit_button_text(inventory_dismantle_button, 14, 10)
	_fit_button_text(inventory_dismantle_all_button, 12, 10)
	_fit_button_text(inventory_upgrade_button, 12, 10)
	_fit_button_text(close_character_button, 18, 12)
	_fit_button_text(settings_display_button, 18, 12)
	_fit_button_text(settings_auto_movement_speed_button, 16, 10)
	_fit_button_text(settings_sound_button, 16, 11)
	_fit_button_text(language_button, 18, 12)
	_fit_button_text(settings_controls_button, 16, 11)
	_fit_button_text(settings_new_game_button, 16, 11)
	_fit_button_text(settings_exit_button, 16, 11)
	_fit_button_text(settings_close_button, 18, 12)
	_fit_button_text(expedition_rope_button, 17, 11)
	_fit_button_text(expedition_beginning_button, 17, 11)
	_fit_button_text(expedition_cancel_button, 18, 12)
	_fit_button_text(cradle_confirmation_confirm_button, 17, 11)
	_fit_button_text(cradle_confirmation_cancel_button, 17, 11)
	_fit_button_text(boss_warning_confirm_button, 17, 11)
	_fit_button_text(boss_warning_cancel_button, 17, 11)


func _build_creation_interface() -> void:
	name_prompt_label = _make_label(Vector2(350, 230), Vector2(580, 44), 24)
	name_prompt_label.text = ""
	name_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	creation_controls.append(name_prompt_label)

	name_input = LineEdit.new()
	name_input.position = Vector2(350, 296)
	name_input.size = Vector2(580, 56)
	name_input.placeholder_text = ""
	name_input.max_length = 24
	name_input.add_theme_font_size_override("font_size", 22)
	name_input.add_theme_color_override("font_color", COLOR_TEXT)
	name_input.add_theme_color_override("font_placeholder_color", Color("7f8998"))
	name_input.add_theme_color_override("caret_color", COLOR_SOUL)
	name_input.add_theme_color_override("selection_color", Color(0.28, 0.66, 0.64, 0.42))
	name_input.add_theme_stylebox_override(
		"normal", Ui.make_button_style(Color("151a22"), Color("3a4658"), 2)
	)
	name_input.add_theme_stylebox_override(
		"focus", Ui.make_button_style(Color("171e28"), COLOR_SOUL, 2)
	)
	name_input.text_submitted.connect(func(_text: String) -> void: _on_name_confirmed())
	add_child(name_input)
	creation_controls.append(name_input)

	name_confirm_button = _make_button(Vector2(440, 382), "")
	name_confirm_button.pressed.connect(_on_name_confirmed)
	creation_controls.append(name_confirm_button)

	save_policy_checkbox = CheckButton.new()
	save_policy_checkbox.position = Vector2(390, 438)
	save_policy_checkbox.size = Vector2(500, 40)
	save_policy_checkbox.button_pressed = true
	save_policy_checkbox.focus_mode = Control.FOCUS_ALL
	save_policy_checkbox.add_theme_font_size_override("font_size", 14)
	save_policy_checkbox.add_theme_color_override("font_color", COLOR_TEXT)
	add_child(save_policy_checkbox)
	creation_controls.append(save_policy_checkbox)
	save_policy_hint_label = _make_label(Vector2(390, 492), Vector2(500, 58), 13)
	save_policy_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_policy_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creation_controls.append(save_policy_hint_label)

	creation_points_label = _make_label(Vector2(0, 112), Vector2(1280, 48), 24)
	creation_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	creation_controls.append(creation_points_label)

	for index in range(GameRules.ATTRIBUTE_ORDER.size()):
		var attribute_id: String = GameRules.ATTRIBUTE_ORDER[index]
		var x := 38.0 + index * 247.0
		var attribute_label := _make_label(Vector2(x, 200), Vector2(216, 40), 20)
		attribute_name_labels[attribute_id] = attribute_label
		attribute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		creation_controls.append(attribute_label)

		var minus_button := _make_button(Vector2(x + 12, 270), "−", Vector2(54, 46))
		minus_button.pressed.connect(_change_pending_attribute.bind(attribute_id, -1))
		creation_controls.append(minus_button)

		var value_label := _make_label(Vector2(x + 70, 266), Vector2(76, 50), 28)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		attribute_value_labels[attribute_id] = value_label
		creation_controls.append(value_label)

		var plus_button := _make_button(Vector2(x + 150, 270), "+", Vector2(54, 46))
		plus_button.pressed.connect(_change_pending_attribute.bind(attribute_id, 1))
		creation_controls.append(plus_button)

	creation_preview_label = _make_label(Vector2(190, 390), Vector2(900, 166), 21)
	creation_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	creation_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creation_controls.append(creation_preview_label)

	creation_confirm_button = _make_button(Vector2(440, 614), "")
	creation_confirm_button.pressed.connect(_on_attributes_confirmed)
	creation_controls.append(creation_confirm_button)


func _configure_character_slot_focus() -> void:
	## Slot controls surround the portrait, so document order is not a useful
	## keyboard/gamepad route. Link each direction to the nearest visual control.
	for source_slot in GameRules.EQUIPMENT_SLOT_ORDER:
		var source: Button = character_equipment_buttons[source_slot]
		var source_center := source.position + source.size * 0.5
		for direction_name in ["left", "right", "top", "bottom"]:
			var best: Button = null
			var best_score := INF
			for target_slot in GameRules.EQUIPMENT_SLOT_ORDER:
				if target_slot == source_slot:
					continue
				var target: Button = character_equipment_buttons[target_slot]
				var delta := target.position + target.size * 0.5 - source_center
				var primary := 0.0
				var secondary := 0.0
				match direction_name:
					"left":
						if delta.x >= 0.0: continue
						primary = -delta.x
						secondary = absf(delta.y)
					"right":
						if delta.x <= 0.0: continue
						primary = delta.x
						secondary = absf(delta.y)
					"top":
						if delta.y >= 0.0: continue
						primary = -delta.y
						secondary = absf(delta.x)
					"bottom":
						if delta.y <= 0.0: continue
						primary = delta.y
						secondary = absf(delta.x)
				var score := primary + secondary * 2.0
				if score < best_score:
					best_score = score
					best = target
			if best == null:
				continue
			match direction_name:
				"left": source.focus_neighbor_left = best.get_path()
				"right": source.focus_neighbor_right = best.get_path()
				"top": source.focus_neighbor_top = best.get_path()
				"bottom": source.focus_neighbor_bottom = best.get_path()
	if character_panel_mode == "inventory":
		for index in range(GameRules.ATTRIBUTE_ORDER.size()):
			var attribute_id: String = GameRules.ATTRIBUTE_ORDER[index]
			_apply_compact_character_attribute_button(
				character_attribute_spend_buttons[attribute_id],
				CharacterSheetLayout.attribute_button_rect(index),
			)


func _configure_character_focus() -> void:
	if screen != Screen.CHARACTER:
		return
	var controls: Array[Control] = [
		skills_mode_button, inventory_mode_button, menu_button, close_character_button,
	]
	if character_panel_mode == "inventory":
		for slot_id in GameRules.EQUIPMENT_SLOT_ORDER:
			controls.append(character_equipment_buttons[slot_id])
		if inventory_panel != null:
			controls.append_array(inventory_panel.focusable_controls())
		controls.append(character_cheat_stats_button)
		for attribute_id in GameRules.ATTRIBUTE_ORDER:
			controls.append(character_attribute_spend_buttons[attribute_id])
	else:
		if skill_tree_panel != null:
			controls.append_array(skill_tree_panel.focusable_controls())
	var available: Array[Control] = []
	for control in controls:
		if control != null and control.visible and not bool(control.get("disabled")):
			Ui.enable_keyboard_focus(control)
			if not available.has(control):
				available.append(control)
	if available.size() < 2:
		return
	for source_index in range(available.size()):
		var source := available[source_index]
		var source_center := source.global_position + source.size * 0.5
		for direction_name in ["left", "right", "top", "bottom"]:
			var best: Control = null
			var best_score := INF
			for target in available:
				if target == source:
					continue
				var delta := target.global_position + target.size * 0.5 - source_center
				var primary := 0.0
				var secondary := 0.0
				match direction_name:
					"left":
						if delta.x >= 0.0: continue
						primary = -delta.x
						secondary = absf(delta.y)
					"right":
						if delta.x <= 0.0: continue
						primary = delta.x
						secondary = absf(delta.y)
					"top":
						if delta.y >= 0.0: continue
						primary = -delta.y
						secondary = absf(delta.x)
					"bottom":
						if delta.y <= 0.0: continue
						primary = delta.y
						secondary = absf(delta.x)
				var score := primary + secondary * 1.65
				if score < best_score:
					best_score = score
					best = target
			if best == null:
				best = available[
					(source_index - 1 + available.size()) % available.size()
					if direction_name == "left" or direction_name == "top"
					else (source_index + 1) % available.size()
				]
			match direction_name:
				"left": source.focus_neighbor_left = best.get_path()
				"right": source.focus_neighbor_right = best.get_path()
				"top": source.focus_neighbor_top = best.get_path()
				"bottom": source.focus_neighbor_bottom = best.get_path()


func _restore_focus_after_character_close() -> void:
	if screen != Screen.BASE or main_menu_open or settings_open:
		return
	if (
		character_return_focus != null
		and is_instance_valid(character_return_focus)
		and character_return_focus.visible
		and not bool(character_return_focus.get("disabled"))
	):
		character_return_focus.grab_focus()
	elif character_button.visible and not character_button.disabled:
		character_button.grab_focus()
	else:
		start_button.grab_focus()
	character_return_focus = null


func _apply_compact_character_attribute_button(button: Button, target_rect: Rect2) -> void:
	# The shared button factory deliberately uses roomy defaults. Attribute rows
	# have their own compact, touch-safe contract so theme minimum sizes cannot
	# push the Wisdom button below its label.
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		if not button.has_theme_stylebox_override(style_name):
			continue
		var style := button.get_theme_stylebox(style_name).duplicate() as StyleBox
		style.content_margin_left = 3.0
		style.content_margin_right = 3.0
		style.content_margin_top = 1.0
		style.content_margin_bottom = 1.0
		button.add_theme_stylebox_override(style_name, style)
	button.position = target_rect.position
	button.size = target_rect.size


func _build_character_interface() -> void:
	character_primary_label = _make_label(
		CharacterSheetLayout.PRIMARY_ATTRIBUTES_HEADER_RECT.position,
		CharacterSheetLayout.PRIMARY_ATTRIBUTES_HEADER_RECT.size,
		11,
	)
	character_primary_label.clip_text = true
	character_primary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	character_primary_label.size = CharacterSheetLayout.PRIMARY_ATTRIBUTES_HEADER_RECT.size
	character_controls.append(character_primary_label)
	character_inventory_controls.append(character_primary_label)
	character_equipment_label = _make_label(Vector2(396, 76), Vector2(192, 16), 12)
	character_equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_controls.append(character_equipment_label)
	character_inventory_controls.append(character_equipment_label)
	for slot in GameRules.EQUIPMENT_SLOT_ORDER:
		var slot_rect: Rect2 = CharacterSheetLayout.slot_rect(slot)
		var slot_button := _make_button(slot_rect.position, "", slot_rect.size)
		slot_button.name = "EquipmentSlot_%s" % slot
		slot_button.add_theme_font_size_override("font_size", 1)
		slot_button.expand_icon = true
		slot_button.pressed.connect(_on_equipment_slot_pressed.bind(slot))
		var glyph := InventorySlotIconClass.new()
		glyph.name = "EmptySlotGlyph"
		glyph.position = Vector2(6, 6)
		glyph.size = Vector2(52, 52)
		glyph.set_slot(slot)
		slot_button.add_child(glyph)
		character_equipment_buttons[slot] = slot_button
		character_equipment_glyphs[slot] = glyph
		character_controls.append(slot_button)
		character_inventory_controls.append(slot_button)
	_configure_character_slot_focus()
	character_soul_level_label = _make_label(
		CharacterSheetLayout.SOUL_FORM_RECT.position,
		CharacterSheetLayout.SOUL_FORM_RECT.size,
		11,
	)
	character_soul_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	character_soul_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	character_soul_level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_soul_level_label.add_theme_constant_override("line_spacing", -1)
	character_controls.append(character_soul_level_label)
	character_inventory_controls.append(character_soul_level_label)
	character_status_strip = StatusStripClass.new()
	character_status_strip.name = "CharacterStatusStrip"
	character_status_strip.position = CharacterSheetLayout.STATUS_STRIP_RECT.position
	character_status_strip.size = CharacterSheetLayout.STATUS_STRIP_RECT.size
	add_child(character_status_strip)
	character_controls.append(character_status_strip)
	character_inventory_controls.append(character_status_strip)
	character_derived_label = _make_label(
		CharacterSheetLayout.DERIVED_STATS_RECT.position,
		CharacterSheetLayout.DERIVED_STATS_RECT.size,
		12,
	)
	character_derived_label.add_theme_constant_override("line_spacing", -1)
	character_controls.append(character_derived_label)
	character_inventory_controls.append(character_derived_label)

	character_attribute_points_label = _make_label(
		CharacterSheetLayout.FREE_STATS_RECT.position,
		CharacterSheetLayout.FREE_STATS_RECT.size,
		12,
	)
	character_attribute_points_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_controls.append(character_attribute_points_label)
	character_inventory_controls.append(character_attribute_points_label)
	character_cheat_stats_button = _make_button(
		CharacterSheetLayout.CHEAT_BUTTON_RECT.position,
		"",
		CharacterSheetLayout.CHEAT_BUTTON_RECT.size,
	)
	character_cheat_stats_button.add_theme_font_size_override("font_size", 12)
	character_cheat_stats_button.pressed.connect(_on_cheat_add_stats_pressed)
	character_controls.append(character_cheat_stats_button)
	character_inventory_controls.append(character_cheat_stats_button)
	for index in range(GameRules.ATTRIBUTE_ORDER.size()):
		var attribute_id: String = GameRules.ATTRIBUTE_ORDER[index]
		var row_label_rect := CharacterSheetLayout.attribute_label_rect(index)
		var row_label := _make_label(row_label_rect.position, row_label_rect.size, 11)
		row_label.name = "CharacterAttribute_%s" % attribute_id
		row_label.clip_text = true
		row_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_label.size = row_label_rect.size
		character_attribute_row_labels[attribute_id] = row_label
		character_controls.append(row_label)
		character_inventory_controls.append(row_label)
		var button_rect := CharacterSheetLayout.attribute_button_rect(index)
		var spend_button := _make_button(button_rect.position, "+", button_rect.size)
		spend_button.name = "CharacterAttributeSpend_%s" % attribute_id
		spend_button.add_theme_font_size_override("font_size", 14)
		_apply_compact_character_attribute_button(spend_button, button_rect)
		spend_button.pressed.connect(_on_spend_attribute_point.bind(attribute_id))
		character_attribute_spend_buttons[attribute_id] = spend_button
		character_controls.append(spend_button)
		character_inventory_controls.append(spend_button)

	skills_mode_button = _make_button(CharacterSheetLayout.SKILLS_TAB_RECT.position, "", CharacterSheetLayout.SKILLS_TAB_RECT.size)
	skills_mode_button.toggle_mode = true
	skills_mode_button.pressed.connect(_select_character_panel.bind("skills"))
	character_controls.append(skills_mode_button)
	character_common_controls.append(skills_mode_button)
	inventory_mode_button = _make_button(CharacterSheetLayout.INVENTORY_TAB_RECT.position, "", CharacterSheetLayout.INVENTORY_TAB_RECT.size)
	inventory_mode_button.toggle_mode = true
	inventory_mode_button.pressed.connect(_select_character_panel.bind("inventory"))
	character_controls.append(inventory_mode_button)
	character_common_controls.append(inventory_mode_button)

	skill_tree_panel = SkillTreePanelClass.new()
	skill_tree_panel.name = "SkillTreePanel"
	skill_tree_panel.position = Vector2.ZERO
	skill_tree_panel.size = Vector2(1280, 646)
	add_child(skill_tree_panel)
	skill_tree_panel.skill_selected.connect(_on_skill_pressed)
	skill_tree_panel.purchase_requested.connect(_on_skill_purchase_pressed)
	skill_tree_panel.stage_requested.connect(_select_skill_stage)
	skill_tree_panel.loadout_requested.connect(_cycle_ability_loadout)
	character_controls.append(skill_tree_panel)
	skills_panel_controls.append(skill_tree_panel)

	# Public aliases retain the existing integration/test surface while the panel
	# owns layout, selection, details and code-drawn node presentation.
	skills_title_label = skill_tree_panel.title_label
	skills_meta_label = skill_tree_panel.meta_label
	skills_status_label = skill_tree_panel.status_label
	skeleton_tab_button = skill_tree_panel.stage_buttons["skeleton"]
	zombie_tab_button = skill_tree_panel.stage_buttons["zombie"]
	ghoul_tab_button = skill_tree_panel.stage_buttons["ghoul"]
	revenant_tab_button = skill_tree_panel.stage_buttons["revenant"]
	almost_human_tab_button = skill_tree_panel.stage_buttons["almost_human"]
	skill_node_buttons = skill_tree_panel.node_buttons
	ability_loadout_buttons = skill_tree_panel.loadout_buttons
	skeleton_skill_controls.assign(skill_tree_panel.stage_controls["skeleton"])
	zombie_skill_controls.assign(skill_tree_panel.stage_controls["zombie"])
	ghoul_skill_controls.assign(skill_tree_panel.stage_controls["ghoul"])
	revenant_skill_controls.assign(skill_tree_panel.stage_controls["revenant"])
	almost_human_skill_controls.assign(skill_tree_panel.stage_controls["almost_human"])

	inventory_panel = InventoryPanelClass.new()
	inventory_panel.position = CharacterSheetLayout.INVENTORY_PANEL_RECT.position
	inventory_panel.size = CharacterSheetLayout.INVENTORY_PANEL_RECT.size
	inventory_panel.visible = false
	add_child(inventory_panel)
	inventory_panel.equip_requested.connect(_on_inventory_equip_pressed)
	inventory_panel.unequip_requested.connect(_on_inventory_equip_pressed)
	inventory_panel.dismantle_requested.connect(_on_inventory_dismantle_pressed)
	inventory_panel.dismantle_all_requested.connect(_on_inventory_dismantle_all_pressed)
	inventory_panel.upgrade_requested.connect(_on_inventory_upgrade_pressed)
	inventory_panel.bind_requested.connect(_on_inventory_bind_pressed)
	inventory_panel.close_requested.connect(_on_inventory_panel_close_requested)
	inventory_panel.presentation_changed.connect(_sync_inventory_panel_state)
	inventory_controls.append(inventory_panel)
	character_controls.append(inventory_panel)
	character_inventory_controls.append(inventory_panel)
	inventory_stack_buttons = inventory_panel.row_buttons
	inventory_prev_button = inventory_panel.previous_button
	inventory_page_label = inventory_panel.page_label
	inventory_next_button = inventory_panel.next_button
	inventory_detail_label = inventory_panel.selected_detail_label
	inventory_equip_button = inventory_panel.equip_button
	inventory_dismantle_button = inventory_panel.dismantle_button
	inventory_dismantle_all_button = inventory_panel.dismantle_all_button
	inventory_upgrade_button = inventory_panel.upgrade_button
	_set_controls_visible(inventory_controls, false)

	close_character_button = _make_button(CharacterSheetLayout.RETURN_RECT.position, "", CharacterSheetLayout.RETURN_RECT.size)
	close_character_button.pressed.connect(_close_character)
	character_controls.append(close_character_button)
	character_common_controls.append(close_character_button)
	for control in character_controls:
		if control is Button:
			Ui.enable_keyboard_focus(control)


func _build_skill_node(skill_id: String, position_value: Vector2, stage_controls: Array[Control]) -> void:
	var button := _make_button(position_value, "", Vector2(220, 82))
	var kind := String(GameRules.SKILLS[skill_id].get("kind", "passive"))
	button.add_theme_font_size_override("font_size", 10 if kind == "passive" else 11)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(_on_skill_pressed.bind(skill_id))
	Ui.apply_skill_node_style(button, kind)
	skill_node_buttons[skill_id] = button
	stage_controls.append(button)
	character_controls.append(button)


func _build_coming_skill_node(node_id: String, position_value: Vector2, stage_controls: Array[Control]) -> void:
	var button := _make_button(position_value, "", Vector2(220, 82))
	button.add_theme_font_size_override("font_size", 11)
	button.disabled = true
	skill_node_buttons[node_id] = button
	stage_controls.append(button)
	character_controls.append(button)


func _build_intrinsic_feature_node(
	feature_id: String,
	position_value: Vector2,
	stage_controls: Array[Control],
) -> void:
	var button := _make_button(position_value, "", Vector2(220, 82))
	button.add_theme_font_size_override("font_size", 10)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = true
	Ui.apply_skill_node_style(button, "passive")
	skill_node_buttons[feature_id] = button
	stage_controls.append(button)
	character_controls.append(button)


func _build_settings_interface() -> void:
	var overlay := ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color("10151df2")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	settings_controls.append(overlay)

	var card := Panel.new()
	card.position = Vector2(330, 40)
	card.size = Vector2(620, 670)
	card.add_theme_stylebox_override("panel", Ui.make_panel_style(COLOR_PANEL_BORDER))
	add_child(card)
	settings_controls.append(card)

	settings_title_label = _make_label(Vector2(370, 52), Vector2(540, 42), 28)
	settings_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_controls.append(settings_title_label)

	settings_radius_label = _make_label(Vector2(390, 96), Vector2(500, 30), 19)
	settings_radius_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_controls.append(settings_radius_label)

	settings_description_label = _make_label(Vector2(390, 122), Vector2(500, 36), 12)
	settings_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_controls.append(settings_description_label)

	settings_minus_button = _make_button(Vector2(390, 160), "−", Vector2(70, 42))
	settings_minus_button.pressed.connect(_change_inspection_radius.bind(-1))
	Ui.enable_keyboard_focus(settings_minus_button)
	settings_controls.append(settings_minus_button)

	settings_plus_button = _make_button(Vector2(820, 160), "+", Vector2(70, 42))
	settings_plus_button.pressed.connect(_change_inspection_radius.bind(1))
	Ui.enable_keyboard_focus(settings_plus_button)
	settings_controls.append(settings_plus_button)
	settings_zoom_button = _make_button(Vector2(470, 160), "", Vector2(340, 42))
	settings_zoom_button.pressed.connect(_cycle_dungeon_zoom)
	Ui.enable_keyboard_focus(settings_zoom_button)
	settings_controls.append(settings_zoom_button)

	settings_auto_movement_speed_button = _make_button(
		Vector2(440, 208), "", Vector2(400, 42),
	)
	settings_auto_movement_speed_button.pressed.connect(_cycle_auto_movement_speed)
	Ui.enable_keyboard_focus(settings_auto_movement_speed_button)
	settings_controls.append(settings_auto_movement_speed_button)

	settings_sound_button = _make_button(Vector2(440, 256), "", Vector2(400, 42))
	settings_sound_button.pressed.connect(_toggle_sound)
	Ui.enable_keyboard_focus(settings_sound_button)
	settings_controls.append(settings_sound_button)

	settings_background_label = _make_label(Vector2(390, 304), Vector2(220, 42), 15)
	settings_background_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_controls.append(settings_background_label)
	settings_background_slider = _make_audio_slider(Vector2(615, 304))
	settings_background_slider.value_changed.connect(_on_background_volume_changed)
	settings_controls.append(settings_background_slider)

	settings_actions_label = _make_label(Vector2(390, 352), Vector2(220, 42), 15)
	settings_actions_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_controls.append(settings_actions_label)
	settings_actions_slider = _make_audio_slider(Vector2(615, 352))
	settings_actions_slider.value_changed.connect(_on_actions_volume_changed)
	settings_controls.append(settings_actions_slider)

	settings_display_button = _make_button(Vector2(440, 400), "", Vector2(400, 42))
	settings_display_button.pressed.connect(_toggle_fullscreen)
	Ui.enable_keyboard_focus(settings_display_button)
	settings_controls.append(settings_display_button)

	language_button = _make_button(Vector2(440, 448), "", Vector2(400, 42))
	language_button.pressed.connect(_on_language_pressed)
	Ui.enable_keyboard_focus(language_button)
	settings_controls.append(language_button)

	settings_input_label = _make_label(Vector2(370, 492), Vector2(540, 44), 11)
	settings_input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_input_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_input_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_controls.append(settings_input_label)

	settings_controls_button = _make_button(Vector2(440, 540), "", Vector2(400, 42))
	settings_controls_button.pressed.connect(_open_controls_remap)
	Ui.enable_keyboard_focus(settings_controls_button)
	settings_controls.append(settings_controls_button)

	settings_new_game_button = _make_button(Vector2(440, 586), "", Vector2(400, 42))
	settings_new_game_button.pressed.connect(_on_new_game_pressed)
	Ui.enable_keyboard_focus(settings_new_game_button)
	settings_controls.append(settings_new_game_button)

	settings_exit_button = _make_button(Vector2(440, 632), "", Vector2(400, 42))
	settings_exit_button.pressed.connect(_on_exit_pressed)
	Ui.enable_keyboard_focus(settings_exit_button)
	settings_controls.append(settings_exit_button)

	settings_close_button = _make_button(Vector2(440, 632), "", Vector2(400, 42))
	settings_close_button.pressed.connect(_close_settings)
	Ui.enable_keyboard_focus(settings_close_button)
	settings_controls.append(settings_close_button)
	_configure_settings_focus_navigation()
	_set_controls_visible(settings_controls, false)


func _make_audio_slider(position_value: Vector2) -> HSlider:
	var slider := HSlider.new()
	slider.position = position_value
	slider.size = Vector2(245, 42)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.allow_greater = false
	slider.allow_lesser = false
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(slider)
	return slider


func _configure_settings_focus_navigation() -> void:
	settings_minus_button.focus_neighbor_left = settings_plus_button.get_path()
	settings_minus_button.focus_neighbor_right = settings_plus_button.get_path()
	settings_minus_button.focus_neighbor_top = settings_close_button.get_path()
	settings_minus_button.focus_neighbor_bottom = settings_zoom_button.get_path()
	settings_plus_button.focus_neighbor_left = settings_minus_button.get_path()
	settings_plus_button.focus_neighbor_right = settings_minus_button.get_path()
	settings_plus_button.focus_neighbor_top = settings_close_button.get_path()
	settings_plus_button.focus_neighbor_bottom = settings_zoom_button.get_path()
	var vertical_controls: Array[Control] = [
		settings_zoom_button,
		settings_auto_movement_speed_button,
		settings_sound_button,
		settings_background_slider,
		settings_actions_slider,
		settings_display_button,
		language_button,
		settings_controls_button,
		settings_new_game_button,
		settings_close_button,
	]
	for index in range(vertical_controls.size()):
		var control := vertical_controls[index]
		control.focus_neighbor_top = (
			settings_minus_button.get_path()
			if index == 0
			else vertical_controls[index - 1].get_path()
		)
		control.focus_neighbor_bottom = (
			settings_minus_button.get_path()
			if index == vertical_controls.size() - 1
			else vertical_controls[index + 1].get_path()
		)


func _build_controls_remap_interface() -> void:
	controls_remap_panel = ControlsPanel.new()
	controls_remap_panel.name = "ControlsRemapPanel"
	controls_remap_panel.close_requested.connect(_close_controls_remap)
	controls_remap_panel.bindings_changed.connect(_on_controls_bindings_changed)
	add_child(controls_remap_panel)
	controls_remap_panel.set_open(false)


func _build_expedition_choice_interface() -> void:
	var overlay := ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color("10151de8")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	expedition_choice_controls.append(overlay)

	var card := Panel.new()
	card.position = Vector2(300, 154)
	card.size = Vector2(680, 420)
	card.add_theme_stylebox_override("panel", Ui.make_panel_style(COLOR_PANEL_BORDER))
	add_child(card)
	expedition_choice_controls.append(card)

	expedition_choice_title_label = _make_label(Vector2(340, 184), Vector2(600, 50), 30)
	expedition_choice_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expedition_choice_controls.append(expedition_choice_title_label)

	expedition_choice_description_label = _make_label(Vector2(360, 246), Vector2(560, 66), 17)
	expedition_choice_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expedition_choice_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	expedition_choice_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expedition_choice_controls.append(expedition_choice_description_label)

	expedition_rope_button = _make_button(Vector2(390, 330), "", Vector2(500, 54))
	expedition_rope_button.pressed.connect(_on_rope_ascent_pressed)
	expedition_choice_controls.append(expedition_rope_button)

	expedition_beginning_button = _make_button(Vector2(390, 398), "", Vector2(500, 54))
	expedition_beginning_button.pressed.connect(_on_beginning_ascent_pressed)
	expedition_choice_controls.append(expedition_beginning_button)

	expedition_cancel_button = _make_button(Vector2(440, 490), "", Vector2(400, 44))
	expedition_cancel_button.pressed.connect(_close_expedition_choice)
	expedition_choice_controls.append(expedition_cancel_button)
	_set_controls_visible(expedition_choice_controls, false)


func _build_cradle_confirmation_interface() -> void:
	var overlay := ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color("10151dec")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	cradle_confirmation_controls.append(overlay)

	var card := Panel.new()
	card.position = Vector2(320, 172)
	card.size = Vector2(640, 376)
	card.add_theme_stylebox_override("panel", Ui.make_panel_style(Color("78618f")))
	add_child(card)
	cradle_confirmation_controls.append(card)

	cradle_confirmation_title_label = _make_label(Vector2(360, 204), Vector2(560, 52), 28)
	cradle_confirmation_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cradle_confirmation_controls.append(cradle_confirmation_title_label)

	cradle_confirmation_description_label = _make_label(Vector2(370, 270), Vector2(540, 104), 20)
	cradle_confirmation_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cradle_confirmation_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cradle_confirmation_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cradle_confirmation_controls.append(cradle_confirmation_description_label)

	cradle_confirmation_confirm_button = _make_button(Vector2(390, 394), "", Vector2(500, 54))
	cradle_confirmation_confirm_button.pressed.connect(_confirm_cradle_evolution)
	cradle_confirmation_controls.append(cradle_confirmation_confirm_button)

	cradle_confirmation_cancel_button = _make_button(Vector2(440, 466), "", Vector2(400, 44))
	cradle_confirmation_cancel_button.pressed.connect(_close_cradle_confirmation)
	cradle_confirmation_controls.append(cradle_confirmation_cancel_button)
	_set_controls_visible(cradle_confirmation_controls, false)


func _build_boss_warning_interface() -> void:
	var overlay := ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.color = Color("10151dec")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	boss_warning_controls.append(overlay)

	var card := Panel.new()
	card.position = Vector2(320, 172)
	card.size = Vector2(640, 376)
	card.add_theme_stylebox_override("panel", Ui.make_panel_style(Color("8f4c3e")))
	add_child(card)
	boss_warning_controls.append(card)

	boss_warning_title_label = _make_label(Vector2(360, 204), Vector2(560, 52), 28)
	boss_warning_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_warning_controls.append(boss_warning_title_label)

	boss_warning_description_label = _make_label(Vector2(370, 270), Vector2(540, 104), 20)
	boss_warning_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_warning_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_warning_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss_warning_controls.append(boss_warning_description_label)

	boss_warning_confirm_button = _make_button(Vector2(390, 394), "", Vector2(500, 54))
	boss_warning_confirm_button.pressed.connect(_confirm_boss_ascent)
	Ui.enable_keyboard_focus(boss_warning_confirm_button)
	boss_warning_controls.append(boss_warning_confirm_button)

	boss_warning_cancel_button = _make_button(Vector2(440, 466), "", Vector2(400, 44))
	boss_warning_cancel_button.pressed.connect(_close_boss_warning)
	Ui.enable_keyboard_focus(boss_warning_cancel_button)
	boss_warning_controls.append(boss_warning_cancel_button)
	_set_controls_visible(boss_warning_controls, false)


func _build_story_interface() -> void:
	story_shade = ColorRect.new()
	story_shade.position = Vector2(0, 570)
	story_shade.size = Vector2(1280, 150)
	story_shade.color = Color(0.02, 0.025, 0.035, 0.82)
	story_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(story_shade)
	story_controls.append(story_shade)

	story_caption_label = _make_label(Vector2(90, 590), Vector2(1100, 100), 22)
	story_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_controls.append(story_caption_label)

	story_click_button = Button.new()
	story_click_button.position = Vector2.ZERO
	story_click_button.size = Vector2(1280, 720)
	story_click_button.flat = true
	story_click_button.focus_mode = Control.FOCUS_NONE
	story_click_button.pressed.connect(_advance_story)
	add_child(story_click_button)
	story_controls.append(story_click_button)
	_set_controls_visible(story_controls, false)


func _build_save_menu_interface() -> void:
	save_menu_panel = SaveMenuPanelClass.new()
	save_menu_panel.name = "SaveMenuPanel"
	save_menu_panel.continue_requested.connect(_on_save_slot_load_requested)
	save_menu_panel.resume_requested.connect(_resume_from_main_menu)
	save_menu_panel.load_requested.connect(_on_save_slot_load_requested)
	save_menu_panel.delete_requested.connect(_on_save_slot_delete_requested)
	save_menu_panel.new_game_requested.connect(_on_main_menu_new_game_requested)
	save_menu_panel.settings_requested.connect(_on_main_menu_settings_requested)
	save_menu_panel.exit_requested.connect(_request_exit)
	add_child(save_menu_panel)


func _build_appearance_choice_interface() -> void:
	appearance_choice_panel = AppearanceChoicePanelClass.new()
	appearance_choice_panel.name = "AppearanceChoicePanel"
	appearance_choice_panel.appearance_confirmed.connect(_confirm_appearance_choice)
	appearance_choice_panel.canceled.connect(_cancel_appearance_choice)
	add_child(appearance_choice_panel)


func _show_startup() -> void:
	main_menu_open = true
	screen = Screen.STARTUP
	_apply_dungeon_layout(false)
	_hide_game_interface()
	_set_controls_visible(creation_controls, false)
	_set_controls_visible(character_controls, false)
	_set_controls_visible(story_controls, false)
	title_label.visible = false
	menu_button.visible = false
	save_menu_panel.set_slots(SaveSystem.list_slots(save_slots_directory))
	save_menu_panel.set_active_slot_id(active_save_slot_id)
	save_menu_panel.set_error(last_save_error)
	save_menu_panel.show_startup()
	queue_redraw()


func _on_startup_new_game_requested() -> void:
	main_menu_open = false
	save_menu_panel.close()
	_reset_for_new_character()
	_show_name_creation()


func _on_main_menu_new_game_requested() -> void:
	if screen == Screen.STARTUP:
		_on_startup_new_game_requested()
		return
	main_menu_open = false
	save_menu_panel.close()
	_reset_for_new_character()
	_show_name_creation()


func _on_main_menu_settings_requested() -> void:
	settings_return_to_main_menu = true
	save_menu_panel.close()
	_open_settings()


func _open_main_menu() -> void:
	if main_menu_open or screen == Screen.STARTUP:
		return
	_cancel_automatic_actions_for_manual_command()
	if not inventory_service_mode.is_empty():
		_close_inventory_service()
	if screen == Screen.CHARACTER:
		_close_character()
	settings_open = false
	_set_controls_visible(settings_controls, false)
	controls_remap_open = false
	controls_remap_panel.set_open(false)
	appearance_choice_panel.close()
	cradle_confirmation_open = false
	_set_controls_visible(cradle_confirmation_controls, false)
	boss_warning_open = false
	_set_controls_visible(boss_warning_controls, false)
	expedition_choice_open = false
	_set_controls_visible(expedition_choice_controls, false)
	_stop_held_movement()
	_cancel_ability_targeting(false)
	main_menu_open = true
	settings_return_to_main_menu = false
	save_menu_panel.set_slots(SaveSystem.list_slots(save_slots_directory))
	save_menu_panel.set_active_slot_id(active_save_slot_id)
	save_menu_panel.set_error(last_save_error)
	save_menu_panel.show_menu(true)
	queue_redraw()


func _resume_from_main_menu() -> void:
	if not main_menu_open or screen == Screen.STARTUP:
		return
	main_menu_open = false
	if active_save_detached_by_delete:
		active_save_detached_can_resave = true
	save_menu_panel.close()
	_refresh_interface()
	if screen == Screen.BASE:
		call_deferred("_restore_base_focus_after_service_close")
	queue_redraw()


func _on_save_slot_load_requested(slot_id: String) -> void:
	var loaded := SaveSystem.load_slot(slot_id, save_slots_directory)
	if not bool(loaded.get("ok", false)):
		last_save_error = Loc.text("MSG_LOAD_FAILED")
		save_menu_panel.set_error(last_save_error)
		save_menu_panel.show_menu(screen != Screen.STARTUP)
		return
	var restored := RunState.new()
	if not restored.restore_save_data(loaded.get("state", {})):
		last_save_error = Loc.text("MSG_LOAD_FAILED")
		save_menu_panel.set_error(last_save_error)
		save_menu_panel.show_menu(screen != Screen.STARTUP)
		return
	state = restored
	active_save_slot_id = String(loaded.get("slot_id", ""))
	save_menu_panel.set_active_slot_id(active_save_slot_id)
	active_save_detached_by_delete = false
	active_save_detached_can_resave = false
	var metadata: Dictionary = loaded.get("metadata", {})
	save_policy_overwrite = String(metadata.get("save_policy", "overwrite")) != "history"
	last_save_error = ""
	main_menu_open = false
	save_menu_panel.close()
	_show_base(Loc.text("MSG_GAME_LOADED"), "none")


func _on_save_slot_delete_requested(slot_id: String) -> void:
	var deleting_active := slot_id == active_save_slot_id and not active_save_slot_id.is_empty()
	var result := SaveSystem.delete_slot(slot_id, save_slots_directory, save_delete_fault_injector)
	if bool(result.get("ok", false)):
		last_save_error = ""
		if deleting_active:
			active_save_slot_id = ""
			active_save_detached_by_delete = true
			active_save_detached_can_resave = false
	else:
		last_save_error = Loc.text("SAVE_MENU_DELETE_ERROR", [int(result.get("error", ERR_CANT_CREATE))])
	var refreshed_slots := SaveSystem.list_slots(save_slots_directory)
	save_menu_panel.set_active_slot_id(active_save_slot_id)
	save_menu_panel.complete_delete(result, refreshed_slots, last_save_error)


func _reset_for_new_character() -> void:
	_cancel_automatic_actions()
	state = RunState.new()
	_clear_hearing_context()
	floor_data.clear()
	pending_attributes = GameRules.default_attributes()
	free_attribute_points = GameRules.STARTING_FREE_ATTRIBUTE_POINTS
	selected_skill_stage = "skeleton"
	skill_feedback = ""
	if skill_tree_panel != null:
		skill_tree_panel.selected_node_id = "strong_bones"
	action_history.clear()
	message = ""
	previous_screen = Screen.BASE
	name_input.text = ""
	active_save_slot_id = ""
	active_save_detached_by_delete = false
	active_save_detached_can_resave = false
	save_policy_overwrite = true
	last_save_error = ""
	if save_policy_checkbox != null:
		save_policy_checkbox.button_pressed = true


func _save_timestamp() -> int:
	return int(save_time_provider.call()) if save_time_provider.is_valid() else int(Time.get_unix_time_from_system())


func _set_controls_visible(controls: Array[Control], value: bool) -> void:
	for control in controls:
		control.visible = value


func _on_language_pressed() -> void:
	Loc.toggle_locale()
	action_history.clear()
	message = ""
	_apply_locale()
	_save_user_settings()


func _apply_locale() -> void:
	start_button.text = Loc.text("BTN_START")
	attack_button.text = Loc.text("BTN_ATTACK")
	spell_button.text = Loc.text("BTN_MAGIC")
	character_action_button.text = Loc.text("BTN_CHARACTER_ACTION")
	interact_button.text = Loc.text("BTN_INTERACT")
	wait_button.text = _wait_button_text()
	wait_count_button.tooltip_text = Loc.text("WAIT_CYCLE_HINT")
	auto_explore_button.text = Loc.text(
		"BTN_AUTO_EXPLORE_STOP" if auto_explore_active else "BTN_AUTO_EXPLORE"
	)
	camp_button.text = Loc.text("BTN_CAMP")
	upgrade_button.text = Loc.text("CAMP_BUILD_CAMPFIRE")
	build_crusher_button.text = Loc.text("CAMP_BUILD_CRUSHER")
	build_whetstone_button.text = Loc.text("CAMP_BUILD_WHETSTONE")
	build_ritual_table_button.text = Loc.text("CAMP_BUILD_RITUAL_TABLE")
	crusher_object_button.text = Loc.text("CAMP_OBJECT_CRUSHER")
	crusher_object_button.tooltip_text = Loc.text("CAMP_OBJECT_CRUSHER_TOOLTIP")
	whetstone_object_button.text = Loc.text("CAMP_OBJECT_WHETSTONE")
	whetstone_object_button.tooltip_text = Loc.text("CAMP_OBJECT_WHETSTONE_TOOLTIP")
	ritual_table_object_button.text = Loc.text("CAMP_OBJECT_RITUAL_TABLE")
	ritual_table_object_button.tooltip_text = Loc.text("CAMP_OBJECT_RITUAL_TABLE_TOOLTIP")
	skills_mode_button.text = Loc.text("CHARACTER_TAB_SKILLS")
	inventory_mode_button.text = Loc.text("CHARACTER_TAB_INVENTORY")
	inventory_equip_button.text = Loc.text("INVENTORY_EQUIP")
	inventory_dismantle_button.text = Loc.text("INVENTORY_DISMANTLE")
	inventory_dismantle_all_button.text = Loc.text("INVENTORY_DISMANTLE_ALL")
	inventory_upgrade_button.text = Loc.text("INVENTORY_UPGRADE")
	inventory_panel.apply_locale()
	character_button.text = Loc.text("BTN_CHARACTER")
	language_button.text = Loc.text("BTN_LANGUAGE", [Loc.language_code()])
	menu_button.text = Loc.text("BTN_MENU")
	name_confirm_button.text = Loc.text("BTN_CONTINUE")
	save_policy_checkbox.text = Loc.text("SAVE_POLICY_OVERWRITE")
	save_policy_checkbox.tooltip_text = Loc.text("SAVE_POLICY_HINT")
	save_policy_hint_label.text = Loc.text("SAVE_POLICY_HINT")
	creation_confirm_button.text = Loc.text("BTN_FINISH_CREATION")
	close_character_button.text = Loc.text("BTN_BACK")
	character_cheat_stats_button.text = Loc.text("BTN_CHEAT_ADD_STATS")
	character_cheat_stats_button.tooltip_text = Loc.text("BTN_CHEAT_ADD_STATS_HINT")
	_fit_button_text(character_cheat_stats_button, 11, 8)
	settings_close_button.text = Loc.text("BTN_SETTINGS_CLOSE")
	settings_controls_button.text = Loc.text("BTN_CONTROLS")
	settings_new_game_button.text = Loc.text(
		"BTN_NEW_GAME_CONFIRM" if new_game_confirmation_pending else "BTN_NEW_GAME"
	)
	settings_exit_button.text = Loc.text(
		"BTN_EXIT_CONFIRM" if exit_confirmation_pending else "BTN_EXIT"
	)
	_fit_button_text(settings_display_button, 18, 12)
	_fit_button_text(settings_new_game_button, 16, 11)
	_fit_button_text(settings_exit_button, 16, 11)
	settings_title_label.text = Loc.text("SETTINGS_TITLE")
	settings_description_label.text = Loc.text("SETTINGS_AUTO_DESC")
	settings_input_label.text = Loc.text("SETTINGS_INPUT_SUMMARY")
	controls_remap_panel.apply_locale()
	save_menu_panel.refresh_locale()
	appearance_choice_panel.apply_locale()
	status_strip.refresh_locale()
	character_status_strip.refresh_locale()
	_refresh_settings_interface()
	_refresh_expedition_choice_interface()
	_refresh_cradle_confirmation_interface()
	_refresh_boss_warning_interface()
	_fit_localized_button_text()
	name_input.placeholder_text = Loc.text("NAME_PLACEHOLDER")
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		attribute_name_labels[attribute_id].text = Loc.text(
			String(GameRules.ATTRIBUTE_NAMES[attribute_id])
		)

	match screen:
		Screen.STARTUP:
			save_menu_panel.set_slots(SaveSystem.list_slots(save_slots_directory))
			save_menu_panel.set_error(last_save_error)
		Screen.NAME_CREATION:
			title_label.text = Loc.text("TITLE_NAME_CREATION")
			name_prompt_label.text = Loc.text("NAME_PROMPT")
		Screen.STAT_CREATION:
			title_label.text = Loc.text("TITLE_STAT_CREATION")
			_refresh_creation_preview()
		Screen.STORY:
			_refresh_story_interface()
		Screen.CHARACTER:
			title_label.text = "%s — %s" % [
				state.character_name,
				Loc.text(String(state.get_form()["name"])),
			]
			_refresh_character_sheet()
		_:
			_refresh_interface()
	_refresh_inspection_panel()
	queue_redraw()


func _toggle_settings() -> void:
	if settings_open:
		_close_settings()
	else:
		_open_settings()


func _open_settings() -> void:
	settings_open = true
	controls_remap_open = false
	controls_remap_panel.set_open(false)
	new_game_confirmation_pending = false
	exit_confirmation_pending = false
	_stop_held_movement()
	_cancel_automatic_actions()
	_set_controls_visible(settings_controls, true)
	# Apply per-control visibility after the modal group is exposed; otherwise
	# the group helper would resurrect the legacy Exit action hidden by the
	# unified main-menu composition.
	_refresh_settings_interface()
	settings_minus_button.grab_focus()
	_audio_action("ui_confirm")


func _close_settings() -> void:
	if not settings_open:
		return
	settings_open = false
	settings_touch_slider = null
	settings_touch_index = -1
	controls_remap_open = false
	controls_remap_panel.set_open(false)
	new_game_confirmation_pending = false
	exit_confirmation_pending = false
	_set_controls_visible(settings_controls, false)
	_save_user_settings()
	_audio_action("ui_cancel")
	_refresh_inspection_panel()
	queue_redraw()
	if settings_return_to_main_menu:
		settings_return_to_main_menu = false
		main_menu_open = true
		save_menu_panel.set_slots(SaveSystem.list_slots(save_slots_directory))
		save_menu_panel.set_error(last_save_error)
		save_menu_panel.show_menu(screen != Screen.STARTUP)


func _open_controls_remap() -> void:
	if not settings_open:
		return
	controls_remap_open = true
	_set_controls_visible(settings_controls, false)
	controls_remap_panel.set_open(true)


func _close_controls_remap() -> void:
	if not controls_remap_open:
		return
	controls_remap_open = false
	controls_remap_panel.set_open(false)
	_set_controls_visible(settings_controls, true)
	_refresh_settings_interface()
	settings_controls_button.grab_focus()
	_save_user_settings()


func _on_controls_bindings_changed() -> void:
	_save_user_settings()


func _change_inspection_radius(amount: int) -> void:
	inspection_radius = clampi(
		inspection_radius + amount,
		MIN_INSPECTION_RADIUS,
		MAX_INSPECTION_RADIUS,
	)
	_refresh_settings_interface()
	_refresh_inspection_panel()
	_save_user_settings()
	queue_redraw()


func _cycle_dungeon_zoom() -> void:
	set_dungeon_cell_size(PresentationSettings.next_cell_size(dungeon_cell_size))
	_save_user_settings()


func _cycle_auto_movement_speed() -> void:
	auto_movement_speed_percent = PresentationSettings.next_auto_movement_speed_percent(
		auto_movement_speed_percent
	)
	_refresh_settings_interface()
	_save_user_settings()


func _dungeon_zoom_direction_from_event(event: InputEvent) -> int:
	if not event is InputEventKey:
		return 0
	var key_event := event as InputEventKey
	if (
		not key_event.pressed
		or key_event.echo
		or key_event.ctrl_pressed
		or key_event.alt_pressed
		or key_event.meta_pressed
	):
		return 0
	if (
		key_event.keycode == KEY_KP_ADD
		or key_event.keycode == KEY_PLUS
		or (key_event.keycode == KEY_EQUAL and key_event.shift_pressed)
		or key_event.unicode == 43
	):
		return 1
	if (
		key_event.keycode == KEY_KP_SUBTRACT
		or (key_event.keycode == KEY_MINUS and not key_event.shift_pressed)
		or key_event.unicode == 45
	):
		return -1
	return 0


func _handle_dungeon_zoom_hotkey(event: InputEvent) -> bool:
	if screen != Screen.DUNGEON:
		return false
	var direction := _dungeon_zoom_direction_from_event(event)
	if direction == 0:
		return false
	var next_size := PresentationSettings.clamped_cell_size_step(
		dungeon_cell_size, direction,
	)
	if next_size != dungeon_cell_size:
		set_dungeon_cell_size(next_size)
		_save_user_settings()
	return true


func set_dungeon_cell_size(value: int) -> void:
	dungeon_cell_size = PresentationSettings.sanitize_cell_size(value)
	Renderer.set_runtime_cell_size(dungeon_cell_size)
	if dungeon_viewport != null:
		dungeon_viewport.set_cell_size(dungeon_cell_size)
	_refresh_settings_interface()
	_refresh_dungeon_viewport()
	queue_redraw()


func _toggle_sound() -> void:
	audio_muted = not audio_muted
	_apply_audio_settings()
	_refresh_settings_interface()
	_save_user_settings()


func _on_background_volume_changed(value: float) -> void:
	var next_value := clampi(roundi(value / 5.0) * 5, 0, 100)
	if background_volume == next_value:
		return
	background_volume = next_value
	_apply_audio_settings()
	_refresh_settings_interface()
	_save_user_settings()


func _on_actions_volume_changed(value: float) -> void:
	var next_value := clampi(roundi(value / 5.0) * 5, 0, 100)
	if actions_volume == next_value:
		return
	actions_volume = next_value
	_apply_audio_settings()
	_refresh_settings_interface()
	_save_user_settings()


func _settings_slider_at(global_position: Vector2) -> HSlider:
	for slider in [settings_background_slider, settings_actions_slider]:
		if slider != null and slider.visible and slider.get_global_rect().has_point(global_position):
			return slider
	return null


func _set_audio_slider_from_pointer(slider: HSlider, global_position: Vector2) -> void:
	if slider == null or slider.size.x <= 0.0:
		return
	var normalized := clampf(
		(global_position.x - slider.global_position.x) / slider.size.x, 0.0, 1.0,
	)
	slider.value = roundf(normalized * 20.0) * 5.0


func _refresh_settings_interface() -> void:
	if settings_radius_label == null:
		return
	settings_radius_label.text = Loc.text("SETTINGS_RADIUS", [inspection_radius])
	settings_minus_button.disabled = inspection_radius <= MIN_INSPECTION_RADIUS
	settings_plus_button.disabled = inspection_radius >= MAX_INSPECTION_RADIUS
	settings_zoom_button.text = Loc.text("SETTINGS_ZOOM", [
		Loc.text(PresentationSettings.locale_key(dungeon_cell_size)),
		dungeon_cell_size,
	])
	settings_zoom_button.tooltip_text = Loc.text("SETTINGS_ZOOM_DESC")
	settings_zoom_button.accessibility_name = "%s. %s" % [
		settings_zoom_button.text, settings_zoom_button.tooltip_text,
	]
	settings_auto_movement_speed_button.text = Loc.text("SETTINGS_AUTO_SPEED", [
		Loc.text(PresentationSettings.auto_movement_speed_locale_key(
			auto_movement_speed_percent
		)),
	])
	settings_auto_movement_speed_button.tooltip_text = Loc.text("SETTINGS_AUTO_SPEED_DESC")
	settings_auto_movement_speed_button.accessibility_name = "%s. %s" % [
		settings_auto_movement_speed_button.text,
		settings_auto_movement_speed_button.tooltip_text,
	]
	settings_sound_button.text = Loc.text(
		"SETTINGS_SOUND_OFF" if audio_muted else "SETTINGS_SOUND_ON"
	)
	settings_background_label.text = Loc.text("SETTINGS_BACKGROUND_VOLUME", [background_volume])
	settings_actions_label.text = Loc.text("SETTINGS_ACTIONS_VOLUME", [actions_volume])
	settings_background_slider.set_value_no_signal(background_volume)
	settings_actions_slider.set_value_no_signal(actions_volume)
	settings_display_button.text = Loc.text(
		"SETTINGS_FULLSCREEN" if fullscreen_enabled else "SETTINGS_WINDOWED"
	)
	settings_new_game_button.text = Loc.text("BTN_MAIN_MENU")
	settings_exit_button.visible = false
	settings_close_button.position.y = 632
	_fit_button_text(settings_auto_movement_speed_button, 16, 10)
	_fit_button_text(settings_sound_button, 16, 11)


func _toggle_fullscreen() -> void:
	fullscreen_enabled = not fullscreen_enabled
	_apply_window_mode()
	_refresh_settings_interface()
	_save_user_settings()


func _on_new_game_pressed() -> void:
	_close_settings()
	if not main_menu_open:
		_open_main_menu()


func _on_exit_pressed() -> void:
	if not exit_confirmation_pending:
		exit_confirmation_pending = true
		new_game_confirmation_pending = false
		_refresh_settings_interface()
		return
	_request_exit()


func _request_exit() -> void:
	var detached_menu_exit := (
		main_menu_open and active_save_detached_by_delete and not active_save_detached_can_resave
	)
	if screen == Screen.BASE and not state.character_name.is_empty() and not detached_menu_exit:
		_save_game_at_base()
	if exit_request_hook.is_valid():
		exit_request_hook.call()
	else:
		get_tree().quit()


func _open_expedition_choice() -> void:
	if screen != Screen.BASE:
		return
	expedition_choice_open = true
	_stop_held_movement()
	_refresh_expedition_choice_interface()
	_set_controls_visible(expedition_choice_controls, true)


func _close_expedition_choice() -> void:
	if not expedition_choice_open:
		return
	expedition_choice_open = false
	_set_controls_visible(expedition_choice_controls, false)


func _refresh_expedition_choice_interface() -> void:
	if expedition_choice_title_label == null:
		return
	expedition_choice_title_label.text = Loc.text("EXPEDITION_CHOICE_TITLE")
	expedition_choice_description_label.text = Loc.text("EXPEDITION_CHOICE_DESC")
	expedition_rope_button.text = (
		Loc.text("BTN_ASCEND_ROPE", [state.rope_floor])
		if state.has_rope_destination()
		else Loc.text("BTN_ASCEND_ROPE_LOCKED")
	)
	expedition_rope_button.disabled = not state.has_rope_destination()
	expedition_beginning_button.text = Loc.text("BTN_ASCEND_BEGINNING", [99])
	expedition_cancel_button.text = Loc.text("BTN_BACK")
	_fit_button_text(expedition_rope_button, 17, 11)
	_fit_button_text(expedition_beginning_button, 17, 11)


func _on_rope_ascent_pressed() -> void:
	if not expedition_choice_open or not state.has_rope_destination():
		return
	_begin_expedition_at(state.rope_floor)


func _on_beginning_ascent_pressed() -> void:
	if not expedition_choice_open:
		return
	_begin_expedition_at(99)


func _begin_expedition_at(floor_number: int) -> void:
	expedition_choice_open = false
	_set_controls_visible(expedition_choice_controls, false)
	state.begin_expedition(floor_number)
	screen = Screen.DUNGEON
	_apply_dungeon_layout(true)
	start_button.visible = false
	upgrade_button.visible = false
	build_crusher_button.visible = false
	build_whetstone_button.visible = false
	build_ritual_table_button.visible = false
	crusher_object_button.visible = false
	whetstone_object_button.visible = false
	ritual_table_object_button.visible = false
	camp_upgrades_label.visible = false
	material_resources_strip.visible = false
	equipment_label.visible = false
	attack_button.visible = true
	spell_button.visible = true
	active_2_button.visible = true
	active_3_button.visible = true
	character_action_button.visible = true
	interact_button.visible = true
	wait_button.visible = true
	wait_count_button.visible = true
	auto_explore_button.visible = true
	camp_button.visible = true
	character_button.visible = false
	inspection_label.visible = true
	hint_label.visible = true
	_load_floor(state.current_floor)


func _open_cradle_confirmation() -> void:
	if screen != Screen.DUNGEON:
		return
	if bool(floor_data.get("cradle_used", false)):
		_log_action(Loc.text("MSG_CRADLE_USED"))
		_refresh_interface()
		return
	if GameRules.next_form(state.current_form_id).is_empty():
		_log_action(Loc.text("MSG_CRADLE_MAX"))
		_refresh_interface()
		return
	_stop_held_movement()
	cradle_confirmation_open = true
	_refresh_cradle_confirmation_interface()
	_set_controls_visible(cradle_confirmation_controls, true)


func _close_cradle_confirmation() -> void:
	if not cradle_confirmation_open:
		return
	cradle_confirmation_open = false
	_set_controls_visible(cradle_confirmation_controls, false)
	queue_redraw()


func _refresh_cradle_confirmation_interface() -> void:
	if cradle_confirmation_title_label == null:
		return
	cradle_confirmation_title_label.text = Loc.text("CRADLE_CONFIRM_TITLE")
	var next := GameRules.next_form(state.current_form_id)
	if next.is_empty():
		cradle_confirmation_description_label.text = Loc.text("MSG_CRADLE_MAX")
		cradle_confirmation_confirm_button.disabled = true
		cradle_confirmation_confirm_button.text = Loc.text("CRADLE_CONFIRM_UNAVAILABLE")
	else:
		var cost := GameRules.evolution_cost(state.current_form_id)
		var required_level := GameRules.required_soul_level(String(next["id"]))
		cradle_confirmation_description_label.text = Loc.text("CRADLE_CONFIRM_DESC", [
			Loc.text(String(state.get_form()["name"])),
			Loc.text(String(next["name"])),
			cost,
			state.carried_souls,
			required_level,
			state.get_effective_soul_level(),
		])
		if state.get_effective_soul_level() < required_level:
			cradle_confirmation_confirm_button.text = Loc.text("CRADLE_CONFIRM_LEVEL_BLOCKED", [required_level])
			cradle_confirmation_confirm_button.disabled = true
		else:
			cradle_confirmation_confirm_button.text = Loc.text("CRADLE_CONFIRM_BUTTON", [cost])
			cradle_confirmation_confirm_button.disabled = state.carried_souls < cost
	cradle_confirmation_cancel_button.text = Loc.text("CRADLE_CONFIRM_CANCEL")
	_fit_button_text(cradle_confirmation_confirm_button, 17, 11)
	_fit_button_text(cradle_confirmation_cancel_button, 17, 11)


func _confirm_cradle_evolution() -> void:
	if not cradle_confirmation_open or cradle_confirmation_confirm_button.disabled:
		return
	_close_cradle_confirmation()
	_use_cradle()


func _open_boss_warning() -> void:
	if screen != Screen.DUNGEON:
		return
	_stop_held_movement()
	boss_warning_open = true
	_refresh_boss_warning_interface()
	_set_controls_visible(boss_warning_controls, true)
	boss_warning_confirm_button.grab_focus()
	queue_redraw()


func _close_boss_warning() -> void:
	if not boss_warning_open:
		return
	boss_warning_open = false
	_set_controls_visible(boss_warning_controls, false)
	queue_redraw()


func _refresh_boss_warning_interface() -> void:
	if boss_warning_title_label == null:
		return
	boss_warning_title_label.text = Loc.text("BOSS_WARNING_TITLE")
	boss_warning_description_label.text = Loc.text("BOSS_WARNING_DESC", [BossFloor90.FLOOR_NUMBER])
	boss_warning_confirm_button.text = Loc.text("BOSS_WARNING_CONFIRM", [BossFloor90.FLOOR_NUMBER])
	boss_warning_cancel_button.text = Loc.text("BOSS_WARNING_CANCEL")
	_fit_button_text(boss_warning_confirm_button, 17, 11)
	_fit_button_text(boss_warning_cancel_button, 17, 11)


func _confirm_boss_ascent() -> void:
	if not boss_warning_open:
		return
	_close_boss_warning()
	if (
		screen != Screen.DUNGEON
		or state.current_floor - 1 != BossFloor90.FLOOR_NUMBER
		or player_pos != floor_data.get("exit", Vector2i(-1, -1))
	):
		return
	_complete_floor_ascent()


func _apply_window_mode() -> void:
	if OS.has_feature("headless"):
		return
	var desired_mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if fullscreen_enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(desired_mode)


func _setup_audio_manager() -> void:
	audio_manager = AudioManagerClass.new()
	audio_manager.name = "AudioManager"
	audio_manager.playback_enabled = audio_playback_enabled
	add_child(audio_manager)
	_apply_audio_settings()


func _apply_audio_settings() -> void:
	if audio_manager != null:
		audio_manager.apply_settings(audio_muted, background_volume, actions_volume)


func _audio_action(event_id: String) -> void:
	if audio_manager != null:
		audio_manager.play_action(event_id)


func _load_user_settings() -> void:
	if not persistence_enabled:
		return
	var loaded := SaveSystem.load_settings()
	if loaded.is_empty():
		return
	Loc.set_locale(String(loaded.get("locale", Loc.current_locale)))
	inspection_radius = clampi(
		int(loaded.get("inspection_radius", DEFAULT_INSPECTION_RADIUS)),
		MIN_INSPECTION_RADIUS,
		MAX_INSPECTION_RADIUS,
	)
	dungeon_cell_size = PresentationSettings.sanitize_cell_size(
		loaded.get("dungeon_cell_size", PresentationSettings.DEFAULT_CELL_SIZE),
	)
	auto_movement_speed_percent = PresentationSettings.sanitize_auto_movement_speed_percent(
		loaded.get(
			"auto_movement_speed_percent",
			PresentationSettings.DEFAULT_AUTO_MOVEMENT_SPEED_PERCENT,
		),
	)
	Renderer.set_runtime_cell_size(dungeon_cell_size)
	fullscreen_enabled = bool(loaded.get("fullscreen", false))
	var audio = loaded.get("audio", {})
	if audio is Dictionary:
		audio_muted = bool(audio.get("muted", false))
		background_volume = clampi(
			int(audio.get("background_volume", DEFAULT_BACKGROUND_VOLUME)), 0, 100,
		)
		actions_volume = clampi(
			int(audio.get("actions_volume", DEFAULT_ACTIONS_VOLUME)), 0, 100,
		)
	var bindings = loaded.get("bindings", {})
	if bindings is Dictionary:
		InputProfile.import_bindings(bindings)
	call_deferred("_apply_window_mode")


func _save_user_settings() -> void:
	if not persistence_enabled:
		return
	SaveSystem.save_settings({
		"fullscreen": fullscreen_enabled,
		"inspection_radius": inspection_radius,
		"dungeon_cell_size": dungeon_cell_size,
		"auto_movement_speed_percent": auto_movement_speed_percent,
		"locale": Loc.current_locale,
		"bindings": InputProfile.export_bindings(),
		"audio": {
			"muted": audio_muted,
			"background_volume": background_volume,
			"actions_volume": actions_volume,
		},
	})


func _save_game_at_base(reason := "update") -> bool:
	if not persistence_enabled or state.character_name.is_empty():
		return false
	var meaningful_snapshot := reason in ["create", "death", "safe_return"]
	var requested_slot_id := active_save_slot_id
	if not save_policy_overwrite and meaningful_snapshot:
		requested_slot_id = ""
	var result := SaveSystem.save_slot(
		state,
		requested_slot_id,
		"overwrite" if save_policy_overwrite else "history",
		save_slots_directory,
		_save_timestamp(),
		save_id_factory,
		{},
		save_fault_injector,
	)
	if not bool(result.get("ok", false)):
		last_save_error = Loc.text("MSG_SAVE_FAILED", [int(result.get("error", ERR_CANT_CREATE))])
		if screen == Screen.BASE:
			_log_action(last_save_error)
			_refresh_interface()
		return false
	active_save_slot_id = String(result.get("slot_id", active_save_slot_id))
	active_save_detached_by_delete = false
	active_save_detached_can_resave = false
	last_save_error = ""
	return true


func _log_action(text: String) -> void:
	message = text
	if text.strip_edges().is_empty():
		return
	action_history.push_front(text)
	if action_history.size() > 5:
		action_history.resize(5)
	_refresh_action_history()


func _append_to_latest_action(text: String) -> void:
	if action_history.is_empty():
		_log_action(text.strip_edges())
		return
	action_history[0] += text
	message = action_history[0]
	_refresh_action_history()


func _refresh_action_history() -> void:
	var colors := ["72d7cf", "789b9c", "64797d", "53636a", "465158"]
	var lines := PackedStringArray()
	for index in range(action_history.size()):
		var font_size := (10 if index == 0 else 8) if screen == Screen.DUNGEON else (16 if index == 0 else 12)
		lines.append("[color=#%s][font_size=%d]%s[/font_size][/color]" % [
			colors[index], font_size, action_history[index],
		])
	message_label.text = "\n".join(lines)


func _hide_game_interface() -> void:
	expedition_choice_open = false
	_set_controls_visible(expedition_choice_controls, false)
	cradle_confirmation_open = false
	_set_controls_visible(cradle_confirmation_controls, false)
	boss_warning_open = false
	_set_controls_visible(boss_warning_controls, false)
	souls_label.visible = false
	soul_icon.visible = false
	stats_label.visible = false
	sidebar_progress_label.visible = false
	status_strip.visible = false
	equipment_label.visible = false
	camp_upgrades_label.visible = false
	material_resources_strip.visible = false
	inspection_label.visible = false
	hint_label.visible = false
	message_label.visible = false
	start_button.visible = false
	attack_button.visible = false
	spell_button.visible = false
	active_2_button.visible = false
	active_3_button.visible = false
	upgrade_button.visible = false
	build_crusher_button.visible = false
	build_whetstone_button.visible = false
	build_ritual_table_button.visible = false
	crusher_object_button.visible = false
	whetstone_object_button.visible = false
	ritual_table_object_button.visible = false
	character_action_button.visible = false
	interact_button.visible = false
	wait_button.visible = false
	wait_count_button.visible = false
	auto_explore_button.visible = false
	camp_button.visible = false
	character_button.visible = false
	if dungeon_viewport != null:
		dungeon_viewport.visible = false


func _show_name_creation() -> void:
	if audio_manager != null:
		audio_manager.set_background("base")
	if save_menu_panel != null:
		save_menu_panel.close()
	screen = Screen.NAME_CREATION
	_apply_dungeon_layout(false)
	_hide_game_interface()
	_set_controls_visible(creation_controls, false)
	_set_controls_visible(character_controls, false)
	title_label.visible = true
	menu_button.visible = true
	title_label.text = Loc.text("TITLE_NAME_CREATION")
	name_prompt_label.text = Loc.text("NAME_PROMPT")
	name_prompt_label.visible = true
	name_input.visible = true
	name_confirm_button.visible = true
	save_policy_checkbox.visible = true
	save_policy_hint_label.visible = false
	name_input.grab_focus()
	queue_redraw()


func _on_name_confirmed() -> void:
	var chosen_name := name_input.text.strip_edges()
	if chosen_name.is_empty():
		name_prompt_label.text = Loc.text("NAME_EMPTY")
		return
	state.character_name = chosen_name
	save_policy_overwrite = save_policy_checkbox.button_pressed
	_show_stat_creation()


func _show_stat_creation() -> void:
	if audio_manager != null:
		audio_manager.set_background("base")
	screen = Screen.STAT_CREATION
	_apply_dungeon_layout(false)
	_hide_game_interface()
	_set_controls_visible(character_controls, false)
	_set_controls_visible(creation_controls, true)
	name_prompt_label.visible = false
	name_input.visible = false
	name_confirm_button.visible = false
	save_policy_checkbox.visible = false
	save_policy_hint_label.visible = false
	title_label.visible = true
	title_label.text = Loc.text("TITLE_STAT_CREATION")
	_refresh_creation_preview()
	queue_redraw()


func _change_pending_attribute(attribute_id: String, amount: int) -> void:
	var current_value := int(pending_attributes[attribute_id])
	if amount > 0:
		if free_attribute_points <= 0:
			return
		pending_attributes[attribute_id] = current_value + 1
		free_attribute_points -= 1
	else:
		if current_value <= GameRules.STARTING_ATTRIBUTE_VALUE:
			return
		pending_attributes[attribute_id] = current_value - 1
		free_attribute_points += 1
	_refresh_creation_preview()
	queue_redraw()


func _refresh_creation_preview() -> void:
	creation_points_label.text = Loc.text("FREE_POINTS", [free_attribute_points])
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		attribute_value_labels[attribute_id].text = str(pending_attributes[attribute_id])
	var derived := GameRules.calculate_derived_stats(pending_attributes, "skeleton")
	creation_preview_label.text = (
		Loc.text("SKELETON_PARAMETERS") + "\n\n"
		+ Loc.text("PARAM_DAMAGE") + ": %d     " + Loc.text("PARAM_ACCURACY") + ": %d     "
		+ Loc.text("PARAM_HP") + ": %d     " + Loc.text("PARAM_DODGE") + ": %d\n"
		+ Loc.text("PARAM_MANA") + ": %d     " + Loc.text("PARAM_SPELL_POWER") + ": %d     "
		+ Loc.text("PARAM_REGENERATION") + ": %d     " + Loc.text("PARAM_RANGED_DAMAGE") + ": %d"
	) % [
		derived["damage"], derived["accuracy"], derived["max_hp"], derived["dodge"],
		derived["mana"], derived["spell_power"], derived["regeneration"], derived["ranged_damage"],
	]
	creation_confirm_button.disabled = free_attribute_points != 0


func _on_attributes_confirmed() -> void:
	if free_attribute_points != 0:
		return
	state.configure_character(state.character_name, pending_attributes)
	action_history.clear()
	_show_story("intro", Loc.text("MSG_AWAKENS", [state.character_name]))


func _show_story(kind: String, completion_message: String) -> void:
	_stop_held_movement()
	if audio_manager != null:
		if kind == "death":
			audio_manager.stop_background()
		else:
			audio_manager.set_background("base")
	story_kind = kind
	story_index = 0
	story_completion_message = completion_message
	screen = Screen.STORY
	_apply_dungeon_layout(false)
	_hide_game_interface()
	_set_controls_visible(creation_controls, false)
	_set_controls_visible(character_controls, false)
	title_label.visible = false
	menu_button.visible = false
	_set_controls_visible(story_controls, true)
	_refresh_story_interface()
	queue_redraw()


func _refresh_story_interface() -> void:
	if story_caption_label == null:
		return
	var caption_key := "STORY_DEATH"
	if story_kind == "intro":
		caption_key = ["STORY_INTRO_1", "STORY_INTRO_2", "STORY_INTRO_3"][story_index]
	story_caption_label.text = "%s\n%s" % [
		Loc.text(caption_key),
		Loc.text("STORY_CONTINUE"),
	]


func _advance_story() -> void:
	if screen != Screen.STORY:
		return
	if story_kind == "intro" and story_index < INTRO_ART.size() - 1:
		story_index += 1
		_refresh_story_interface()
		queue_redraw()
		return
	_set_controls_visible(story_controls, false)
	menu_button.visible = true
	_show_base(story_completion_message, "create" if story_kind == "intro" else "death")


func _show_base(text: String, save_reason := "update") -> void:
	if audio_manager != null:
		audio_manager.set_background("base")
	projectile_traces.clear()
	_clear_hit_effects()
	_clear_hearing_context()
	_stop_held_movement()
	_cancel_automatic_actions()
	expedition_choice_open = false
	_set_controls_visible(expedition_choice_controls, false)
	cradle_confirmation_open = false
	_set_controls_visible(cradle_confirmation_controls, false)
	boss_warning_open = false
	_set_controls_visible(boss_warning_controls, false)
	inspected_target.clear()
	inventory_service_mode = ""
	inventory_panel.visible = false
	screen = Screen.BASE
	_apply_dungeon_layout(false)
	_log_action(text)
	_set_controls_visible(creation_controls, false)
	_set_controls_visible(character_controls, false)
	_set_controls_visible(story_controls, false)
	menu_button.visible = true
	title_label.visible = true
	stats_label.visible = true
	souls_label.visible = true
	sidebar_progress_label.visible = true
	equipment_label.visible = false
	camp_upgrades_label.visible = true
	material_resources_strip.visible = true
	inspection_label.visible = false
	hint_label.visible = true
	message_label.visible = true
	start_button.visible = true
	upgrade_button.visible = true
	build_crusher_button.visible = true
	build_whetstone_button.visible = true
	build_ritual_table_button.visible = true
	attack_button.visible = false
	spell_button.visible = false
	active_2_button.visible = false
	active_3_button.visible = false
	character_action_button.visible = false
	interact_button.visible = false
	wait_button.visible = false
	wait_count_button.visible = false
	auto_explore_button.visible = false
	camp_button.visible = false
	character_button.visible = true
	_refresh_interface()
	_set_base_actions_visible(true)
	_configure_base_focus()
	start_button.call_deferred("grab_focus")
	if save_reason != "none":
		_save_game_at_base(save_reason)
	queue_redraw()


func _on_start_pressed() -> void:
	_open_expedition_choice()


func _load_floor(floor_number: int) -> void:
	_cancel_automatic_actions()
	_cancel_ability_targeting(false)
	_clear_hearing_context()
	if audio_manager != null:
		audio_manager.set_background("dungeon")
	_audio_action("world_transition")
	state.current_floor = floor_number
	var cradle_chance := state.get_cradle_chance()
	if floor_number == BossFloor90.FLOOR_NUMBER:
		floor_data = BossFloor90.create()
	else:
		floor_data = generator.generate(floor_number, rng.randi(), cradle_chance)
	var cradle_appeared: bool = floor_data["cradle"] != Vector2i(-1, -1)
	if not cradle_appeared:
		state.record_cradle_result(false)
		floor_data["cradle_pity_resolved"] = true
	player_pos = floor_data["start"]
	magic_traces.clear()
	projectile_traces.clear()
	_clear_hit_effects()
	inspected_target.clear()
	var checkpoint_activated := state.activate_checkpoint(floor_number)
	if checkpoint_activated:
		_log_action(Loc.text("MSG_CHECKPOINT", [floor_number]))
	else:
		_log_action(Loc.text("MSG_ENTER_FLOOR", [floor_number]))
	_update_player_visibility()
	_refresh_interface()
	queue_redraw()


func _use_cradle() -> void:
	if bool(floor_data.get("cradle_used", false)):
		_log_action(Loc.text("MSG_CRADLE_USED"))
		_refresh_interface()
		return
	var result := state.evolve_at_cradle()
	if result["ok"]:
		_audio_action("evolution")
		floor_data["cradle_used"] = true
		_log_action(Loc.text("MSG_CRADLE_EVOLVED", [
			Loc.text(String(state.get_form()["name"])),
			int(result["cost"]),
		]))
	else:
		match String(result["reason"]):
			"maximum":
				_log_action(Loc.text("MSG_CRADLE_MAX"))
			"soul_level":
				_log_action(Loc.text("MSG_CRADLE_NEEDS_SOUL_LEVEL", [
					int(result["required_soul_level"]), int(result["soul_level"]),
				]))
			_:
				_log_action(Loc.text("MSG_CRADLE_NEEDS_SOULS", [int(result["cost"])]))
	_refresh_interface()
	queue_redraw()


func _on_attack_pressed() -> void:
	if screen != Screen.DUNGEON:
		return
	_activate_ability_slot("attack")


func _on_ability_slot_pressed(slot_id: String) -> void:
	_activate_ability_slot(slot_id)


func _on_camp_pressed() -> void:
	if screen != Screen.DUNGEON:
		return
	_cancel_automatic_actions_for_manual_command()
	_stop_held_movement()
	var result := state.camp_and_eat()
	if result["ok"]:
		_log_action(Loc.text("MSG_CAMP_EAT", [result["hunger"]]))
	else:
		match String(result["reason"]):
			"no_hunger":
				_log_action(Loc.text("MSG_CAMP_SKELETON"))
			"full":
				_log_action(Loc.text("MSG_CAMP_FULL"))
			_:
				_log_action(Loc.text("MSG_CAMP_NO_FOOD"))
	_refresh_interface()
	queue_redraw()


func _on_interact_pressed() -> void:
	if screen != Screen.DUNGEON:
		return
	_cancel_automatic_actions_for_manual_command()
	if player_pos == floor_data["base_gate"]:
		_finalize_current_floor_cradle()
		var delivered := state.safe_return()
		_audio_action("world_transition")
		_show_base(Loc.text("MSG_SAFE_RETURN", [delivered]), "safe_return")
		return
	if player_pos == floor_data.get("cradle", Vector2i(-1, -1)):
		_open_cradle_confirmation()
		return
	if _can_advance_floor():
		_on_ascend_pressed()
		return
	if player_pos == floor_data["exit"]:
		_log_action(Loc.text("MSG_EXIT_BLOCKED"))
		_refresh_interface()
		return
	_log_action(Loc.text("MSG_NOTHING_TO_USE"))
	_refresh_interface()


func _can_advance_floor() -> bool:
	return (
		not floor_data.is_empty()
		and bool(floor_data.get("exit_known", false))
	)


func _on_primary_action_pressed() -> void:
	if _should_offer_ascend_button():
		_on_ascend_pressed()
	else:
		_on_interact_pressed()


func _should_offer_ascend_button() -> bool:
	return (
		_can_advance_floor()
		and player_pos != floor_data.get("base_gate", Vector2i(-1, -1))
		and player_pos != floor_data.get("cradle", Vector2i(-1, -1))
	)


func _on_ascend_pressed() -> void:
	if screen != Screen.DUNGEON:
		return
	if auto_travel_active:
		var was_auto_explore := auto_explore_active
		_cancel_automatic_actions_for_manual_command()
		_log_action(Loc.text(
			"MSG_EXPLORE_CANCELLED" if was_auto_explore else "MSG_ASCEND_INTERRUPTED"
		))
		_refresh_interface()
		queue_redraw()
		return
	if not _can_advance_floor():
		_log_action(Loc.text("MSG_ASCEND_LOCKED"))
		_refresh_interface()
		return
	_stop_held_movement()
	var exit_position: Vector2i = floor_data["exit"]
	if player_pos == exit_position:
		if state.current_floor - 1 == BossFloor90.FLOOR_NUMBER:
			_open_boss_warning()
		else:
			_complete_floor_ascent()
		return
	var path := _find_floor_path(player_pos, exit_position, true)
	if path.is_empty():
		_log_action(Loc.text("MSG_ASCEND_NO_PATH"))
		_refresh_interface()
		return
	var action_generation := _begin_automatic_action(false)
	_log_action(Loc.text("MSG_ASCEND_STARTED", [path.size() - 1]))
	for path_index in range(1, path.size()):
		if path_index > 1:
			var delay_completed: bool = await _wait_for_next_automatic_step(
				action_generation, false
			)
			if not delay_completed:
				return
		if not _automatic_action_is_current(action_generation, false):
			return
		var expected_position: Vector2i = path[path_index]
		var direction := expected_position - player_pos
		_attempt_player_action(direction)
		if action_generation != automatic_action_generation:
			return
		if screen != Screen.DUNGEON:
			_cancel_automatic_actions()
			return
		if not _automatic_action_is_current(action_generation, false):
			return
		if player_pos != expected_position:
			_cancel_automatic_actions()
			_log_action(Loc.text("MSG_ASCEND_INTERRUPTED"))
			_refresh_interface()
			return
	if player_pos == exit_position:
		_cancel_automatic_actions()
		_log_action(Loc.text("MSG_ASCEND_ARRIVED"))
		_refresh_interface()
		queue_redraw()


func _complete_floor_ascent() -> void:
	_finalize_current_floor_cradle()
	if state.current_floor <= 1:
		_show_victory()
	else:
		_load_floor(state.current_floor - 1)


func _find_floor_path(start: Vector2i, goal: Vector2i, known_only := false) -> Array[Vector2i]:
	var blocked_cells: Dictionary = {}
	for enemy in floor_data["enemies"]:
		blocked_cells[enemy["pos"]] = true
	return GridNavigation.find_path(
		floor_data["tiles"],
		start,
		goal,
		floor_data.get("explored_cells", {}),
		known_only,
		blocked_cells,
		true,
	)


func _on_upgrade_pressed() -> void:
	if screen != Screen.BASE:
		return
	_on_build_camp_upgrade("campfire")


func _on_build_camp_upgrade(upgrade_id: String) -> void:
	if screen != Screen.BASE:
		return
	var result := state.build_camp_upgrade(upgrade_id)
	if bool(result.get("ok", false)):
		_audio_action("station_success")
		_log_action(
			Loc.text("MSG_CAMPFIRE_SOUL_LEVEL", [state.get_effective_soul_level()])
			if upgrade_id == "campfire"
			else Loc.text("MSG_CAMP_UPGRADE_BUILT", [
				Loc.text(String(GameRules.CAMP_UPGRADES[upgrade_id]["name"])),
			])
		)
		_save_game_at_base()
	else:
		_log_action(Loc.text(
			"MSG_CAMP_UPGRADE_EXISTS"
			if result.get("reason", "") == "built"
			else "MSG_CAMP_UPGRADE_NEEDS"
		))
	_refresh_interface()
	queue_redraw()


func _open_inventory_service(upgrade_id: String) -> void:
	if (
		screen != Screen.BASE
		or inventory_service_mode != ""
		or not bool(state.camp_upgrades.get(upgrade_id, false))
	):
		return
	inventory_service_mode = upgrade_id
	inventory_feedback = ""
	dismantle_all_confirmation_pending = false
	inventory_panel.set_mode(
		InventoryPanel.Mode.CRUSHER if upgrade_id == "crusher"
		else InventoryPanel.Mode.WHETSTONE if upgrade_id == "whetstone"
		else InventoryPanel.Mode.RITUAL
	)
	inventory_panel.set_filter("weapon" if upgrade_id == "whetstone" else "all")
	inventory_panel.clear_navigation_state()
	inventory_panel.bind_state(state, true)
	inventory_panel.position = Vector2(85, 405)
	inventory_panel.visible = true
	_set_base_actions_visible(false)
	camp_upgrades_label.visible = false
	hint_label.visible = false
	message_label.visible = false
	menu_button.visible = false
	inventory_panel.call_deferred("grab_initial_focus")
	queue_redraw()


func _close_inventory_service() -> void:
	if inventory_service_mode.is_empty():
		return
	inventory_service_mode = ""
	inventory_panel.visible = false
	inventory_panel.clear_navigation_state()
	inventory_feedback = ""
	dismantle_all_confirmation_pending = false
	_set_base_actions_visible(true)
	camp_upgrades_label.visible = true
	hint_label.visible = true
	message_label.visible = true
	menu_button.visible = true
	_refresh_interface()
	_configure_base_focus()
	call_deferred("_restore_base_focus_after_service_close")
	queue_redraw()


func _restore_base_focus_after_service_close() -> void:
	if (
		screen == Screen.BASE
		and inventory_service_mode.is_empty()
		and not main_menu_open
		and not settings_open
	):
		start_button.grab_focus()


func _on_inventory_panel_close_requested() -> void:
	if not inventory_service_mode.is_empty():
		_close_inventory_service()
	elif screen == Screen.CHARACTER:
		_close_character()


func _set_base_actions_visible(value: bool) -> void:
	start_button.visible = value
	upgrade_button.visible = value
	build_crusher_button.visible = value
	build_whetstone_button.visible = value
	build_ritual_table_button.visible = value
	character_button.visible = value
	crusher_object_button.visible = (
		value and bool(state.camp_upgrades.get("crusher", false))
	)
	whetstone_object_button.visible = (
		value and bool(state.camp_upgrades.get("whetstone", false))
	)
	ritual_table_object_button.visible = (
		value and bool(state.camp_upgrades.get("ritual_table", false))
	)


func _configure_base_focus() -> void:
	var focusable: Array[Button] = [start_button]
	for button in [
		build_crusher_button, build_whetstone_button, build_ritual_table_button,
		upgrade_button, character_button,
	]:
		Ui.enable_keyboard_focus(button)
		if button.visible and not button.disabled:
			focusable.append(button)
	for object_button in [crusher_object_button, whetstone_object_button, ritual_table_object_button]:
		if object_button.visible:
			focusable.append(object_button)
	if focusable.is_empty():
		return
	Ui.enable_keyboard_focus(start_button)
	for index in range(focusable.size()):
		var button := focusable[index]
		var previous := focusable[(index - 1 + focusable.size()) % focusable.size()]
		var next := focusable[(index + 1) % focusable.size()]
		button.focus_neighbor_top = previous.get_path()
		button.focus_neighbor_left = previous.get_path()
		button.focus_neighbor_bottom = next.get_path()
		button.focus_neighbor_right = next.get_path()


func _on_wait_pressed() -> void:
	if screen != Screen.DUNGEON:
		return
	_cancel_automatic_actions_for_manual_command()
	_stop_held_movement()
	var completed_turns := 0
	var interrupted := false
	var interrupted_by_hp_loss := false
	var interrupted_by_ranged := false
	var interrupted_by_hearing := false
	var hearing_revision_at_start := hearing_contacts.event_revision
	var combat_single_turn := wait_turn_count == 100 and _has_visible_enemy()
	var turns_to_wait := 1 if combat_single_turn else wait_turn_count
	for _turn_index in range(turns_to_wait):
		if turns_to_wait > 1 and _has_visible_enemy():
			interrupted = true
			break
		_log_action(Loc.text("MSG_WAIT"))
		var health_before_turn := state.get_effective_health()
		incoming_ranged_attack_this_turn = false
		_complete_player_turn()
		completed_turns += 1
		if screen != Screen.DUNGEON:
			return
		if turns_to_wait > 1 and state.get_effective_health() < health_before_turn:
			interrupted = true
			interrupted_by_hp_loss = true
			break
		if turns_to_wait > 1 and incoming_ranged_attack_this_turn:
			interrupted = true
			interrupted_by_ranged = true
			break
		if (
			turns_to_wait > 1
			and state.has_hearing()
			and hearing_contacts.event_revision != hearing_revision_at_start
		):
			interrupted = true
			interrupted_by_hearing = true
			break
	if interrupted_by_hp_loss:
		_log_action(Loc.text("MSG_WAIT_INTERRUPTED_HP", [completed_turns]))
	elif interrupted_by_ranged:
		_log_action(Loc.text("MSG_WAIT_INTERRUPTED_RANGED", [completed_turns]))
	elif interrupted_by_hearing:
		_log_action(Loc.text("MSG_WAIT_INTERRUPTED_HEARING", [completed_turns]))
	elif interrupted:
		_log_action(Loc.text("MSG_WAIT_INTERRUPTED", [completed_turns]))
	else:
		_log_action(Loc.text("MSG_WAIT_COMPLETED", [completed_turns]))
	if screen == Screen.DUNGEON:
		_refresh_interface()
		queue_redraw()


func _cycle_wait_turn_count() -> void:
	var current_index := WAIT_TURN_OPTIONS.find(wait_turn_count)
	wait_turn_count = WAIT_TURN_OPTIONS[(current_index + 1) % WAIT_TURN_OPTIONS.size()]
	_refresh_interface()
	queue_redraw()


func _wait_button_text() -> String:
	if wait_turn_count == 1:
		return Loc.text("BTN_WAIT_ONE")
	return Loc.text("BTN_WAIT_MANY", [wait_turn_count])


func _has_visible_enemy() -> bool:
	for enemy in floor_data.get("enemies", []):
		if _is_cell_visible(enemy["pos"]):
			return true
	return false


func _on_auto_explore_pressed() -> void:
	if screen != Screen.DUNGEON:
		return
	if auto_travel_active:
		if auto_explore_active:
			_finish_auto_explore("MSG_EXPLORE_CANCELLED")
		else:
			_cancel_automatic_actions_for_manual_command()
			_log_action(Loc.text("MSG_ASCEND_INTERRUPTED"))
			_refresh_interface()
			queue_redraw()
		return
	_stop_held_movement()
	if _has_visible_enemy():
		_log_action(Loc.text("MSG_EXPLORE_ENEMY"))
		_refresh_interface()
		return
	var action_generation := _begin_automatic_action(true)
	_refresh_interface()
	queue_redraw()
	_run_auto_explore(action_generation)


func _run_auto_explore(action_generation := -1) -> void:
	if action_generation < 0:
		action_generation = _begin_automatic_action(true)
	var step_limit := maxi(1, floor_data.get("tiles", {}).size() * 2)
	var completed_steps := 0
	while _automatic_action_is_current(action_generation, true) and completed_steps < step_limit:
		if _has_visible_enemy():
			_finish_auto_explore("MSG_EXPLORE_ENEMY", action_generation)
			return
		var path := _find_nearest_exploration_path()
		if path.size() < 2:
			_finish_auto_explore("MSG_EXPLORE_COMPLETE", action_generation)
			return
		if completed_steps > 0:
			var delay_completed: bool = await _wait_for_next_automatic_step(
				action_generation, true
			)
			if not delay_completed:
				return
			if _has_visible_enemy():
				_finish_auto_explore("MSG_EXPLORE_ENEMY", action_generation)
				return
		var expected_position: Vector2i = path[1]
		_attempt_player_action(expected_position - player_pos)
		if action_generation != automatic_action_generation:
			return
		if screen != Screen.DUNGEON:
			_cancel_automatic_actions()
			return
		if not _automatic_action_is_current(action_generation, true):
			return
		if player_pos != expected_position:
			_finish_auto_explore("MSG_EXPLORE_INTERRUPTED", action_generation)
			return
		completed_steps += 1
		if _has_visible_enemy():
			_finish_auto_explore("MSG_EXPLORE_ENEMY", action_generation)
			return
	if _automatic_action_is_current(action_generation, true):
		_finish_auto_explore("MSG_EXPLORE_INTERRUPTED", action_generation)


func _find_nearest_exploration_path() -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []
	var best_goal := Vector2i(-1, -1)
	var tiles: Dictionary = floor_data.get("tiles", {})
	var explored: Dictionary = floor_data.get("explored_cells", {})
	for cell_variant in tiles:
		var cell: Vector2i = cell_variant
		if (
			cell == player_pos
			or tiles.get(cell, "void") not in ["floor", "door_closed"]
			or not bool(explored.get(cell, false))
			or (tiles.get(cell) != "door_closed" and not _can_reveal_unexplored_geometry(cell))
		):
			continue
		var path := GridNavigation.find_path(
			tiles,
			player_pos,
			cell,
			explored,
			true,
			{},
			true,
		)
		if path.is_empty():
			continue
		if (
			best_path.is_empty()
			or path.size() < best_path.size()
			or (
				path.size() == best_path.size()
				and (cell.y < best_goal.y or (cell.y == best_goal.y and cell.x < best_goal.x))
			)
		):
			best_path = path
			best_goal = cell
	return best_path


func _can_reveal_unexplored_geometry(origin: Vector2i) -> bool:
	var explored: Dictionary = floor_data.get("explored_cells", {})
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			var candidate := origin + Vector2i(x_offset, y_offset)
			if (
				floor_data["tiles"].get(candidate, "void") != "void"
				and not bool(explored.get(candidate, false))
			):
				return true
	return false


func _finish_auto_explore(message_key: String, action_generation := -1) -> void:
	if (
		not auto_explore_active
		or (action_generation >= 0 and action_generation != automatic_action_generation)
	):
		return
	_clear_auto_explore_state()
	if screen == Screen.DUNGEON:
		_log_action(Loc.text(message_key))
		_refresh_interface()
		queue_redraw()


func _clear_auto_explore_state() -> void:
	_cancel_automatic_actions()


func _begin_automatic_action(explore_mode: bool) -> int:
	automatic_action_generation += 1
	auto_explore_active = explore_mode
	auto_travel_active = true
	return automatic_action_generation


func _cancel_automatic_actions() -> void:
	automatic_action_generation += 1
	auto_explore_active = false
	auto_travel_active = false


func _cancel_automatic_actions_for_manual_command() -> bool:
	if not auto_travel_active:
		return false
	_cancel_automatic_actions()
	return true


func _automatic_action_is_current(action_generation: int, explore_mode: bool) -> bool:
	return (
		action_generation == automatic_action_generation
		and auto_travel_active
		and (not explore_mode or auto_explore_active)
		and screen == Screen.DUNGEON
		and not main_menu_open
		and not settings_open
	)


func _automatic_step_delay_seconds() -> float:
	if auto_step_delay_override >= 0.0:
		return auto_step_delay_override
	return AUTO_STEP_DELAY / PresentationSettings.auto_movement_speed_multiplier(
		auto_movement_speed_percent
	)


func _wait_for_next_automatic_step(action_generation: int, explore_mode: bool) -> bool:
	var delay_seconds := _automatic_step_delay_seconds()
	if delay_seconds <= 0.0:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(delay_seconds).timeout
	return _automatic_action_is_current(action_generation, explore_mode)


func _show_character() -> void:
	if screen != Screen.BASE and screen != Screen.DUNGEON:
		return
	_cancel_automatic_actions_for_manual_command()
	previous_screen = screen
	character_return_focus = get_viewport().gui_get_focus_owner()
	_stop_held_movement()
	screen = Screen.CHARACTER
	_apply_dungeon_layout(false)
	_hide_game_interface()
	_set_controls_visible(creation_controls, false)
	_set_controls_visible(character_controls, true)
	title_label.visible = true
	souls_label.visible = true
	_apply_character_header()
	_refresh_character_sheet()
	if character_panel_mode == "inventory":
		inventory_panel.call_deferred("grab_initial_focus")
	else:
		skills_mode_button.call_deferred("grab_focus")
	call_deferred("_configure_character_focus")
	queue_redraw()


func _close_character() -> void:
	if screen != Screen.CHARACTER:
		return
	screen = previous_screen
	_apply_dungeon_layout(screen == Screen.DUNGEON)
	_set_controls_visible(character_controls, false)
	menu_button.focus_mode = Control.FOCUS_NONE
	title_label.visible = true
	stats_label.visible = true
	souls_label.visible = true
	sidebar_progress_label.visible = true
	equipment_label.visible = false
	soul_icon.visible = screen == Screen.DUNGEON
	camp_upgrades_label.visible = screen == Screen.BASE
	material_resources_strip.visible = screen == Screen.BASE
	hint_label.visible = screen == Screen.BASE or screen == Screen.DUNGEON
	message_label.visible = true
	character_button.visible = screen == Screen.BASE
	inspection_label.visible = screen == Screen.DUNGEON
	if screen == Screen.BASE:
		_set_base_actions_visible(true)
		_configure_base_focus()
		call_deferred("_restore_focus_after_character_close")
	else:
		attack_button.visible = true
		spell_button.visible = true
		active_2_button.visible = true
		active_3_button.visible = true
		character_action_button.visible = true
		interact_button.visible = true
		wait_button.visible = true
		wait_count_button.visible = true
		auto_explore_button.visible = true
		camp_button.visible = true
		get_viewport().gui_release_focus()
	_refresh_interface()
	queue_redraw()


func _refresh_character_sheet() -> void:
	var showing_inventory := screen == Screen.CHARACTER and character_panel_mode == "inventory"
	_set_controls_visible(character_common_controls, screen == Screen.CHARACTER)
	_set_controls_visible(character_inventory_controls, showing_inventory)
	if screen == Screen.CHARACTER:
		_apply_character_header()
	var derived := state.get_derived_stats()
	character_primary_label.text = Loc.text("PRIMARY_ATTRIBUTES")
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		var attribute_name := Loc.text(String(GameRules.ATTRIBUTE_NAMES[attribute_id]))
		var row_label: Label = character_attribute_row_labels[attribute_id]
		row_label.text = "%s: %d" % [attribute_name, state.attributes[attribute_id]]
		_fit_single_line_label(row_label, 11, 9)
		var spend_button: Button = character_attribute_spend_buttons[attribute_id]
		spend_button.tooltip_text = "%s +1" % attribute_name
		spend_button.accessibility_name = spend_button.tooltip_text
	var derived_lines := PackedStringArray([
		Loc.text("PARAMETERS"),
		Loc.text("PARAM_DAMAGE") + ": %d" % derived["damage"],
		Loc.text("PARAM_ACCURACY") + ": %d" % derived["accuracy"],
		Loc.text("PARAM_HP") + ": %d/%d" % [state.hp, derived["max_hp"]],
		Loc.text("PARAM_DODGE") + ": %d" % derived["dodge"],
		Loc.text("PARAM_MANA") + ": %d/%d" % [state.mana, derived["mana"]],
		Loc.text("PARAM_MANA_REGENERATION") + ": %d%%" % state.get_mana_regeneration_percent(),
		Loc.text("PARAM_SPELL_POWER") + ": %d" % derived["spell_power"],
		Loc.text("PARAM_REGENERATION") + ": %d" % derived["regeneration"],
		Loc.text("PARAM_RANGED_DAMAGE") + ": %d" % derived["ranged_damage"],
		Loc.text("PARAM_RANGED_RANGE") + ": %d" % state.get_ranged_range(),
		Loc.text("PARAM_VISION") + ": %d" % state.get_vision_radius(),
	])
	if state.uses_hunger():
		derived_lines.append(Loc.text("CHARACTER_SURVIVAL", [state.hunger, state.food]))
	character_derived_label.text = "\n".join(derived_lines)
	character_equipment_label.text = Loc.text("EQUIPMENT")
	character_soul_level_label.text = Loc.text("SOUL_LEVEL_APPEARANCE_LABEL", [
		state.get_effective_soul_level(),
		Loc.text(String(GameRules.FORMS[state.current_form_id]["name"])),
		Loc.text(String(GameRules.FORMS[state.get_display_form_id()]["name"])),
	])
	for slot in GameRules.EQUIPMENT_SLOT_ORDER:
		var slot_button: Button = character_equipment_buttons[slot]
		var unlocked := GameRules.is_slot_unlocked(state.current_form_id, slot)
		var item_key := String(state.loadout.get(slot, ""))
		var slot_glyph: InventorySlotIcon = character_equipment_glyphs[slot]
		var slot_name := Loc.text(String(GameRules.EQUIPMENT_SLOTS[slot]["name"]))
		slot_button.icon = null
		slot_button.text = ""
		slot_button.modulate = Color.WHITE
		var permanent := not item_key.is_empty() and GameRules.is_item_permanent(item_key)
		slot_glyph.set_slot(slot, not unlocked, permanent)
		slot_glyph.visible = item_key.is_empty() or permanent
		var accessible_value := Loc.text("INVENTORY_EMPTY")
		if not item_key.is_empty():
			var item_rules := GameRules.item_rules(item_key)
			var icon_path := String(item_rules.get("icon", ""))
			if not icon_path.is_empty():
				slot_button.icon = load(icon_path) as Texture2D
			accessible_value = _item_display_name(item_key)
			if permanent:
				accessible_value += " · " + Loc.text("INVENTORY_PERMANENT_LOCKED")
		elif not unlocked:
			accessible_value = Loc.text("INVENTORY_SLOT_LOCKED")
		slot_button.tooltip_text = "%s · %s" % [slot_name, accessible_value]
		slot_button.accessibility_name = slot_button.tooltip_text
		# Locked and empty mannequin slots remain inspectable so the inventory can
		# explain their state and switch to the corresponding category.
		slot_button.disabled = false
	_refresh_souls_label()
	character_attribute_points_label.text = Loc.text(
		"SKILL_FREE_STATS", [state.unspent_attribute_points]
	)
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		character_attribute_spend_buttons[attribute_id].visible = (
			screen == Screen.CHARACTER
		and character_panel_mode == "inventory"
			and state.unspent_attribute_points > 0
		)
	character_status_strip.refresh(state.active_statuses)
	_refresh_skills_interface()
	_refresh_inventory_interface()
	_configure_character_focus()


func _apply_character_header() -> void:
	var form_name := Loc.text(String(GameRules.FORMS[state.current_form_id]["name"]))
	var full_title := "%s · %s" % [state.character_name, form_name]
	title_label.position = CharacterSheetLayout.NAME_FORM_RECT.position
	title_label.size = CharacterSheetLayout.NAME_FORM_RECT.size
	title_label.text = full_title
	title_label.clip_text = true
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fit_single_line_label(title_label, 26, 18)
	var title_font := title_label.get_theme_font("font")
	var title_size := title_label.get_theme_font_size("font_size")
	if title_font.get_string_size(full_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > title_label.size.x:
		var abbreviated := full_title
		while abbreviated.length() > 1 and title_font.get_string_size(
			abbreviated + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size,
		).x > title_label.size.x:
			abbreviated = abbreviated.substr(0, abbreviated.length() - 1)
		title_label.text = abbreviated.strip_edges() + "…"
	title_label.tooltip_text = full_title
	title_label.accessibility_name = full_title
	souls_label.position = CharacterSheetLayout.SOULS_RECT.position
	souls_label.size = CharacterSheetLayout.SOULS_RECT.size
	souls_label.clip_text = true
	souls_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	souls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	souls_label.add_theme_font_size_override("font_size", 15)
	menu_button.position = CharacterSheetLayout.MENU_RECT.position
	menu_button.size = CharacterSheetLayout.MENU_RECT.size
	menu_button.add_theme_font_size_override("font_size", 16)


func _equipment_category_glyph(category: String) -> String:
	match category:
		"weapon": return "⚔"
		"offhand": return "◧"
		"feet": return "⌁"
		"body": return "◇"
		"legs": return "⋮"
		"hands": return "✦"
		"head": return "⌂"
		"talisman": return "◆"
		"ring": return "○"
		"back": return "▥"
	return "·"


func _select_character_panel(mode: String) -> void:
	_reset_dismantle_all_confirmation()
	character_panel_mode = mode
	inventory_feedback = ""
	if mode == "inventory":
		inventory_panel.set_mode(InventoryPanel.Mode.CHARACTER)
		inventory_panel.clear_navigation_state()
	_refresh_character_sheet()
	if mode == "inventory":
		inventory_mode_button.call_deferred("grab_focus")
	else:
		skills_mode_button.call_deferred("grab_focus")
	queue_redraw()


func _on_equipment_slot_pressed(slot: String) -> void:
	_reset_dismantle_all_confirmation()
	character_panel_mode = "inventory"
	inventory_feedback = ""
	inventory_panel.set_mode(InventoryPanel.Mode.CHARACTER)
	inventory_panel.bind_state(state, previous_screen == Screen.BASE)
	inventory_panel.select_equipment_slot(slot, GameRules.is_slot_unlocked(state.current_form_id, slot))
	_sync_inventory_panel_state()
	_refresh_character_sheet()
	inventory_panel.call_deferred("grab_initial_focus")
	queue_redraw()


func _on_inventory_stack_pressed(visible_index: int) -> void:
	inventory_panel.select_visible_index(visible_index)
	_sync_inventory_panel_state()


func _change_inventory_page(direction: int) -> void:
	inventory_panel.change_page(direction)
	_sync_inventory_panel_state()


func _on_inventory_equip_pressed() -> void:
	_reset_dismantle_all_confirmation()
	_sync_inventory_panel_state()
	if not selected_equipment_slot.is_empty():
		var result := state.unequip(selected_equipment_slot)
		if bool(result.get("ok", false)):
			inventory_feedback = Loc.text("MSG_ITEM_UNEQUIPPED", [
				_item_display_name(String(result["item_key"])),
			])
			selected_inventory_key = String(result["item_key"])
			selected_equipment_slot = ""
			inventory_panel.select_item(selected_inventory_key, "inventory")
	else:
		var destination_slot := ""
		if not inventory_panel.selected_destination_slot().is_empty():
			destination_slot = inventory_panel.selected_destination_slot()
		var result := state.equip_from_inventory(selected_inventory_key, destination_slot)
		if bool(result.get("ok", false)):
			inventory_feedback = Loc.text("MSG_ITEM_EQUIPPED", [result["item_name"]])
			if int(state.inventory.get(selected_inventory_key, 0)) <= 0:
				selected_inventory_key = ""
			inventory_panel.select_item(selected_inventory_key, "inventory")
		else:
			inventory_feedback = Loc.text("MSG_FORM_CANNOT_EQUIP_SELECTED")
	if previous_screen == Screen.BASE:
		_save_game_at_base()
	_refresh_character_sheet()
	queue_redraw()


func _on_inventory_dismantle_pressed() -> void:
	_reset_dismantle_all_confirmation()
	_sync_inventory_panel_state()
	if (
		(screen != Screen.BASE and previous_screen != Screen.BASE)
		or selected_inventory_key.is_empty()
		or inventory_panel.selected_item_source() != "inventory"
	):
		return
	var selected_name := _item_display_name(selected_inventory_key)
	var result := state.dismantle_item(selected_inventory_key)
	if bool(result.get("ok", false)):
		_audio_action("station_success")
		var gained: Dictionary = result["gained"]
		inventory_feedback = Loc.text("MSG_ITEM_DISMANTLED", [
			selected_name, gained["wood"], gained["stone"], gained["cloth"],
		])
		if int(state.inventory.get(selected_inventory_key, 0)) <= 0:
			selected_inventory_key = ""
		inventory_panel.select_item(selected_inventory_key, "inventory")
		_save_game_at_base()
	else:
		inventory_feedback = Loc.text(
			"MSG_BOUND_ITEM_CANNOT_DISMANTLE"
			if result.get("reason", "") == "bound"
			else "MSG_CRUSHER_REQUIRED"
		)
	_refresh_character_sheet()
	queue_redraw()


func _on_inventory_upgrade_pressed() -> void:
	_reset_dismantle_all_confirmation()
	_sync_inventory_panel_state()
	if screen != Screen.BASE and previous_screen != Screen.BASE:
		return
	var selected_key := selected_inventory_key
	if not selected_equipment_slot.is_empty():
		selected_key = String(state.loadout.get(selected_equipment_slot, ""))
	if selected_key.is_empty():
		return
	var result := state.upgrade_weapon(
		selected_key,
		rng.randf(),
		rng.randf(),
		selected_equipment_slot,
	)
	if bool(result.get("ok", false)):
		match String(result["outcome"]):
			"upgraded":
				_audio_action("station_success")
				inventory_feedback = Loc.text("MSG_WEAPON_UPGRADED", [result["new_level"]])
			"downgraded":
				_audio_action("station_fail")
				inventory_feedback = Loc.text("MSG_WEAPON_DOWNGRADED", [result["new_level"]])
			_:
				_audio_action("station_fail")
				inventory_feedback = Loc.text("MSG_WEAPON_UNCHANGED")
		if selected_equipment_slot.is_empty():
			selected_inventory_key = String(result["item_key"])
		inventory_panel.select_item(
			String(result["item_key"]),
			"equipped" if not selected_equipment_slot.is_empty() else "inventory",
			selected_equipment_slot,
		)
		_save_game_at_base()
	else:
		match String(result.get("reason", "")):
			"resources":
				inventory_feedback = Loc.text("MSG_WEAPON_UPGRADE_RESOURCES", [
					GameRules.WEAPON_UPGRADE_COST["stone"],
					GameRules.WEAPON_UPGRADE_COST["wood"],
					GameRules.WEAPON_UPGRADE_COST["cloth"],
				])
			_:
				inventory_feedback = Loc.text("MSG_WHETSTONE_REQUIRED")
	_refresh_character_sheet()
	queue_redraw()


func _on_inventory_bind_pressed() -> void:
	_sync_inventory_panel_state()
	if screen != Screen.BASE or inventory_service_mode != "ritual_table":
		return
	var source := inventory_panel.selected_item_source()
	var equipped_slot := inventory_panel.selected_equipped_slot()
	var selected_key := inventory_panel.selected_item_key()
	var result := state.bind_item(selected_key, source, equipped_slot)
	if bool(result.get("ok", false)):
		_audio_action("evolution")
		inventory_feedback = Loc.text("MSG_ITEM_BOUND", [
			_item_display_name(String(result["item_key"])),
			int(result["cost"]),
		])
		selected_inventory_key = String(result["item_key"])
		inventory_panel.select_item(
			selected_inventory_key,
			source,
			equipped_slot,
		)
		_save_game_at_base()
	else:
		match String(result.get("reason", "")):
			"bound": inventory_feedback = Loc.text("MSG_ITEM_ALREADY_BOUND")
			"souls": inventory_feedback = Loc.text("MSG_ITEM_BIND_NEEDS_SOULS", [
				int(result.get("cost", GameRules.ITEM_BINDING_SOUL_COST)),
			])
			_: inventory_feedback = Loc.text("MSG_RITUAL_TABLE_REQUIRED")
	inventory_panel.feedback = inventory_feedback
	inventory_panel.refresh()
	_sync_inventory_panel_state()
	_refresh_interface()
	queue_redraw()


func _on_inventory_dismantle_all_pressed() -> void:
	if screen != Screen.BASE and previous_screen != Screen.BASE:
		return
	if not dismantle_all_confirmation_pending:
		dismantle_all_confirmation_pending = true
		inventory_feedback = Loc.text("INVENTORY_DISMANTLE_ALL_CONFIRM")
		inventory_panel.set_confirmation_pending(true)
		_refresh_inventory_interface()
		return
	var result := state.dismantle_all_items()
	dismantle_all_confirmation_pending = false
	inventory_panel.set_confirmation_pending(false)
	if bool(result.get("ok", false)):
		_audio_action("station_success")
		var gained: Dictionary = result["gained"]
		inventory_feedback = Loc.text("MSG_ITEMS_DISMANTLED_ALL", [
			result["count"], gained["wood"], gained["stone"], gained["cloth"],
		])
		selected_inventory_key = ""
		selected_equipment_slot = ""
		inventory_page = 0
		_save_game_at_base()
	else:
		inventory_feedback = Loc.text("MSG_CRUSHER_REQUIRED")
	_refresh_character_sheet()
	queue_redraw()


func _reset_dismantle_all_confirmation() -> void:
	dismantle_all_confirmation_pending = false
	if inventory_panel != null:
		inventory_panel.cancel_confirmation()


func _refresh_inventory_interface() -> void:
	if inventory_panel == null:
		return
	var showing_inventory := (
		(screen == Screen.CHARACTER and character_panel_mode == "inventory")
		or (screen == Screen.BASE and not inventory_service_mode.is_empty())
	)
	inventory_panel.visible = showing_inventory
	skills_mode_button.button_pressed = character_panel_mode == "skills"
	inventory_mode_button.button_pressed = character_panel_mode == "inventory"
	if not showing_inventory:
		return
	if inventory_service_mode.is_empty():
		inventory_panel.set_mode(InventoryPanel.Mode.CHARACTER)
		inventory_panel.position = CharacterSheetLayout.INVENTORY_PANEL_RECT.position
		inventory_panel.size = CharacterSheetLayout.INVENTORY_PANEL_RECT.size
	inventory_panel.bind_state(state, screen == Screen.BASE or previous_screen == Screen.BASE)
	# Preserve the small public compatibility surface used by existing scene
	# tests and preview scripts while the component owns selection at runtime.
	if inventory_panel.selected_item_key().is_empty():
		if not selected_equipment_slot.is_empty():
			inventory_panel.select_item(
				String(state.loadout.get(selected_equipment_slot, "")),
				"equipped",
				selected_equipment_slot,
			)
		elif not selected_inventory_key.is_empty():
			inventory_panel.select_item(selected_inventory_key, "inventory")
	inventory_panel.feedback = inventory_feedback
	inventory_panel.dismantle_all_confirmation_pending = dismantle_all_confirmation_pending
	inventory_panel.refresh()
	_sync_inventory_panel_state()


func _sync_inventory_panel_state() -> void:
	if inventory_panel == null:
		return
	selected_inventory_key = inventory_panel.selected_item_key()
	selected_equipment_slot = inventory_panel.selected_equipped_slot()
	inventory_page = inventory_panel.page
	dismantle_all_confirmation_pending = inventory_panel.dismantle_all_confirmation_pending


func _item_display_name(item_key: String) -> String:
	var rules := GameRules.item_rules(item_key)
	if rules.is_empty():
		return Loc.text("MSG_UNKNOWN_ITEM")
	var name := Loc.text(String(rules["name"]))
	var level := GameRules.item_upgrade_level(item_key)
	return "%s +%d" % [name, level] if level > 0 else name


func _select_skill_stage(stage_id: String) -> void:
	if not state.is_stage_unlocked(stage_id):
		skill_feedback = Loc.text("SKILL_STAGE_LOCKED")
		_refresh_skills_interface()
		return
	selected_skill_stage = stage_id
	skill_feedback = ""
	_refresh_skills_interface()
	queue_redraw()


func _refresh_skills_interface() -> void:
	var showing_skills := screen == Screen.CHARACTER and character_panel_mode == "skills"
	_set_controls_visible(skills_panel_controls, showing_skills)
	if skill_tree_panel != null:
		skill_tree_panel.set_context(state, selected_skill_stage, skill_feedback)


func _skill_node_text(skill_id: String) -> String:
	var skill: Dictionary = GameRules.SKILLS[skill_id]
	var level := state.get_skill_level(skill_id)
	var lines := PackedStringArray([
		Loc.text(String(skill["name"])),
		Loc.text("SKILL_KIND_ACTIVE" if skill.get("kind", "passive") == "active" else "SKILL_KIND_PASSIVE"),
		Loc.text("SKILL_LEVEL", [level, int(skill["max_level"])]),
		Loc.text(String(skill["description"])),
	])
	if level >= int(skill["max_level"]):
		lines.append(Loc.text("SKILL_MAX"))
	else:
		lines.append(Loc.text("SKILL_COST", [GameRules.skill_cost(skill_id, level)]))
	return "\n".join(lines)


func _refresh_ability_loadout_controls() -> void:
	for slot_id in AbilitySystem.SLOT_ORDER:
		var button: Button = ability_loadout_buttons[slot_id]
		var ability_id := state.get_slotted_ability(slot_id)
		button.text = "%s\n%s" % [
			Loc.text(_ability_slot_name_key(slot_id)),
			_ability_display_name(ability_id),
		]
		button.tooltip_text = Loc.text("ABILITY_ASSIGN_HINT")


func _cycle_ability_loadout(slot_id: String) -> void:
	var options := AbilitySystem.options_for_slot(slot_id, state.skill_levels)
	if options.is_empty():
		return
	var current_index := options.find(state.get_slotted_ability(slot_id))
	var next_index := (maxi(-1, current_index) + 1) % options.size()
	if state.assign_ability(slot_id, options[next_index]):
		skill_feedback = Loc.text("ABILITY_ASSIGNED", [
			Loc.text(_ability_slot_name_key(slot_id)),
			_ability_display_name(String(options[next_index])),
		])
		if previous_screen == Screen.BASE:
			_save_game_at_base()
	_refresh_skills_interface()
	_refresh_interface()
	queue_redraw()


func _ability_slot_name_key(slot_id: String) -> String:
	match slot_id:
		"attack":
			return "ABILITY_SLOT_ATTACK"
		"active_1":
			return "ABILITY_SLOT_ACTIVE_1"
		"active_2":
			return "ABILITY_SLOT_ACTIVE_2"
	return "ABILITY_SLOT_ACTIVE_3"


func _ability_display_name(ability_id: String) -> String:
	if ability_id.is_empty():
		return Loc.text("ABILITY_EMPTY")
	var rules := AbilitySystem.ability(ability_id)
	return Loc.text(String(rules.get("name", ability_id)))


func _skill_prerequisites_met(skill_id: String) -> bool:
	for required_skill in GameRules.SKILLS[skill_id]["requires"]:
		if state.get_skill_level(required_skill) < int(
			GameRules.SKILLS[skill_id]["requires"][required_skill]
		):
			return false
	return true


func _on_skill_pressed(skill_id: String) -> void:
	if skill_tree_panel == null or not skill_tree_panel.node_buttons.has(skill_id):
		return
	skill_feedback = ""
	skill_tree_panel.select_node(skill_id)
	_refresh_skills_interface()
	_configure_character_focus()
	queue_redraw()


func _on_skill_purchase_pressed(skill_id: String) -> void:
	var result := state.purchase_skill(skill_id)
	if result["ok"]:
		skill_feedback = Loc.text("SKILL_PURCHASED", [
			Loc.text(String(GameRules.SKILLS[skill_id]["name"])),
			result["level"],
		])
		if skill_id == "sharp_vision" and previous_screen == Screen.DUNGEON:
			_update_player_visibility()
		if skill_id == "ears" and previous_screen == Screen.DUNGEON:
			_clear_hearing_context()
			_sync_hearing_proximity()
		if previous_screen == Screen.BASE:
			_save_game_at_base()
	else:
		match String(result["reason"]):
			"souls":
				skill_feedback = Loc.text("SKILL_NEEDS_SOULS", [result["cost"]])
			"prerequisite":
				skill_feedback = Loc.text("SKILL_NEEDS_PREVIOUS")
			"stage_locked":
				skill_feedback = Loc.text("SKILL_STAGE_LOCKED")
			_:
				skill_feedback = Loc.text("SKILL_ALREADY_MAX")
	_refresh_character_sheet()
	if (
		skill_tree_panel != null
		and skill_tree_panel.action_button.disabled
		and skill_tree_panel.action_button.has_focus()
		and skill_node_buttons.has(skill_id)
	):
		skill_node_buttons[skill_id].call_deferred("grab_focus")
	queue_redraw()


func _on_spend_attribute_point(attribute_id: String) -> void:
	if state.spend_attribute_point(attribute_id):
		skill_feedback = ""
		if previous_screen == Screen.BASE:
			_save_game_at_base()
	_refresh_character_sheet()
	queue_redraw()


func _on_cheat_add_stats_pressed() -> void:
	state.unspent_attribute_points += 5
	state.soul_level += 1
	# The test grant is exact and intentionally bypasses equipment soul bonuses.
	state.carried_souls += 100
	state.lifetime_souls_earned += 100
	if previous_screen == Screen.BASE:
		_save_game_at_base()
	_refresh_character_sheet()
	queue_redraw()


func _show_victory() -> void:
	_stop_held_movement()
	_cancel_automatic_actions()
	_clear_hearing_context()
	if audio_manager != null:
		audio_manager.stop_background()
	_audio_action("victory")
	screen = Screen.VICTORY
	_apply_dungeon_layout(false)
	_set_controls_visible(creation_controls, false)
	_set_controls_visible(character_controls, false)
	start_button.visible = false
	upgrade_button.visible = false
	build_crusher_button.visible = false
	build_whetstone_button.visible = false
	build_ritual_table_button.visible = false
	crusher_object_button.visible = false
	whetstone_object_button.visible = false
	ritual_table_object_button.visible = false
	camp_upgrades_label.visible = false
	attack_button.visible = false
	spell_button.visible = false
	active_2_button.visible = false
	active_3_button.visible = false
	character_action_button.visible = false
	interact_button.visible = false
	wait_button.visible = false
	wait_count_button.visible = false
	auto_explore_button.visible = false
	camp_button.visible = false
	character_button.visible = false
	inspection_label.visible = false
	souls_label.visible = true
	stats_label.visible = true
	sidebar_progress_label.visible = true
	equipment_label.visible = true
	soul_icon.visible = false
	store_gateway.unlock_achievement("surface_reached")
	_log_action(Loc.text("MSG_VICTORY"))
	_refresh_interface()
	queue_redraw()


func _process(delta: float) -> void:
	if main_menu_open or settings_open:
		return
	_update_magic_traces(delta)
	_update_projectile_traces(delta)
	_update_hit_effects(delta)
	if settings_open or cradle_confirmation_open or boss_warning_open or appearance_choice_panel.visible:
		return
	if not ability_targeting_id.is_empty():
		return
	if auto_travel_active:
		return
	if held_direction == Vector2i.ZERO:
		return
	if screen != Screen.DUNGEON or not _is_direction_pressed(held_direction):
		_stop_held_movement()
		return
	movement_repeat_timer -= delta
	if movement_repeat_timer > 0.0:
		return
	if _attempt_player_action(held_direction):
		movement_repeat_timer = MOVE_REPEAT_INTERVAL
	else:
		_stop_held_movement()


func _input(event: InputEvent) -> void:
	if audio_manager != null and event.is_pressed():
		audio_manager.notify_user_gesture()
	if main_menu_open and save_menu_panel.visible:
		if save_menu_panel.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if settings_open and event is InputEventScreenTouch:
		if event.pressed:
			settings_touch_slider = _settings_slider_at(event.position)
			settings_touch_index = event.index if settings_touch_slider != null else -1
			if settings_touch_slider != null:
				_set_audio_slider_from_pointer(settings_touch_slider, event.position)
				get_viewport().set_input_as_handled()
				return
		elif event.index == settings_touch_index:
			if settings_touch_slider != null:
				_set_audio_slider_from_pointer(settings_touch_slider, event.position)
			settings_touch_slider = null
			settings_touch_index = -1
			get_viewport().set_input_as_handled()
			return
	if (
		settings_open
		and event is InputEventScreenDrag
		and event.index == settings_touch_index
		and settings_touch_slider != null
	):
		_set_audio_slider_from_pointer(settings_touch_slider, event.position)
		get_viewport().set_input_as_handled()
		return
	if settings_open and (
		get_viewport().gui_get_focus_owner() == settings_background_slider
		or get_viewport().gui_get_focus_owner() == settings_actions_slider
	):
		var slider_direction := 0
		if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
			slider_direction = -1
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
			slider_direction = 1
		if slider_direction != 0:
			var focused_slider := get_viewport().gui_get_focus_owner() as HSlider
			focused_slider.value = clampf(
				focused_slider.value + slider_direction * 5.0, 0.0, 100.0,
			)
			get_viewport().set_input_as_handled()
			return
	# Capture remapping before focused buttons consume arbitrary keyboard input.
	# Normal menu navigation stays in the regular GUI/unhandled input flow.
	if (
		controls_remap_open
		and controls_remap_panel != null
		and not controls_remap_panel.capture_action.is_empty()
		and controls_remap_panel.handle_input(event)
	):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if main_menu_open and save_menu_panel.visible:
		if save_menu_panel.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if screen == Screen.STORY:
		if event.is_action_pressed("interact"):
			_advance_story()
			get_viewport().set_input_as_handled()
		return
	if appearance_choice_panel.visible:
		if appearance_choice_panel.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if cradle_confirmation_open:
		if event.is_action_pressed("game_menu"):
			_close_cradle_confirmation()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			_confirm_cradle_evolution()
			get_viewport().set_input_as_handled()
		return
	if boss_warning_open:
		if event.is_action_pressed("game_menu"):
			_close_boss_warning()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			_confirm_boss_ascent()
			get_viewport().set_input_as_handled()
		return
	if expedition_choice_open:
		if event.is_action_pressed("game_menu"):
			_close_expedition_choice()
			get_viewport().set_input_as_handled()
		return
	if controls_remap_open:
		if controls_remap_panel.handle_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("game_menu"):
			_close_controls_remap()
			get_viewport().set_input_as_handled()
		return
	if settings_open:
		if event.is_action_pressed("game_menu") or event.is_action_pressed("ui_cancel"):
			_close_settings()
			get_viewport().set_input_as_handled()
		elif (
			get_viewport().gui_get_focus_owner() == settings_background_slider
			or get_viewport().gui_get_focus_owner() == settings_actions_slider
		) and (
			event.is_action_pressed("ui_left")
			or event.is_action_pressed("ui_right")
			or event.is_action_pressed("move_left")
			or event.is_action_pressed("move_right")
		):
			var focused_slider := get_viewport().gui_get_focus_owner() as HSlider
			var direction := -1 if (
				event.is_action_pressed("ui_left") or event.is_action_pressed("move_left")
			) else 1
			focused_slider.value = clampf(focused_slider.value + direction * 5.0, 0.0, 100.0)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and settings_controls.has(focused):
				focused.pressed.emit()
				get_viewport().set_input_as_handled()
		return
	if not inventory_service_mode.is_empty():
		if inventory_panel.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if screen == Screen.CHARACTER and character_panel_mode == "inventory":
		if inventory_panel.handle_input(event):
			get_viewport().set_input_as_handled()
			return
	if screen == Screen.CHARACTER and (
		event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	):
		var focused_character_control := get_viewport().gui_get_focus_owner()
		if focused_character_control is Button and _is_character_button(focused_character_control):
			focused_character_control.pressed.emit()
			get_viewport().set_input_as_handled()
			return
	if _handle_dungeon_zoom_hotkey(event):
		get_viewport().set_input_as_handled()
		return
	if not ability_targeting_id.is_empty():
		if event.is_action_pressed("game_menu") or event.is_action_pressed("ui_cancel"):
			_cancel_ability_targeting()
			get_viewport().set_input_as_handled()
			return
		var targeting_direction := _dash_direction_from_event(event)
		if targeting_direction != Vector2i.ZERO:
			_select_dash_direction(targeting_direction)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_confirm_dash()
			get_viewport().set_input_as_handled()
		return
	var released_direction := InputProfile.action_direction_released(event)
	if released_direction != Vector2i.ZERO and released_direction == held_direction:
		_stop_held_movement()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.echo:
		return
	if auto_travel_active and (
		event.is_action_pressed("auto_explore")
		or event.is_action_pressed("ascend_floor")
	):
		var was_auto_explore := auto_explore_active
		_cancel_automatic_actions_for_manual_command()
		_log_action(Loc.text(
			"MSG_EXPLORE_CANCELLED" if was_auto_explore else "MSG_ASCEND_INTERRUPTED"
		))
		_refresh_interface()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	var physical_character_cancel: bool = (
		event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_B
	)
	if screen == Screen.CHARACTER and (
		event.is_action_pressed("ui_cancel")
		or event.is_action_pressed("game_menu")
		or physical_character_cancel
	):
		_close_character()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("character_sheet"):
		if screen == Screen.BASE or screen == Screen.DUNGEON:
			_show_character()
			get_viewport().set_input_as_handled()
			return
		if screen == Screen.CHARACTER:
			_close_character()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("game_menu"):
		if [Screen.BASE, Screen.DUNGEON, Screen.CHARACTER].has(screen):
			_open_main_menu()
			get_viewport().set_input_as_handled()
		return
	if screen == Screen.BASE and (
		event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	):
		var focused_base_control := get_viewport().gui_get_focus_owner()
		if focused_base_control is Button and [
			start_button, build_crusher_button, build_whetstone_button,
			build_ritual_table_button, upgrade_button, character_button,
			crusher_object_button, whetstone_object_button, ritual_table_object_button,
		].has(focused_base_control):
			focused_base_control.pressed.emit()
			get_viewport().set_input_as_handled()
		return
	if screen != Screen.DUNGEON:
		return

	if event.is_action_pressed("ascend_floor"):
		_on_ascend_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("attack"):
		_on_attack_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cast_spell"):
		_on_spell_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("wait_turn"):
		_on_wait_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("auto_explore"):
		_on_auto_explore_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("camp"):
		_on_camp_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_stop_held_movement()
		_on_interact_pressed()
		get_viewport().set_input_as_handled()
		return
	var direction := _movement_direction_from_event(event)
	if direction != Vector2i.ZERO:
		_cancel_automatic_actions_for_manual_command()
		held_direction = direction
		movement_repeat_timer = MOVE_REPEAT_INITIAL_DELAY
		if not _attempt_player_action(direction):
			_stop_held_movement()
		get_viewport().set_input_as_handled()
		return


func _is_character_button(control: Control) -> bool:
	if character_controls.has(control) or control == menu_button:
		return true
	return (
		skill_tree_panel != null
		and skill_tree_panel.is_ancestor_of(control)
	)

func _movement_direction_from_event(event: InputEvent) -> Vector2i:
	return InputProfile.action_direction_from_event(event)


func _dash_direction_from_event(event: InputEvent) -> Vector2i:
	var direction := _movement_direction_from_event(event)
	if direction == Vector2i.ZERO:
		return direction
	if direction.x != 0:
		var up_pressed := Input.is_action_pressed("move_up")
		var down_pressed := Input.is_action_pressed("move_down")
		if up_pressed != down_pressed:
			direction.y = -1 if up_pressed else 1
	else:
		var left_pressed := Input.is_action_pressed("move_left")
		var right_pressed := Input.is_action_pressed("move_right")
		if left_pressed != right_pressed:
			direction.x = -1 if left_pressed else 1
	return direction


func _is_direction_pressed(direction: Vector2i) -> bool:
	match direction:
		Vector2i.UP:
			return Input.is_action_pressed("move_up")
		Vector2i.DOWN:
			return Input.is_action_pressed("move_down")
		Vector2i.LEFT:
			return Input.is_action_pressed("move_left")
		Vector2i.RIGHT:
			return Input.is_action_pressed("move_right")
	return false


func _stop_held_movement() -> void:
	held_direction = Vector2i.ZERO
	movement_repeat_timer = 0.0


func _clear_hearing_context() -> void:
	hearing_contacts.clear()
	hidden_attack_heard_this_enemy_phase = false
	if String(inspected_target.get("kind", "")) == "noise":
		inspected_target.clear()


func _interrupt_automatic_actions_for_hearing() -> void:
	if not state.has_hearing():
		return
	_stop_held_movement()
	_cancel_automatic_actions()


func _sync_hearing_proximity() -> bool:
	if not state.has_hearing():
		_clear_hearing_context()
		return false
	var has_dungeon_context := (
		screen == Screen.DUNGEON
		or (screen == Screen.CHARACTER and previous_screen == Screen.DUNGEON)
	)
	if not has_dungeon_context or floor_data.is_empty():
		return false
	var result := hearing_contacts.sync_proximity(
		floor_data.get("enemies", []),
		player_pos,
		state.get_hearing_radius(),
		floor_data.get("visible_cells", {}),
		floor_data,
	)
	if not bool(result.get("has_new", false)):
		return false
	_interrupt_automatic_actions_for_hearing()
	_log_action(Loc.text("MSG_HEARING_MOVEMENT"))
	return true


func _record_hidden_enemy_attack(enemy: Dictionary) -> void:
	if not state.has_hearing():
		_clear_hearing_context()
		return
	var uid := String(enemy.get("uid", ""))
	var origin: Variant = enemy.get("pos")
	if not origin is Vector2i:
		return
	if GridNavigation.is_in_sealed_room(floor_data, origin):
		return
	if hearing_contacts.record_hidden_attack(uid, origin, state.total_turns):
		hidden_attack_heard_this_enemy_phase = true
		_interrupt_automatic_actions_for_hearing()


func _flush_hidden_attack_hearing_log() -> void:
	if not state.has_hearing():
		hidden_attack_heard_this_enemy_phase = false
		return
	if not hidden_attack_heard_this_enemy_phase:
		return
	hidden_attack_heard_this_enemy_phase = false
	_log_action(Loc.text("MSG_HEARING_HIDDEN_ATTACK"))


func _handle_board_tap(tap_position: Vector2) -> void:
	if dungeon_viewport == null:
		return
	var target: Vector2i = dungeon_viewport.screen_to_world_cell(tap_position)
	if target.x < 0:
		return
	_handle_board_cell(target)


func _is_hearing_contact_presented_at(cell: Vector2i) -> bool:
	return state.has_hearing() and HearingContactSystemClass.is_contact_presented(
		hearing_contacts.has_contact_at(cell), floor_data, player_pos, cell,
	)


func _handle_board_cell(target: Vector2i) -> void:
	if (
		main_menu_open
		or settings_open
		or cradle_confirmation_open
		or boss_warning_open
		or appearance_choice_panel.visible
		or screen != Screen.DUNGEON
	):
		return
	if (
		target.x < 0 or target.y < 0
		or target.x >= int(floor_data.get("width", 0))
		or target.y >= int(floor_data.get("height", 0))
	):
		return
	var direction := target - player_pos
	var is_adjacent := absi(direction.x) + absi(direction.y) == 1
	# Automatic movement blocks far inspection so a stray pointer cannot change
	# selection or stop the route. A neighboring board command has manual parity:
	# it invalidates the route first, then moves/attacks exactly once.
	if auto_travel_active and not is_adjacent:
		return
	if is_adjacent:
		_cancel_automatic_actions_for_manual_command()
	_stop_held_movement()
	# A noise marker is anonymous inspection, never an implicit combat target.
	# Adjacent pointer commands retain movement/attack parity; farther contacts
	# remain inspection-only and consume no turn.
	if not is_adjacent and _is_hearing_contact_presented_at(target):
		inspected_target = {"kind": "noise", "pos": target}
		_refresh_inspection_panel()
		queue_redraw()
		return
	if ability_targeting_id == "dash":
		if ability_target_cells.has(target):
			_confirm_dash(target)
		else:
			_log_dash_invalid_reason(String(ability_unavailable_cells.get(target, "invalid")))
			_refresh_interface()
			queue_redraw()
		return
	if is_adjacent:
		if _cell_has_inspection_subject(target):
			_select_inspection_target(target)
		_attempt_player_action(direction)
	else:
		_select_inspection_target(target)
		_refresh_inspection_panel()
		queue_redraw()


func _cell_has_inspection_subject(cell: Vector2i) -> bool:
	if not _is_cell_explored(cell):
		return false
	if _is_cell_visible(cell) and _enemy_index_at(cell) >= 0:
		return true
	if _is_cell_observed(cell):
		for item in floor_data["items"]:
			if item["pos"] == cell:
				return true
		if (
			cell == floor_data["base_gate"]
			or cell == floor_data["exit"]
			or cell == floor_data["start"]
			or cell == floor_data.get("cradle", Vector2i(-1, -1))
		):
			return true
	return (
		floor_data["tiles"].get(cell, "void") != "floor"
		or not GridNavigation.room_at_door(floor_data, cell).is_empty()
	)


func _attempt_player_action(direction: Vector2i) -> bool:
	var target := player_pos + direction
	var opens_door: bool = floor_data["tiles"].get(target, "void") == "door_closed"
	if opens_door:
		floor_data["tiles"][target] = "floor"
	if floor_data["tiles"].get(target, "void") != "floor":
		if (
			target == floor_data.get("boss_door", Vector2i(-1, -1))
			and not bool(floor_data.get("boss_door_open", false))
		):
			_log_action(Loc.text("MSG_BOSS_DOOR_LOCKED"))
		else:
			_log_action(Loc.text("MSG_WALL"))
		_refresh_interface()
		return false

	var enemy_index := _enemy_index_at(target)
	var action_should_stop := false
	var attacked_enemy := false
	var committed_ability_id := ""
	if enemy_index >= 0:
		var target_uid := String(floor_data["enemies"][enemy_index].get("uid", ""))
		var attack_ability_id := _effective_attack_ability()
		if _execute_attack_ability(attack_ability_id, target_uid):
			committed_ability_id = attack_ability_id
		attacked_enemy = true
	else:
		player_pos = target
		_audio_action("step")
		action_should_stop = _pick_up_item_at_player()
		if not action_should_stop:
			_log_action(Loc.text("MSG_DOOR_OPENED") if opens_door else _tile_hint())
	_update_player_visibility()

	if screen == Screen.DUNGEON:
		_complete_player_turn(committed_ability_id)
	_refresh_interface()
	queue_redraw()
	if screen != Screen.DUNGEON:
		return false
	# A held movement key keeps striking the enemy in that direction. Once it
	# dies, the following repeat naturally steps into the vacated cell.
	if attacked_enemy:
		return true
	if (
		player_pos == floor_data["base_gate"]
		or player_pos == floor_data["exit"]
		or player_pos == floor_data.get("cradle", Vector2i(-1, -1))
	):
		return false
	return not action_should_stop


func _complete_player_turn(pending_ability_id := "", pending_duration := -1) -> void:
	if screen != Screen.DUNGEON:
		return
	if not state.has_hearing():
		_clear_hearing_context()
	# Snapshot action modifiers before survival/enemy response. A one-turn Rested
	# status therefore affects this action and its pending cooldown, then expires.
	var resolved_pending_duration := pending_duration
	if not pending_ability_id.is_empty() and resolved_pending_duration < 0:
		resolved_pending_duration = state.effective_cooldown(pending_ability_id)
	var survival := state.advance_survival_turn()
	if survival["hunger_changed"]:
		_append_to_latest_action(Loc.text("MSG_HUNGER_TICK", [survival["hunger"]]))
	if int(survival["healed"]) > 0:
		_append_to_latest_action(Loc.text("MSG_REGENERATED", [survival["healed"]]))
	if int(survival["mana_restored"]) > 0:
		_append_to_latest_action(Loc.text("MSG_MANA_REGENERATED", [survival["mana_restored"]]))
	if int(survival["starvation_damage"]) > 0:
		_cancel_automatic_actions()
		_append_to_latest_action(Loc.text("MSG_STARVATION", [survival["starvation_damage"]]))
	if survival["died"]:
		_handle_death()
		return
	if int(survival["starvation_damage"]) > 0:
		_audio_action("player_hurt")
	_enemy_turn()
	if screen == Screen.DUNGEON:
		state.finish_completed_round(pending_ability_id, resolved_pending_duration)
		# Prune only after the enemy response. A contact refreshed during that
		# response has a new expiry and therefore survives this boundary.
		hearing_contacts.prune_after_round(state.total_turns)


func _activate_ability_slot(slot_id: String, options: Dictionary = {}) -> bool:
	if screen != Screen.DUNGEON:
		return false
	_cancel_automatic_actions_for_manual_command()
	_stop_held_movement()
	_stop_automatic_ability_modes()
	var ability_id := state.get_slotted_ability(slot_id)
	if slot_id == "attack":
		ability_id = _effective_attack_ability()
	if ability_id.is_empty():
		_log_action(Loc.text("MSG_ABILITY_SLOT_EMPTY"))
		_refresh_interface()
		return false
	var cooldown := state.cooldown_remaining(ability_id)
	if cooldown > 0:
		_log_action(Loc.text("MSG_ABILITY_COOLDOWN", [
			Loc.text(String(AbilitySystem.ability(ability_id).get("name", ability_id))), cooldown,
		]))
		_refresh_interface()
		return false
	if not state.can_use_ability(ability_id):
		_log_action(Loc.text("MSG_ABILITY_FORM_LOCKED"))
		_refresh_interface()
		return false
	if ability_id == "dash":
		return _begin_dash_targeting()
	if ability_id == "choose_appearance":
		return _open_appearance_choice()
	var executed := false
	match ability_id:
		"basic_attack", "double_attack", "circular_attack":
			executed = _execute_attack_ability(
				ability_id,
				String(options.get("target_uid", "")),
				options,
			)
		"magic_missile":
			executed = _cast_magic_missile(float(options.get("ricochet_roll", -1.0)))
	if executed:
		_complete_player_turn(ability_id)
	if screen == Screen.DUNGEON:
		_refresh_interface()
		queue_redraw()
	return executed


func _open_appearance_choice() -> bool:
	if screen != Screen.DUNGEON or not state.can_use_ability("choose_appearance"):
		return false
	_stop_held_movement()
	_stop_automatic_ability_modes()
	appearance_choice_panel.open_for(state)
	queue_redraw()
	return true


func _cancel_appearance_choice() -> void:
	if not appearance_choice_panel.visible:
		return
	appearance_choice_panel.close()
	_refresh_interface()
	queue_redraw()


func _confirm_appearance_choice(form_id: String) -> void:
	if not appearance_choice_panel.visible:
		return
	if state.set_display_form_id(form_id):
		_log_action(Loc.text("MSG_APPEARANCE_CHANGED", [
			Loc.text(String(GameRules.FORMS[state.get_display_form_id()]["name"])),
		]))
	appearance_choice_panel.close()
	_refresh_interface()
	queue_redraw()


func _effective_attack_ability() -> String:
	# Physical multi-hit abilities remain assigned, but a ranged weapon safely
	# turns the primary slot into one contextual Basic Shot until it is removed.
	if state.has_ranged_weapon():
		return "basic_attack"
	var assigned := state.get_slotted_ability("attack")
	if assigned.is_empty() or not state.can_use_ability(assigned):
		return "basic_attack"
	if state.cooldown_remaining(assigned) > 0:
		return "basic_attack"
	return assigned


func _execute_attack_ability(
	ability_id: String,
	preferred_uid := "",
	options: Dictionary = {},
) -> bool:
	if state.has_ranged_weapon():
		return _execute_ranged_attack(preferred_uid, options)
	if ability_id == "circular_attack":
		var target_uids: Array[String] = []
		for cell in AbilitySystem.circular_target_cells(player_pos):
			var index := _enemy_index_at(cell)
			if index >= 0:
				target_uids.append(String(floor_data["enemies"][index].get("uid", "")))
		if target_uids.is_empty():
			_log_action(Loc.text("MSG_CIRCULAR_NO_TARGETS"))
			return false
		_audio_action("melee_attack")
		_log_action(Loc.text("MSG_CIRCULAR_ATTACK"))
		var attack_rolls: Array = options.get("attack_rolls", [])
		for target_index in range(target_uids.size()):
			var forced_roll := (
				int(attack_rolls[target_index]) if target_index < attack_rolls.size() else -1
			)
			var strike := _perform_melee_strike(target_uids[target_index], forced_roll)
			if not strike.is_empty():
				_append_to_latest_action(String(strike["message"]))
		return true

	var target_uid := preferred_uid
	if target_uid.is_empty() or not _is_uid_adjacent(target_uid):
		target_uid = _resolve_adjacent_enemy_uid()
	if target_uid.is_empty():
		_log_action(Loc.text("MSG_NO_ADJACENT_ENEMY"))
		return false
	_audio_action("melee_attack")
	var attack_rolls: Array = options.get("attack_rolls", [])
	var first_roll := int(attack_rolls[0]) if not attack_rolls.is_empty() else -1
	var first := _perform_melee_strike(target_uid, first_roll)
	if first.is_empty():
		return false
	_log_action(String(first["message"]))
	if ability_id == "double_attack" and not bool(first.get("killed", false)):
		var second_roll := int(attack_rolls[1]) if attack_rolls.size() > 1 else -1
		var second := _perform_melee_strike(target_uid, second_roll)
		if not second.is_empty():
			_append_to_latest_action(Loc.text("MSG_DOUBLE_ATTACK_SECOND", [second["message"]]))
	elif ability_id == "basic_attack" and not bool(first.get("killed", false)):
		var passive_level := state.get_skill_level("almost_double_strike")
		var passive_chance := AbilitySystem.almost_double_strike_chance(passive_level)
		var passive_roll := (
			float(options["passive_roll"]) if options.has("passive_roll") else rng.randf()
		)
		if (
			state.current_form_id == "almost_human"
			and AbilitySystem.chance_succeeds(passive_roll, passive_chance)
		):
			var second_roll := int(attack_rolls[1]) if attack_rolls.size() > 1 else -1
			var passive_strike := _perform_melee_strike(target_uid, second_roll)
			if not passive_strike.is_empty():
				_append_to_latest_action(Loc.text(
					"MSG_PASSIVE_DOUBLE_STRIKE", [passive_strike["message"]],
				))
	return true


func _attack_enemy(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= floor_data.get("enemies", []).size():
		return
	var result := _perform_melee_strike(
		String(floor_data["enemies"][enemy_index].get("uid", "")),
	)
	if not result.is_empty():
		_log_action(String(result["message"]))


func _perform_melee_strike(enemy_uid: String, forced_d20 := -1) -> Dictionary:
	var enemy_index := _enemy_index_by_uid(enemy_uid)
	if enemy_index < 0:
		return {}
	var enemy: Dictionary = floor_data["enemies"][enemy_index]
	var rules: Dictionary = GameRules.ENEMIES[enemy["id"]]
	var d20 := rng.randi_range(1, 20) if forced_d20 < 1 else clampi(forced_d20, 1, 20)
	var attack := CombatSystem.resolve_attack(d20, state.get_accuracy(), int(enemy["dodge"]))
	var attack_roll := int(attack["attack_total"])
	var defense_target := int(attack["defense_target"])
	var enemy_name := Loc.text(String(rules["name"]))
	if not bool(attack["hit"]):
		return {
			"message": Loc.text("MSG_PLAYER_MISS", [enemy_name, attack_roll, defense_target]),
			"hit": false,
			"killed": false,
		}
	var damage_result := _damage_enemy_by_uid(enemy_uid, state.get_damage())
	if damage_result.is_empty():
		return {}
	var result_message := ""
	if bool(damage_result["killed"]):
		result_message = Loc.text("MSG_ENEMY_KILLED", [enemy_name, damage_result["souls"]])
		result_message += String(damage_result.get("reward_suffix", ""))
	else:
		result_message = Loc.text("MSG_PLAYER_HIT", [enemy_name, damage_result["hp"]])
	return {
		"message": result_message,
		"hit": true,
		"killed": damage_result["killed"],
	}


func _execute_ranged_attack(preferred_uid: String, options: Dictionary = {}) -> bool:
	var resolved := _resolve_ranged_target(preferred_uid)
	if not bool(resolved.get("ok", false)):
		var message_key := String(resolved.get("message", "MSG_RANGED_NO_TARGET"))
		var message_arguments: Array = (
			[state.get_ranged_range()]
			if message_key == "MSG_RANGED_NO_TARGET" or message_key == "MSG_RANGED_OUT_OF_RANGE"
			else []
		)
		_log_action(Loc.text(message_key, message_arguments))
		return false
	var enemy_index := int(resolved["enemy_index"])
	var enemy: Dictionary = floor_data["enemies"][enemy_index]
	var enemy_uid := String(enemy.get("uid", ""))
	var enemy_position: Vector2i = enemy["pos"]
	var enemy_rules: Dictionary = GameRules.ENEMIES[enemy["id"]]
	var enemy_name := Loc.text(String(enemy_rules["name"]))
	var attack_rolls: Array = options.get("attack_rolls", [])
	var forced_d20 := int(attack_rolls[0]) if not attack_rolls.is_empty() else -1
	var d20 := rng.randi_range(1, 20) if forced_d20 < 1 else clampi(forced_d20, 1, 20)
	var attack := CombatSystem.resolve_attack(d20, state.get_accuracy(), int(enemy["dodge"]))
	_audio_action("ranged_shot")
	_add_projectile_trace(player_pos, enemy_position)
	if not bool(attack["hit"]):
		_log_action(Loc.text("MSG_PLAYER_RANGED_MISS", [
			enemy_name, attack["attack_total"], attack["defense_target"],
		]))
		return true
	var damage := state.get_ranged_damage()
	var damage_result := _damage_enemy_by_uid(enemy_uid, damage)
	if bool(damage_result.get("killed", false)):
		_log_action(Loc.text("MSG_PLAYER_RANGED_KILLED", [
			enemy_name, damage, damage_result["souls"],
		]) + String(damage_result.get("reward_suffix", "")))
	else:
		_log_action(Loc.text("MSG_PLAYER_RANGED_HIT", [
			enemy_name, damage, damage_result.get("hp", 0),
		]))
	return true


func _resolve_ranged_target(preferred_uid := "") -> Dictionary:
	var maximum_range := state.get_ranged_range()
	if not preferred_uid.is_empty():
		return _validate_ranged_target_uid(preferred_uid, maximum_range)

	var raw_selection_kind := String(inspected_target.get("kind", ""))
	if raw_selection_kind == "noise":
		var selected_noise := _resolve_selected_inspection_target()
		if String(selected_noise.get("kind", "")) == "noise":
			return {"ok": false, "message": "MSG_RANGED_NO_TARGET"}
	if raw_selection_kind == "enemy":
		var selected_uid := String(inspected_target.get("uid", ""))
		if selected_uid.is_empty() and inspected_target.get("entity", {}) is Dictionary:
			selected_uid = String(inspected_target.get("entity", {}).get("uid", ""))
		return _validate_ranged_target_uid(selected_uid, maximum_range)

	var best_index := -1
	var best_distance := maximum_range + 1
	var best_position := Vector2i(1_000_000, 1_000_000)
	var best_uid := ""
	for index in range(floor_data.get("enemies", []).size()):
		var enemy: Dictionary = floor_data["enemies"][index]
		var position: Vector2i = enemy["pos"]
		if not _is_cell_visible(position):
			continue
		if not CombatSystem.is_ranged_target_valid(
			floor_data["tiles"], player_pos, position, maximum_range,
		):
			continue
		var distance := _manhattan(player_pos, position)
		var uid := String(enemy.get("uid", ""))
		if (
			distance < best_distance
			or (
				distance == best_distance
				and (
					position.y < best_position.y
					or (
						position.y == best_position.y
						and (
							position.x < best_position.x
							or (position.x == best_position.x and uid < best_uid)
						)
					)
				)
			)
		):
			best_index = index
			best_distance = distance
			best_position = position
			best_uid = uid
	if best_index < 0:
		return {"ok": false, "message": "MSG_RANGED_NO_TARGET"}
	return {"ok": true, "enemy_index": best_index}


func _validate_ranged_target_uid(enemy_uid: String, maximum_range: int) -> Dictionary:
	var enemy_index := _enemy_index_by_uid(enemy_uid)
	if enemy_index < 0:
		return {"ok": false, "message": "MSG_RANGED_NO_TARGET"}
	var position: Vector2i = floor_data["enemies"][enemy_index]["pos"]
	if not _is_cell_visible(position):
		return {"ok": false, "message": "MSG_RANGED_TARGET_HIDDEN"}
	var distance := _manhattan(player_pos, position)
	if distance < 1 or distance > maximum_range:
		return {"ok": false, "message": "MSG_RANGED_OUT_OF_RANGE"}
	if not CombatSystem.is_ranged_target_valid(
		floor_data["tiles"], player_pos, position, maximum_range,
	):
		return {"ok": false, "message": "MSG_RANGED_LINE_BLOCKED"}
	return {"ok": true, "enemy_index": enemy_index}


func _on_spell_pressed(ricochet_roll := -1.0) -> void:
	_activate_ability_slot("active_1", {"ricochet_roll": ricochet_roll})


func _cast_magic_missile(ricochet_roll := -1.0) -> bool:
	if not state.can_cast_magic_missile():
		_log_action(Loc.text("MSG_MAGIC_LOCKED"))
		return false
	if state.mana < GameRules.MAGIC_MISSILE_MANA_COST:
		_log_action(Loc.text("MSG_MAGIC_NO_MANA", [GameRules.MAGIC_MISSILE_MANA_COST]))
		return false

	var spell_range := state.get_magic_missile_range()
	var target_index := -1
	var selected := _resolve_selected_inspection_target()
	if not selected.is_empty() and selected.get("kind", "") == "noise":
		_log_action(Loc.text("MSG_MAGIC_NO_TARGET", [spell_range]))
		return false
	if not selected.is_empty() and selected.get("kind", "") == "enemy":
		var selected_position := _inspection_target_position(selected)
		if _manhattan(player_pos, selected_position) > spell_range:
			_log_action(Loc.text("MSG_MAGIC_OUT_OF_RANGE", [spell_range]))
			return false
		if not _has_clear_spell_line(player_pos, selected_position):
			_log_action(Loc.text("MSG_MAGIC_LINE_BLOCKED"))
			return false
		target_index = _enemy_index_at(selected_position)
	else:
		target_index = _nearest_enemy_index_from(player_pos, spell_range, "", true, true)
	if target_index < 0:
		_log_action(Loc.text("MSG_MAGIC_NO_TARGET", [spell_range]))
		return false

	state.spend_mana(GameRules.MAGIC_MISSILE_MANA_COST)
	_audio_action("magic_cast")
	var primary_enemy: Dictionary = floor_data["enemies"][target_index]
	var primary_uid := String(primary_enemy.get("uid", ""))
	var primary_position: Vector2i = primary_enemy["pos"]
	var damage := state.get_magic_missile_damage()
	_add_magic_trace(player_pos, primary_position)
	var primary_result := _apply_magic_damage(target_index, damage)
	_log_action(String(primary_result["message"]))

	var ricochet_index := _nearest_enemy_index_from(
		primary_position,
		GameRules.MAGIC_RICOCHET_RANGE,
		primary_uid,
		false,
	)
	var chance := state.get_magic_ricochet_chance()
	var roll := rng.randf() if ricochet_roll < 0.0 else clampf(ricochet_roll, 0.0, 1.0)
	if ricochet_index >= 0 and chance > 0.0 and roll < chance:
		var ricochet_position: Vector2i = floor_data["enemies"][ricochet_index]["pos"]
		_add_magic_trace(primary_position, ricochet_position)
		var ricochet_result := _apply_magic_damage(ricochet_index, damage)
		_append_to_latest_action(Loc.text("MSG_MAGIC_RICOCHET", [ricochet_result["message"]]))
	return true


func _resolve_adjacent_enemy_uid() -> String:
	var inspection_target := _get_inspection_target()
	if not inspection_target.is_empty() and inspection_target.get("kind", "") == "noise":
		return ""
	if not inspection_target.is_empty() and inspection_target.get("kind", "") == "enemy":
		var inspection_position := _inspection_target_position(inspection_target)
		if _manhattan(player_pos, inspection_position) == 1:
			var selected_index := _enemy_index_at(inspection_position)
			if selected_index >= 0:
				return String(floor_data["enemies"][selected_index].get("uid", ""))
	for direction in CARDINAL_DIRECTIONS:
		var enemy_index := _enemy_index_at(player_pos + direction)
		if enemy_index >= 0:
			return String(floor_data["enemies"][enemy_index].get("uid", ""))
	return ""


func _is_uid_adjacent(enemy_uid: String) -> bool:
	var enemy_index := _enemy_index_by_uid(enemy_uid)
	return (
		enemy_index >= 0
		and _manhattan(player_pos, floor_data["enemies"][enemy_index]["pos"]) == 1
	)


func _stop_automatic_ability_modes() -> void:
	_cancel_automatic_actions()


func _occupied_dash_cells(include_player := false) -> Dictionary:
	var occupied := {}
	for enemy in floor_data.get("enemies", []):
		occupied[enemy["pos"]] = true
	if include_player:
		occupied[player_pos] = true
	return occupied


func _begin_dash_targeting() -> bool:
	_stop_automatic_ability_modes()
	_refresh_dash_partition()
	if ability_target_cells.is_empty():
		_log_action(Loc.text("MSG_DASH_NO_TARGET"))
		_refresh_interface()
		return false
	ability_targeting_id = "dash"
	ability_target_cursor = _nearest_dash_target(player_pos)
	_log_action(Loc.text("MSG_DASH_TARGETING"))
	_refresh_interface()
	queue_redraw()
	return false


func _refresh_dash_partition() -> void:
	var partition := AbilitySystem.dash_partition(
		floor_data["tiles"],
		player_pos,
		floor_data.get("explored_cells", {}),
		floor_data.get("visible_cells", {}),
		_occupied_dash_cells(),
	)
	ability_target_cells.clear()
	ability_target_cells.append_array(partition.get("valid", []))
	ability_unavailable_cells = (partition.get("invalid", {}) as Dictionary).duplicate(true)


func _nearest_dash_target(origin: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_chebyshev := 1_000_000
	var best_manhattan := 1_000_000
	var best_order := 1_000_000
	for candidate in ability_target_cells:
		var delta := candidate - origin
		var chebyshev := maxi(absi(delta.x), absi(delta.y))
		var manhattan := absi(delta.x) + absi(delta.y)
		var order := (candidate.y + 1000) * 4096 + candidate.x + 1000
		if (
			chebyshev < best_chebyshev
			or (chebyshev == best_chebyshev and manhattan < best_manhattan)
			or (
				chebyshev == best_chebyshev and manhattan == best_manhattan
				and order < best_order
			)
		):
			best_chebyshev = chebyshev
			best_manhattan = manhattan
			best_order = order
			best = candidate
	return best


func _select_dash_direction(direction: Vector2i) -> bool:
	if ability_targeting_id != "dash":
		return false
	var source := ability_target_cursor if ability_target_cells.has(ability_target_cursor) else player_pos
	var best := Vector2i(-1, -1)
	var best_score := INF
	for candidate in ability_target_cells:
		if candidate == source:
			continue
		var delta := candidate - source
		if direction.x != 0 and signi(delta.x) != direction.x:
			continue
		if direction.y != 0 and signi(delta.y) != direction.y:
			continue
		if direction.x == 0 and delta.y == 0:
			continue
		if direction.y == 0 and delta.x == 0:
			continue
		var primary := (
			absi(delta.x) if direction.x != 0 and direction.y == 0
			else (absi(delta.y) if direction.y != 0 and direction.x == 0 else maxi(absi(delta.x), absi(delta.y)))
		)
		var perpendicular := (
			absi(delta.y) if direction.y == 0
			else (absi(delta.x) if direction.x == 0 else absi(absi(delta.x) - absi(delta.y)))
		)
		var score := float(primary) + float(perpendicular) * 2.0
		if score < best_score or (is_equal_approx(score, best_score) and candidate.y * 4096 + candidate.x < best.y * 4096 + best.x):
			best_score = score
			best = candidate
	if best.x < 0:
		return false
	ability_target_cursor = best
	queue_redraw()
	return true


func _confirm_dash(target := Vector2i(-1, -1)) -> bool:
	if ability_targeting_id != "dash":
		return false
	var chosen: Vector2i = ability_target_cursor if target.x < 0 else target
	_refresh_dash_partition()
	if not ability_target_cells.has(chosen):
		_log_dash_invalid_reason(String(ability_unavailable_cells.get(chosen, "invalid")))
		_refresh_interface()
		return false
	var distance := AbilitySystem.dash_distance(player_pos, chosen)
	player_pos = chosen
	_audio_action("dash")
	_cancel_ability_targeting(false)
	_log_action(Loc.text("MSG_DASH_COMPLETE", [distance]))
	var opened_chest := _pick_up_item_at_player()
	if opened_chest:
		_append_to_latest_action(Loc.text("MSG_DASH_CHEST"))
	_update_player_visibility()
	_complete_player_turn("dash")
	if screen == Screen.DUNGEON:
		_refresh_interface()
		queue_redraw()
	return true


func _cancel_ability_targeting(log_cancel := true) -> void:
	if ability_targeting_id.is_empty():
		return
	ability_targeting_id = ""
	ability_target_cells.clear()
	ability_unavailable_cells.clear()
	ability_target_cursor = Vector2i(-1, -1)
	if log_cancel:
		_log_action(Loc.text("MSG_ABILITY_CANCELLED"))
		_refresh_interface()
	queue_redraw()


func _log_dash_invalid_reason(reason: String) -> void:
	var key: String = {
		"hidden": "MSG_DASH_INVALID_HIDDEN",
		"blocked_tile": "MSG_DASH_INVALID_TILE",
		"occupied_endpoint": "MSG_DASH_INVALID_OCCUPIED",
		"occupied_path": "MSG_DASH_INVALID_OCCUPIED",
		"blocked_path": "MSG_DASH_INVALID_PATH",
	}.get(reason, "MSG_DASH_INVALID")
	_log_action(Loc.text(String(key)))


func _nearest_enemy_index_from(
	origin: Vector2i,
	radius: int,
	excluded_uid := "",
	require_clear_line := false,
	require_player_visibility := false
) -> int:
	var nearest_index := -1
	var nearest_distance := radius + 1
	for index in range(floor_data.get("enemies", []).size()):
		var enemy: Dictionary = floor_data["enemies"][index]
		if not excluded_uid.is_empty() and String(enemy.get("uid", "")) == excluded_uid:
			continue
		if GridNavigation.is_in_sealed_room(floor_data, enemy["pos"]):
			continue
		var distance := _manhattan(origin, enemy["pos"])
		if require_clear_line and not _has_clear_spell_line(origin, enemy["pos"]):
			continue
		if require_player_visibility and not _is_cell_visible(enemy["pos"]):
			continue
		if distance <= radius and distance < nearest_distance:
			nearest_index = index
			nearest_distance = distance
	return nearest_index


func _update_player_visibility(log_discoveries := true) -> void:
	if floor_data.is_empty():
		return
	var visible := {}
	var explored: Dictionary = floor_data.get("explored_cells", {}).duplicate(true)
	var observed: Dictionary = floor_data.get("observed_cells", {}).duplicate(true)
	var vision_radius := state.get_vision_radius()
	for cell_variant in floor_data["tiles"]:
		var cell: Vector2i = cell_variant
		if floor_data["tiles"].get(cell, "void") == "void":
			continue
		if _manhattan(player_pos, cell) > vision_radius:
			continue
		if not _has_clear_spell_line(player_pos, cell):
			continue
		visible[cell] = true
		explored[cell] = true
		observed[cell] = true
	# One extra ring maps nearby geometry without revealing occupants, loot or
	# landmarks. Expanding only from visible floor prevents seeing through walls,
	# while diagonal neighbours soften the diamond-shaped sight boundary.
	for visible_variant in visible:
		var visible_cell: Vector2i = visible_variant
		if floor_data["tiles"].get(visible_cell, "void") != "floor":
			continue
		for y_offset in range(-1, 2):
			for x_offset in range(-1, 2):
				var mapped_cell := visible_cell + Vector2i(x_offset, y_offset)
				if (
					_manhattan(player_pos, mapped_cell) <= vision_radius + 1
					and floor_data["tiles"].get(mapped_cell, "void") != "void"
				):
					explored[mapped_cell] = true
	floor_data["visible_cells"] = visible
	floor_data["explored_cells"] = explored
	floor_data["observed_cells"] = observed

	var knew_exit := bool(floor_data.get("exit_known", false))
	if visible.has(floor_data["exit"]):
		floor_data["exit_known"] = true
	if log_discoveries and not knew_exit and bool(floor_data.get("exit_known", false)):
		_append_to_latest_action(Loc.text("MSG_EXIT_DISCOVERED"))

	var cradle_position: Vector2i = floor_data.get("cradle", Vector2i(-1, -1))
	var knew_cradle := bool(floor_data.get("cradle_known", false))
	if cradle_position.x >= 0 and visible.has(cradle_position):
		floor_data["cradle_known"] = true
		if not bool(floor_data.get("cradle_pity_resolved", false)):
			state.record_cradle_result(true)
			floor_data["cradle_pity_resolved"] = true
	if log_discoveries and not knew_cradle and bool(floor_data.get("cradle_known", false)):
		_append_to_latest_action(Loc.text("MSG_CRADLE_APPEARED"))
	_sync_hearing_proximity()


func _is_cell_visible(cell: Vector2i) -> bool:
	return bool(floor_data.get("visible_cells", {}).get(cell, false))


func _is_cell_explored(cell: Vector2i) -> bool:
	return bool(floor_data.get("explored_cells", {}).get(cell, false))


func _is_cell_observed(cell: Vector2i) -> bool:
	var observed: Dictionary = floor_data.get(
		"observed_cells",
		floor_data.get("visible_cells", {}),
	)
	return bool(observed.get(cell, false))


func _finalize_current_floor_cradle() -> void:
	if floor_data.is_empty() or bool(floor_data.get("cradle_pity_resolved", false)):
		return
	state.record_cradle_result(false)
	floor_data["cradle_pity_resolved"] = true


func _has_clear_spell_line(from: Vector2i, to: Vector2i) -> bool:
	if floor_data.is_empty():
		return true
	return GridNavigation.has_clear_line(floor_data["tiles"], from, to)


func _add_magic_trace(from: Vector2i, to: Vector2i) -> void:
	magic_traces.append({
		"from": from,
		"to": to,
		"remaining": MAGIC_TRACE_DURATION,
	})
	queue_redraw()


func _update_magic_traces(delta: float) -> void:
	if magic_traces.is_empty():
		return
	for index in range(magic_traces.size() - 1, -1, -1):
		magic_traces[index]["remaining"] = float(magic_traces[index]["remaining"]) - delta
		if float(magic_traces[index]["remaining"]) <= 0.0:
			magic_traces.remove_at(index)
	queue_redraw()


func _add_projectile_trace(from: Vector2i, to: Vector2i) -> void:
	projectile_traces.append({
		"from": from,
		"to": to,
		"remaining": PROJECTILE_TRACE_DURATION,
	})
	queue_redraw()


func _update_projectile_traces(delta: float) -> void:
	if projectile_traces.is_empty():
		return
	for index in range(projectile_traces.size() - 1, -1, -1):
		projectile_traces[index]["remaining"] = (
			float(projectile_traces[index]["remaining"]) - delta
		)
		if float(projectile_traces[index]["remaining"]) <= 0.0:
			projectile_traces.remove_at(index)
	queue_redraw()


func _update_hit_effects(delta: float) -> void:
	var changed := false
	for uid_variant in enemy_hit_flashes.keys():
		var uid := String(uid_variant)
		enemy_hit_flashes[uid] = float(enemy_hit_flashes[uid]) - delta
		if float(enemy_hit_flashes[uid]) <= 0.0:
			enemy_hit_flashes.erase(uid)
		changed = true
	if player_hit_flash_remaining > 0.0:
		player_hit_flash_remaining = maxf(0.0, player_hit_flash_remaining - delta)
		changed = true
	for index in range(lethal_hit_afterimages.size() - 1, -1, -1):
		lethal_hit_afterimages[index]["remaining"] = (
			float(lethal_hit_afterimages[index].get("remaining", 0.0)) - delta
		)
		if float(lethal_hit_afterimages[index]["remaining"]) <= 0.0:
			lethal_hit_afterimages.remove_at(index)
		changed = true
	if changed:
		_refresh_dungeon_viewport()
		queue_redraw()


func _start_player_hit_flash() -> void:
	player_hit_flash_remaining = HIT_FLASH_DURATION
	_refresh_dungeon_viewport()


func _clear_hit_effects() -> void:
	enemy_hit_flashes.clear()
	player_hit_flash_remaining = 0.0
	lethal_hit_afterimages.clear()


func _apply_magic_damage(enemy_index: int, damage: int) -> Dictionary:
	if enemy_index < 0 or enemy_index >= floor_data.get("enemies", []).size():
		return {"message": "", "killed": false}
	var enemy: Dictionary = floor_data["enemies"][enemy_index]
	var rules: Dictionary = GameRules.ENEMIES[enemy["id"]]
	var enemy_name := Loc.text(String(rules["name"]))
	var damage_result := _damage_enemy_by_uid(String(enemy.get("uid", "")), damage)
	var result_message := ""
	if bool(damage_result.get("killed", false)):
		result_message = Loc.text("MSG_MAGIC_KILLED", [
			enemy_name, damage, damage_result["souls"],
		])
		result_message += String(damage_result.get("reward_suffix", ""))
	else:
		result_message = Loc.text("MSG_MAGIC_HIT", [enemy_name, damage, damage_result["hp"]])
	return {"message": result_message, "killed": damage_result.get("killed", false)}


func _damage_enemy_by_uid(enemy_uid: String, damage: int) -> Dictionary:
	var enemy_index := _enemy_index_by_uid(enemy_uid)
	if enemy_index < 0:
		return {}
	var enemy: Dictionary = floor_data["enemies"][enemy_index]
	hearing_contacts.remove_uid(enemy_uid)
	var applied_damage := maxi(0, damage)
	if applied_damage > 0:
		enemy_hit_flashes[enemy_uid] = HIT_FLASH_DURATION
	enemy["hp"] -= applied_damage
	if enemy["hp"] > 0:
		floor_data["enemies"][enemy_index] = enemy
		return {"killed": false, "hp": enemy["hp"], "souls": 0, "reward_suffix": ""}
	var rules: Dictionary = GameRules.ENEMIES[enemy["id"]]
	if applied_damage > 0:
		enemy_hit_flashes.erase(enemy_uid)
		lethal_hit_afterimages.append({
			"enemy_id": String(enemy["id"]),
			"pos": enemy["pos"],
			"remaining": LETHAL_AFTERIMAGE_DURATION,
			"duration": LETHAL_AFTERIMAGE_DURATION,
		})
	var gained := state.add_souls(int(enemy["souls"]))
	floor_data["enemies"].remove_at(enemy_index)
	var reward_suffix := ""
	if bool(rules.get("meat", false)):
		var food_gained := state.add_food(1)
		if state.uses_hunger():
			reward_suffix += Loc.text("MSG_FOOD_GAINED", [food_gained])
	var boss_result := _open_boss_door_after(enemy)
	if not boss_result.is_empty():
		reward_suffix += boss_result
	return {
		"killed": true,
		"hp": 0,
		"souls": gained,
		"reward_suffix": reward_suffix,
	}


func _open_boss_door_after(enemy: Dictionary) -> String:
	if (
		String(enemy.get("uid", "")) != String(floor_data.get("boss_uid", ""))
		or bool(floor_data.get("boss_door_open", false))
	):
		return ""
	var door_position: Vector2i = floor_data.get("boss_door", Vector2i(-1, -1))
	if door_position.x < 0:
		return ""
	floor_data["boss_defeated"] = true
	floor_data["boss_door_open"] = true
	floor_data["tiles"][door_position] = "floor"
	_update_player_visibility(false)
	return Loc.text("MSG_BOSS_DOOR_OPEN")


func _enemy_turn() -> void:
	hidden_attack_heard_this_enemy_phase = false
	for index in range(floor_data["enemies"].size()):
		var enemy: Dictionary = floor_data["enemies"][index]
		var sees_player := _enemy_can_see_player(enemy)
		if sees_player:
			enemy["last_seen_player"] = player_pos
			if not bool(enemy.get("has_seen_player", false)):
				enemy["has_seen_player"] = true
				floor_data["enemies"][index] = enemy
				continue
		elif not enemy.has("last_seen_player"):
			continue
		elif enemy["pos"] == enemy["last_seen_player"]:
			enemy.erase("last_seen_player")
			floor_data["enemies"][index] = enemy
			continue
		floor_data["enemies"][index] = enemy

		if sees_player and _try_enemy_dash(index):
			continue
		if sees_player and _try_enemy_ranged_attack(index):
			if screen != Screen.DUNGEON:
				return
			continue

		if sees_player and _manhattan(enemy["pos"], player_pos) == 1:
			var enemy_rules: Dictionary = GameRules.ENEMIES[enemy["id"]]
			var attack := CombatSystem.resolve_attack(
				rng.randi_range(1, 20), int(enemy["accuracy"]), state.get_dodge(),
			)
			var attack_roll := int(attack["attack_total"])
			var defense_target := int(attack["defense_target"])
			var enemy_name := Loc.text(String(enemy_rules["name"]))
			var attacker_hidden := not _is_cell_visible(enemy["pos"])
			if attacker_hidden:
				_record_hidden_enemy_attack(enemy)
			if not bool(attack["hit"]):
				if attacker_hidden:
					_append_to_latest_action(Loc.text("MSG_HIDDEN_ENEMY_MISS"))
				else:
					_append_to_latest_action(Loc.text("MSG_ENEMY_MISS", [
						enemy_name, attack_roll, defense_target,
					]))
				continue
			_start_player_hit_flash()
			_cancel_automatic_actions()
			if state.take_damage(int(enemy["damage"])):
				_flush_hidden_attack_hearing_log()
				_handle_death()
				return
			_audio_action("player_hurt")
			_append_to_latest_action(Loc.text(
				"MSG_HIDDEN_ENEMY_HIT" if attacker_hidden else "MSG_ENEMY_HIT",
				[enemy["damage"]] if attacker_hidden else [enemy_name, enemy["damage"]],
			))
			continue

		var pursuit_target: Vector2i = player_pos if sees_player else enemy["last_seen_player"]
		var step := _enemy_step_toward(index, pursuit_target)
		if step != enemy["pos"]:
			enemy["pos"] = step
			floor_data["enemies"][index] = enemy
	_sync_hearing_proximity()
	_flush_hidden_attack_hearing_log()


func _try_enemy_ranged_attack(enemy_index: int, forced_d20 := -1) -> bool:
	if enemy_index < 0 or enemy_index >= floor_data.get("enemies", []).size():
		return false
	var enemy: Dictionary = floor_data["enemies"][enemy_index]
	var rules: Dictionary = GameRules.ENEMIES.get(String(enemy.get("id", "")), {})
	if String(enemy.get("attack_type", rules.get("attack_type", "melee"))) != "ranged":
		return false
	var attack_range := int(enemy.get("range", rules.get("range", 0)))
	if not CombatSystem.is_ranged_target_valid(
		floor_data["tiles"], enemy["pos"], player_pos, attack_range,
	):
		return false

	incoming_ranged_attack_this_turn = true
	if auto_explore_active:
		_clear_auto_explore_state()
	var shooter_visible := _is_cell_visible(enemy["pos"])
	if not shooter_visible:
		_record_hidden_enemy_attack(enemy)
	if shooter_visible:
		_add_projectile_trace(enemy["pos"], player_pos)
	var d20 := rng.randi_range(1, 20) if forced_d20 < 1 else clampi(forced_d20, 1, 20)
	var attack := CombatSystem.resolve_attack(d20, int(enemy["accuracy"]), state.get_dodge())
	_audio_action("ranged_shot")
	var enemy_name := Loc.text(String(rules["name"]))
	if not bool(attack["hit"]):
		_append_to_latest_action(Loc.text(
			"MSG_ENEMY_RANGED_MISS" if shooter_visible else "MSG_HIDDEN_RANGED_MISS",
			[enemy_name, attack["attack_total"], attack["defense_target"]]
			if shooter_visible else [],
		))
		return true
	var damage := int(enemy["damage"])
	_start_player_hit_flash()
	_cancel_automatic_actions()
	if state.take_damage(damage):
		_flush_hidden_attack_hearing_log()
		_handle_death()
		return true
	_audio_action("player_hurt")
	_append_to_latest_action(Loc.text(
		"MSG_ENEMY_RANGED_HIT" if shooter_visible else "MSG_HIDDEN_RANGED_HIT",
		[enemy_name, damage] if shooter_visible else [damage],
	))
	return true


func _try_enemy_dash(enemy_index: int) -> bool:
	if enemy_index < 0 or enemy_index >= floor_data.get("enemies", []).size():
		return false
	var enemy: Dictionary = floor_data["enemies"][enemy_index]
	var rules: Dictionary = GameRules.ENEMIES.get(String(enemy.get("id", "")), {})
	var abilities: Array = enemy.get("abilities", rules.get("abilities", []))
	if not abilities.has("dash"):
		return false
	var distance := AbilitySystem.dash_distance(enemy["pos"], player_pos)
	if distance < 2 or distance > 4:
		return false
	var direction := AbilitySystem.direction_to_straight_endpoint(enemy["pos"], player_pos)
	if direction == Vector2i.ZERO:
		return false
	var known_floor := {}
	for cell_variant in floor_data["tiles"]:
		var cell: Vector2i = cell_variant
		if floor_data["tiles"].get(cell, "void") == "floor":
			known_floor[cell] = true
	var occupied := {player_pos: true}
	for other_index in range(floor_data["enemies"].size()):
		if other_index != enemy_index:
			occupied[floor_data["enemies"][other_index]["pos"]] = true
	var candidates := AbilitySystem.dash_targets_in_direction(
		floor_data["tiles"], enemy["pos"], direction, known_floor, occupied,
	)
	var expected_endpoint := player_pos - direction
	if candidates.is_empty() or candidates[candidates.size() - 1] != expected_endpoint:
		return false
	enemy["pos"] = expected_endpoint
	floor_data["enemies"][enemy_index] = enemy
	_audio_action("dash")
	_append_to_latest_action(Loc.text("MSG_ENEMY_DASH", [
		Loc.text(String(rules["name"])),
	]))
	return true


func _enemy_can_see_player(enemy: Dictionary) -> bool:
	var rules: Dictionary = GameRules.ENEMIES.get(String(enemy.get("id", "")), {})
	var vision := int(enemy.get("vision", rules.get("vision", 0)))
	return (
		vision > 0
		and _manhattan(enemy["pos"], player_pos) <= vision
		and _has_clear_spell_line(enemy["pos"], player_pos)
	)


func _enemy_step_toward_player(enemy_index: int) -> Vector2i:
	return _enemy_step_toward(enemy_index, player_pos)


func _enemy_step_toward(enemy_index: int, target: Vector2i) -> Vector2i:
	var enemy: Dictionary = floor_data["enemies"][enemy_index]
	var current: Vector2i = enemy["pos"]
	var blocked_cells: Dictionary = {}
	for index in range(floor_data["enemies"].size()):
		if index == enemy_index:
			continue
		blocked_cells[floor_data["enemies"][index]["pos"]] = true
	return GridNavigation.next_step(floor_data["tiles"], current, target, blocked_cells)


func _pick_up_item_at_player() -> bool:
	for index in range(floor_data["items"].size()):
		var item: Dictionary = floor_data["items"][index]
		if item["pos"] != player_pos:
			continue
		var item_key := state.add_item(String(item["id"]))
		var gains := state.add_resources({
			"wood": int(item.get("wood", 0)),
			"stone": int(item.get("stone", 0)),
		})
		floor_data["items"].remove_at(index)
		_audio_action("chest_open")
		_log_action(Loc.text("MSG_CHEST_OPENED", [
			_item_display_name(item_key), gains["wood"], gains["stone"],
		]))
		return true
	return false


func _handle_death() -> void:
	_cancel_automatic_actions()
	_cancel_ability_targeting(false)
	projectile_traces.clear()
	_clear_hit_effects()
	_clear_hearing_context()
	if audio_manager != null:
		audio_manager.stop_background()
	_audio_action("death")
	var losses := state.die()
	_show_story("death", Loc.text("MSG_DEATH", [
		losses["souls"],
		losses["items"],
	]))


func _enemy_index_at(cell: Vector2i) -> int:
	for index in range(floor_data["enemies"].size()):
		if floor_data["enemies"][index]["pos"] == cell:
			return index
	return -1


func _enemy_index_by_uid(enemy_uid: String) -> int:
	for index in range(floor_data.get("enemies", []).size()):
		if String(floor_data["enemies"][index].get("uid", "")) == enemy_uid:
			return index
	return -1


func _tile_hint() -> String:
	if player_pos == floor_data.get("cradle", Vector2i(-1, -1)):
		return Loc.text("MSG_CRADLE_TILE")
	if player_pos == floor_data["base_gate"]:
		return Loc.text("MSG_PATH_BASE")
	if player_pos == floor_data["exit"]:
		return Loc.text("MSG_PATH_UP", [maxi(1, state.current_floor - 1)])
	if player_pos == floor_data["start"]:
		return Loc.text("MSG_TILE_START")
	return Loc.text("MSG_TURN_DONE")


func _select_inspection_target(cell: Vector2i) -> void:
	if cell == player_pos:
		inspected_target.clear()
		return
	if not _is_cell_explored(cell):
		inspected_target.clear()
		return
	var observed := _is_cell_observed(cell)

	var enemy_index := _enemy_index_at(cell)
	if enemy_index >= 0 and _is_cell_visible(cell):
		var enemy: Dictionary = floor_data["enemies"][enemy_index]
		inspected_target = {
			"kind": "enemy",
			"uid": String(enemy.get("uid", "")),
			"entity": enemy,
		}
		return

	for item in floor_data["items"]:
		if observed and item["pos"] == cell:
			inspected_target = {
				"kind": "item",
				"uid": String(item.get("uid", "")),
				"entity": item,
			}
			return

	if observed and cell == floor_data["base_gate"]:
		inspected_target = {"kind": "base", "pos": cell}
	elif observed and cell == floor_data["exit"]:
		inspected_target = {"kind": "exit", "pos": cell}
	elif observed and cell == floor_data["start"]:
		inspected_target = {"kind": "start", "pos": cell}
	elif observed and cell == floor_data.get("cradle", Vector2i(-1, -1)):
		inspected_target = {"kind": "cradle", "pos": cell}
	else:
		inspected_target = {"kind": "tile", "pos": cell}


func _get_inspection_target() -> Dictionary:
	var selected := _resolve_selected_inspection_target()
	if not selected.is_empty():
		selected["manual"] = true
		return selected
	var automatic := _nearest_automatic_inspection_target()
	if not automatic.is_empty():
		automatic["manual"] = false
	return automatic


func _resolve_selected_inspection_target() -> Dictionary:
	if inspected_target.is_empty() or floor_data.is_empty():
		return {}
	var kind := String(inspected_target.get("kind", ""))
	if kind == "noise":
		var noise_position: Variant = inspected_target.get("pos")
		if noise_position is Vector2i and _is_hearing_contact_presented_at(noise_position):
			return {"kind": "noise", "pos": noise_position}
		inspected_target.clear()
		return {}
	if kind == "enemy" or kind == "item":
		var collection: Array = floor_data["enemies"] if kind == "enemy" else floor_data["items"]
		var target_uid := String(inspected_target.get("uid", ""))
		for entity in collection:
			if (
				(not target_uid.is_empty() and String(entity.get("uid", "")) == target_uid)
				or (target_uid.is_empty() and entity == inspected_target.get("entity", {}))
			):
				if kind == "enemy" and not _is_cell_visible(entity["pos"]):
					inspected_target.clear()
					return {}
				if kind == "item" and not _is_cell_observed(entity["pos"]):
					inspected_target.clear()
					return {}
				return {"kind": kind, "entity": entity}
		inspected_target.clear()
		return {}
	var position: Vector2i = inspected_target.get("pos", player_pos)
	if not _is_cell_explored(position):
		inspected_target.clear()
		return {}
	return inspected_target.duplicate(true)


func _nearest_automatic_inspection_target() -> Dictionary:
	if floor_data.is_empty():
		return {}
	var nearest := {}
	var nearest_distance := inspection_radius + 1
	for enemy in floor_data["enemies"]:
		if not _is_cell_visible(enemy["pos"]):
			continue
		var enemy_distance := _manhattan(player_pos, enemy["pos"])
		if enemy_distance <= inspection_radius and enemy_distance < nearest_distance:
			nearest = {"kind": "enemy", "entity": enemy}
			nearest_distance = enemy_distance
	if not nearest.is_empty():
		return nearest

	for item in floor_data["items"]:
		if not _is_cell_observed(item["pos"]):
			continue
		var item_distance := _manhattan(player_pos, item["pos"])
		if item_distance <= inspection_radius and item_distance < nearest_distance:
			nearest = {"kind": "item", "entity": item}
			nearest_distance = item_distance
	if not nearest.is_empty():
		return nearest

	var special_targets := [
		{"kind": "base", "pos": floor_data["base_gate"]},
		{"kind": "exit", "pos": floor_data["exit"]},
		{"kind": "start", "pos": floor_data["start"]},
	]
	for room in floor_data.get("rooms", []):
		special_targets.append({"kind": "tile", "pos": room["door"]})
	var cradle_position: Vector2i = floor_data.get("cradle", Vector2i(-1, -1))
	if cradle_position.x >= 0:
		special_targets.append({"kind": "cradle", "pos": cradle_position})
	for special in special_targets:
		if not _is_cell_observed(special["pos"]):
			continue
		var special_distance := _manhattan(player_pos, special["pos"])
		if special_distance <= inspection_radius and special_distance < nearest_distance:
			nearest = special
			nearest_distance = special_distance
	return nearest


func _inspection_target_position(target: Dictionary) -> Vector2i:
	if target.has("entity"):
		return target["entity"]["pos"]
	return target.get("pos", player_pos)


func _inspection_target_name(target: Dictionary) -> String:
	match String(target.get("kind", "")):
		"enemy":
			var enemy_rules: Dictionary = GameRules.ENEMIES[target["entity"]["id"]]
			return Loc.text(String(enemy_rules["name"]))
		"item":
			return Loc.text("INSPECT_CHEST")
		"base":
			return Loc.text("INSPECT_BASE")
		"exit":
			return Loc.text("INSPECT_EXIT")
		"start":
			return Loc.text("INSPECT_START")
		"cradle":
			return Loc.text("INSPECT_CRADLE")
		"tile":
			var tile_type := String(floor_data["tiles"].get(target["pos"], "void"))
			if not GridNavigation.room_at_door(floor_data, target["pos"]).is_empty():
				return Loc.text("INSPECT_DOOR" if tile_type == "door_closed" else "INSPECT_DOOR_OPEN")
			if target["pos"] == floor_data.get("boss_door", Vector2i(-1, -1)):
				return Loc.text(
					"INSPECT_BOSS_DOOR_OPEN"
					if bool(floor_data.get("boss_door_open", false))
					else "INSPECT_BOSS_DOOR"
				)
			if tile_type == "wall":
				return Loc.text("INSPECT_WALL")
			if tile_type == "floor":
				return Loc.text("INSPECT_FLOOR")
			return Loc.text("INSPECT_VOID")
		"noise":
			return Loc.text("INSPECT_NOISE_SOURCE")
	return ""


func _refresh_inspection_panel() -> void:
	if inspection_label == null:
		return
	inspection_label.visible = screen == Screen.DUNGEON
	if not inspection_label.visible:
		return
	var target := _get_inspection_target()
	var header_key := "INSPECT_HEADER_SELECTED" if bool(target.get("manual", false)) else "INSPECT_HEADER_AUTO"
	var level_line := Loc.text("TITLE_FLOOR", [state.current_floor])
	if target.is_empty():
		inspection_label.text = "%s\n%s\n%s" % [
			level_line,
			Loc.text(header_key),
			Loc.text("INSPECT_NONE", [inspection_radius]),
		]
		return

	var position := _inspection_target_position(target)
	var distance := _manhattan(player_pos, position)
	var lines := PackedStringArray([
		level_line,
		Loc.text(header_key),
		Loc.text("INSPECT_TARGET", [_inspection_target_name(target), distance]),
	])
	if target["kind"] == "enemy":
		var enemy: Dictionary = target["entity"]
		var enemy_rules: Dictionary = GameRules.ENEMIES[enemy["id"]]
		lines.append(Loc.text("INSPECT_ENEMY_STATS", [
			enemy["hp"], enemy["max_hp"], enemy["damage"], enemy["accuracy"],
			int(enemy.get("vision", enemy_rules.get("vision", 0))),
		]))
	elif target["kind"] == "item":
		lines.append(Loc.text("INSPECT_CHEST_DESC"))
	elif target["kind"] == "cradle":
		if bool(floor_data.get("cradle_used", false)):
			lines.append(Loc.text("INSPECT_CRADLE_USED"))
		else:
			var next := GameRules.next_form(state.current_form_id)
			if next.is_empty():
				lines.append(Loc.text("EVOLUTION_MAX"))
			else:
				lines.append(Loc.text("INSPECT_CRADLE_READY", [
					Loc.text(String(next["name"])),
					GameRules.evolution_cost(state.current_form_id),
					GameRules.required_soul_level(String(next["id"])),
				]))
	inspection_label.text = "\n".join(lines)


func _refresh_interface() -> void:
	var form := state.get_form()
	var next := GameRules.next_form(state.current_form_id)
	var evolution_text := Loc.text("EVOLUTION_MAX")
	if not next.is_empty():
		evolution_text = Loc.text("EVOLUTION_NEXT", [
			Loc.text(String(next["name"])),
			GameRules.evolution_cost(state.current_form_id),
			GameRules.required_soul_level(String(next["id"])),
		])

	if screen == Screen.DUNGEON:
		title_label.text = Loc.text(String(form["name"]))
		title_label.size = Vector2(184, 20)
		hint_label.text = _tile_hint()
	elif screen == Screen.BASE:
		title_label.text = Loc.text("TITLE_BASE")
		hint_label.text = Loc.text("HINT_BASE")
		_apply_base_layout()
	else:
		title_label.text = Loc.text("TITLE_EXIT")
		hint_label.text = Loc.text("HINT_END")

	var progress_lines := PackedStringArray()
	if screen == Screen.DUNGEON:
		stats_label.text = state.character_name
		_fit_single_line_label(stats_label, 12, 8)
		stats_label.size = Vector2(184, 24)
		_fit_single_line_label(title_label, 9, 8)
		progress_lines.append(Loc.text("SOUL_LEVEL_LABEL", [state.get_effective_soul_level()]))
		if state.uses_hunger():
			progress_lines.append(Loc.text("CHARACTER_SURVIVAL", [state.hunger, state.food]))
	else:
		stats_label.text = "\n".join(PackedStringArray([
			state.character_name,
			Loc.text("SIDEBAR_FORM", [Loc.text(String(form["name"]))]),
		]))
		if screen != Screen.BASE:
			progress_lines.append(Loc.text("SIDEBAR_EVOLUTION", [evolution_text]))
		if state.uses_hunger():
			progress_lines.append(Loc.text("CHARACTER_SURVIVAL", [state.hunger, state.food]))
	sidebar_progress_label.text = "\n".join(progress_lines)
	status_strip.visible = screen == Screen.DUNGEON or screen == Screen.BASE
	status_strip.refresh(state.active_statuses)
	_refresh_souls_label()
	material_resources_strip.visible = screen == Screen.BASE
	if screen == Screen.BASE:
		material_resources_strip.refresh(state.resources)

	var equipment_lines := PackedStringArray([Loc.text("SIDEBAR_EQUIPMENT")])
	for slot in form["slots"]:
		var slot_name := Loc.text(String(GameRules.SLOT_NAMES[slot]))
		var item_id := String(state.loadout.get(slot, ""))
		var item_name := "—"
		if not item_id.is_empty():
			item_name = _item_display_name(item_id)
		equipment_lines.append("%s: %s" % [slot_name, item_name])
	equipment_label.text = "\n".join(equipment_lines)

	camp_upgrades_label.text = Loc.text("CAMP_MATERIAL_HINT")
	build_crusher_button.text = Loc.text(
		"CAMP_BUILT_CRUSHER"
		if bool(state.camp_upgrades.get("crusher", false))
		else "CAMP_BUILD_CRUSHER"
	)
	build_whetstone_button.text = Loc.text(
		"CAMP_BUILT_WHETSTONE"
		if bool(state.camp_upgrades.get("whetstone", false))
		else "CAMP_BUILD_WHETSTONE"
	)
	build_ritual_table_button.text = Loc.text(
		"CAMP_BUILT_RITUAL_TABLE"
		if bool(state.camp_upgrades.get("ritual_table", false))
		else "CAMP_BUILD_RITUAL_TABLE"
	)
	upgrade_button.text = Loc.text(
		"CAMP_BUILT_CAMPFIRE"
		if bool(state.camp_upgrades.get("campfire", false))
		else "CAMP_BUILD_CAMPFIRE"
	)
	build_crusher_button.disabled = not state.can_build_camp_upgrade("crusher")
	build_whetstone_button.disabled = not state.can_build_camp_upgrade("whetstone")
	build_ritual_table_button.disabled = not state.can_build_camp_upgrade("ritual_table")
	upgrade_button.disabled = not state.can_build_camp_upgrade("campfire")
	crusher_object_button.visible = (
		screen == Screen.BASE
		and inventory_service_mode.is_empty()
		and bool(state.camp_upgrades.get("crusher", false))
	)
	whetstone_object_button.visible = (
		screen == Screen.BASE
		and inventory_service_mode.is_empty()
		and bool(state.camp_upgrades.get("whetstone", false))
	)
	ritual_table_object_button.visible = (
		screen == Screen.BASE
		and inventory_service_mode.is_empty()
		and bool(state.camp_upgrades.get("ritual_table", false))
	)
	if screen == Screen.BASE and inventory_service_mode.is_empty():
		_configure_base_focus()
	wait_button.text = _wait_button_text()
	auto_explore_button.text = Loc.text(
		"BTN_AUTO_EXPLORE_STOP" if auto_explore_active else "BTN_AUTO_EXPLORE"
	)
	auto_explore_button.disabled = false
	_refresh_hotbar()
	if interact_button.visible:
		interact_button.text = Loc.text(
			"BTN_ASCEND" if _should_offer_ascend_button() else "BTN_INTERACT"
		)
		interact_button.disabled = not (
			player_pos == floor_data.get("base_gate", Vector2i(-1, -1))
			or player_pos == floor_data.get("cradle", Vector2i(-1, -1))
			or _should_offer_ascend_button()
		)
	if camp_button.visible:
		camp_button.disabled = not state.uses_hunger()
	_fit_button_text(attack_button, 11, 8)
	_fit_button_text(spell_button, 11, 8)
	_fit_button_text(active_2_button, 11, 8)
	_fit_button_text(active_3_button, 11, 8)
	_fit_button_text(wait_button, 13, 10)
	_fit_button_text(auto_explore_button, 13, 9)
	_fit_button_text(camp_button, 14, 10)
	_fit_button_text(character_action_button, 14, 10)
	_fit_button_text(interact_button, 14, 10)
	_fit_button_text(build_crusher_button, 15, 11)
	_fit_button_text(build_whetstone_button, 15, 11)
	_fit_button_text(build_ritual_table_button, 15, 10)
	_fit_button_text(upgrade_button, 15, 11)
	_refresh_inspection_panel()
	_refresh_action_history()
	_refresh_dungeon_viewport()


func _refresh_hotbar() -> void:
	for slot_id in AbilitySystem.SLOT_ORDER:
		var button: Button = hotbar_ability_buttons[slot_id]
		var badge: Label = hotbar_cooldown_badges[slot_id]
		var assigned := state.get_slotted_ability(slot_id)
		var shown_ability := _effective_attack_ability() if slot_id == "attack" else assigned
		var cooldown := state.cooldown_remaining(assigned)
		var prefix := "F" if slot_id == "attack" else ("Q" if slot_id == "active_1" else "")
		var shown_name := (
			Loc.text("ABILITY_BASIC_SHOT")
			if slot_id == "attack" and state.has_ranged_weapon()
			else _ability_display_name(shown_ability)
		)
		var effective_text := "%s%s" % [
			("%s · " % prefix) if not prefix.is_empty() else "",
			shown_name,
		]
		if slot_id == "attack" and cooldown > 0 and shown_ability == "basic_attack":
			effective_text = Loc.text("ABILITY_ATTACK_FALLBACK", [
				effective_text, _ability_display_name(assigned), cooldown,
			])
		button.text = effective_text
		button.disabled = slot_id != "attack" and (assigned.is_empty() or cooldown > 0)
		badge.text = str(cooldown)
		badge.visible = cooldown > 0
		button.tooltip_text = (
			Loc.text("ABILITY_HOTBAR_COOLDOWN", [
				Loc.text(_ability_slot_name_key(slot_id)),
				_ability_display_name(assigned),
				cooldown,
			])
			if cooldown > 0
			else Loc.text("ABILITY_HOTBAR_TOOLTIP", [
				Loc.text(_ability_slot_name_key(slot_id)),
				_ability_display_name(assigned),
			])
		)
		button.accessibility_name = button.tooltip_text
		badge.tooltip_text = button.tooltip_text
		badge.accessibility_name = button.tooltip_text
	if state.get_slotted_ability("active_1") == "magic_missile":
		spell_button.tooltip_text = Loc.text("MAGIC_MISSILE_TOOLTIP", [
			state.get_magic_missile_damage(),
			state.get_magic_missile_range(),
			GameRules.MAGIC_MISSILE_MANA_COST,
		])


func _refresh_souls_label() -> void:
	if souls_label != null:
		var compact := screen == Screen.DUNGEON or screen == Screen.BASE
		var key := "DUNGEON_SOUL_COUNTER" if compact else "SOUL_COUNTER"
		souls_label.text = Loc.text(key, [
			state.carried_souls,
			state.get_total_souls(),
		])
		if screen == Screen.BASE:
			souls_label.tooltip_text = Loc.text("BASE_SOULS_TOOLTIP", [
				state.carried_souls, state.get_total_souls(),
			])
			souls_label.accessibility_name = souls_label.tooltip_text
			_fit_single_line_label(souls_label, 11, 7)
		elif screen == Screen.DUNGEON:
			souls_label.tooltip_text = Loc.text("BASE_SOULS_TOOLTIP", [
				state.carried_souls, state.get_total_souls(),
			])
			souls_label.accessibility_name = souls_label.tooltip_text
			_fit_single_line_label(souls_label, 9, 7)
		else:
			souls_label.tooltip_text = souls_label.text
			souls_label.accessibility_name = souls_label.text


func _apply_base_layout() -> void:
	title_label.position = BASE_TITLE_RECT.position
	title_label.size = BASE_TITLE_RECT.size
	soul_icon.visible = true
	soul_icon.position = BASE_SOUL_ICON_RECT.position
	soul_icon.size = BASE_SOUL_ICON_RECT.size
	souls_label.clip_text = true
	souls_label.position = BASE_SOULS_RECT.position
	souls_label.size = BASE_SOULS_RECT.size
	souls_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	souls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	material_resources_strip.position = BASE_MATERIALS_RECT.position
	material_resources_strip.size = BASE_MATERIALS_RECT.size
	stats_label.position = BaseLayout.STATS_RECT.position
	stats_label.size = BaseLayout.STATS_RECT.size
	stats_label.add_theme_font_size_override("font_size", 17)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_strip.position = BaseLayout.STATUS_RECT.position
	status_strip.size = BaseLayout.STATUS_RECT.size
	sidebar_progress_label.position = BaseLayout.PROGRESS_RECT.position
	sidebar_progress_label.size = BaseLayout.PROGRESS_RECT.size
	sidebar_progress_label.add_theme_font_size_override("font_size", 15)
	camp_upgrades_label.position = BaseLayout.CAMP_UPGRADES_RECT.position
	camp_upgrades_label.size = BaseLayout.CAMP_UPGRADES_RECT.size
	start_button.position = BaseLayout.START_RECT.position
	start_button.size = BaseLayout.START_RECT.size
	build_crusher_button.position = BaseLayout.BUILD_CRUSHER_RECT.position
	build_crusher_button.size = BaseLayout.BUILD_CRUSHER_RECT.size
	build_whetstone_button.position = BaseLayout.BUILD_WHETSTONE_RECT.position
	build_whetstone_button.size = BaseLayout.BUILD_WHETSTONE_RECT.size
	build_ritual_table_button.position = BaseLayout.BUILD_RITUAL_TABLE_RECT.position
	build_ritual_table_button.size = BaseLayout.BUILD_RITUAL_TABLE_RECT.size
	upgrade_button.position = BaseLayout.BUILD_CAMPFIRE_RECT.position
	upgrade_button.size = BaseLayout.BUILD_CAMPFIRE_RECT.size
	character_button.position = BaseLayout.CHARACTER_BUTTON_RECT.position
	character_button.size = BaseLayout.CHARACTER_BUTTON_RECT.size
	hint_label.position = BaseLayout.HINT_RECT.position
	hint_label.size = BaseLayout.HINT_RECT.size
	message_label.position = BaseLayout.MESSAGE_RECT.position
	message_label.size = BaseLayout.MESSAGE_RECT.size
	var station_buttons := {
		"crusher": crusher_object_button,
		"whetstone": whetstone_object_button,
		"ritual_table": ritual_table_object_button,
	}
	for station_id in station_buttons:
		var station_rect := BaseLayout.station_hitbox_rect(station_id)
		var button: Button = station_buttons[station_id]
		button.position = station_rect.position
		button.size = station_rect.size


func _draw() -> void:
	Renderer.draw_frame(
		self,
		size,
		state,
		screen == Screen.BASE or screen == Screen.DUNGEON or screen == Screen.VICTORY,
		screen == Screen.BASE,
		screen == Screen.DUNGEON,
		_get_inspection_target() if screen == Screen.DUNGEON else {},
	)

	match screen:
		Screen.NAME_CREATION:
			_draw_name_creation()
		Screen.STAT_CREATION:
			_draw_stat_creation()
		Screen.STORY:
			_draw_story()
		Screen.BASE:
			_draw_base()
		Screen.DUNGEON:
			_draw_dungeon()
		Screen.CHARACTER:
			_draw_character_sheet()
		Screen.VICTORY:
			_draw_victory()


func _draw_name_creation() -> void:
	Renderer.draw_name_creation(self)


func _draw_stat_creation() -> void:
	Renderer.draw_stat_creation(self)


func _draw_story() -> void:
	Renderer.draw_story(self, size, story_kind, story_index)


func _draw_character_sheet() -> void:
	Renderer.draw_character_sheet(self, state, character_panel_mode, selected_skill_stage)


func _draw_dungeon() -> void:
	_refresh_dungeon_viewport()


func _refresh_dungeon_viewport() -> void:
	if dungeon_viewport == null or screen != Screen.DUNGEON or floor_data.is_empty():
		return
	var inspection_target := _get_inspection_target()
	var inspection_cell := Vector2i.ZERO
	if not inspection_target.is_empty():
		inspection_cell = _inspection_target_position(inspection_target)
	var hearing_cells: Array[Vector2i] = []
	if state.has_hearing():
		hearing_cells = hearing_contacts.presentation_positions()
	else:
		_clear_hearing_context()
	dungeon_viewport.set_presentation(
		floor_data,
		state,
		player_pos,
		magic_traces,
		projectile_traces,
		inspection_cell,
		not inspection_target.is_empty(),
		bool(inspection_target.get("manual", false)),
		ability_target_cells,
		ability_unavailable_cells,
		ability_target_cursor,
		enemy_hit_flashes,
		player_hit_flash_remaining,
		lethal_hit_afterimages,
		hearing_cells,
	)


func _apply_dungeon_layout(enabled: bool) -> void:
	if stats_label == null:
		return
	dungeon_viewport.visible = enabled
	soul_icon.visible = enabled
	if enabled:
		soul_icon.position = Vector2(1080, 22)
		soul_icon.size = Vector2(22, 22)
		title_label.clip_text = true
		title_label.position = Vector2(1080, 86)
		title_label.size = Vector2(184, 20)
		title_label.add_theme_font_size_override("font_size", 9)
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		souls_label.clip_text = true
		souls_label.position = Vector2(1106, 16)
		souls_label.size = Vector2(64, 34)
		souls_label.add_theme_font_size_override("font_size", 9)
		souls_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		souls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		menu_button.position = Vector2(1174, 16)
		menu_button.size = Vector2(90, 34)
		menu_button.add_theme_font_size_override("font_size", 14)
		stats_label.clip_text = true
		stats_label.position = Vector2(1080, 60)
		stats_label.size = Vector2(184, 24)
		stats_label.add_theme_font_size_override("font_size", 12)
		stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_strip.position = Renderer.DUNGEON_STATUS_RECT.position
		status_strip.size = Renderer.DUNGEON_STATUS_RECT.size
		sidebar_progress_label.position = Vector2(1080, 208)
		sidebar_progress_label.size = Vector2(184, 26)
		sidebar_progress_label.add_theme_font_size_override("font_size", 8)
		sidebar_progress_label.add_theme_constant_override("line_spacing", -3)
		equipment_label.visible = false
		inspection_label.position = Vector2(1088, 246)
		inspection_label.size = Vector2(168, 246)
		inspection_label.add_theme_font_size_override("font_size", 9)
		hint_label.position = Vector2(1088, 514)
		hint_label.size = Vector2(168, 22)
		hint_label.add_theme_font_size_override("font_size", 9)
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message_label.position = Vector2(1088, 540)
		message_label.size = Vector2(168, 154)
		message_label.add_theme_font_size_override("normal_font_size", 9)
		message_label.add_theme_constant_override("line_separation", -3)
		message_label.focus_mode = Control.FOCUS_NONE

		attack_button.position = Vector2(8, 674)
		attack_button.size = Vector2(112, 38)
		spell_button.position = Vector2(122, 674)
		spell_button.size = Vector2(120, 38)
		active_2_button.position = Vector2(244, 674)
		active_2_button.size = Vector2(100, 38)
		active_3_button.position = Vector2(346, 674)
		active_3_button.size = Vector2(100, 38)
		wait_button.position = Vector2(448, 674)
		wait_button.size = Vector2(106, 38)
		wait_count_button.position = Vector2(556, 674)
		wait_count_button.size = Vector2(28, 38)
		auto_explore_button.position = Vector2(586, 674)
		auto_explore_button.size = Vector2(110, 38)
		camp_button.position = Vector2(698, 674)
		camp_button.size = Vector2(82, 38)
		character_action_button.position = Vector2(782, 674)
		character_action_button.size = Vector2(126, 38)
		interact_button.position = Vector2(910, 674)
		interact_button.size = Vector2(154, 38)
	else:
		status_strip.visible = false
		status_strip.position = BASE_STATUS_RECT.position
		status_strip.size = BASE_STATUS_RECT.size
		title_label.clip_text = false
		title_label.position = Vector2(28, 20)
		title_label.size = Vector2(790, 48)
		title_label.add_theme_font_size_override("font_size", 28)
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		souls_label.clip_text = false
		souls_label.position = Vector2(28, 56)
		souls_label.size = Vector2(620, 24)
		souls_label.add_theme_font_size_override("font_size", 16)
		souls_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		souls_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		menu_button.position = Vector2(1140, 14)
		menu_button.size = Vector2(106, 42)
		menu_button.add_theme_font_size_override("font_size", 18)
		stats_label.clip_text = false
		stats_label.position = Vector2(846, 78)
		stats_label.size = Vector2(400, 56)
		stats_label.add_theme_font_size_override("font_size", 17)
		stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		sidebar_progress_label.position = Vector2(846, 222)
		sidebar_progress_label.size = Vector2(400, 106)
		sidebar_progress_label.add_theme_font_size_override("font_size", 15)
		sidebar_progress_label.add_theme_constant_override("line_spacing", 0)
		equipment_label.position = Vector2(846, 338)
		equipment_label.size = Vector2(400, 142)
		equipment_label.add_theme_font_size_override("font_size", 14)
		equipment_label.add_theme_constant_override("line_spacing", -1)
		inspection_label.position = Vector2(860, 508)
		inspection_label.size = Vector2(372, 164)
		inspection_label.add_theme_font_size_override("font_size", 16)
		hint_label.position = Vector2(28, 558)
		hint_label.size = Vector2(790, 34)
		hint_label.add_theme_font_size_override("font_size", 16)
		hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		message_label.position = Vector2(28, 602)
		message_label.size = Vector2(790, 106)
		message_label.add_theme_font_size_override("normal_font_size", 16)
		message_label.add_theme_constant_override("line_separation", -2)

		attack_button.position = Vector2(28, 558)
		attack_button.size = Vector2(90, 36)
		spell_button.position = Vector2(120, 558)
		spell_button.size = Vector2(94, 36)
		active_2_button.position = Vector2(216, 558)
		active_2_button.size = Vector2(90, 36)
		active_3_button.position = Vector2(308, 558)
		active_3_button.size = Vector2(90, 36)
		wait_button.position = Vector2(400, 558)
		wait_button.size = Vector2(100, 36)
		wait_count_button.position = Vector2(502, 558)
		wait_count_button.size = Vector2(26, 36)
		auto_explore_button.position = Vector2(530, 558)
		auto_explore_button.size = Vector2(72, 36)
		camp_button.position = Vector2(604, 558)
		camp_button.size = Vector2(60, 36)
		character_action_button.position = Vector2(666, 558)
		character_action_button.size = Vector2(74, 36)
		interact_button.position = Vector2(742, 558)
		interact_button.size = Vector2(76, 36)


func _draw_base() -> void:
	Renderer.draw_base(self, state)


func _draw_victory() -> void:
	Renderer.draw_victory(self)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Renderer.cell_rect(cell)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return GridNavigation.manhattan(a, b)
