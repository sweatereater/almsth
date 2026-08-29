class_name AudioManager
extends Node

const MASTER_BUS := "Master"
const GAME_AUDIO_BUS := "GameAudio"
const BACKGROUND_BUS := "AlmsthBackground"
const ACTIONS_BUS := "AlmsthActions"
const DEFAULT_BACKGROUND_VOLUME := 50
const DEFAULT_ACTIONS_VOLUME := 75
const FADE_DURATION := 0.5
const STEP_COOLDOWN_SECONDS := 0.12
const ACTION_POOL_SIZE := 8

const BACKGROUND_STREAM_PATHS := {
	"base": "res://assets/audio/base_ambience.wav",
	"dungeon": "res://assets/audio/dungeon_ambience.wav",
}
const ACTION_STREAM_PATHS := {
	"ui_confirm": "res://assets/audio/ui_confirm.wav",
	"ui_cancel": "res://assets/audio/ui_cancel.wav",
	"step": "res://assets/audio/step.wav",
	"dash": "res://assets/audio/dash.wav",
	"melee_attack": "res://assets/audio/melee_attack.wav",
	"player_hurt": "res://assets/audio/player_hurt.wav",
	"ranged_shot": "res://assets/audio/ranged_shot.wav",
	"magic_cast": "res://assets/audio/magic_cast.wav",
	"chest_open": "res://assets/audio/chest_open.wav",
	"world_transition": "res://assets/audio/world_transition.wav",
	"station_success": "res://assets/audio/station_success.wav",
	"station_fail": "res://assets/audio/station_fail.wav",
	"evolution": "res://assets/audio/evolution.wav",
	"death": "res://assets/audio/death.wav",
	"victory": "res://assets/audio/evolution.wav",
}

@export var playback_enabled := true

var muted := false
var background_volume := DEFAULT_BACKGROUND_VOLUME
var actions_volume := DEFAULT_ACTIONS_VOLUME
var current_background := ""
var background_history: Array[String] = []
var action_history: Array[String] = []
var now_provider: Callable
var event_sink: Callable
var background_players: Array[AudioStreamPlayer] = []
var action_players: Array[AudioStreamPlayer] = []
var action_streams: Dictionary = {}
var background_streams: Dictionary = {}
var action_pool_cursor := 0
var active_background_index := -1
var fading_from_index := -1
var fading_to_index := -1
var fade_elapsed := 0.0
var fade_to_silence := false
var waiting_for_user_gesture := false
var last_step_time := -1.0e20
var runtime_headless := false


func _ready() -> void:
	runtime_headless = is_headless_runtime()
	if runtime_headless:
		playback_enabled = false
	ensure_audio_buses()
	if not runtime_headless:
		_build_players()
	waiting_for_user_gesture = (
		playback_enabled
		and (OS.has_feature("web") or OS.has_feature("mobile"))
	)
	apply_settings(muted, background_volume, actions_volume)


func _process(delta: float) -> void:
	advance_fade(delta)


func _exit_tree() -> void:
	for player in background_players:
		player.stop()
		player.stream = null
	for player in action_players:
		player.stop()
		player.stream = null
	background_streams.clear()
	action_streams.clear()
	background_players.clear()
	action_players.clear()


static func is_headless_runtime() -> bool:
	return OS.has_feature("headless") or DisplayServer.get_name().to_lower() == "headless"


static func ensure_audio_buses() -> void:
	_ensure_bus(GAME_AUDIO_BUS, MASTER_BUS)
	_ensure_bus(BACKGROUND_BUS, GAME_AUDIO_BUS)
	_ensure_bus(ACTIONS_BUS, GAME_AUDIO_BUS)


static func _ensure_bus(bus_name: String, send_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus(AudioServer.bus_count)
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send_name)


static func percent_to_db(percent: int) -> float:
	var clamped := clampi(percent, 0, 100)
	return -80.0 if clamped == 0 else linear_to_db(clamped / 100.0)


func apply_settings(mute_value: bool, background_percent: int, actions_percent: int) -> void:
	ensure_audio_buses()
	muted = mute_value
	background_volume = clampi(background_percent, 0, 100)
	actions_volume = clampi(actions_percent, 0, 100)
	var game_index := AudioServer.get_bus_index(GAME_AUDIO_BUS)
	var background_index := AudioServer.get_bus_index(BACKGROUND_BUS)
	var actions_index := AudioServer.get_bus_index(ACTIONS_BUS)
	if game_index >= 0:
		AudioServer.set_bus_mute(game_index, muted)
	if background_index >= 0:
		AudioServer.set_bus_volume_db(background_index, percent_to_db(background_volume))
		AudioServer.set_bus_mute(background_index, background_volume == 0)
	if actions_index >= 0:
		AudioServer.set_bus_volume_db(actions_index, percent_to_db(actions_volume))
		AudioServer.set_bus_mute(actions_index, actions_volume == 0)


func set_background(context: String) -> bool:
	if not BACKGROUND_STREAM_PATHS.has(context) or context == current_background:
		return false
	current_background = context
	background_history.append(context)
	_emit_semantic("background", context)
	# Do not even load an AudioStream in headless/test mode. Semantic dispatch
	# above remains available to deterministic tests and telemetry sinks.
	if not _can_play():
		return true
	var stream := _background_stream(context)
	if stream == null:
		return true
	var next_index := 0 if active_background_index != 0 else 1
	var next_player := background_players[next_index]
	next_player.stop()
	next_player.stream = stream
	# Start both an initial ambience and a replacement from silence so there is no
	# one-frame volume jump before the fade state advances.
	next_player.volume_db = -80.0
	next_player.play()
	fading_from_index = active_background_index
	fading_to_index = next_index
	active_background_index = next_index
	fade_elapsed = 0.0
	fade_to_silence = false
	return true


func stop_background() -> bool:
	if current_background.is_empty():
		return false
	current_background = ""
	background_history.append("stop")
	_emit_semantic("background", "stop")
	if not _can_play() or active_background_index < 0:
		active_background_index = -1
		fading_from_index = -1
		fading_to_index = -1
		fade_to_silence = false
		return true
	fading_from_index = active_background_index
	fading_to_index = -1
	fade_elapsed = 0.0
	fade_to_silence = true
	return true


func notify_user_gesture() -> void:
	if not waiting_for_user_gesture:
		return
	waiting_for_user_gesture = false
	if current_background.is_empty() or not _can_play():
		return
	var stream := _background_stream(current_background)
	if stream == null or background_players.is_empty():
		return
	active_background_index = 0
	background_players[0].stream = stream
	background_players[0].volume_db = 0.0
	background_players[0].play()


func play_action(event_id: String) -> bool:
	if not ACTION_STREAM_PATHS.has(event_id):
		return false
	var now := _now_seconds()
	if event_id == "step" and now - last_step_time + 0.000001 < STEP_COOLDOWN_SECONDS:
		return false
	if event_id == "step":
		last_step_time = now
	action_history.append(event_id)
	_emit_semantic("action", event_id)
	if not _can_play() or action_players.is_empty():
		return true
	var stream := _action_stream(event_id)
	if stream == null:
		return true
	var player := action_players[action_pool_cursor]
	action_pool_cursor = (action_pool_cursor + 1) % action_players.size()
	player.stop()
	player.stream = stream
	player.play()
	return true


func advance_fade(delta: float) -> void:
	if fade_to_silence:
		fade_elapsed += maxf(delta, 0.0)
		var progress := clampf(fade_elapsed / FADE_DURATION, 0.0, 1.0)
		if fading_from_index >= 0 and fading_from_index < background_players.size():
			background_players[fading_from_index].volume_db = lerpf(0.0, -80.0, progress)
		if progress >= 1.0:
			if fading_from_index >= 0 and fading_from_index < background_players.size():
				background_players[fading_from_index].stop()
			active_background_index = -1
			fading_from_index = -1
			fade_to_silence = false
		return
	if fading_to_index < 0:
		return
	fade_elapsed += maxf(delta, 0.0)
	var progress := clampf(fade_elapsed / FADE_DURATION, 0.0, 1.0)
	var levels := crossfade_levels(progress)
	if fading_from_index >= 0 and fading_from_index < background_players.size():
		background_players[fading_from_index].volume_db = levels.x
	if fading_to_index < background_players.size():
		background_players[fading_to_index].volume_db = levels.y
	if progress >= 1.0:
		if fading_from_index >= 0 and fading_from_index < background_players.size():
			background_players[fading_from_index].stop()
		fading_from_index = -1
		fading_to_index = -1


static func crossfade_levels(progress: float) -> Vector2:
	var clamped := clampf(progress, 0.0, 1.0)
	return Vector2(lerpf(0.0, -80.0, clamped), lerpf(-80.0, 0.0, clamped))


func _build_players() -> void:
	if runtime_headless or is_headless_runtime():
		return
	if not background_players.is_empty() or not action_players.is_empty():
		return
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Background%d" % index
		player.bus = BACKGROUND_BUS
		add_child(player)
		background_players.append(player)
	for index in range(ACTION_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "Action%d" % index
		player.bus = ACTIONS_BUS
		add_child(player)
		action_players.append(player)


func _background_stream(context: String) -> AudioStream:
	if background_streams.has(context):
		return background_streams[context]
	var stream := load(String(BACKGROUND_STREAM_PATHS.get(context, ""))) as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	background_streams[context] = stream
	return stream


func _action_stream(event_id: String) -> AudioStream:
	if action_streams.has(event_id):
		return action_streams[event_id]
	var stream := load(String(ACTION_STREAM_PATHS.get(event_id, ""))) as AudioStream
	action_streams[event_id] = stream
	return stream


func _can_play() -> bool:
	return (
		playback_enabled
		and not runtime_headless
		and not is_headless_runtime()
		and not waiting_for_user_gesture
		and is_inside_tree()
	)


func _now_seconds() -> float:
	if now_provider.is_valid():
		return float(now_provider.call())
	return Time.get_ticks_msec() / 1000.0


func _emit_semantic(kind: String, event_id: String) -> void:
	if event_sink.is_valid():
		event_sink.call(kind, event_id)
