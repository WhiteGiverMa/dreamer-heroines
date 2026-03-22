extends "res://src/base/game_system.gd"

# AudioManager - 音频管理器
# 统一管理游戏音效和背景音乐

enum BusType { MASTER, SFX, MUSIC, UI }

@export var sfx_bus: String = "SFX"
@export var music_bus: String = "Music"
@export var ui_bus: String = "UI"

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 16

var sound_library: Dictionary = {}
var music_library: Dictionary = {}

var default_volumes: Dictionary = {
	"Master": 1.0,
	"SFX": 0.8,
	"Music": 0.6,
	"UI": 0.7
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	system_name = "audio_manager"
	# 不在这里执行初始化，等待 BootSequence 调用

func initialize() -> void:
	print("[AudioManager] 开始初始化...")
	_setup_audio_players()
	_setup_default_bus_volumes()
	print("[AudioManager] 初始化完成")
	_mark_ready()

func _setup_audio_players():
	# 创建背景音乐播放器
	music_player = AudioStreamPlayer.new()
	music_player.bus = music_bus
	add_child(music_player)
	
	# 创建SFX播放器池
	for i in range(max_sfx_players):
		var player = AudioStreamPlayer.new()
		player.bus = sfx_bus
		add_child(player)
		sfx_players.append(player)

func _setup_default_bus_volumes():
	for bus_name in default_volumes.keys():
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(default_volumes[bus_name]))

func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sound_library.has(sound_name):
		push_warning("Sound not found in library: " + sound_name)
		return
	
	var stream = sound_library[sound_name]
	var player = _get_available_sfx_player()
	
	if player:
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch_scale
		player.play()

func play_music(music_name: String, fade_duration: float = 1.0, loop: bool = true) -> void:
	if not music_library.has(music_name):
		push_warning("Music not found in library: " + music_name)
		return
	
	var stream = music_library[music_name]
	stream.loop = loop
	
	if music_player.playing:
		_fade_music_out(fade_duration)
		await get_tree().create_timer(fade_duration).timeout
	
	music_player.stream = stream
	music_player.play()
	_fade_music_in(fade_duration)

func stop_music(fade_duration: float = 0.5) -> void:
	if music_player.playing:
		_fade_music_out(fade_duration)
		await get_tree().create_timer(fade_duration).timeout
		music_player.stop()

func pause_music() -> void:
	music_player.stream_paused = true

func resume_music() -> void:
	music_player.stream_paused = false

func set_bus_volume(bus_type: BusType, volume_linear: float) -> void:
	var bus_name = _get_bus_name(bus_type)
	var db = linear_to_db(clamp(volume_linear, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), db)

func get_bus_volume(bus_type: BusType) -> float:
	var bus_name = _get_bus_name(bus_type)
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		var db = AudioServer.get_bus_volume_db(bus_idx)
		return db_to_linear(db)
	return 1.0

func register_sound(sound_name: String, stream: AudioStream) -> void:
	sound_library[sound_name] = stream

func register_music(music_name: String, stream: AudioStream) -> void:
	music_library[music_name] = stream

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	return sfx_players[0]  # 如果全部占用，复用第一个

func _get_bus_name(bus_type: BusType) -> String:
	match bus_type:
		BusType.MASTER:
			return "Master"
		BusType.SFX:
			return sfx_bus
		BusType.MUSIC:
			return music_bus
		BusType.UI:
			return ui_bus
	return "Master"

func _fade_music_in(duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", 0.0, duration).from(-80.0)

func _fade_music_out(duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)

# 预加载常用音效
func preload_common_sounds() -> void:
	# 这里可以预加载常用音效
	# register_sound("jump", preload("res://assets/audio/sfx/jump.wav"))
	# register_sound("shoot", preload("res://assets/audio/sfx/shoot.wav"))
	pass
