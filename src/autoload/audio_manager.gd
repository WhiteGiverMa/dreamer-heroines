extends "res://src/base/game_system.gd"

# AudioManager - 音频管理
# 统一管理游戏音效和背景音

# =============================================================================
# AUDIO BUS CONTRACT - 音频总线契约 (v1.0)
# =============================================================================
# 本文件定义了游戏中所有音频总线的拓扑结构。所有更改必须先在此
# 注释中更新契约，然后才能修改 runtime 行为。
#
# 稳定顶层总线 (Stable Top-Level Buses):
#   - Master    →  所有总线的最终目标，禁止直接发送
#   - Music     →  背景音乐，Send→Master
#   - SFX       →  音效聚合总线（不直接使用），Send→Master
#   - UI        →  UI音效，Send→Master
#
# SFX 子总线 (SFX Child Buses):
#   - SFX_Player    →  玩家动作音效，Send→SFX
#   - SFX_Weapons  →  武器音效，Send→SFX
#   - SFX_Enemies  →  敌人音效，Send→SFX
#   - SFX_Impacts  →  撞击/命中音效，Send→SFX
#   - SFX_Skills   →  技能音效，Send→SFX
#
# 附加顶层总线 (Additional Top-Level Buses):
#   - Voice     →  角色语音（对话/喊叫），Send→Master
#   - Ambience  →  环境音/氛围音，Send→Reverb
#   - Reverb    →  混响处理器，Send→Master
#
# 发送拓扑 (Send Topology):
#   Music→Master, SFX→Master, SFX_*→SFX, UI→Master,
#   Voice→Master, Ambience→Reverb, Reverb→Master
#
# 路由策略 (Routing Policy):
#   - play_sfx(key) 根据 key 前缀自动路由到对应 SFX_* 子总线
#   - 未知 SFX key 降级路由到父总线 SFX（保持向后兼容）
#   - 旧 play_sfx() 调用仍然有效（路由到 SFX）
#   - Voice 总线存在但尚未在设置界面暴露
#   - Ambience 路由到 Reverb；战斗总线保持干声(dry)
#
# 总线数量: 12 个 (1 Master + 3 顶层 + 5 SFX_* + 3 附加)
# =============================================================================

enum BusType {
	MASTER,
	SFX,
	MUSIC,
	UI,
	VOICE,
	AMBIENCE,
	REVERB,
	SFX_PLAYER,
	SFX_WEAPONS,
	SFX_ENEMIES,
	SFX_IMPACTS,
	SFX_SKILLS
}

@export var sfx_bus: String = "SFX"
@export var music_bus: String = "Music"
@export var ui_bus: String = "UI"

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 16

var sound_library: Dictionary = {}
var music_library: Dictionary = {}
var _missing_audio_warned: Dictionary = {}

# =============================================================================
# LEGACY SOUND ID NORMALIZATION
# =============================================================================
# Maps legacy/unnormalized sound keys to canonical sfx_* IDs.
# This ensures backward compatibility with gameplay scripts using old key formats.
#
# Alias types:
#   - Static: "legacy_key" -> "canonical_key"
#   - Dynamic: "{weapon_name}_shoot" -> "sfx_gunshot_{weapon_name}"
#                "{weapon_name}_reload" -> "sfx_reload_{weapon_name}"
# =============================================================================
const _LEGACY_SOUND_ALIASES: Dictionary = {
	# Player action sounds
	"jump": "sfx_jump",
	"player_hurt": "sfx_player_hurt",
	"player_death": "sfx_player_death",
	# Enemy sounds
	"enemy_shoot": "sfx_enemy_shoot",
	"enemy_melee": "sfx_enemy_melee",
	"enemy_hurt": "sfx_enemy_hurt",
	"enemy_death": "sfx_enemy_death",
	"enemy_dive": "sfx_enemy_dive",
	# Level interaction sounds
	"checkpoint_unlock": "sfx_checkpoint_unlock",
	"checkpoint_activate": "sfx_checkpoint_activate",
	# Weapon sounds (legacy bare keys)
	"empty_click": "sfx_empty_click",
	"shoot": "sfx_gunshot_pistol",  # Generic fallback
}

# =============================================================================
# CATEGORY TO BUS ROUTING MATRIX
# =============================================================================
# Maps normalized sound key prefixes to audio bus names.
# First-match wins. Unknown keys fallback to "SFX".
# =============================================================================
const _CATEGORY_TO_BUS: Dictionary = {
	"sfx_player_": "SFX_Player",
	"sfx_jump": "SFX_Player",
	"sfx_gunshot_": "SFX_Weapons",
	"sfx_reload_": "SFX_Weapons",
	"sfx_empty_click": "SFX_Weapons",
	"sfx_enemy_": "SFX_Enemies",
	"sfx_checkpoint_": "SFX_Skills",
	"sfx_explosion_": "SFX_Impacts",
	"sfx_impact_": "SFX_Impacts",
	"sfx_skill_": "SFX_Skills",
	"sfx_ui_": "UI",
	"sfx_ambience_": "Ambience",
	"music_": "Music",
}

# Known weapon name prefixes for dynamic normalization
# These are stripped from weapon_name and matched against registered sfx_gunshot_* keys
const _WEAPON_SHOOT_PREFIX: String = "_shoot"
const _WEAPON_RELOAD_PREFIX: String = "_reload"

var default_volumes: Dictionary = {"Master": 1.0, "SFX": 0.8, "Music": 0.6, "UI": 0.7}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	system_name = "audio_manager"
	# 不在这里执行初始化，等待 BootSequence 调用


func initialize() -> void:
	print("[AudioManager] 开始初始化...")
	_setup_audio_players()
	_setup_default_bus_volumes()
	_load_saved_volumes()
	_validate_required_buses()
	preload_common_sounds()
	print("[AudioManager] 初始化完")
	_mark_ready()


func _setup_audio_players():
	# 创建背景音乐播放
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


func _load_saved_volumes() -> void:
	"""从 SaveManager 加载保存的音量设置并应用到总线"""
	if not SaveManager:
		print("[AudioManager] SaveManager 不可用，使用默认音量")
		return

	var settings = SaveManager.load_settings()
	if settings.is_empty():
		print("[AudioManager] 没有保存的设置，使用默认音量")
		return

	# 应用保存的音量到各总线
	if settings.has("master_volume"):
		set_bus_volume(BusType.MASTER, settings.get("master_volume", 1.0))
	if settings.has("music_volume"):
		set_bus_volume(BusType.MUSIC, settings.get("music_volume", 0.7))
	if settings.has("sfx_volume"):
		set_bus_volume(BusType.SFX, settings.get("sfx_volume", 0.8))
	if settings.has("ui_volume"):
		set_bus_volume(BusType.UI, settings.get("ui_volume", 0.7))

	print("[AudioManager] 已从保存的设置加载音量")


const REQUIRED_BUSES: Array[String] = [
	"Master",
	"Music",
	"SFX",
	"UI",
	"Voice",
	"Ambience",
	"Reverb",
	"SFX_Player",
	"SFX_Weapons",
	"SFX_Enemies",
	"SFX_Impacts",
	"SFX_Skills"
]


func _validate_required_buses() -> void:
	for bus_name in REQUIRED_BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			push_warning("[AudioManager] Required audio bus missing: " + bus_name)


func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var normalized_key = _normalize_sound_key(sound_name)
	if not sound_library.has(normalized_key):
		_warn_missing_audio_once("sfx", sound_name + " (normalized: " + normalized_key + ")")
		return
	var stream = sound_library[normalized_key]
	var player = _get_available_sfx_player()
	if player:
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch_scale
		player.bus = _get_bus_from_category(normalized_key)
		player.play()


# =============================================================================
# Sound ID Normalization
# =============================================================================
# Converts legacy/unnormalized sound keys to canonical sfx_* IDs.
# Runs before library lookup in play_sfx().
#
# Resolution order:
#   1. Check static _LEGACY_SOUND_ALIASES map
#   2. Dynamic weapon patterns: {weapon_name}_shoot -> sfx_gunshot_{weapon_name}
#                              {weapon_name}_reload -> sfx_reload_{weapon_name}
#   3. Return original key if no normalization found
# =============================================================================
func _normalize_sound_key(sound_name: String) -> String:
	# 1. Check static alias map first
	if _LEGACY_SOUND_ALIASES.has(sound_name):
		return _LEGACY_SOUND_ALIASES[sound_name]

	# 2. Dynamic weapon sound normalization
	#    {weapon_name}_shoot -> sfx_gunshot_{weapon_name}
	if sound_name.ends_with(_WEAPON_SHOOT_PREFIX):
		var weapon_name = sound_name.substr(0, sound_name.length() - _WEAPON_SHOOT_PREFIX.length())
		# Try exact match first (e.g., "sfx_gunshot_rifle" if registered)
		var canonical = "sfx_gunshot_" + weapon_name
		if sound_library.has(canonical):
			return canonical
		# Fallback: try registered sfx_gunshot_* variants
		return canonical

	#    {weapon_name}_reload -> sfx_reload_{weapon_name}
	if sound_name.ends_with(_WEAPON_RELOAD_PREFIX):
		var weapon_name = sound_name.substr(0, sound_name.length() - _WEAPON_RELOAD_PREFIX.length())
		var canonical = "sfx_reload_" + weapon_name
		if sound_library.has(canonical):
			return canonical
		# Fallback to generic reload if weapon-specific not found
		if sound_library.has("sfx_reload_generic"):
			return "sfx_reload_generic"
		return canonical

	# 3. No normalization found, return original
	return sound_name


# =============================================================================
# Category to Bus Routing
# =============================================================================
# Determines the correct audio bus for a normalized sound key.
# First-match prefix wins. Unknown keys fallback to "SFX".
# =============================================================================
func _get_bus_from_category(normalized_key: String) -> String:
	for prefix: String in _CATEGORY_TO_BUS.keys():
		if normalized_key.begins_with(prefix):
			return _CATEGORY_TO_BUS[prefix]
	return "SFX"  # Fallback for unknown categories


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
	return sfx_players[0]  # 如果全部占用，复用第一


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
		BusType.VOICE:
			return "Voice"
		BusType.AMBIENCE:
			return "Ambience"
		BusType.REVERB:
			return "Reverb"
		BusType.SFX_PLAYER:
			return "SFX_Player"
		BusType.SFX_WEAPONS:
			return "SFX_Weapons"
		BusType.SFX_ENEMIES:
			return "SFX_Enemies"
		BusType.SFX_IMPACTS:
			return "SFX_Impacts"
		BusType.SFX_SKILLS:
			return "SFX_Skills"
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


# 预加载常用音
func preload_common_sounds() -> void:
	# 武器音效
	_register_weapon_sounds()
	# 爆炸音效
	_register_explosion_sounds()
	# UI音效
	_register_ui_sounds()
	print("[AudioManager] 音效预加载完成，已注册 %d 个音效" % sound_library.size())


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
