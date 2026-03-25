# 音频素材来源文档

> **项目**: DreamerHeroines
> **更新日期**: 2026-03-24
> **用途**: 占位符音频素材下载指南

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

### 音频总线

```
Master → Music / SFX / UI
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

*最后更新: 2026-03-24*
