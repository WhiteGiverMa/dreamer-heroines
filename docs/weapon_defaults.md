# 武器默认值参考

> 本文档记录武器属性的默认值和推荐范围，供 Agent 编辑 .tscn 文件时参考。

---

## 通用属性 (WeaponBase)

| 属性 | 类型 | 描述 | 推荐范围 |
|------|------|------|----------|
| `weapon_name` | String | 武器名称 | - |
| `damage` | int | 单发伤害 | 5-150 |
| `fire_rate` | float | 射击间隔(秒) | 0.03-2.5 |
| `reload_time` | float | 换弹时间(秒) | 1.2-4.0 |
| `magazine_size` | int | 弹匣容量 | 3-60 |
| `max_ammo` | int | 最大携带弹药 | 30-600 |
| `projectile_speed` | float | 子弹速度(像素/秒) | 600-4000 |
| `max_range` | float | 最大射程(像素) | 400-5000 |
| `spread` | float | 散布角度(度) | 0-25 |
| `is_automatic` | bool | 是否全自动 | - |
| `recoil_amount` | float | 后坐力强度 | 0-20 |
| `screen_shake_amount` | float | 屏幕震动强度 | 0-1.0 |

---

## 步枪 (Rifle)

**定位**: 全能型武器，中距离主力

```
weapon_name = "基础步枪"
damage = 15
fire_rate = 0.1
reload_time = 2.0
magazine_size = 30
max_ammo = 300
projectile_speed = 1200.0
max_range = 1500.0
spread = 3.0
is_automatic = true
recoil_amount = 3.0
screen_shake_amount = 0.2
```

---

## 霰弹枪 (Shotgun)

**定位**: 近距离高爆发，远距离衰减

**特殊属性**:
- `pellet_count`: int = 8 — 弹丸数量
- `pellet_spread`: float = 15.0 — 弹丸散布角度

```
weapon_name = "基础霰弹枪"
damage = 12              # 每发弹丸伤害
fire_rate = 0.8
reload_time = 2.5
magazine_size = 6
max_ammo = 60
projectile_speed = 900.0
max_range = 800.0
spread = 0.0             # 基础散布为0
is_automatic = false
recoil_amount = 8.0
screen_shake_amount = 0.5
pellet_count = 8
pellet_spread = 15.0
```

**总伤害**: 12 × 8 = 96 (全中)

---

## 狙击枪 (Sniper) - 未实现

**定位**: 远距离精准击杀，高伤害低射速

```
weapon_name = "基础狙击枪"
damage = 80
fire_rate = 1.5
reload_time = 3.0
magazine_size = 5
max_ammo = 40
projectile_speed = 2500.0
max_range = 3000.0
spread = 0.5
is_automatic = false
recoil_amount = 15.0
screen_shake_amount = 0.8
```

---

## 冲锋枪 (SMG) - 未实现

**定位**: 近距离高射速，低单发伤害

```
weapon_name = "基础冲锋枪"
damage = 8
fire_rate = 0.05          # 每秒20发
reload_time = 1.8
magazine_size = 45
max_ammo = 450
projectile_speed = 1000.0
max_range = 1200.0
spread = 8.0
is_automatic = true
recoil_amount = 2.0
screen_shake_amount = 0.15
```

**DPS**: 8 / 0.05 = 160 伤害/秒

---

## 设计原则

1. **射程与速度**: `lifetime = max_range / projectile_speed`，建议 0.8s - 1.5s
2. **DPS 平衡**: 步枪 150，霰弹枪 96(近)/48(远)，狙击 53，冲锋枪 160
3. **弹药管理**: 高射速武器需要大弹匣，低射速武器需要小弹匣
4. **后坐力**: 影响玩家移动速度，狙击最大，冲锋枪最小

---

## Agent 使用指南

当用户要求调整武器属性时：

1. 打开 `scenes/weapons/{weapon}.tscn`
2. 选中根节点
3. 在 Inspector 中修改 Weapon Stats 分组的属性
4. 参考本文档的推荐范围进行验证

示例提示词：
```
"将步枪的伤害从15调整到20"
"根据狙击枪的默认值创建 sniper.tscn"
```
