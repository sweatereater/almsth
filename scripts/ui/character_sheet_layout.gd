class_name CharacterSheetLayout
extends RefCounted

## One virtual 1280x720 geometry contract for the mutually-exclusive Character tabs.

const NAME_FORM_RECT := Rect2(20, 14, 365, 34)
const SOULS_RECT := Rect2(20, 49, 365, 24)
const INVENTORY_TAB_RECT := Rect2(406, 16, 172, 44)
const SKILLS_TAB_RECT := Rect2(588, 16, 172, 44)
const MENU_RECT := Rect2(1152, 16, 108, 44)

const STATS_CARD_RECT := Rect2(16, 76, 276, 570)
const FIGURE_CARD_RECT := Rect2(307, 76, 368, 570)
const INVENTORY_CARD_RECT := Rect2(691, 76, 573, 570)
const SKILLS_CARD_RECT := Rect2(16, 76, 1248, 570)
const RETURN_RECT := Rect2(450, 658, 380, 46)

const FIGURE_SOURCE_RECT := Rect2(7, 8, 250, 692)
const FIGURE_RECT := Rect2(402, 122, 178, 493)
const FIGURE_BASELINE_Y := 612.0

const SOUL_FORM_RECT := Rect2(28, 88, 252, 48)
const PRIMARY_ATTRIBUTES_RECT := Rect2(28, 142, 220, 140)
const FREE_STATS_RECT := Rect2(28, 290, 220, 32)
const STATUS_STRIP_RECT := Rect2(28, 326, 252, 30)
const DERIVED_STATS_RECT := Rect2(28, 364, 252, 228)
const CHEAT_BUTTON_RECT := Rect2(126, 600, 154, 34)

const SLOT_SIZE := Vector2(64, 64)
const SLOT_RECTS := {
	"head": Rect2(323, 96, 64, 64),
	"body": Rect2(323, 190, 64, 64),
	"hands": Rect2(323, 284, 64, 64),
	"legs": Rect2(323, 378, 64, 64),
	"feet": Rect2(323, 472, 64, 64),
	"ring_1": Rect2(323, 566, 64, 64),
	"jacket": Rect2(595, 96, 64, 64),
	"talisman": Rect2(595, 190, 64, 64),
	"back": Rect2(595, 284, 64, 64),
	"right_hand": Rect2(595, 378, 64, 64),
	"left_hand": Rect2(595, 472, 64, 64),
	"ring_2": Rect2(595, 566, 64, 64),
}

const INVENTORY_PANEL_RECT := Rect2(703, 88, 549, 546)
const INVENTORY_FILTER_AREA := Rect2(703, 88, 549, 86)
const INVENTORY_FILTER_ROWS := [6, 5]


static func slot_rect(slot_id: String) -> Rect2:
	return SLOT_RECTS.get(slot_id, Rect2())
