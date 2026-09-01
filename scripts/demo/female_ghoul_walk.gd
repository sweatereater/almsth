extends Control

## Separate map-art review scene. Never instantiates Main or loads/saves user data.
const Motion := preload("res://scripts/demo/female_ghoul_motion.gd")
const DungeonView := preload("res://scripts/ui/dungeon_viewport.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const Ui := preload("res://scripts/ui/ui_factory.gd")
const InputProfile := preload("res://scripts/system/input_bindings.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const FRAME_PATH := "res://assets/dungeon/female-ghoul/frames/walk-%02d.png"
const AUTO_CORNERS := [Vector2i(5, 4), Vector2i(5, 3), Vector2i(2, 3), Vector2i(2, 4)]
const TEXT := {
	"ru": {
		"title": "ГУЛЬ\nЖенский образ",
		"subtitle": "Прототип ходьбы",
		"controls": "WASD / стрелки\nДвижение\n\n1 / 2 / 3\nМасштаб клетки\n\nПробел — автошаг\nR — начать заново\nL — RU / EN",
		"auto_on": "Остановить [Space]", "auto_off": "Автошаг [Space]",
		"reset": "Сначала [R]", "idle": "Опора", "walk": "Шаг",
		"note": "Отдельная сцена\nБез боя и сохранений\nОдин ракурс + зеркало",
		"footer": "88 px — клетка • 84 px — холст спрайта • стопы привязаны к клетке • Esc — выход",
	},
	"en": {
		"title": "GHOUL\nFemale character",
		"subtitle": "Walking prototype",
		"controls": "WASD / arrows\nMove\n\n1 / 2 / 3\nCell scale\n\nSpace — auto walk\nR — reset\nL — RU / EN",
		"auto_on": "Stop [Space]", "auto_off": "Auto walk [Space]",
		"reset": "Reset [R]", "idle": "Planted", "walk": "Step",
		"note": "Separate scene\nNo combat or saves\nOne view + mirror",
		"footer": "88 px cell • 84 px sprite canvas • feet anchored to the cell • Esc — quit",
	},
}

var motion := Motion.new()
var state := RunState.new()
var floor_data := Motion.make_floor()
var frames: Array[Texture2D] = []
var dungeon_view: DungeonView
var locale := "ru"
var auto_walk := false
var auto_corner := 0
var manual_control_enabled := true
var title_label: Label
var subtitle_label: Label
var controls_label: Label
var note_label: Label
var status_label: Label
var footer_label: Label
var auto_button: Button
var reset_button: Button
var zoom_buttons: Array[Button] = []


func _ready() -> void:
	InputProfile.ensure_defaults()
	state.current_form_id = "ghoul"
	for index in range(Motion.FRAME_COUNT):
		frames.append(load(FRAME_PATH % index) as Texture2D)
	dungeon_view = DungeonView.new()
	add_child(dungeon_view)
	dungeon_view.set_cell_size(88)
	_build_ui()
	for argument in OS.get_cmdline_user_args():
		if argument == "--locale=en":
			locale = "en"
		elif argument == "--autowalk":
			auto_walk = true
	_apply_locale()
	refresh_presentation()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("10151d"))
	draw_rect(Rect2(1072, 8, 200, 660), Renderer.COLOR_PANEL)
	draw_rect(Rect2(8, 676, 1264, 36), Renderer.COLOR_PANEL)


func _build_ui() -> void:
	title_label = Ui.make_label(self, Vector2(1084, 22), Vector2(180, 62), 21)
	subtitle_label = Ui.make_label(self, Vector2(1084, 88), Vector2(180, 28), 15)
	subtitle_label.add_theme_color_override("font_color", Ui.COLOR_SOUL)
	for index in range(3):
		var pixels: int = [44, 66, 88][index]
		var button := Ui.make_button(self, Vector2(1082 + index * 60, 132), str(pixels), Vector2(56, 36))
		button.toggle_mode = true
		button.pressed.connect(set_zoom.bind(pixels))
		zoom_buttons.append(button)
	controls_label = Ui.make_label(self, Vector2(1084, 184), Vector2(180, 233), 16)
	auto_button = Ui.make_button(self, Vector2(1082, 425), "", Vector2(180, 40))
	auto_button.add_theme_font_size_override("font_size", 15)
	auto_button.pressed.connect(toggle_auto)
	reset_button = Ui.make_button(self, Vector2(1082, 473), "", Vector2(180, 36))
	reset_button.pressed.connect(reset_demo)
	var language_button := Ui.make_button(self, Vector2(1082, 517), "RU / EN [L]", Vector2(180, 34))
	language_button.pressed.connect(toggle_locale)
	status_label = Ui.make_label(self, Vector2(1084, 562), Vector2(180, 25), 16)
	note_label = Ui.make_label(self, Vector2(1084, 600), Vector2(180, 62), 13)
	note_label.add_theme_color_override("font_color", Color("a3adba"))
	footer_label = Ui.make_label(self, Vector2(20, 680), Vector2(1238, 26), 16)


func _process(delta: float) -> void:
	if not manual_control_enabled:
		return
	motion.advance(delta)
	if not motion.moving:
		var requested := _held_direction()
		if requested != Vector2i.ZERO:
			auto_walk = false
		elif auto_walk:
			requested = _auto_direction()
		motion.begin_step(floor_data, requested)
	refresh_presentation()


func _held_direction() -> Vector2i:
	for entry in [["move_left", Vector2i.LEFT], ["move_right", Vector2i.RIGHT], ["move_up", Vector2i.UP], ["move_down", Vector2i.DOWN]]:
		if Input.is_action_pressed(entry[0]):
			return entry[1]
	return Vector2i.ZERO


func _auto_direction() -> Vector2i:
	if motion.cell == AUTO_CORNERS[auto_corner]:
		auto_corner = (auto_corner + 1) % AUTO_CORNERS.size()
	var difference: Vector2i = AUTO_CORNERS[auto_corner] - motion.cell
	var requested := Vector2i(signi(difference.x), 0) if difference.x != 0 else Vector2i(0, signi(difference.y))
	if not motion.can_enter(floor_data, motion.cell + requested):
		# Restarting auto from an arbitrary manual cell must never walk into a wall.
		auto_walk = false
		return Vector2i.ZERO
	return requested


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1: set_zoom(44)
		KEY_2: set_zoom(66)
		KEY_3: set_zoom(88)
		KEY_SPACE: toggle_auto()
		KEY_R: reset_demo()
		KEY_L: toggle_locale()
		KEY_ESCAPE: get_tree().quit()


func refresh_presentation() -> void:
	dungeon_view.set_presentation(
		floor_data, state, motion.cell, [], [], Vector2i(-1, -1), false, false,
		[], {}, Vector2i(-1, -1), {}, 0.0, [], [],
		{"texture": frames[motion.frame_index()], "offset_cells": motion.offset_cells(), "flip_h": motion.facing_right},
	)
	status_label.text = "%s • %d / 4" % [TEXT[locale]["walk" if motion.moving else "idle"], motion.frame_index() + 1]
	auto_button.text = TEXT[locale]["auto_on" if auto_walk else "auto_off"]
	for index in range(zoom_buttons.size()):
		zoom_buttons[index].set_pressed_no_signal(dungeon_view.runtime_cell_size == [44, 66, 88][index])
	footer_label.text = TEXT[locale]["footer"].replace("88", str(dungeon_view.runtime_cell_size)).replace("84", str(dungeon_view.runtime_cell_size - 4))


func set_zoom(pixels: int) -> void:
	dungeon_view.set_cell_size(pixels)
	refresh_presentation()


func toggle_auto() -> void:
	auto_walk = not auto_walk
	refresh_presentation()


func reset_demo() -> void:
	motion.reset()
	auto_walk = false
	auto_corner = 0
	refresh_presentation()


func toggle_locale() -> void:
	locale = "en" if locale == "ru" else "ru"
	_apply_locale()
	refresh_presentation()


func _apply_locale() -> void:
	Loc.set_locale(locale)
	title_label.text = TEXT[locale]["title"]
	subtitle_label.text = TEXT[locale]["subtitle"]
	controls_label.text = TEXT[locale]["controls"]
	note_label.text = TEXT[locale]["note"]
	reset_button.text = TEXT[locale]["reset"]
