class_name CharacterSheetLayout
extends RefCounted

## One virtual 1280x720 geometry contract for the mutually-exclusive Character tabs.

const NAME_FORM_RECT := Rect2(20, 14, 365, 34)
const SOULS_RECT := Rect2(20, 49, 365, 24)
const INVENTORY_TAB_RECT := Rect2(406, 16, 172, 44)
const SKILLS_TAB_RECT := Rect2(588, 16, 172, 44)
const MENU_RECT := Rect2(1152, 16, 108, 44)

const STATS_CARD_RECT := Rect2(16, 76, 240, 570)
const FIGURE_CARD_RECT := Rect2(270, 76, 405, 570)
const INVENTORY_CARD_RECT := Rect2(691, 76, 573, 570)
const SKILLS_CARD_RECT := Rect2(16, 76, 1248, 570)
const RETURN_RECT := Rect2(432, 658, 416, 46)

const FIGURE_SOURCE_RECT := Rect2(7, 8, 250, 692)
## Native art is fitted by CharacterArtwork; this is the enclosing arch niche.
const FIGURE_RECT := Rect2(350, 102, 245, 530)
const FIGURE_BASELINE_Y := 620.0

const SOUL_FORM_RECT := Rect2(28, 86, 216, 56)
const PRIMARY_ATTRIBUTES_RECT := Rect2(28, 146, 216, 140)
const PRIMARY_ATTRIBUTES_HEADER_RECT := Rect2(28, 146, 216, 22)
const ATTRIBUTE_ROW_COUNT := 5
const ATTRIBUTE_ROW_START_Y := 169.0
const ATTRIBUTE_ROW_STRIDE := 23.0
const ATTRIBUTE_ROW_SIZE := Vector2(216, 22)
const ATTRIBUTE_LABEL_SIZE := Vector2(182, 22)
const ATTRIBUTE_BUTTON_SIZE := Vector2(28, 22)
const ATTRIBUTE_BUTTON_X := 216.0
const FREE_STATS_RECT := Rect2(28, 290, 216, 32)
const STATUS_STRIP_RECT := Rect2(28, 326, 216, 30)
const PARAMETERS_HEADER_RECT := Rect2(28, 363, 216, 22)
const DERIVED_STATS_RECT := Rect2(28, 386, 216, 228)

const SLOT_SIZE := Vector2(64, 64)
const SLOT_RECTS := {
	"head": Rect2(282, 96, 64, 64),
	"body": Rect2(282, 190, 64, 64),
	"hands": Rect2(282, 284, 64, 64),
	"legs": Rect2(282, 378, 64, 64),
	"feet": Rect2(282, 472, 64, 64),
	"ring_1": Rect2(282, 566, 64, 64),
	"jacket": Rect2(599, 96, 64, 64),
	"talisman": Rect2(599, 190, 64, 64),
	"back": Rect2(599, 284, 64, 64),
	"right_hand": Rect2(599, 378, 64, 64),
	"left_hand": Rect2(599, 472, 64, 64),
	"ring_2": Rect2(599, 566, 64, 64),
}

const INVENTORY_PANEL_RECT := Rect2(703, 88, 549, 546)
const INVENTORY_FILTER_AREA := Rect2(703, 88, 549, 40)
const INVENTORY_FILTER_ROWS := [6]


static func slot_rect(slot_id: String) -> Rect2:
	return SLOT_RECTS.get(slot_id, Rect2())


static func attribute_row_rect(index: int) -> Rect2:
	if index < 0 or index >= ATTRIBUTE_ROW_COUNT:
		return Rect2()
	return Rect2(
		Vector2(PRIMARY_ATTRIBUTES_RECT.position.x, ATTRIBUTE_ROW_START_Y + index * ATTRIBUTE_ROW_STRIDE),
		ATTRIBUTE_ROW_SIZE,
	)


static func attribute_label_rect(index: int) -> Rect2:
	var row := attribute_row_rect(index)
	return Rect2(row.position, ATTRIBUTE_LABEL_SIZE) if row.has_area() else Rect2()


static func attribute_button_rect(index: int) -> Rect2:
	var row := attribute_row_rect(index)
	return (
		Rect2(Vector2(ATTRIBUTE_BUTTON_X, row.position.y), ATTRIBUTE_BUTTON_SIZE)
		if row.has_area() else Rect2()
	)
