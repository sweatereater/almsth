class_name StoreGateway
extends RefCounted

## Store-neutral boundary. Steam/VK Play adapters can implement this contract;
## gameplay never imports either SDK directly.

enum Channel { STANDALONE, STEAM, VK_PLAY }

var channel := Channel.STANDALONE


func configure_for_current_build() -> void:
	if OS.has_feature("steam"):
		channel = Channel.STEAM
	elif OS.has_feature("vk_play"):
		channel = Channel.VK_PLAY


func initialize() -> bool:
	return true


func unlock_achievement(_achievement_id: String) -> void:
	pass


func set_stat(_stat_id: String, _value: int) -> void:
	pass


func shutdown() -> void:
	pass
