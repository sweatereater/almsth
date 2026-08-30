class_name PresentationSettings
extends RefCounted

## Dungeon zoom is presentation-only. Keeping validation here gives settings,
## camera helpers, UI and tests one shared contract.

const CELL_SIZE_MAP := 44
const CELL_SIZE_TACTICS := 66
const CELL_SIZE_DETAILS := 88
const DEFAULT_CELL_SIZE := CELL_SIZE_TACTICS
const CELL_SIZES: Array[int] = [CELL_SIZE_MAP, CELL_SIZE_TACTICS, CELL_SIZE_DETAILS]


static func sanitize_cell_size(value: Variant) -> int:
	if not value is int and not value is float:
		return DEFAULT_CELL_SIZE
	var rounded := roundi(float(value))
	return rounded if CELL_SIZES.has(rounded) else DEFAULT_CELL_SIZE


static func next_cell_size(current: int, direction := 1) -> int:
	var sanitized := sanitize_cell_size(current)
	var index := CELL_SIZES.find(sanitized)
	return CELL_SIZES[posmod(index + direction, CELL_SIZES.size())]


static func clamped_cell_size_step(current: int, direction: int) -> int:
	var sanitized := sanitize_cell_size(current)
	var index := CELL_SIZES.find(sanitized)
	return CELL_SIZES[clampi(index + signi(direction), 0, CELL_SIZES.size() - 1)]


static func locale_key(cell_size: int) -> String:
	match sanitize_cell_size(cell_size):
		CELL_SIZE_MAP: return "SETTINGS_ZOOM_MAP"
		CELL_SIZE_DETAILS: return "SETTINGS_ZOOM_DETAILS"
	return "SETTINGS_ZOOM_TACTICS"
