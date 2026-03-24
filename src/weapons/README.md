# src/weapons/ — 武器系统

武器逻辑、投射物和相关特效。

## 职责

- 武器射击逻辑（弹药管理、射速控制、散布计算）
- 投射物生成与生命周期管理
- 视觉效果（枪口闪光、弹壳抛射、命中特效）
- 与配置文件 `config/weapon_stats.json` 联动

## 文件

| 名称 | 用途 | 备注 |
|------|------|------|
| `weapon_base.gd` | 旧版武器基类 | 紧耦合持有者，逐步迁移至 `weapon.gd` |
| `weapon.gd` | 组合式武器组件 | 信号驱动，零持有者依赖，可复用 |
| `weapon_stats.gd` | 武器数据资源 | 与逻辑分离，支持无限弹药模式 |
| `rifle_weapon.gd` | 步枪武器 | 继承 Weapon，添加后坐力动画 |
| `shotgun_weapon.gd` | 霰弹枪武器 | 继承 Weapon，多弹丸发射 |
| `projectile.gd` | 投射物基类 | 对象池支持，阵营碰撞系统 |
| `effects/hit_effect.gd` | 命中特效 | 子弹命中敌人时播放 |
| `effects/impact_effect.gd` | 撞击特效 | 子弹撞击地面/墙壁时播放 |

## 架构设计

### 继承层次

```
Node2D
├── WeaponBase (旧版基类，含 owner_player 引用)
│   └── 紧耦合设计，逐步废弃
│
├── Weapon (新版基类)
│   ├── 使用 WeaponStats 资源配置
│   ├── 信号驱动通信 (shot_fired, ammo_changed 等)
│   └── 零持有者依赖，可被玩家/敌人复用
│
└── RifleWeapon / ShotgunWeapon (具体武器)
    └── 继承 Weapon，扩展特定行为
```

### 射击模式

- **全自动 (is_automatic=true)**: 按住射击键持续发射，如步枪、冲锋枪
- **半自动 (is_automatic=false)**: 每次按键单发，如霰弹枪、狙击枪
- **霰弹枪特殊**: 单次射击多发弹丸，使用 `pellet_count` 配置

### 投射物系统

- **对象池模式**: `Projectile.deactivate_for_pool()` / `fire()` 支持回收复用
- **阵营碰撞**: 基于 `Faction` 枚举动态设置碰撞掩码
- **穿透机制**: `pierce_count` 控制可穿透目标数量
- **生命周期**: `lifetime` 或屏幕退出自动回收

### 配置联动

武器数值从 `config/weapon_stats.json` 加载，通过 `WeaponStats` 资源封装。JSON 配置字段与 `WeaponStats` 属性一一对应，支持运行时热重载调参。
