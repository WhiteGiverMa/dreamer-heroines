# 音频素材来源文档

> **项目**: DreamerHeroines
> **更新日期**: 2026-03-27
> **用途**: 占位符音频素材下载指南

---

## 音频总线架构

### 12 总线拓扑结构

本项目采用 12 总线分层架构，实现精细的音频路由控制：

```
Master (root)
├── Music → Master
├── SFX → Master (聚合总线，不直接使用)
│   ├── SFX_Player → SFX
│   ├── SFX_Weapons → SFX
│   ├── SFX_Enemies → SFX
│   ├── SFX_Impacts → SFX
│   └── SFX_Skills → SFX
├── UI → Master
├── Voice → Master (保留总线，暂无 UI 控制)
├── Ambience → Reverb
└── Reverb → Master (含 AudioEffectReverb)
```

### 总线分类说明

| 层级 | 总线名 | 发送目标 | 用途 |
|------|--------|----------|------|
| 根 | Master | — | 最终输出，禁止直接发送 |
| 顶层 | Music | Master | 背景音乐 |
| 顶层 | SFX | Master | 聚合总线，不直接使用 |
| 顶层 | UI | Master | UI 音效 |
| 顶层 | Voice | Master | 角色语音（保留） |
| 顶层 | Ambience | Reverb | 环境音，路由到混响 |
| 顶层 | Reverb | Master | 混响处理器 |
| 子级 | SFX_Player | SFX | 玩家动作音效 |
| 子级 | SFX_Weapons | SFX | 武器音效 |
| 子级 | SFX_Enemies | SFX | 敌人音效 |
| 子级 | SFX_Impacts | SFX | 撞击/命中音效 |
| 子级 | SFX_Skills | SFX | 技能音效 |

> **总线契约**: 完整定义见 `src/autoload/audio_manager.gd` 顶部 `AUDIO BUS CONTRACT` 注释

---

### 声音类别归属表

| 类别 | 总线 | 音效 ID 示例 |
|------|------|--------------|
| 玩家动作 | SFX_Player | `sfx_jump`, `sfx_player_hurt`, `sfx_player_death` |
| 武器音效 | SFX_Weapons | `sfx_gunshot_pistol`, `sfx_reload_generic`, `sfx_empty_click` |
| 敌人音效 | SFX_Enemies | `sfx_enemy_shoot`, `sfx_enemy_melee`, `sfx_enemy_hurt`, `sfx_enemy_death` |
| 撞击音效 | SFX_Impacts | `sfx_explosion_small`, `sfx_explosion_large`, `sfx_impact_bullet` |
| 技能音效 | SFX_Skills | `sfx_skill_cast`, `sfx_skill_hit` |
| UI 音效 | UI | `sfx_ui_click`, `sfx_ui_hover` |
| 环境音 | Ambience | `sfx_ambience_wind`, `sfx_ambience_rain` |
| 角色语音 | Voice | （保留，暂无具体音效） |

### 路由策略

`AudioManager.play_sfx(key)` 根据 key 前缀自动路由到对应总线：

1. 检查 `_CATEGORY_TO_BUS` 映射，匹配前缀
2. 首次匹配生效
3. 未知 key 降级到父总线 `SFX`（保持向后兼容）

---

### Reverb 策略

**仅 Ambience 总线路由到 Reverb**

- `Ambience → Reverb → Master`
- 战斗总线（SFX_*）保持干声 (dry)，不经过混响
- UI、Music、Voice 直接发送到 Master

混响参数（`AudioEffectReverb`）：
- `room_size = 0.3`
- `wet = 0.2`
- `damping = 0.3`

> 这种设计使环境音具有空间感，而战斗音效保持清晰定位。

---

### Voice 总线状态

Voice 总线已实现但**未在设置界面暴露**：
- 总线存在于 `default_bus_layout.tres`
- 发送到 Master
- 设置界面仅有 Master、Music、SFX、UI 四个音量滑块
- 后续版本将添加 Voice 音量控制

---

## 规范化声音 ID

### 规范格式

所有音效 ID 遵循 `sfx_{category}_{name}` 格式：

| 前缀 | 类别 | 示例 |
|------|------|------|
| `sfx_player_` | 玩家动作 | `sfx_player_hurt`, `sfx_player_death` |
| `sfx_gunshot_` | 武器射击 | `sfx_gunshot_pistol`, `sfx_gunshot_rifle` |
| `sfx_reload_` | 换弹 | `sfx_reload_generic` |
| `sfx_enemy_` | 敌人 | `sfx_enemy_shoot`, `sfx_enemy_death` |
| `sfx_explosion_` | 爆炸 | `sfx_explosion_small`, `sfx_explosion_large` |
| `sfx_impact_` | 撞击 | `sfx_impact_bullet` |
| `sfx_skill_` | 技能 | `sfx_skill_cast` |
| `sfx_ui_` | UI | `sfx_ui_click`, `sfx_ui_hover` |
| `sfx_ambience_` | 环境音 | `sfx_ambience_wind` |

### 遗留别名映射

`AudioManager` 自动将遗留键转换为规范格式：

| 遗留键 | 规范键 | 用途 |
|--------|--------|------|
| `jump` | `sfx_jump` | 玩家跳跃 |
| `player_hurt` | `sfx_player_hurt` | 玩家受伤 |
| `player_death` | `sfx_player_death` | 玩家死亡 |
| `enemy_shoot` | `sfx_enemy_shoot` | 敌人射击 |
| `enemy_melee` | `sfx_enemy_melee` | 敌人近战 |
| `enemy_hurt` | `sfx_enemy_hurt` | 敌人受伤 |
| `enemy_death` | `sfx_enemy_death` | 敌人死亡 |
| `empty_click` | `sfx_empty_click` | 空仓挂机 |
| `shoot` | `sfx_gunshot_pistol` | 通用射击（备用） |

### 动态武器音效规范化

武器音效支持动态键转换：

| 动态键模式 | 转换规则 | 示例 |
|------------|----------|------|
| `{weapon}_shoot` | → `sfx_gunshot_{weapon}` | `rifle_shoot` → `sfx_gunshot_rifle` |
| `{weapon}_reload` | → `sfx_reload_{weapon}` 或 `sfx_reload_generic` | `rifle_reload` → `sfx_reload_generic` |

### 规范化工作流程

```
play_sfx("rifle_shoot")
    ↓
_normalize_sound_key("rifle_shoot")
    ↓ (检测到 _shoot 后缀)
"sfx_gunshot_rifle"
    ↓
sound_library.has("sfx_gunshot_rifle")?
    ↓ 是
播放音效，路由到 SFX_Weapons
```

### 未知键处理

- 未知键触发一次性警告：`"Sound not found in library (warn once): {key}"`
- 警告消息显示规范化后的键
- 未知 SFX 键降级路由到父总线 `SFX`

---

## 推荐音效资源网站

### 1. Mixkit (首选 - 无需署名)

**URL**: https://mixkit.co/free-sound-effects/

**许可**: Mixkit License (免费商用，无需署名)

**优点**: 专业质量，直接下载 WAV

**直接链接**:
- 枪声: https://mixkit.co/free-sound-effects/gun/
- 爆炸: https://mixkit.co/free-sound-effects/explosion/
- 战争: https://mixkit.co/free-sound-effects/war/

---

### 2. OpenGameArt (CC0)

**URL**: https://opengameart.org/

**许可**: CC0 (公共领域，无需署名)

**推荐资源**:
- Firearm Sound Effects: https://opengameart.org/content/firearm-sound-effects
- Random Gunfire SFX: https://opengameart.org/content/random-gunfire-sfx
- Action Game SFX Pack: https://opengameart.org/content/action-gameshmup-sfx-pack
- Impact/Gun SFX: https://opengameart.org/content/impactsgunsfx

---

### 3. Kenney.nl (CC0)

**URL**: https://kenney.nl/assets/category:Audio

**许可**: CC0 (公共领域，无需署名)

**推荐资源**:
- RPG Audio: https://kenney.nl/assets/rpg-audio

---

### 4. Freesound.org (需注册)

**URL**: https://freesound.org/

**许可**: CC0 / CC-BY (需检查每个文件)

**推荐音效包**:
- Guns and Weapon: https://freesound.org/people/jalastram/packs/14010/
- Real Gun Sounds: https://freesound.org/people/areniporgen/packs/38798/

**搜索词**: `gunshot`, `pistol`, `rifle`, `shotgun`, `explosion`, `reload`

---

### 5. Pixabay

**URL**: https://pixabay.com/sound-effects/search/gun/

**许可**: Pixabay Content License (免费商用，无需署名)

**搜索词**: `gunshot`, `machine gun`, `explosion`, `cannon fire`

---

### 6. itch.io

**URL**: https://itch.io/game-assets/free/tag-sound-effects/tag-weapons

**推荐资源**:
- Sci-Fi Weapon Shots: https://lentikula.itch.io/sci-fi-weapon-shots-sfx-freecc0
- Gun SFX v1: https://cyberofficial.itch.io/sfx-pack

---

## 项目所需音效清单

| 音效ID | 文件名 | 用途 | 搜索词 | 推荐来源 |
|--------|--------|------|--------|----------|
| `sfx_gunshot_pistol` | gunshot_pistol.wav | 手枪射击 | `pistol shot`, `handgun` | Mixkit |
| `sfx_gunshot_rifle` | gunshot_rifle.wav | 步枪射击 | `rifle shot`, `M4`, `AR-15` | Freesound |
| `sfx_gunshot_shotgun` | gunshot_shotgun.wav | 霰弹枪 | `shotgun blast`, `shotgun pump` | OpenGameArt |
| `sfx_gunshot_sniper` | gunshot_sniper.wav | 狙击枪 | `sniper`, `rifle` | Freesound |
| `sfx_reload_generic` | reload.wav | 换弹 | `gun reload`, `magazine` | Mixkit |
| `sfx_empty_click` | empty_click.wav | 空仓挂机 | `empty click`, `gun click` | Freesound |
| `sfx_shell_eject` | shell_eject.wav | 弹壳弹出 | `shell`, `casing`, `brass` | Freesound |
| `sfx_explosion_small` | explosion_small.wav | 小爆炸 | `explosion`, `grenade` | Mixkit |
| `sfx_explosion_large` | explosion_large.wav | 大爆炸 | `large explosion`, `bomb` | Pixabay |
| `sfx_impact_bullet` | impact_bullet.wav | 子弹命中 | `bullet impact`, `hit` | OpenGameArt |
| `sfx_ui_click` | ui_click.wav | 按钮点击 | `ui click`, `menu` | Kenney.nl |
| `sfx_ui_hover` | ui_hover.wav | 悬停 | `ui hover` | Kenney.nl |

---

## 音频技术规格

### WAV 音效 (SFX)

| 属性 | 规格 |
|------|------|
| 格式 | WAV (16-bit PCM) |
| 采样率 | 44100 Hz |
| 声道 | 单声道 (Mono) |
| 时长 | < 3 秒 |
| 文件大小 | < 500 KB |

### OGG 音乐

| 属性 | 规格 |
|------|------|
| 格式 | OGG Vorbis |
| 采样率 | 44100 Hz |
| 声道 | 立体声 (Stereo) |
| 比特率 | 128-192 kbps |

---

## Godot 导入设置

### WAV 导入

```
Import 面板设置:
- Force > Mono: ✅
- Force > Max Rate: ✅ 44100 Hz
- Compress > Mode: QOA (默认)
```

---

## 许可证说明

| 许可 | 要求 | 来源 |
|------|------|------|
| CC0 | 无需署名 | OpenGameArt, Kenney.nl |
| Mixkit License | 无需署名 | Mixkit |
| Pixabay License | 无需署名 | Pixabay |
| CC-BY | 需署名 | Freesound (部分) |

> **注意**: 使用 CC-BY 素材时，需在游戏致谢页面标注原作者。

---

## 目录结构

```
assets/audio/
├── sfx/
│   ├── weapons/          # 武器音效
│   │   ├── gunshot_pistol.wav
│   │   ├── gunshot_rifle.wav
│   │   ├── gunshot_shotgun.wav
│   │   ├── gunshot_sniper.wav
│   │   ├── reload.wav
│   │   ├── empty_click.wav
│   │   └── shell_eject.wav
│   ├── explosions/       # 爆炸音效
│   │   ├── explosion_small.wav
│   │   └── explosion_large.wav
│   └── ui/               # UI音效
│       ├── click.wav
│       └── hover.wav
├── music/                # 背景音乐
└── ambience/             # 环境音
```

---

## 使用方法

### 播放音效

音效已在 `AudioManager` 中自动注册，直接调用即可：

```gdscript
# 播放武器音效
AudioManager.play_sfx("sfx_gunshot_pistol")
AudioManager.play_sfx("sfx_gunshot_rifle")
AudioManager.play_sfx("sfx_gunshot_shotgun")
AudioManager.play_sfx("sfx_gunshot_sniper")

# 播放换弹音效
AudioManager.play_sfx("sfx_reload_generic")
AudioManager.play_sfx("sfx_empty_click")
AudioManager.play_sfx("sfx_shell_eject")

# 播放爆炸音效
AudioManager.play_sfx("sfx_explosion_small")
AudioManager.play_sfx("sfx_explosion_large")

# 播放UI音效
AudioManager.play_sfx("sfx_ui_click")
AudioManager.play_sfx("sfx_ui_hover")

# 可选参数: 音量和音调
AudioManager.play_sfx("sfx_gunshot_rifle", volume_db=-3.0, pitch_scale=1.1)
```

### 已注册音效ID列表

| 音效ID | 文件 | 用途 |
|--------|------|------|
| `sfx_gunshot_pistol` | gunshot_pistol.wav | 手枪射击 |
| `sfx_gunshot_rifle` | gunshot_rifle.wav | 步枪射击 |
| `sfx_gunshot_shotgun` | gunshot_shotgun.wav | 霰弹枪射击 |
| `sfx_gunshot_sniper` | gunshot_sniper.wav | 狙击枪射击 |
| `sfx_reload_generic` | reload.wav | 换弹 |
| `sfx_empty_click` | empty_click.wav | 空仓挂机 |
| `sfx_shell_eject` | shell_eject.wav | 弹壳弹出 |
| `sfx_explosion_small` | explosion_small.wav | 小爆炸 |
| `sfx_explosion_large` | explosion_large.wav | 大爆炸 |
| `sfx_ui_click` | click.wav | 按钮点击 |
| `sfx_ui_hover` | hover.wav | 按钮悬停 |

---

*最后更新: 2026-03-27*
