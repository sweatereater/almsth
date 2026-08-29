class_name GameRenderer
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const Rules := preload("res://scripts/game/game_rules.gd")

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
const DUNGEON_FLOOR_TEXTURE: Texture2D = preload("res://assets/dungeon/floor-stone.png")
const DUNGEON_WALL_TEXTURE: Texture2D = preload("res://assets/dungeon/wall-stone.png")
const DUNGEON_CHEST_SPRITE: Texture2D = preload("res://assets/dungeon/chest.png")
const PLAYER_SKELETON_SPRITE: Texture2D = preload("res://assets/dungeon/player-skeleton.png")
const ENEMY_SPRITES := {
	"grave_rat": preload("res://assets/dungeon/enemy-grave-rat.png"),
	"hollow_guard": preload("res://assets/dungeon/enemy-hollow-guard.png"),
	"soul_leech": preload("res://assets/dungeon/enemy-soul-leech.png"),
	"skeletal_archer": preload("res://assets/dungeon/enemy-skeletal-archer.svg"),
	"minotaur": preload("res://assets/dungeon/enemy-minotaur.png"),
}

const BOARD_ORIGIN := Vector2(28, 82)
const DUNGEON_VIEW_RECT := Rect2(8, 8, 1056, 660)
const DUNGEON_SIDEBAR_RECT := Rect2(1072, 8, 200, 704)
const DUNGEON_HP_RECT := Rect2(1080, 158, 184, 26)
const DUNGEON_MANA_RECT := Rect2(1080, 190, 184, 26)
const DUNGEON_INSPECTION_RECT := Rect2(1080, 396, 184, 104)
const DUNGEON_HISTORY_RECT := Rect2(1080, 506, 184, 196)
const CELL_SIZE := 66
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
const CHARACTER_SKILLS_CARD := Rect2(Vector2(85, 350), Vector2(1110, 300))


static func draw_frame(
	canvas: CanvasItem,
	viewport_size: Vector2,
	state: RunState,
	show_sidebar: bool,
	show_inspection: bool,
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
		)
		draw_resource_bar(
			canvas, DUNGEON_MANA_RECT, state.mana, state.get_max_mana(),
			Loc.text("PARAM_MANA"), Color("496ead"),
		)
		canvas.draw_rect(DUNGEON_INSPECTION_RECT, Color("171d27"))
		canvas.draw_rect(DUNGEON_INSPECTION_RECT, COLOR_GOLD, false, 2.0)
		canvas.draw_rect(DUNGEON_HISTORY_RECT, Color("141a23"))
		canvas.draw_rect(DUNGEON_HISTORY_RECT, COLOR_PANEL_BORDER, false, 2.0)
		return
	canvas.draw_rect(Rect2(Vector2(834, 68), Vector2(428, 640)), COLOR_PANEL_SHADOW)
	canvas.draw_rect(Rect2(Vector2(828, 62), Vector2(428, 640)), COLOR_PANEL)
	canvas.draw_rect(Rect2(Vector2(828, 62), Vector2(428, 640)), COLOR_PANEL_BORDER, false, 2.0)
	canvas.draw_line(Vector2(830, 64), Vector2(1254, 64), Color(COLOR_SOUL, 0.38), 2.0)
	draw_resource_bar(
		canvas,
		Rect2(Vector2(846, 140), Vector2(400, 28)),
		state.hp,
		state.get_max_hp(),
		Loc.text("PARAM_HP"),
		Color("a84450"),
	)
	draw_resource_bar(
		canvas,
		Rect2(Vector2(846, 180), Vector2(400, 28)),
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
) -> void:
	canvas.draw_rect(rect, Color("10151d"))
	var ratio := clampf(float(current_value) / float(maxi(1, maximum_value)), 0.0, 1.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill_color)
	canvas.draw_rect(rect, COLOR_PANEL_BORDER, false, 2.0)
	_draw_centered_text(
		canvas,
		rect,
		"%s  %d / %d" % [label, current_value, maximum_value],
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
	for x in [85.0, 465.0, 845.0]:
		var card := Rect2(Vector2(x, 82), Vector2(350, 260))
		canvas.draw_rect(Rect2(card.position + Vector2(0, 4), card.size), COLOR_PANEL_SHADOW)
		canvas.draw_rect(card, COLOR_PANEL)
		canvas.draw_rect(card, COLOR_PANEL_BORDER, false, 2.0)
	var skills_card := CHARACTER_SKILLS_CARD
	canvas.draw_rect(Rect2(skills_card.position + Vector2(0, 5), skills_card.size), COLOR_PANEL_SHADOW)
	canvas.draw_rect(skills_card, COLOR_PANEL)
	canvas.draw_rect(skills_card, COLOR_PANEL_BORDER, false, 2.0)
	canvas.draw_texture_rect(
		SKELETON_EQUIPMENT_ART,
		Rect2(Vector2(493, 121), Vector2(294, 196)),
		false,
		Color(1.0, 1.0, 1.0, 0.78),
	)
	if panel_mode == "inventory":
		return
	if selected_stage != "skeleton":
		return
	var node_edges := [
		{"from": Vector2(325, 503), "to": Vector2(350, 503), "skill": "strong_bones"},
		{"from": Vector2(570, 503), "to": Vector2(595, 503), "skill": "fundamentals"},
		{"from": Vector2(815, 503), "to": Vector2(840, 503), "skill": "fundamentals"},
		{"from": Vector2(325, 597), "to": Vector2(350, 597), "skill": "magic_awakening"},
		{"from": Vector2(570, 597), "to": Vector2(595, 597), "skill": "magic_missile"},
		{"from": Vector2(815, 597), "to": Vector2(840, 597), "skill": "magic_missile_range"},
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
	ability_target_cursor := Vector2i(-1, -1),
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
				if cell == boss_door:
					_draw_boss_door(canvas, rect, bool(floor_data.get("boss_door_open", false)))
			canvas.draw_rect(rect, Color(0.10, 0.13, 0.17, 0.74), false, 2.0)
			if not visible_now:
				canvas.draw_rect(
					rect,
					COLOR_FOG_WALL_MEMORY if tiles[cell] == "wall" else COLOR_FOG_MEMORY,
				)
	for target_cell in ability_target_cells:
		var target_rect := cell_rect(target_cell).grow(-6)
		canvas.draw_rect(target_rect, Color(0.22, 0.78, 0.74, 0.22))
		canvas.draw_rect(target_rect, COLOR_SOUL, false, 4.0)
	if ability_target_cursor.x >= 0:
		canvas.draw_rect(cell_rect(ability_target_cursor).grow(-2), COLOR_GOLD, false, 5.0)

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
			)
	_draw_magic_traces(canvas, magic_traces)
	_draw_projectile_traces(canvas, projectile_traces)

	for enemy in floor_data["enemies"]:
		if not _is_cell_visible(floor_data, enemy["pos"]):
			continue
		var enemy_rules: Dictionary = Rules.ENEMIES[enemy["id"]]
		var rect := cell_rect(enemy["pos"]).grow(-8)
		var draw_scale := float(enemy_rules.get("draw_scale", 1.0))
		canvas.draw_circle(rect.get_center() + Vector2(0, 6), 18, Color(0.02, 0.025, 0.035, 0.72))
		canvas.draw_circle(rect.get_center(), 24, Color(Color(enemy_rules["color"]), 0.30))
		var enemy_texture: Texture2D = ENEMY_SPRITES.get(String(enemy["id"]))
		if enemy_texture != null:
			_draw_entity_sprite(canvas, enemy_texture, enemy["pos"], draw_scale)
		else:
			_draw_centered_text(canvas, rect, Loc.text(String(enemy_rules["glyph"])), Color.WHITE, 28)
		_draw_health_bar(canvas, enemy["pos"], int(enemy["hp"]), int(enemy["max_hp"]))

	if has_inspection:
		var inspection_color := COLOR_GOLD if manual_inspection else COLOR_SOUL
		canvas.draw_rect(cell_rect(inspection_cell).grow(-4), inspection_color, false, 4.0)

	var player_rect := cell_rect(player_pos).grow(-8)
	canvas.draw_circle(player_rect.get_center() + Vector2(0, 6), 18, Color(0.02, 0.025, 0.035, 0.72))
	canvas.draw_circle(player_rect.get_center(), 22, Color(Color(state.get_form()["color"]), 0.38))
	canvas.draw_circle(player_rect.get_center(), 28, COLOR_PLAYER_RING, false, 4.0, true)
	if state.current_form_id == "skeleton":
		_draw_entity_sprite(canvas, PLAYER_SKELETON_SPRITE, player_pos)
	else:
		_draw_centered_text(canvas, player_rect, Loc.text("GLYPH_PLAYER"), Color("17202b"), 28)


static func draw_base(canvas: CanvasItem, state: RunState = null) -> void:
	var area := Rect2(BOARD_ORIGIN, Vector2(780, 458))
	canvas.draw_texture_rect(CAMP_ART, area, false)
	canvas.draw_rect(area, Color(0.02, 0.025, 0.035, 0.10))
	if state != null and bool(state.camp_upgrades.get("crusher", false)):
		canvas.draw_texture_rect(
			CAMP_CRUSHER_ART,
			Rect2(Vector2(52, 244), Vector2(250, 178)),
			false,
		)
	if state != null and bool(state.camp_upgrades.get("whetstone", false)):
		canvas.draw_texture_rect(
			CAMP_WHETSTONE_ART,
			Rect2(Vector2(558, 244), Vector2(205, 174)),
			false,
		)
	if state != null and bool(state.camp_upgrades.get("ritual_table", false)):
		canvas.draw_texture_rect(
			CAMP_RITUAL_TABLE_ART,
			Rect2(Vector2(294, 218), Vector2(270, 180)),
			false,
		)
	if state != null and bool(state.camp_upgrades.get("campfire", false)):
		canvas.draw_texture_rect(
			CAMP_CAMPFIRE_ART,
			Rect2(Vector2(340, 354), Vector2(170, 112)),
			false,
		)
	canvas.draw_rect(area, COLOR_PANEL_BORDER, false, 2.0)
	var caption_rect := Rect2(area.position + Vector2(0, 390), Vector2(area.size.x, 68))
	canvas.draw_rect(caption_rect, Color(0.02, 0.025, 0.035, 0.72))
	_draw_centered_text(canvas, caption_rect, Loc.text("BASE_SUBTITLE"), COLOR_TEXT, 18)


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


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))


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


static func _draw_chest_sprite(canvas: CanvasItem, cell: Vector2i, visible_now: bool) -> void:
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
	_draw_entity_sprite(canvas, DUNGEON_CHEST_SPRITE, cell, 0.88, modulate)


static func _draw_entity_sprite(
	canvas: CanvasItem,
	texture: Texture2D,
	cell: Vector2i,
	draw_scale := 1.0,
	modulate := Color.WHITE,
) -> void:
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var available_size := Vector2(CELL_SIZE - 4, CELL_SIZE - 4) * maxf(0.1, draw_scale)
	var scale_ratio := minf(
		available_size.x / source_size.x,
		available_size.y / source_size.y,
	)
	var draw_size := source_size * scale_ratio
	var logical_rect := cell_rect(cell)
	var draw_position := logical_rect.get_center() - draw_size * 0.5
	if draw_scale > 1.0:
		# Oversized bosses still stand on one logical cell. Anchoring their feet to
		# that cell makes the larger art clear without changing pathfinding.
		draw_position.y = logical_rect.end.y - draw_size.y - 2.0
	var draw_rect := Rect2(draw_position, draw_size)
	canvas.draw_texture_rect(texture, draw_rect, false, modulate)


static func _draw_boss_door(canvas: CanvasItem, rect: Rect2, open: bool) -> void:
	if open:
		var threshold := rect.grow(-6)
		canvas.draw_line(
			Vector2(threshold.position.x, threshold.position.y + 6),
			Vector2(threshold.end.x, threshold.position.y + 6),
			Color("8b6947"),
			6.0,
		)
		canvas.draw_line(
			Vector2(threshold.position.x, threshold.end.y - 6),
			Vector2(threshold.end.x, threshold.end.y - 6),
			Color("554536"),
			4.0,
		)
		return
	var slab := rect.grow(-6)
	canvas.draw_rect(slab, Color("3c2926"))
	canvas.draw_rect(slab, Color("9a654b"), false, 4.0)
	for offset in [16.0, 32.0, 48.0]:
		canvas.draw_line(
			Vector2(slab.position.x + offset, slab.position.y + 4),
			Vector2(slab.position.x + offset, slab.end.y - 4),
			Color("211a1b"),
			4.0,
		)
	canvas.draw_line(
		Vector2(slab.position.x + 4, slab.get_center().y),
		Vector2(slab.end.x - 4, slab.get_center().y),
		Color("b17a58"),
		6.0,
	)
	canvas.draw_circle(slab.get_center(), 6.0, Color("d1a15f"))


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


static func _draw_health_bar(
	canvas: CanvasItem,
	cell: Vector2i,
	hp_value: int,
	max_hp_value: int,
) -> void:
	var rect := cell_rect(cell)
	var background := Rect2(rect.position + Vector2(8, 52), Vector2(CELL_SIZE - 16, 8))
	canvas.draw_rect(background, Color("401f25"))
	var width := background.size.x * float(hp_value) / float(max_hp_value)
	canvas.draw_rect(Rect2(background.position, Vector2(width, background.size.y)), COLOR_DANGER)


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
