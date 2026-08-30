class_name BaseLayout
extends RefCounted

## Shared source of truth for the Base composition. Station art and hitboxes
## keep their old normalized placement when the image rectangle changes.

const OLD_IMAGE_RECT := Rect2(28, 82, 780, 458)
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
const BUILD_CRUSHER_RECT := Rect2(SIDEBAR_INNER_X, 520, SIDEBAR_INNER_WIDTH, 38)
const BUILD_WHETSTONE_RECT := Rect2(SIDEBAR_INNER_X, 561, SIDEBAR_INNER_WIDTH, 38)
const BUILD_RITUAL_TABLE_RECT := Rect2(SIDEBAR_INNER_X, 602, SIDEBAR_INNER_WIDTH, 38)
const BUILD_CAMPFIRE_RECT := Rect2(SIDEBAR_INNER_X, 643, SIDEBAR_INNER_WIDTH, 38)
const CHARACTER_BUTTON_RECT := Rect2(858, 14, 272, 42)
const HINT_RECT := Rect2(28, 562, 818, 34)
const MESSAGE_RECT := Rect2(28, 602, 818, 106)

const STATION_OVERLAY_SOURCE_RECTS := {
	"crusher": Rect2(52, 244, 250, 178),
	"whetstone": Rect2(558, 244, 205, 174),
	"ritual_table": Rect2(294, 218, 270, 180),
	"campfire": Rect2(340, 354, 170, 112),
}
const STATION_HITBOX_SOURCE_RECTS := {
	"crusher": Rect2(64, 350, 220, 82),
	"whetstone": Rect2(566, 350, 190, 82),
	"ritual_table": Rect2(304, 332, 240, 100),
}


static func normalized_rect(rect: Rect2, container: Rect2) -> Rect2:
	return Rect2(
		(rect.position - container.position) / container.size,
		rect.size / container.size,
	)


static func map_normalized_rect(normalized: Rect2, container: Rect2) -> Rect2:
	return Rect2(
		container.position + normalized.position * container.size,
		normalized.size * container.size,
	)


static func map_from_old_image(rect: Rect2) -> Rect2:
	return map_normalized_rect(normalized_rect(rect, OLD_IMAGE_RECT), IMAGE_RECT)


static func station_overlay_rect(station_id: String) -> Rect2:
	return map_from_old_image(STATION_OVERLAY_SOURCE_RECTS.get(station_id, Rect2()))


static func station_hitbox_rect(station_id: String) -> Rect2:
	return map_from_old_image(STATION_HITBOX_SOURCE_RECTS.get(station_id, Rect2()))
