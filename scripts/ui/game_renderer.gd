class_name GameRenderer
extends RefCounted

const HearingContactSystem := preload("res://scripts/game/hearing_contact_system.gd")

const Loc := preload("res://scripts/localization/localization.gd")
const Rules := preload("res://scripts/game/game_rules.gd")
const PresentationSettings := preload("res://scripts/system/presentation_settings.gd")
const CharacterSheetLayout := preload("res://scripts/ui/character_sheet_layout.gd")
const BaseLayout := preload("res://scripts/ui/base_layout.gd")

const CAMP_ART: Texture2D = preload("res://assets/art/camp-base-expanded.png")
const CAMP_CRUSHER_ART: Texture2D = preload("res://assets/art/camp-crusher.png")
const CAMP_WHETSTONE_ART: Texture2D = preload("res://assets/art/camp-whetstone.png")
const CAMP_RITUAL_TABLE_ART: Texture2D = preload("res://assets/art/camp-ritual-table.png")
const CAMP_CAMPFIRE_ART: Texture2D = preload("res://assets/art/camp-campfire.png")
const DEATH_BONES_OVERLAY: Texture2D = preload("res://assets/art/death-bones-overlay.png")
const INTRO_ART: Array[Texture2D] = [
	preload("res://assets/art/intro-01-wandering.png"),
	preload("res://assets/art/intro-02-poncho.png"),
	preload("res://assets/art/intro-03-awakening.png"),
]
const DEATH_ART: Texture2D = preload("res://assets/art/death-bones.png")
const SKELETON_EQUIPMENT_ART: Texture2D = preload("res://assets/art/skeleton-equipment.png")
const SOUL_ICON_TEXTURE: Texture2D = preload("res://assets/ui/soul-icon.png")
const DUNGEON_FLOOR_TEXTURE: Texture2D = preload("res://assets/dungeon/floor-stone.png")
const DUNGEON_WALL_TEXTURE: Texture2D = preload("res://assets/dungeon/wall-stone.png")
const DUNGEON_CHEST_SPRITE: Texture2D = preload("res://assets/dungeon/chest.png")
const PLAYER_SKELETON_SPRITE: Texture2D = preload("res://assets/dungeon/player-skeleton.png")
const PLAYER_SPRITES := {
	"skeleton": preload("res://assets/dungeon/player-skeleton.png"),
	"zombie": preload("res://assets/dungeon/player-zombie.png"),
	"ghoul": preload("res://assets/dungeon/player-ghoul.png"),
	"revenant": preload("res://assets/dungeon/player-revenant.png"),
	"almost_human": preload("res://assets/dungeon/player-almost-human.png"),
}
const FORM_PORTRAITS := {
	"skeleton": preload("res://assets/portraits/form-skeleton.png"),
	"zombie": preload("res://assets/portraits/form-zombie.png"),
	"ghoul": preload("res://assets/portraits/form-ghoul.png"),
	"revenant": preload("res://assets/portraits/form-revenant.png"),
	"almost_human": preload("res://assets/portraits/form-almost-human.png"),
}
const FORM_FULLBODY := {
	"skeleton": preload("res://assets/ui/character-fullbody/form-skeleton.png"),
	"zombie": preload("res://assets/ui/character-fullbody/form-zombie.png"),
	"ghoul": preload("res://assets/ui/character-fullbody/form-ghoul.png"),
	"revenant": preload("res://assets/ui/character-fullbody/form-revenant.png"),
	"almost_human": preload("res://assets/ui/character-fullbody/form-almost-human.png"),
}
const PLAYER_FORM_GLYPHS := {
	"skeleton": "GLYPH_FORM_SKELETON",
	"zombie": "GLYPH_FORM_ZOMBIE",
	"ghoul": "GLYPH_FORM_GHOUL",
	"revenant": "GLYPH_FORM_REVENANT",
	"almost_human": "GLYPH_FORM_ALMOST_HUMAN",
}
const ENEMY_SPRITES := {
	"blind_scavenger": preload("res://assets/dungeon/enemy-blind-scavenger.png"),
	"arachnid": preload("res://assets/dungeon/enemy-arachnid.png"),
	"bone_crossbowman": preload("res://assets/dungeon/enemy-bone-crossbowman.png"),
	"slag_smith": preload("res://assets/dungeon/enemy-slag-smith.png"),
	"grave_rat": preload("res://assets/dungeon/enemy-grave-rat.png"),
	"hollow_guard": preload("res://assets/dungeon/enemy-hollow-guard.png"),
	"soul_leech": preload("res://assets/dungeon/enemy-soul-leech.png"),
	"skeletal_archer": preload("res://assets/dungeon/enemy-skeletal-archer.svg"),
	"minotaur": preload("res://assets/dungeon/enemy-minotaur.png"),
}

static var stage1_textures: Dictionary = {}

const BOARD_ORIGIN := Vector2(28, 82)
const DUNGEON_VIEW_RECT := Rect2(8, 8, 1056, 660)
const DUNGEON_SIDEBAR_RECT := Rect2(1072, 8, 200, 704)
const DUNGEON_HP_RECT := Rect2(1080, 116, 184, 26)
const DUNGEON_STATUS_RECT := Rect2(1080, 146, 184, 30)
const DUNGEON_MANA_RECT := Rect2(1080, 180, 184, 26)
const DUNGEON_INSPECTION_RECT := Rect2(1080, 238, 184, 262)
const DUNGEON_HISTORY_RECT := Rect2(1080, 506, 184, 196)
const DUNGEON_ENEMY_HP_RECT := Rect2(1090, 486, 164, 8)
const SELECTION_BORDER_WIDTH := 2.0
const PLAYER_FOOT_GLOW_FOOTPRINT := Vector2(0.46, 0.16)
const PLAYER_FOOT_GLOW_ALPHA := 0.16
const HEARING_MARKER_RADIUS := 13.0
const HEARING_MARKER_OUTLINE_WIDTH := 2.0
const HEARING_MARKER_FONT_SIZE := 22
const CELL_SIZE := PresentationSettings.DEFAULT_CELL_SIZE
static var runtime_cell_size := CELL_SIZE
const MAGIC_TRACE_DURATION := 1.0
const PROJECTILE_TRACE_DURATION := 0.45
const FLOOR_TEXTURE_SAMPLE_SIZE := 176
## A 950 px source sample covers roughly ten times the texture area of the old
## 300 px sample, turning the former four-block look into much finer masonry
## without adding textures or draw calls.
const WALL_TEXTURE_SAMPLE_SIZE := 950
const WALL_MASONRY_DENSITY_FACTOR := 10
const WALL_TINT_VARIANTS: Array[Color] = [
	Color("cbd2dc"),
	Color("d0d5dc"),
	Color("d2d7df"),
	Color("d5d6d6"),
	Color("cdd3d8"),
]
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

const COLOR_BACKGROUND := Color("11151c")
const COLOR_PANEL := Color("1c2330")
const COLOR_PANEL_BORDER := Color("354052")
const COLOR_FLOOR_A := Color("292f3a")
const COLOR_FLOOR_B := Color("252b35")
const COLOR_WALL := Color("505867")
const COLOR_WALL_INNER := Color("3a424f")
const COLOR_TEXT := Color("e6e2d8")
const COLOR_MUTED := Color("9aa3b2")
const COLOR_SOUL := Color("72d7cf")
const COLOR_DANGER := Color("d26060")
const COLOR_GOLD := Color("d4ad62")
const COLOR_PLAYER_RING := Color("f1df91")
const COLOR_PANEL_SHADOW := Color(0.015, 0.02, 0.03, 0.72)
## Remembered walkable cells stay readable enough for navigation, while walls
## retain the denser fog that preserves the boundary contrast.
const COLOR_FOG_MEMORY := Color(0.008, 0.012, 0.02, 0.32)
const COLOR_FOG_WALL_MEMORY := Color(0.008, 0.012, 0.02, 0.78)
const CHARACTER_SKILLS_CARD := CharacterSheetLayout.SKILLS_CARD_RECT


static func draw_frame(
	canvas: CanvasItem,
	viewport_size: Vector2,
	state: RunState,
	show_sidebar: bool,
	show_base_layout: bool,
	show_inspection: bool,
	inspection_target: Dictionary = {},
) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), COLOR_BACKGROUND)
	if not show_sidebar:
		return
	if show_inspection:
		canvas.draw_rect(DUNGEON_VIEW_RECT, Color("0b0e13"))
		canvas.draw_rect(Rect2(DUNGEON_SIDEBAR_RECT.position + Vector2(3, 4), DUNGEON_SIDEBAR_RECT.size), COLOR_PANEL_SHADOW)
		canvas.draw_rect(DUNGEON_SIDEBAR_RECT, COLOR_PANEL)
		canvas.draw_rect(DUNGEON_SIDEBAR_RECT, COLOR_PANEL_BORDER, false, 2.0)
		canvas.draw_line(
			DUNGEON_SIDEBAR_RECT.position + Vector2(2, 2),
			Vector2(DUNGEON_SIDEBAR_RECT.end.x - 2, DUNGEON_SIDEBAR_RECT.position.y + 2),
			Color(COLOR_SOUL, 0.38),
			2.0,
		)
		draw_resource_bar(
			canvas, DUNGEON_HP_RECT, state.hp, state.get_max_hp(),
			Loc.text("PARAM_HP"), Color("a84450"),
			("+%d" % state.get_temporary_hp()) if state.get_temporary_hp() > 0 else "",
		)
		draw_resource_bar(
			canvas, DUNGEON_MANA_RECT, state.mana, state.get_max_mana(),
			Loc.text("PARAM_MANA"), Color("496ead"),
		)
		canvas.draw_rect(DUNGEON_INSPECTION_RECT, Color("171d27"))
		canvas.draw_rect(DUNGEON_INSPECTION_RECT, COLOR_GOLD, false, 2.0)
		if String(inspection_target.get("kind", "")) == "enemy":
			var enemy: Dictionary = inspection_target.get("entity", {})
			var maximum_hp := maxi(1, int(enemy.get("max_hp", 1)))
			var current_hp := clampi(int(enemy.get("hp", maximum_hp)), 0, maximum_hp)
			canvas.draw_rect(DUNGEON_ENEMY_HP_RECT, Color("10151d"))
			canvas.draw_rect(Rect2(
				DUNGEON_ENEMY_HP_RECT.position,
				Vector2(DUNGEON_ENEMY_HP_RECT.size.x * float(current_hp) / maximum_hp, DUNGEON_ENEMY_HP_RECT.size.y),
			), Color("a84450"))
			canvas.draw_rect(DUNGEON_ENEMY_HP_RECT, COLOR_PANEL_BORDER, false, 1.0)
		canvas.draw_rect(DUNGEON_HISTORY_RECT, Color("141a23"))
		canvas.draw_rect(DUNGEON_HISTORY_RECT, COLOR_PANEL_BORDER, false, 2.0)
		return
	var sidebar_rect := BaseLayout.SIDEBAR_RECT if show_base_layout else Rect2(828, 62, 428, 640)
	var shadow_rect := (
		BaseLayout.SIDEBAR_SHADOW_RECT
		if show_base_layout else Rect2(834, 68, 428, 640)
	)
	var hp_rect := BaseLayout.HP_RECT if show_base_layout else Rect2(846, 140, 400, 28)
	var mana_rect := BaseLayout.MANA_RECT if show_base_layout else Rect2(846, 180, 400, 28)
	canvas.draw_rect(shadow_rect, COLOR_PANEL_SHADOW)
	canvas.draw_rect(sidebar_rect, COLOR_PANEL)
	canvas.draw_rect(sidebar_rect, COLOR_PANEL_BORDER, false, 2.0)
	canvas.draw_line(
		sidebar_rect.position + Vector2(2, 2),
		Vector2(sidebar_rect.end.x - 2, sidebar_rect.position.y + 2),
		Color(COLOR_SOUL, 0.38), 2.0,
	)
	draw_resource_bar(
		canvas,
		hp_rect,
		state.hp,
		state.get_max_hp(),
		Loc.text("PARAM_HP"),
		Color("a84450"),
	)
	draw_resource_bar(
		canvas,
		mana_rect,
		state.mana,
		state.get_max_mana(),
		Loc.text("PARAM_MANA"),
		Color("496ead"),
	)
	if show_inspection:
		var inspection_frame := Rect2(Vector2(846, 494), Vector2(400, 188))
		canvas.draw_rect(inspection_frame, Color("171d27"))
		canvas.draw_rect(inspection_frame, COLOR_GOLD, false, 2.0)


static func draw_resource_bar(
	canvas: CanvasItem,
	rect: Rect2,
	current_value: int,
	maximum_value: int,
	label: String,
	fill_color: Color,
	value_suffix := "",
) -> void:
	canvas.draw_rect(rect, Color("10151d"))
	var ratio := clampf(float(current_value) / float(maxi(1, maximum_value)), 0.0, 1.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill_color)
	canvas.draw_rect(rect, COLOR_PANEL_BORDER, false, 2.0)
	_draw_centered_text(
		canvas,
		rect,
		"%s  %d / %d%s" % [
			label, current_value, maximum_value,
			("  %s" % value_suffix) if not value_suffix.is_empty() else "",
		],
		COLOR_TEXT,
		15,
	)


static func draw_name_creation(canvas: CanvasItem) -> void:
	var card := Rect2(Vector2(300, 180), Vector2(680, 300))
	canvas.draw_rect(Rect2(card.position + Vector2(0, 6), card.size), COLOR_PANEL_SHADOW)
	canvas.draw_rect(card, COLOR_PANEL)
	canvas.draw_rect(card, COLOR_PANEL_BORDER, false, 2.0)
	canvas.draw_circle(Vector2(640, 165), 42, Color("314c50"))
	canvas.draw_circle(Vector2(640, 165), 52, Color(COLOR_SOUL, 0.45), false, 3.0, true)


static func draw_stat_creation(canvas: CanvasItem) -> void:
	for index in range(Rules.ATTRIBUTE_ORDER.size()):
		var x := 38.0 + index * 247.0
		var card := Rect2(Vector2(x, 180), Vector2(216, 158))
		canvas.draw_rect(Rect2(card.position + Vector2(0, 4), card.size), COLOR_PANEL_SHADOW)
		canvas.draw_rect(card, COLOR_PANEL)
		canvas.draw_rect(card, COLOR_PANEL_BORDER, false, 2.0)
	var preview_card := Rect2(Vector2(170, 370), Vector2(940, 210))
	canvas.draw_rect(Rect2(preview_card.position + Vector2(0, 5), preview_card.size), COLOR_PANEL_SHADOW)
	canvas.draw_rect(preview_card, COLOR_PANEL)
	canvas.draw_rect(preview_card, COLOR_PANEL_BORDER, false, 2.0)


static func draw_story(
	canvas: CanvasItem,
	viewport_size: Vector2,
	story_kind: String,
	story_index: int,
) -> void:
	if story_kind == "death":
		canvas.draw_texture_rect(CAMP_ART, Rect2(Vector2.ZERO, viewport_size), false)
		canvas.draw_texture_rect(
			DEATH_BONES_OVERLAY,
			Rect2(Vector2(260, 330), Vector2(760, 360)),
			false,
		)
		return
	var texture := INTRO_ART[clampi(story_index, 0, INTRO_ART.size() - 1)]
	canvas.draw_texture_rect(texture, Rect2(Vector2.ZERO, viewport_size), false)


static func draw_character_sheet(
	canvas: CanvasItem,
	state: RunState,
	panel_mode: String,
	selected_stage: String,
) -> void:
	if panel_mode == "inventory":
		for card in [
			CharacterSheetLayout.STATS_CARD_RECT,
			CharacterSheetLayout.FIGURE_CARD_RECT,
			CharacterSheetLayout.INVENTORY_CARD_RECT,
		]:
			canvas.draw_rect(Rect2(card.position + Vector2(0, 4), card.size), COLOR_PANEL_SHADOW)
			canvas.draw_rect(card, COLOR_PANEL)
			canvas.draw_rect(card, COLOR_PANEL_BORDER, false, 2.0)
		var figure_rect: Rect2 = CharacterSheetLayout.FIGURE_RECT
		canvas.draw_rect(figure_rect, Color("121720"))
		var visual_form_id := player_visual_form_id(state)
		var fullbody: Texture2D = FORM_FULLBODY.get(visual_form_id)
		if fullbody != null:
			canvas.draw_texture_rect_region(
				fullbody,
				figure_rect,
				CharacterSheetLayout.FIGURE_SOURCE_RECT,
				Color.WHITE,
				false,
				true,
			)
		canvas.draw_line(
			Vector2(figure_rect.position.x + 24.0, CharacterSheetLayout.FIGURE_BASELINE_Y),
			Vector2(figure_rect.end.x - 24.0, CharacterSheetLayout.FIGURE_BASELINE_Y),
			Color(COLOR_PANEL_BORDER, 0.42), 1.0,
		)
		return

	var skills_card := CHARACTER_SKILLS_CARD
	canvas.draw_rect(Rect2(skills_card.position + Vector2(0, 5), skills_card.size), COLOR_PANEL_SHADOW)
	canvas.draw_rect(skills_card, COLOR_PANEL)
	canvas.draw_rect(skills_card, COLOR_PANEL_BORDER, false, 2.0)
	if selected_stage != "skeleton":
		return
	var node_edges := [
		{"from": Vector2(325, 311), "to": Vector2(350, 311), "skill": "strong_bones"},
		{"from": Vector2(570, 311), "to": Vector2(595, 311), "skill": "fundamentals"},
		{"from": Vector2(815, 311), "to": Vector2(840, 311), "skill": "fundamentals"},
		{"from": Vector2(325, 455), "to": Vector2(350, 455), "skill": "magic_awakening"},
		{"from": Vector2(570, 455), "to": Vector2(595, 455), "skill": "magic_missile"},
		{"from": Vector2(815, 455), "to": Vector2(840, 455), "skill": "magic_missile_range"},
	]
	for edge in node_edges:
		var edge_color := COLOR_PANEL_BORDER
		if state.get_skill_level(String(edge["skill"])) > 0:
			edge_color = COLOR_SOUL
		canvas.draw_line(edge["from"], edge["to"], edge_color, 4.0)


static func draw_dungeon(
	canvas: CanvasItem,
	floor_data: Dictionary,
	state: RunState,
	player_pos: Vector2i,
	magic_traces: Array[Dictionary],
	projectile_traces: Array[Dictionary],
	inspection_cell: Vector2i,
	has_inspection: bool,
	manual_inspection: bool,
	ability_target_cells: Array[Vector2i] = [],
	ability_unavailable_cells: Dictionary = {},
	ability_target_cursor := Vector2i(-1, -1),
	enemy_hit_flashes: Dictionary = {},
	player_hit_flash_remaining := 0.0,
	lethal_hit_afterimages: Array[Dictionary] = [],
	hearing_contact_cells: Array[Vector2i] = [],
) -> void:
	var tiles: Dictionary = floor_data["tiles"]
	var boss_door: Vector2i = floor_data.get("boss_door", Vector2i(-1, -1))
	for y in range(floor_data["height"]):
		for x in range(floor_data["width"]):
			var cell := Vector2i(x, y)
			var rect := cell_rect(cell)
			if not _is_cell_explored(floor_data, cell):
				continue
			var visible_now := _is_cell_visible(floor_data, cell)
			if tiles[cell] == "void":
				continue
			elif tiles[cell] == "wall":
				if _is_perimeter_wall(tiles, cell):
					_draw_thin_perimeter_wall(canvas, tiles, cell, rect)
					if not visible_now:
						canvas.draw_rect(rect, COLOR_FOG_WALL_MEMORY)
					continue
				canvas.draw_rect(rect, COLOR_WALL)
				_draw_dungeon_texture(
					canvas,
					DUNGEON_WALL_TEXTURE,
					rect.grow(-2),
					cell,
					wall_texture_tint(cell),
					WALL_TEXTURE_SAMPLE_SIZE,
				)
				canvas.draw_rect(rect.grow(-6), Color(0.08, 0.10, 0.13, 0.18), false, 2.0)
			else:
				var floor_tint := Color("b0b8c2") if (x + y) % 2 == 0 else Color("a3acb7")
				_draw_dungeon_texture(canvas, DUNGEON_FLOOR_TEXTURE, rect, cell, floor_tint)
				_draw_floor_decoration(canvas, floor_data, cell, rect)
				if cell == boss_door:
					_draw_boss_door(canvas, rect, bool(floor_data.get("boss_door_open", false)))
				else:
					var room := GridNavigation.room_at_door(floor_data, cell)
					if not room.is_empty():
						_draw_door(canvas, rect, tiles[cell] == "floor", room["outward"].x != 0)
			canvas.draw_rect(rect, Color(0.10, 0.13, 0.17, 0.74), false, 2.0)
			if not visible_now:
				canvas.draw_rect(
					rect,
					COLOR_FOG_WALL_MEMORY if tiles[cell] == "wall" else COLOR_FOG_MEMORY,
				)
	for target_cell in ability_target_cells:
		var target_rect := cell_rect(target_cell).grow(-4)
		canvas.draw_rect(target_rect, Color(0.22, 0.78, 0.74, 0.11))
		canvas.draw_rect(target_rect, COLOR_SOUL, false, 2.0)
	for invalid_cell_variant in ability_unavailable_cells:
		var invalid_cell: Vector2i = invalid_cell_variant
		if String(ability_unavailable_cells[invalid_cell]) == "hidden":
			continue
		var invalid_rect := cell_rect(invalid_cell).grow(-5)
		canvas.draw_rect(invalid_rect, Color(0.31, 0.35, 0.42, 0.09))
		_draw_dashed_rect(canvas, invalid_rect, Color(0.46, 0.50, 0.58, 0.72), 1.0)
		var invalid_center := invalid_rect.get_center()
		canvas.draw_line(invalid_center - Vector2(3, 3), invalid_center + Vector2(3, 3), Color(0.58, 0.61, 0.67, 0.78), 1.0)
		canvas.draw_line(invalid_center + Vector2(3, -3), invalid_center + Vector2(-3, 3), Color(0.58, 0.61, 0.67, 0.78), 1.0)
	if ability_target_cursor.x >= 0:
		_draw_corner_ticks(canvas, cell_rect(ability_target_cursor).grow(-3), COLOR_GOLD, 2.0)

	if _is_cell_observed(floor_data, floor_data["start"]):
		_draw_marker(
			canvas,
			floor_data["start"],
			Loc.text("GLYPH_START"),
			_fog_marker_color(floor_data, floor_data["start"], Color("6a7383")),
		)
	if _is_cell_observed(floor_data, floor_data["base_gate"]):
		_draw_marker(
			canvas,
			floor_data["base_gate"],
			Loc.text("GLYPH_BASE"),
			_fog_marker_color(floor_data, floor_data["base_gate"], Color("4f8f78")),
		)
	if bool(floor_data.get("exit_known", false)):
		_draw_marker(
			canvas,
			floor_data["exit"],
			"↑",
			_fog_marker_color(floor_data, floor_data["exit"], Color("b58a45")),
		)
	var cradle_position: Vector2i = floor_data.get("cradle", Vector2i(-1, -1))
	if cradle_position.x >= 0 and bool(floor_data.get("cradle_known", false)):
		var cradle_color := (
			Color("78618f") if not bool(floor_data.get("cradle_used", false)) else Color("505461")
		)
		_draw_marker(
			canvas,
			cradle_position,
			"Ω",
			_fog_marker_color(floor_data, cradle_position, cradle_color),
		)

	for item in floor_data["items"]:
		if _is_cell_observed(floor_data, item["pos"]):
			_draw_chest_sprite(
				canvas,
				item["pos"],
				_is_cell_visible(floor_data, item["pos"]),
				String(item.get("appearance", "chest")),
			)
	_draw_enemy_preparations(canvas, floor_data)
	_draw_magic_traces(canvas, magic_traces)
	_draw_projectile_traces(canvas, projectile_traces)
	for hearing_cell in hearing_contact_cells:
		if not HearingContactSystem.is_contact_presented(
			true, floor_data, player_pos, hearing_cell,
		):
			continue
		_draw_hearing_contact(canvas, hearing_cell)

	for enemy in floor_data["enemies"]:
		if not _is_cell_visible(floor_data, enemy["pos"]):
			continue
		var enemy_rules: Dictionary = Rules.ENEMIES[enemy["id"]]
		var rect := cell_rect(enemy["pos"]).grow(-runtime_cell_size * 0.12)
		var footprint: Vector2 = enemy_rules.get("draw_footprint", Vector2.ONE)
		var shadow_center := cell_rect(enemy["pos"]).get_center() + Vector2(0, runtime_cell_size * 0.30)
		_draw_ellipse(
			canvas, shadow_center,
			Vector2(runtime_cell_size * 0.28, runtime_cell_size * 0.09),
			Color(0.02, 0.025, 0.035, 0.58),
		)
		var enemy_texture: Texture2D = enemy_texture(String(enemy["id"]))
		var flash_remaining := float(enemy_hit_flashes.get(String(enemy.get("uid", "")), 0.0))
		if enemy_texture != null:
			_draw_entity_sprite(
				canvas, enemy_texture, enemy["pos"], footprint,
				_hit_flash_modulate(flash_remaining),
			)
		else:
			_draw_centered_text(canvas, rect, Loc.text(String(enemy_rules["glyph"])), Color.WHITE, 28)

	for afterimage in lethal_hit_afterimages:
		var afterimage_cell: Vector2i = afterimage.get("pos", Vector2i(-1, -1))
		if afterimage_cell.x < 0 or not _is_cell_visible(floor_data, afterimage_cell):
			continue
		var afterimage_texture: Texture2D = enemy_texture(String(afterimage.get("enemy_id", "")))
		if afterimage_texture == null:
			continue
		var afterimage_duration := maxf(0.001, float(afterimage.get("duration", 0.22)))
		var afterimage_alpha := 0.55 * clampf(
			float(afterimage.get("remaining", 0.0)) / afterimage_duration, 0.0, 1.0,
		)
		var afterimage_rules: Dictionary = Rules.ENEMIES.get(
			String(afterimage.get("enemy_id", "")), {},
		)
		_draw_entity_sprite(
			canvas,
			afterimage_texture,
			afterimage_cell,
			afterimage_rules.get("draw_footprint", Vector2.ONE),
			Color(1.0, 0.12, 0.12, afterimage_alpha),
		)

	if has_inspection and manual_inspection and _is_cell_visible(floor_data, inspection_cell):
		var inspection_color := COLOR_GOLD if manual_inspection else COLOR_SOUL
		canvas.draw_rect(cell_rect(inspection_cell).grow(-2), inspection_color, false, SELECTION_BORDER_WIDTH)

	var visual_form_id := player_visual_form_id(state)
	var player_cell_rect := cell_rect(player_pos)
	_draw_ellipse(
		canvas,
		player_cell_rect.position + Vector2(runtime_cell_size * 0.5, runtime_cell_size * 0.90),
		Vector2(runtime_cell_size, runtime_cell_size) * PLAYER_FOOT_GLOW_FOOTPRINT * 0.5,
		Color(COLOR_PLAYER_RING, PLAYER_FOOT_GLOW_ALPHA),
	)
	var player_texture: Texture2D = PLAYER_SPRITES.get(visual_form_id)
	if player_texture != null:
		_draw_entity_sprite(
			canvas, player_texture, player_pos, Vector2.ONE,
			_hit_flash_modulate(player_hit_flash_remaining),
		)


static func player_visual_form_id(state: RunState) -> String:
	return state.get_display_form_id()


static func _stage1_texture(path: String) -> Texture2D:
	if not stage1_textures.has(path) and ResourceLoader.exists(path):
		stage1_textures[path] = load(path)
	return stage1_textures.get(path)


static func enemy_texture(enemy_id: String) -> Texture2D:
	return ENEMY_SPRITES.get(enemy_id)


static func _draw_floor_decoration(canvas: CanvasItem, floor: Dictionary, cell: Vector2i, rect: Rect2) -> void:
	if not _is_cell_observed(floor, cell):
		return
	var decoration: Dictionary = floor.get("decorations", {}).get(cell, {})
	if decoration.is_empty():
		return
	var path := "res://assets/dungeon/decor-%s-%d.png" % [decoration.kind, int(decoration.variant) + 1]
	var texture := _stage1_texture(path)
	if texture != null:
		canvas.draw_texture_rect(texture, rect if decoration.kind == "mosaic" else rect.grow(-runtime_cell_size * 0.08), false, Color(0.75, 0.77, 0.80, 0.72))


static func enemy_telegraph_cells(floor: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not enemy.has("preparation") or not _is_cell_visible(floor, enemy.pos):
		return result
	var target: Vector2i = enemy.preparation.target
	var cells: Array[Vector2i] = []
	if String(enemy.id) == "bone_crossbowman":
		cells = GridNavigation.supercover_trace(enemy.pos, target)
	else:
		cells.append(target)
	for cell in cells:
		if _is_cell_visible(floor, cell):
			result.append(cell)
	return result


static func _draw_enemy_preparations(canvas: CanvasItem, floor: Dictionary) -> void:
	for enemy in floor.enemies:
		var cells := enemy_telegraph_cells(floor, enemy)
		if cells.is_empty():
			continue
		if String(enemy.id) == "slag_smith":
			var rect := cell_rect(cells[0]).grow(-3)
			canvas.draw_rect(rect, Color(0.95, 0.36, 0.18, 0.14))
			_draw_dashed_rect(canvas, rect, Color(1.0, 0.55, 0.25, 0.94), 2.0)
		else:
			var from := cell_rect(enemy.pos).get_center()
			var to := cell_rect(enemy.preparation.target).get_center()
			for cell in cells:
				var clipped := _clip_segment_to_rect(from, to, cell_rect(cell))
				if clipped.size() == 2:
					_draw_dashed_segment(canvas, clipped[0], clipped[1], Color(0.97, 0.64, 0.28, 0.95), 2.0)


static func _clip_segment_to_rect(from: Vector2, to: Vector2, rect: Rect2) -> PackedVector2Array:
	var delta := to - from
	var low := 0.0
	var high := 1.0
	for axis in range(2):
		if absf(delta[axis]) < 0.0001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return PackedVector2Array()
		else:
			var a := (rect.position[axis] - from[axis]) / delta[axis]
			var b := (rect.end[axis] - from[axis]) / delta[axis]
			low = maxf(low, minf(a, b))
			high = minf(high, maxf(a, b))
			if low > high:
				return PackedVector2Array()
	return PackedVector2Array([from + delta * low, from + delta * high])


static func draw_base(canvas: CanvasItem, state: RunState = null) -> void:
	var area := BaseLayout.IMAGE_RECT
	canvas.draw_texture_rect(CAMP_ART, area, false)
	canvas.draw_rect(area, Color(0.02, 0.025, 0.035, 0.10))
	if state != null:
		for station in ["kettle", "bunk", "mural"]:
			if bool(state.camp_upgrades.get(station, false)):
				var texture := _stage1_texture("res://assets/art/camp-%s.png" % station)
				if texture != null:
					canvas.draw_texture_rect(texture, BaseLayout.station_overlay_rect(station), false)
	if state != null and bool(state.camp_upgrades.get("crusher", false)):
		canvas.draw_texture_rect(
			CAMP_CRUSHER_ART,
			BaseLayout.station_overlay_rect("crusher"),
			false,
		)
	if state != null and bool(state.camp_upgrades.get("whetstone", false)):
		canvas.draw_texture_rect(
			CAMP_WHETSTONE_ART,
			BaseLayout.station_overlay_rect("whetstone"),
			false,
		)
	if state != null and bool(state.camp_upgrades.get("ritual_table", false)):
		canvas.draw_texture_rect(
			CAMP_RITUAL_TABLE_ART,
			BaseLayout.station_overlay_rect("ritual_table"),
			false,
		)
	if state != null and bool(state.camp_upgrades.get("campfire", false)):
		canvas.draw_texture_rect(
			CAMP_CAMPFIRE_ART,
			BaseLayout.station_overlay_rect("campfire"),
			false,
		)
	canvas.draw_rect(area, COLOR_PANEL_BORDER, false, 2.0)


static func draw_victory(canvas: CanvasItem) -> void:
	var area := Rect2(BOARD_ORIGIN, Vector2(780, 458))
	canvas.draw_rect(area, Color("2b2924"))
	canvas.draw_rect(area, COLOR_GOLD, false, 3.0)
	for index in range(18):
		var x := area.position.x + 20 + index * 43
		canvas.draw_line(
			Vector2(x, area.position.y),
			Vector2(x - 90, area.end.y),
			Color(0.95, 0.85, 0.55, 0.12),
			16,
		)
	_draw_centered_text(
		canvas,
		Rect2(area.position + Vector2(100, 135), Vector2(580, 100)),
		Loc.text("EXIT_CENTER"),
		Color("f3dda1"),
		30,
	)


static func set_runtime_cell_size(value: int) -> void:
	runtime_cell_size = PresentationSettings.sanitize_cell_size(value)


static func cell_rect(cell: Vector2i, cell_size := -1) -> Rect2:
	var resolved_size := (
		runtime_cell_size
		if cell_size <= 0
		else PresentationSettings.sanitize_cell_size(cell_size)
	)
	return Rect2(Vector2(cell) * resolved_size, Vector2(resolved_size, resolved_size))


static func _draw_dungeon_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	rect: Rect2,
	cell: Vector2i,
	tint: Color = Color.WHITE,
	sample_size := FLOOR_TEXTURE_SAMPLE_SIZE,
) -> void:
	var sample_extent := mini(sample_size, mini(texture.get_width(), texture.get_height()))
	var longest_side := maxf(1.0, maxf(rect.size.x, rect.size.y))
	var source_size := Vector2(
		maxf(1.0, sample_extent * rect.size.x / longest_side),
		maxf(1.0, sample_extent * rect.size.y / longest_side),
	)
	var max_source_x := maxf(1.0, texture.get_width() - source_size.x)
	var max_source_y := maxf(1.0, texture.get_height() - source_size.y)
	var source_x := fposmod(float(cell.x * 173 + cell.y * 67), max_source_x)
	var source_y := fposmod(float(cell.y * 149 + cell.x * 43), max_source_y)
	var source_rect := Rect2(Vector2(source_x, source_y), source_size)
	canvas.draw_texture_rect_region(texture, rect, source_rect, tint)


static func wall_texture_tint(cell: Vector2i) -> Color:
	# A coordinate hash gives stable variation across redraws, saves and devices.
	# Five close tints break repetition without RNG state or per-floor resources.
	var tint_index := posmod(
		cell.x * 73 + cell.y * 151 + cell.x * cell.y * 7,
		WALL_TINT_VARIANTS.size(),
	)
	return WALL_TINT_VARIANTS[tint_index]


static func _draw_chest_sprite(canvas: CanvasItem, cell: Vector2i, visible_now: bool, appearance := "chest") -> void:
	var logical_rect := cell_rect(cell)
	if visible_now:
		# The sprite is deliberately brighter than the dungeon palette so a chest
		# stays readable at one-cell scale without a costly animated effect.
		canvas.draw_circle(
			logical_rect.get_center() + Vector2(0, 2),
			28.0,
			Color(0.78, 0.49, 0.16, 0.30),
		)
	var shadow_color := Color(0.02, 0.025, 0.035, 0.42 if visible_now else 0.34)
	canvas.draw_circle(logical_rect.get_center() + Vector2(0, 8), 20.0, shadow_color)
	var modulate := (
		Color(1.62, 1.42, 1.12, 1.0)
		if visible_now
		else Color(0.34, 0.37, 0.42, 0.82)
	)
	var texture := _stage1_texture("res://assets/dungeon/chest-crypt.png") if appearance == "crypt" else DUNGEON_CHEST_SPRITE
	if texture != null:
		_draw_entity_sprite(canvas, texture, cell, Vector2(0.85, 0.85) if appearance == "crypt" else Vector2(0.88, 0.88), modulate)


static func _draw_entity_sprite(
	canvas: CanvasItem,
	texture: Texture2D,
	cell: Vector2i,
	visual_footprint := Vector2.ONE,
	modulate := Color.WHITE,
) -> void:
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var footprint := Vector2(
		clampf(visual_footprint.x, 0.1, 1.5),
		clampf(visual_footprint.y, 0.1, 2.0),
	)
	var available_size := Vector2(runtime_cell_size, runtime_cell_size) * footprint - Vector2(4, 4)
	var scale_ratio := minf(
		available_size.x / source_size.x,
		available_size.y / source_size.y,
	)
	var draw_size := source_size * scale_ratio
	var logical_rect := cell_rect(cell)
	var draw_position := Vector2(
		logical_rect.get_center().x - draw_size.x * 0.5,
		logical_rect.end.y - draw_size.y - 2.0,
	)
	var draw_rect := Rect2(draw_position, draw_size)
	canvas.draw_texture_rect(texture, draw_rect, false, modulate)


static func _draw_boss_door(canvas: CanvasItem, rect: Rect2, open: bool) -> void:
	_draw_door(canvas, rect, open, false, true)


static func _draw_door(
	canvas: CanvasItem, rect: Rect2, open: bool, horizontal: bool, boss := false,
) -> void:
	var size := rect.size.x
	var frame := Color("9a7755") if boss else Color("786448")
	# All geometry is proportional to one logical tile, including stroke width.
	# An open door has a clear center and permanent jambs on the wall sides.
	for x in [0.12, 0.88]:
		canvas.draw_line(
			_door_point(rect, Vector2(x, 0.1), horizontal),
			_door_point(rect, Vector2(x, 0.9), horizontal), frame, size * 0.12,
		)
	if open:
		canvas.draw_line(
			_door_point(rect, Vector2(0.22, 0.72), horizontal),
			_door_point(rect, Vector2(0.78, 0.72), horizontal),
			Color("685b4b"), size * 0.035,
		)
		return
	var slab := rect.grow(-size * 0.2)
	canvas.draw_rect(slab, Color("473629") if not boss else Color("3c2926"))
	canvas.draw_rect(slab, frame, false, size * 0.035)
	for x in [0.35, 0.5, 0.65]:
		canvas.draw_line(
			_door_point(rect, Vector2(x, 0.23), horizontal),
			_door_point(rect, Vector2(x, 0.77), horizontal), Color("251f1c"), size * 0.025,
		)
	if boss:
		canvas.draw_line(
			_door_point(rect, Vector2(0.23, 0.5), horizontal),
			_door_point(rect, Vector2(0.77, 0.5), horizontal), Color("b17a58"), size * 0.08,
		)
		canvas.draw_circle(rect.get_center(), size * 0.075, Color("d1a15f"))
	else:
		canvas.draw_circle(_door_point(rect, Vector2(0.69, 0.55), horizontal), size * 0.04, frame)


static func _door_point(rect: Rect2, point: Vector2, horizontal: bool) -> Vector2:
	return rect.position + (Vector2(point.y, point.x) if horizontal else point) * rect.size


static func _draw_magic_traces(canvas: CanvasItem, magic_traces: Array[Dictionary]) -> void:
	for trace in magic_traces:
		var ratio := clampf(
			float(trace["remaining"]) / MAGIC_TRACE_DURATION,
			0.0,
			1.0,
		)
		var from_position := cell_rect(trace["from"]).get_center()
		var to_position := cell_rect(trace["to"]).get_center()
		var glow_color := Color(0.38, 0.82, 1.0, 0.20 * ratio)
		var core_color := Color(0.76, 0.96, 1.0, 0.95 * ratio)
		canvas.draw_line(from_position, to_position, glow_color, 22.0, true)
		canvas.draw_line(from_position, to_position, core_color, 6.0, true)
		canvas.draw_circle(to_position, 14.0, Color(0.65, 0.90, 1.0, 0.35 * ratio))
		canvas.draw_circle(to_position, 8.0, core_color)


static func _draw_projectile_traces(
	canvas: CanvasItem,
	projectile_traces: Array[Dictionary],
) -> void:
	for trace in projectile_traces:
		var remaining_ratio := clampf(
			float(trace["remaining"]) / PROJECTILE_TRACE_DURATION,
			0.0,
			1.0,
		)
		var progress := 1.0 - remaining_ratio
		var from_position := cell_rect(trace["from"]).get_center()
		var to_position := cell_rect(trace["to"]).get_center()
		var warm_line := Color(0.94, 0.64, 0.27, 0.62 * remaining_ratio)
		var warm_tip := Color(1.0, 0.84, 0.48, 0.98 * remaining_ratio)
		canvas.draw_line(from_position, to_position, warm_line, 3.0, true)
		var tip_position := from_position.lerp(to_position, progress)
		canvas.draw_circle(tip_position, 6.4, warm_tip)
		var direction := (to_position - from_position).normalized()
		if direction != Vector2.ZERO:
			var side := Vector2(-direction.y, direction.x)
			canvas.draw_colored_polygon(PackedVector2Array([
				tip_position + direction * 10.0,
				tip_position - direction * 6.0 + side * 5.0,
				tip_position - direction * 6.0 - side * 5.0,
			]), warm_tip)


static func _is_perimeter_wall(tiles: Dictionary, cell: Vector2i) -> bool:
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			if tiles.get(cell + Vector2i(x_offset, y_offset), "void") == "void":
				return true
	return false


static func _draw_thin_perimeter_wall(
	canvas: CanvasItem,
	tiles: Dictionary,
	cell: Vector2i,
	rect: Rect2,
) -> void:
	const THICKNESS := 14.0
	var floor_neighbors := 0
	for direction in CARDINAL_DIRECTIONS:
		if tiles.get(cell + direction, "void") != "floor":
			continue
		floor_neighbors += 1
		var strip := Rect2()
		match direction:
			Vector2i.LEFT:
				strip = Rect2(rect.position, Vector2(THICKNESS, rect.size.y))
			Vector2i.RIGHT:
				strip = Rect2(
					Vector2(rect.end.x - THICKNESS, rect.position.y),
					Vector2(THICKNESS, rect.size.y),
				)
			Vector2i.UP:
				strip = Rect2(rect.position, Vector2(rect.size.x, THICKNESS))
			Vector2i.DOWN:
				strip = Rect2(
					Vector2(rect.position.x, rect.end.y - THICKNESS),
					Vector2(rect.size.x, THICKNESS),
				)
		canvas.draw_rect(strip, COLOR_WALL)
		_draw_dungeon_texture(
			canvas,
			DUNGEON_WALL_TEXTURE,
			strip,
			cell + direction,
			wall_texture_tint(cell),
			WALL_TEXTURE_SAMPLE_SIZE,
		)
		canvas.draw_line(strip.position, Vector2(strip.end.x, strip.position.y), COLOR_WALL_INNER, 4.0)
	if floor_neighbors > 0:
		return
	for y_offset in [-1, 1]:
		for x_offset in [-1, 1]:
			if tiles.get(cell + Vector2i(x_offset, y_offset), "void") != "floor":
				continue
			var corner_position := Vector2(
				rect.position.x if x_offset < 0 else rect.end.x - THICKNESS,
				rect.position.y if y_offset < 0 else rect.end.y - THICKNESS,
			)
			var corner_rect := Rect2(corner_position, Vector2(THICKNESS, THICKNESS))
			canvas.draw_rect(corner_rect, COLOR_WALL)
			_draw_dungeon_texture(
				canvas,
				DUNGEON_WALL_TEXTURE,
				corner_rect,
				cell + Vector2i(x_offset, y_offset),
				wall_texture_tint(cell),
				WALL_TEXTURE_SAMPLE_SIZE,
			)


static func _draw_marker(canvas: CanvasItem, cell: Vector2i, glyph: String, color: Color) -> void:
	var rect := cell_rect(cell).grow(-6)
	canvas.draw_rect(rect, color)
	_draw_centered_text(canvas, rect, glyph, Color.WHITE, 28)


## Compatibility probe retained for renderer tests; presentation and input both
## use HearingContactSystem.is_contact_presented as the authoritative policy.
static func _hearing_cell_has_visible_occupant(
	floor_data: Dictionary,
	player_pos: Vector2i,
	cell: Vector2i,
) -> bool:
	return not HearingContactSystem.is_contact_presented(true, floor_data, player_pos, cell)


static func _draw_hearing_contact(canvas: CanvasItem, cell: Vector2i) -> void:
	var center := cell_rect(cell).get_center()
	canvas.draw_circle(center, HEARING_MARKER_RADIUS, Color(0.063, 0.082, 0.114, 0.94))
	canvas.draw_arc(
		center, HEARING_MARKER_RADIUS, 0.0, TAU, 32,
		Color(0.604, 0.639, 0.698, 0.82), HEARING_MARKER_OUTLINE_WIDTH, true,
	)
	var font := ThemeDB.fallback_font
	var glyph := "?"
	var glyph_size := font.get_string_size(
		glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, HEARING_MARKER_FONT_SIZE,
	)
	var baseline := center + Vector2(
		-glyph_size.x * 0.5,
		(font.get_ascent(HEARING_MARKER_FONT_SIZE) - font.get_descent(HEARING_MARKER_FONT_SIZE)) * 0.5,
	)
	canvas.draw_string(
		font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		HEARING_MARKER_FONT_SIZE, Color(0.902, 0.886, 0.847, 0.98),
	)


static func _draw_dashed_rect(
	canvas: CanvasItem,
	rect: Rect2,
	color: Color,
	width: float,
) -> void:
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for index in range(corners.size()):
		_draw_dashed_segment(canvas, corners[index], corners[(index + 1) % 4], color, width)


static func _draw_dashed_segment(
	canvas: CanvasItem,
	from: Vector2,
	to: Vector2,
	color: Color,
	width: float,
) -> void:
	var length := from.distance_to(to)
	if length <= 0.0:
		return
	var direction := (to - from) / length
	var offset := 0.0
	while offset < length:
		var dash_end := minf(offset + 3.0, length)
		canvas.draw_line(from + direction * offset, from + direction * dash_end, color, width)
		offset += 6.0


static func _draw_corner_ticks(
	canvas: CanvasItem,
	rect: Rect2,
	color: Color,
	width: float,
) -> void:
	var tick := minf(8.0, minf(rect.size.x, rect.size.y) * 0.22)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	for segment in [
		[Vector2(left, top + tick), Vector2(left, top), Vector2(left + tick, top)],
		[Vector2(right - tick, top), Vector2(right, top), Vector2(right, top + tick)],
		[Vector2(right, bottom - tick), Vector2(right, bottom), Vector2(right - tick, bottom)],
		[Vector2(left + tick, bottom), Vector2(left, bottom), Vector2(left, bottom - tick)],
	]:
		canvas.draw_polyline(PackedVector2Array(segment), color, width)


static func _draw_ellipse(
	canvas: CanvasItem,
	center: Vector2,
	radius: Vector2,
	color: Color,
) -> void:
	canvas.draw_set_transform(center, 0.0, radius)
	canvas.draw_circle(Vector2.ZERO, 1.0, color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _hit_flash_modulate(remaining: float) -> Color:
	if remaining <= 0.0:
		return Color.WHITE
	var strength := clampf(remaining / 0.18, 0.0, 1.0)
	if remaining >= 0.13:
		strength = 1.0
	return Color(1.0 + 0.30 * strength, 1.0 - 0.72 * strength, 1.0 - 0.72 * strength, 1.0)


static func _draw_centered_text(
	canvas: CanvasItem,
	rect: Rect2,
	text: String,
	color: Color,
	font_size: int,
) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var position := Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + (rect.size.y + text_size.y) * 0.5 - 3,
	)
	canvas.draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


static func _fog_marker_color(floor_data: Dictionary, cell: Vector2i, color: Color) -> Color:
	return color if _is_cell_visible(floor_data, cell) else color.darkened(0.55)


static func _is_cell_visible(floor_data: Dictionary, cell: Vector2i) -> bool:
	return bool(floor_data.get("visible_cells", {}).get(cell, false))


static func _is_cell_explored(floor_data: Dictionary, cell: Vector2i) -> bool:
	return bool(floor_data.get("explored_cells", {}).get(cell, false))


static func _is_cell_observed(floor_data: Dictionary, cell: Vector2i) -> bool:
	var observed: Dictionary = floor_data.get(
		"observed_cells",
		floor_data.get("visible_cells", {}),
	)
	return bool(observed.get(cell, false))
