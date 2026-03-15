# 资源规范文档 (ASSET_GUIDE)

> **引擎**: Godot 4.6.1  
> **风格**: 占位符资源先行，正式资源替换  
> **版本**: 1.0  
> **最后更新**: 2026-03-15

---

## 目录

1. [占位符资源标准](#1-占位符资源标准)
2. [精灵图尺寸规范](#2-精灵图尺寸规范)
3. [动画帧率标准](#3-动画帧率标准)
4. [音效占位符规范](#4-音效占位符规范)
5. [正式资源替换流程](#5-正式资源替换流程)

---

## 1. 占位符资源标准

### 1.1 占位符资源原则

占位符资源用于快速原型开发，应具备以下特点:

- **功能性**: 能清晰表达资源用途
- **一致性**: 风格统一，避免视觉混乱
- **可替换性**: 便于后续无缝替换为正式资源
- **轻量性**: 文件体积小，加载快速

### 1.2 占位符视觉风格

#### 色彩方案

| 类别 | 主色 | 辅助色 | 用途 |
|------|------|--------|------|
| 玩家 | `#4A90D9` (蓝) | `#2E5C8A` | 玩家角色、UI |
| 友军 | `#5CB85C` (绿) | `#3D7A3D` | NPC、友方单位 |
| 敌人 | `#D9534F` (红) | `#A73A36` | 敌军单位 |
| 环境 | `#8B7355` (棕) | `#6B5741` | 地形、建筑 |
| 道具 | `#F0AD4E` (黄) | `#C48A3A` | 武器、物品 |
| 特效 | `#FFFFFF` (白) | `#CCCCCC` | 粒子、光效 |

#### 几何风格

使用简单的几何形状代替复杂图形:

```
玩家角色: 矩形身体 + 圆形头部 + 线条四肢
敌人: 简化版玩家形状，使用红色系
武器: 矩形枪身 + 线条枪管
环境: 基础矩形/多边形组合
```

### 1.3 占位符资源清单

#### 角色占位符

| 资源名 | 类型 | 描述 | 尺寸 |
|--------|------|------|------|
| `placeholder_player.png` | Sprite | 玩家角色 | 32x64 |
| `placeholder_enemy_basic.png` | Sprite | 基础敌人 | 32x64 |
| `placeholder_enemy_elite.png` | Sprite | 精英敌人 | 40x72 |
| `placeholder_enemy_boss.png` | Sprite | Boss敌人 | 64x96 |

#### 武器占位符

| 资源名 | 类型 | 描述 | 尺寸 |
|--------|------|------|------|
| `placeholder_wep_rifle.png` | Sprite | 突击步枪 | 48x16 |
| `placeholder_wep_smg.png` | Sprite | 冲锋枪 | 32x16 |
| `placeholder_wep_sniper.png` | Sprite | 狙击枪 | 64x16 |
| `placeholder_wep_shotgun.png` | Sprite | 霰弹枪 | 40x16 |
| `placeholder_wep_pistol.png` | Sprite | 手枪 | 24x16 |
| `placeholder_wep_melee.png` | Sprite | 近战武器 | 32x32 |

#### 环境占位符

| 资源名 | 类型 | 描述 | 尺寸 |
|--------|------|------|------|
| `placeholder_ground.png` | Tile | 地面 | 32x32 |
| `placeholder_wall.png` | Tile | 墙壁 | 32x32 |
| `placeholder_cover_low.png` | Sprite | 低矮掩体 | 48x32 |
| `placeholder_cover_high.png` | Sprite | 高掩体 | 48x64 |
| `placeholder_crate.png` | Sprite | 木箱 | 32x32 |

#### 特效占位符

| 资源名 | 类型 | 描述 | 尺寸 |
|--------|------|------|------|
| `placeholder_muzzle_flash.png` | Sprite | 枪口火焰 | 16x16 |
| `placeholder_impact.png` | Sprite | 弹着点 | 16x16 |
| `placeholder_explosion.png` | SpriteSheet | 爆炸动画 | 64x64x8帧 |
| `placeholder_bullet.png` | Sprite | 子弹 | 8x4 |

### 1.4 占位符命名规范

```
格式: placeholder_[类别]_[具体名称].[扩展名]

类别前缀:
- char_     : 角色
- wep_      : 武器
- env_      : 环境
- fx_       : 特效
- ui_       : UI元素
- audio_    : 音频

示例:
- placeholder_char_player.png
- placeholder_wep_ak47.png
- placeholder_env_wall_brick.png
- placeholder_fx_muzzle_flash.png
- placeholder_ui_button.png
- placeholder_audio_gunshot.wav
```

---

## 2. 精灵图尺寸规范

### 2.1 角色精灵图

#### 玩家角色

| 视图 | 尺寸 | 锚点 | 说明 |
|------|------|------|------|
| 侧面 (Side) | 32x64 px | 底部中心 | 主要游戏视角 |
| 背面 (Back) | 32x64 px | 底部中心 | 特殊场景使用 |
| 正面 (Front) | 32x64 px | 底部中心 | 剧情/商店界面 |

#### 敌人角色

| 类型 | 尺寸 | 备注 |
|------|------|------|
| 普通士兵 | 32x64 px | 与玩家同尺寸 |
| 精英士兵 | 40x72 px | 略大，突出威胁 |
| 重型士兵 | 48x80 px | 重装感 |
| Boss | 64x96 px 或更大 | 根据设计调整 |

#### 角色动画帧尺寸

```
动画类型建议帧数:
- Idle (待机): 4-6 帧
- Run (奔跑): 6-8 帧
- Jump (跳跃): 3-4 帧 (起跳/空中/落地)
- Shoot (射击): 2-4 帧
- Reload (换弹): 6-10 帧
- Death (死亡): 4-6 帧
- Hurt (受击): 2 帧

帧布局: 水平排列 (SpriteSheet)
总宽度 = 单帧宽度 × 帧数
高度 = 单帧高度
```

### 2.2 武器精灵图

#### 世界视图 (World View)

| 武器类型 | 尺寸 | 锚点 |
|----------|------|------|
| 手枪 | 24x16 px | 握把底部 |
| 冲锋枪 | 32x16 px | 握把底部 |
| 突击步枪 | 48x16 px | 握把底部 |
| 霰弹枪 | 40x16 px | 握把底部 |
| 狙击步枪 | 64x16 px | 握把底部 |
| 轻机枪 | 56x20 px | 握把底部 |
| 火箭筒 | 48x24 px | 握把底部 |

#### 手持视图 (Held View)

```
手持武器需要两个角度:
1. 侧面视角 (游戏主要视角)
   - 尺寸: 同世界视图
   - 包含握把部分，便于对齐角色手部

2. 枪口火焰位置标记
   - 使用 Marker2D 节点标记枪口位置
   - 便于生成枪口特效和子弹
```

#### UI图标 (Inventory/Slot)

| 用途 | 尺寸 | 背景 |
|------|------|------|
| 武器槽位图标 | 64x64 px | 透明或纯色背景 |
| 装备槽位图标 | 48x48 px | 透明或纯色背景 |
| 物品栏图标 | 32x32 px | 透明 |
| 快捷栏图标 | 48x48 px | 透明 |

### 2.3 环境精灵图

#### 瓦片尺寸 (Tileset)

| 类型 | 尺寸 | 用途 |
|------|------|------|
| 标准瓦片 | 32x32 px | 地面、墙壁基础单位 |
| 半高瓦片 | 32x16 px | 平台、台阶 |
| 斜坡瓦片 | 32x32 px | 45度斜坡 |
| 大瓦片 | 64x64 px | 装饰性元素 |

#### 道具/装饰物

| 类别 | 尺寸范围 | 示例 |
|------|----------|------|
| 小型道具 | 16x16 ~ 32x32 px | 弹药盒、医疗包 |
| 中型道具 | 32x32 ~ 64x64 px | 武器箱、油桶 |
| 大型道具 | 64x64 ~ 128x128 px | 车辆残骸、大型设备 |
| 背景元素 | 128x128+ px | 远景建筑、山脉 |

### 2.4 特效精灵图

#### 粒子纹理

| 效果类型 | 尺寸 | 说明 |
|----------|------|------|
| 枪口火焰 | 32x32 px | 发光效果，Additive混合 |
| 弹壳 | 8x4 px | 小矩形，旋转动画 |
| 弹着点火花 | 16x16 px | 短暂存在 |
| 血迹 | 16x16 ~ 32x32 px | 贴地，根据表面调整 |
| 爆炸核心 | 64x64 px | 中心发光 |
| 烟雾 | 32x32 ~ 64x64 px | 半透明，逐渐扩散 |

#### 动画特效尺寸

```
爆炸动画 (Explosion):
- 帧尺寸: 64x64 px
- 帧数: 8-12 帧
- 总尺寸: 512x64 px (水平排列) 或 64x512 px (垂直排列)
- 动画时长: 0.5-0.8 秒

枪口火焰 (Muzzle Flash):
- 帧尺寸: 32x32 px
- 帧数: 2-4 帧
- 动画时长: 0.05-0.1 秒

换弹特效 (Reload):
- 弹匣掉落: 16x8 px，物理动画
- 弹匣插入: 16x8 px
```

### 2.5 UI元素尺寸

#### 基础UI组件

| 组件 | 尺寸 | 备注 |
|------|------|------|
| 按钮 (Button) | 160x48 px | 标准按钮 |
| 小按钮 | 80x32 px | 次要操作 |
| 血条背景 | 200x20 px | 带边框 |
| 血条填充 | 196x16 px | 内部填充 |
| 弹药显示框 | 120x40 px | 数字+图标 |
| 小地图 | 150x150 px | 圆形遮罩 |
| 技能图标 | 48x48 px | 正方形 |
| 物品槽位 | 64x64 px | 带边框 |

#### 字体大小规范

| 用途 | 字号 | 字体 |
|------|------|------|
| 标题 | 32-48 px | 粗体 |
| 副标题 | 24 px | 粗体 |
| 正文 | 16-18 px | 常规 |
| 小字说明 | 12-14 px | 常规 |
| HUD数字 | 20-24 px | 等宽/数字专用 |
| 伤害数字 | 浮动 | 粗体，带描边 |

---

## 3. 动画帧率标准

### 3.1 标准帧率

| 动画类型 | FPS | 说明 |
|----------|-----|------|
| 角色移动 | 12 FPS | 游戏性动画 |
| 角色动作 | 12-15 FPS | 射击、换弹 |
| 特效动画 | 15-24 FPS | 爆炸、枪口火焰 |
| UI动画 | 30 FPS | 平滑过渡 |
| 待机动画 | 8-10 FPS | 节省资源 |

### 3.2 动画时长参考

#### 角色动画

| 动画 | 帧数 | FPS | 时长 | 循环 |
|------|------|-----|------|------|
| Idle (待机) | 6 | 10 | 0.6s | 是 |
| Run (奔跑) | 8 | 12 | 0.67s | 是 |
| Jump (跳跃) | 4 | 12 | 0.33s | 否 |
| Shoot (射击) | 2 | 24 | 0.08s | 否 |
| Reload (换弹) | 10 | 12 | 0.83s | 否 |
| Death (死亡) | 6 | 12 | 0.5s | 否 |
| Hurt (受击) | 2 | 24 | 0.08s | 否 |

#### 武器动画

| 动画 | 帧数 | FPS | 时长 | 说明 |
|------|------|-----|------|------|
| Fire (开火) | 2-3 | 30 | 0.1s | 后坐力动画 |
| Reload (换弹) | 8-12 | 12 | 0.7-1.0s | 根据武器类型 |
| Equip (装备) | 4 | 12 | 0.33s | 取出武器 |
| Empty (空仓) | 2 | 12 | 0.17s | 空枪挂机 |

#### 特效动画

| 效果 | 帧数 | FPS | 时长 | 循环 |
|------|------|-----|------|------|
| Muzzle Flash | 2-3 | 30 | 0.1s | 否 |
| Explosion | 10 | 20 | 0.5s | 否 |
| Impact Spark | 4 | 24 | 0.17s | 否 |
| Smoke | 8 | 12 | 0.67s | 是(淡出) |
| Shell Ejection | 物理 | - | - | 否 |

### 3.3 动画混合设置

```gdscript
# AnimationPlayer 推荐设置

# 移动混合
- Idle -> Run: 混合时间 0.1s
- Run -> Idle: 混合时间 0.15s

# 动作混合
- 任何状态 -> Shoot: 混合时间 0.05s (快速响应)
- 任何状态 -> Hurt: 混合时间 0.0s (立即响应)
- Shoot -> Idle: 混合时间 0.1s

# 死亡动画
- 任何状态 -> Death: 混合时间 0.0s
- Death 不返回其他状态
```

### 3.4 SpriteSheet规范

#### 布局方式

```
推荐: 水平排列 (Horizontal Strip)

[Frame 1][Frame 2][Frame 3][Frame 4]...

尺寸计算:
- 宽度 = 单帧宽度 × 帧数
- 高度 = 单帧高度

示例 (8帧奔跑动画，32x64每帧):
- SpriteSheet尺寸: 256x64 px
```

#### Godot导入设置

```gdscript
# 在导入面板中设置:

# 对于 SpriteSheet 动画:
- Texture Type: 2D Pixel (像素游戏)
- Filter: Nearest (保持像素清晰)
- Repeat: Disabled

# 对于普通精灵:
- Texture Type: 2D Pixel
- Filter: Nearest
```

#### AnimatedSprite2D vs AnimationPlayer

| 方案 | 适用场景 | 优点 | 缺点 |
|------|----------|------|------|
| AnimatedSprite2D | 简单角色、特效 | 设置简单，性能稍好 | 功能有限 |
| AnimationPlayer | 复杂角色、需要混合 | 功能强大，可动画任何属性 | 设置复杂 |

**推荐**: 角色使用 AnimationPlayer，特效使用 AnimatedSprite2D

---

## 4. 音效占位符规范

### 4.1 占位符音效类型

使用简单的合成音效或免费音效作为占位符:

| 类别 | 来源建议 | 格式 |
|------|----------|------|
| 枪声 | 合成/免费SFX | WAV |
| 爆炸 | 合成/免费SFX | WAV |
| UI | 合成短音 | WAV |
| 环境 | 循环合成音 | OGG |
| 音乐 | 免费音乐/临时作曲 | OGG |

### 4.2 音频格式规范

#### 音效 (Sound Effects)

| 属性 | 设置 | 说明 |
|------|------|------|
| 格式 | WAV (16-bit PCM) | 无损，快速加载 |
| 采样率 | 44100 Hz | 标准CD质量 |
| 声道 | 单声道 (Mono) | 3D定位，节省内存 |
| 时长 | < 3秒 | 长音效分段 |
| 文件大小 | < 500 KB | 控制内存占用 |

#### 音乐 (Music)

| 属性 | 设置 | 说明 |
|------|------|------|
| 格式 | OGG Vorbis | 压缩，流式加载 |
| 采样率 | 44100 Hz | 标准质量 |
| 声道 | 立体声 (Stereo) | 音乐效果 |
| 比特率 | 128-192 kbps | 平衡质量与大小 |
| 加载模式 | Stream | 大文件流式播放 |

### 4.3 占位符音效清单

#### 武器音效

| 音效ID | 描述 | 时长 | 音量 |
|--------|------|------|------|
| `sfx_gunshot_pistol` | 手枪射击 | 0.3s | -6 dB |
| `sfx_gunshot_rifle` | 步枪射击 | 0.4s | -6 dB |
| `sfx_gunshot_sniper` | 狙击枪射击 | 0.5s | -3 dB |
| `sfx_reload_generic` | 通用换弹 | 1.5s | -10 dB |
| `sfx_empty_click` | 空仓挂机 | 0.1s | -12 dB |
| `sfx_shell_eject` | 弹壳弹出 | 0.5s | -15 dB |

#### 环境音效

| 音效ID | 描述 | 时长 | 音量 |
|--------|------|------|------|
| `sfx_explosion_small` | 小爆炸 | 1.0s | -3 dB |
| `sfx_explosion_large` | 大爆炸 | 2.0s | 0 dB |
| `sfx_impact_bullet` | 子弹命中 | 0.2s | -12 dB |
| `sfx_impact_metal` | 金属碰撞 | 0.3s | -10 dB |
| `sfx_footstep` | 脚步声 | 0.2s | -20 dB |

#### UI音效

| 音效ID | 描述 | 时长 | 音量 |
|--------|------|------|------|
| `sfx_ui_click` | 按钮点击 | 0.1s | -10 dB |
| `sfx_ui_hover` | 悬停 | 0.05s | -15 dB |
| `sfx_ui_confirm` | 确认 | 0.3s | -8 dB |
| `sfx_ui_cancel` | 取消 | 0.2s | -8 dB |
| `sfx_ui_error` | 错误 | 0.3s | -6 dB |

### 4.4 音频总线设置

```
Master
├── SFX (音效总线)
│   ├── Weapons (武器)
│   ├── Explosions (爆炸)
│   ├── Impacts (命中)
│   └── UI (界面)
├── Music (音乐总线)
│   ├── BGM (背景音乐)
│   └── Ambient (环境音)
└── Voice (语音总线) [可选]
```

#### 总线效果推荐

```gdscript
# SFX 总线
- 压缩器: 轻微压缩，统一音量
- 限制器: 防止爆音

# Music 总线
- 低通滤波: 暂停时降低高频

# Master 总线
- 限制器: 最终输出保护
```

### 4.5 占位符音效制作

#### 使用SFXR/LabChirp生成

```
参数模板 (手枪):
- Waveform: Square
- Attack: 0.01
- Sustain: 0.1
- Decay: 0.2
- Frequency: 800 Hz
- Frequency Slide: -200

参数模板 (爆炸):
- Waveform: Noise
- Attack: 0.0
- Sustain: 0.1
- Decay: 0.8
- Base Frequency: 100 Hz
```

---

## 5. 正式资源替换流程

### 5.1 资源替换原则

1. **路径保持一致**: 正式资源替换占位符时保持相同相对路径
2. **命名保持一致**: 使用相同的文件名
3. **尺寸兼容**: 正式资源建议与占位符同尺寸或整数倍
4. **格式兼容**: 保持相同的文件格式

### 5.2 替换检查清单

#### 美术资源替换

- [ ] 精灵图尺寸与碰撞体匹配
- [ ] 锚点位置正确
- [ ] 动画帧数与逻辑匹配
- [ ] 透明通道正常
- [ ] 导入设置正确 (Filter: Nearest)
- [ ] 颜色配置文件正确 (sRGB)

#### 音频资源替换

- [ ] 音量级别统一
- [ ] 循环点设置正确 (音乐)
- [ ] 3D音效设置 (需要时)
- [ ] 导入设置正确 (WAV/OGG)
- [ ] 总线分配正确

### 5.3 版本控制策略

#### 资源分支管理

```
main
├── placeholder-assets (占位符资源分支)
└── production-assets (正式资源分支)
    ├── characters/
    ├── weapons/
    └── environments/
```

#### 资源更新流程

```
1. 在独立分支制作/更新资源
2. 本地测试替换效果
3. 提交到 production-assets 分支
4. 创建合并请求到 main
5. 代码审查 (检查尺寸、命名、设置)
6. 合并并测试
```

### 5.4 资源优化检查

#### 纹理优化

```gdscript
# 检查清单:
- [ ] 尺寸为2的幂次方 (32, 64, 128, 256, 512, 1024...)
- [ ] 没有不必要的透明区域
- [ ] 使用图集合并小纹理
- [ ] 压缩格式合适 (VRAM Compressed)
```

#### 音频优化

```gdscript
# 检查清单:
- [ ] 音效使用单声道
- [ ] 音乐使用流式加载
- [ ] 删除未使用的音频
- [ ] 音量标准化
```

### 5.5 资源组织模板

#### 正式资源目录结构

```
assets/
├── characters/
│   ├── player/
│   │   ├── sprites/
│   │   │   ├── idle.png
│   │   │   ├── run.png
│   │   │   └── ...
│   │   ├── animations/
│   │   │   └── player_animations.tres
│   │   └── audio/
│   │       ├── footstep.wav
│   │       └── hurt.wav
│   └── enemies/
│       ├── soldier/
│       ├── elite/
│       └── boss/
│
├── weapons/
│   ├── ak47/
│   │   ├── sprite.png
│   │   ├── muzzle_flash.png
│   │   ├── shell.png
│   │   ├── fire.wav
│   │   └── reload.wav
│   └── ...
│
├── environments/
│   ├── tilesets/
│   ├── backgrounds/
│   └── props/
│
├── effects/
│   ├── particles/
│   ├── explosions/
│   └── impacts/
│
├── audio/
│   ├── music/
│   ├── ambience/
│   └── ui/
│
└── ui/
    ├── fonts/
    ├── icons/
    └── backgrounds/
```

### 5.6 资源命名规范 (正式)

```
格式: [类别]_[名称]_[变体]_[状态].[扩展名]

类别:
- char_     : 角色
- wep_      : 武器
- env_      : 环境
- prop_     : 道具
- fx_       : 特效
- ui_       : UI
- bgm_      : 背景音乐
- sfx_      : 音效

变体 (可选):
- _v1, _v2  : 版本
- _red, _blue: 颜色变体
- _damaged  : 损坏状态

状态 (动画):
- _idle     : 待机
- _run      : 奔跑
- _shoot    : 射击
- _reload   : 换弹
- _die      : 死亡

示例:
- char_player_idle.png
- char_enemy_soldier_run.png
- wep_ak47_fire.wav
- env_wall_brick_damaged.png
- fx_explosion_large.png
- ui_button_hover.png
- bgm_level1_action.ogg
- sfx_gunshot_rifle.wav
```

---

## 附录

### A. 占位符资源快速生成

#### 使用Godot生成占位符

```gdscript
# 在编辑器中运行，生成占位符精灵
@tool
extends EditorScript

func _run() -> void:
    _create_placeholder_sprite("player", Vector2i(32, 64), Color.BLUE)
    _create_placeholder_sprite("enemy", Vector2i(32, 64), Color.RED)
    _create_placeholder_sprite("weapon_rifle", Vector2i(48, 16), Color.GRAY)

func _create_placeholder_sprite(name: String, size: Vector2i, color: Color) -> void:
    var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
    image.fill(color)
    
    # 添加边框
    for x in range(size.x):
        image.set_pixel(x, 0, Color.BLACK)
        image.set_pixel(x, size.y - 1, Color.BLACK)
    for y in range(size.y):
        image.set_pixel(0, y, Color.BLACK)
        image.set_pixel(size.x - 1, y, Color.BLACK)
    
    image.save_png("res://assets/placeholders/placeholder_" + name + ".png")
```

### B. 推荐工具

| 用途 | 工具 | 备注 |
|------|------|------|
| 像素画 | Aseprite, GraphicsGale | 专业像素画工具 |
| 矢量图 | Inkscape | 免费矢量工具 |
| 3D渲染 | Blender | 渲染2D精灵 |
| 音效 | SFXR, LabChirp | 程序化音效 |
| 音频编辑 | Audacity | 免费音频编辑 |
| 图集打包 | TexturePacker, FreeTexturePacker | 合并精灵图 |
| 版本控制 | Git + Git LFS | 大文件管理 |

### C. 资源外包规范

如需外包美术资源，需提供:

1. **风格参考图**: 3-5张参考风格
2. **尺寸规范表**: 本文档第2节
3. **配色方案**: 本文档第1.2节
4. **动画帧率**: 本文档第3节
5. **命名规范**: 本文档第5.6节
6. **交付格式**: PNG序列帧 + 合并SpriteSheet

---

*文档结束*
