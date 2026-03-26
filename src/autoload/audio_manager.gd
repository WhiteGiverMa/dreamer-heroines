extends "res://src/base/game_system.gd"

# AudioManager - 音频管理�?
# 统一管理游戏音效和背景音�?

enum BusType { MASTER, SFX, MUSIC, UI }

@export var sfx_bus: String = "SFX"
@export var music_bus: String = "Music"
@export var ui_bus: String = "UI"

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 16

var sound_library: Dictionary = {}
var music_library: Dictionary = {}
var _missing_audio_warned: Dictionary = {}

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
	preload_common_sounds()
	print("[AudioManager] 初始化完�?)
	_mark_ready()

func _setup_audio_players():
	# 创建背景音乐播放�?
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
		_warn_missing_audio_once("sfx", sound_name)
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
		_warn_missing_audio_once("music", music_name)
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
	return sfx_players[0]  # 如果全部占用，复用第一�?

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

func _warn_missing_audio_once(audio_type: String, audio_name: String) -> void:
	var warn_key = "%s:%s" % [audio_type, audio_name]
	if _missing_audio_warned.has(warn_key):
		return

	_missing_audio_warned[warn_key] = true
	if audio_type == "music":
		push_warning("Music not found in library (warn once): " + audio_name)
		return

	push_warning("Sound not found in library (warn once): " + audio_name)

# 预加载常用音�?
func preload_common_sounds() -> void:
	# 武器音效
	_register_weapon_sounds()
	# 爆炸音效
	_register_explosion_sounds()
	# UI音效
	_register_ui_sounds()
	print("[AudioManager] 音效预加载完成，已注�?%d 个音�? % sound_library.size())

# 武器音效注册
func _register_weapon_sounds() -> void:
	var weapon_sfx_dir := "res://assets/audio/sfx/weapons/"
	var weapon_sounds: Dictionary[String, String] = {
		"sfx_gunshot_pistol": "gunshot_pistol.wav",
		"sfx_gunshot_rifle": "gunshot_rifle.wav",
		"sfx_gunshot_shotgun": "gunshot_shotgun.wav",
		"sfx_gunshot_sniper": "gunshot_sniper.wav",
		"sfx_reload_generic": "reload.wav",
		"sfx_empty_click": "empty_click.wav",
		"sfx_shell_eject": "shell_eject.wav",
	}
	for sound_name: String in weapon_sounds.keys():
		var path: String = weapon_sfx_dir + weapon_sounds[sound_name]
		_try_register_sound(sound_name, path)

# 爆炸音效注册
func _register_explosion_sounds() -> void:
	var explosion_sfx_dir := "res://assets/audio/sfx/explosions/"
	var explosion_sounds: Dictionary[String, String] = {
		"sfx_explosion_small": "explosion_small.wav",
		"sfx_explosion_large": "explosion_large.wav",
	}
	for sound_name: String in explosion_sounds.keys():
		var path: String = explosion_sfx_dir + explosion_sounds[sound_name]
		_try_register_sound(sound_name, path)

# UI音效注册
func _register_ui_sounds() -> void:
	var ui_sfx_dir := "res://assets/audio/sfx/ui/"
	var ui_sounds: Dictionary[String, String] = {
		"sfx_ui_click": "click.wav",
		"sfx_ui_hover": "hover.wav",
	}
	for sound_name: String in ui_sounds.keys():
		var path: String = ui_sfx_dir + ui_sounds[sound_name]
		_try_register_sound(sound_name, path)

# 尝试注册音效（文件不存在时静默跳过）
func _try_register_sound(sound_name: String, path: String) -> void:
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream:
			register_sound(sound_name, stream)
	else:
		print_debug("[AudioManager] 音效文件不存在，跳过: %s" % path)
