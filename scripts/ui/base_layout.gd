class_name BaseLayout
extends RefCounted

## Shared source of truth for the Base composition. Camp layer coordinates are
## authored in the 818x480 local runtime image space and translated once here.

const IMAGE_RECT := Rect2(28, 78, 818, 480)

const SIDEBAR_RECT := Rect2(858, 62, 390, 640)
const SIDEBAR_SHADOW_RECT := Rect2(864, 68, 390, 640)
const SIDEBAR_INNER_X := 876.0
const SIDEBAR_INNER_WIDTH := 362.0
const STATS_RECT := Rect2(SIDEBAR_INNER_X, 78, SIDEBAR_INNER_WIDTH, 54)
const HP_RECT := Rect2(SIDEBAR_INNER_X, 140, SIDEBAR_INNER_WIDTH, 28)
const MANA_RECT := Rect2(SIDEBAR_INNER_X, 178, SIDEBAR_INNER_WIDTH, 28)
const STATUS_RECT := Rect2(SIDEBAR_INNER_X, 214, SIDEBAR_INNER_WIDTH, 30)
const PROGRESS_RECT := Rect2(SIDEBAR_INNER_X, 250, SIDEBAR_INNER_WIDTH, 54)
const CAMP_UPGRADES_RECT := Rect2(SIDEBAR_INNER_X, 310, SIDEBAR_INNER_WIDTH, 144)
const START_RECT := Rect2(SIDEBAR_INNER_X, 470, SIDEBAR_INNER_WIDTH, 46)
const BUILD_RECT := Rect2(SIDEBAR_INNER_X, 520, SIDEBAR_INNER_WIDTH, 42)
const BUILD_CRUSHER_RECT := Rect2(SIDEBAR_INNER_X, 520, SIDEBAR_INNER_WIDTH, 38)
const BUILD_WHETSTONE_RECT := Rect2(SIDEBAR_INNER_X, 561, SIDEBAR_INNER_WIDTH, 38)
const BUILD_RITUAL_TABLE_RECT := Rect2(SIDEBAR_INNER_X, 602, SIDEBAR_INNER_WIDTH, 38)
const BUILD_CAMPFIRE_RECT := Rect2(SIDEBAR_INNER_X, 643, SIDEBAR_INNER_WIDTH, 38)
const CHARACTER_BUTTON_RECT := Rect2(858, 14, 272, 42)
const HINT_RECT := Rect2(28, 562, 818, 34)
const MESSAGE_RECT := Rect2(28, 602, 818, 106)

const CAMP_LAYER_LOCAL_RECTS := {
	"mural": Rect2(469, 94, 101, 81),
	"bunk": Rect2(612, 117, 181, 152),
	"textile_area": Rect2(210, 103, 186, 157),
	"workbench": Rect2(40, 141, 174, 144),
	"writing_set": Rect2(70, 115, 140, 91),
	"ritual_table": Rect2(415, 143, 162, 129),
	"crusher": Rect2(39, 243, 177, 178),
	"whetstone": Rect2(217, 274, 131, 96),
	"campfire": Rect2(339, 296, 179, 131),
	"kettle": Rect2(367, 241, 132, 127),
	"rocking_chair": Rect2(516, 239, 177, 205),
	"record_player": Rect2(656, 227, 159, 242),
}
const CAMP_INTERACTIVE_HITBOX_LOCAL_RECTS := {
	"crusher": Rect2(54, 304, 142, 105),
	"whetstone": Rect2(237, 298, 93, 91),
	"ritual_table": Rect2(430, 181, 132, 77),
	"kettle": Rect2(397, 268, 72, 66),
}


static func camp_layer_rect(module_id: String) -> Rect2:
	var local_rect: Rect2 = CAMP_LAYER_LOCAL_RECTS.get(module_id, Rect2())
	return Rect2(IMAGE_RECT.position + local_rect.position, local_rect.size)


static func station_overlay_rect(station_id: String) -> Rect2:
	return camp_layer_rect(station_id)


static func station_hitbox_rect(station_id: String) -> Rect2:
	var local_rect: Rect2 = CAMP_INTERACTIVE_HITBOX_LOCAL_RECTS.get(station_id, Rect2())
	return Rect2(IMAGE_RECT.position + local_rect.position, local_rect.size)
