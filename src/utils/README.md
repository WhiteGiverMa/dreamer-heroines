# Utils 工具模块

可复用的游戏工具组件，提供通用功能支持。

## 职责

存放跨模块共享的工具类与组件，包括状态管理、伤害系统、碰撞层定义、资源加载等通用功能。

## 文件

| 名称 | 用途 | 备注 |
|------|------|------|
| `state_machine.gd` | 通用状态机 | 管理复杂状态转换，自动收集子节点 |
| `health_component.gd` | 生命值组件 | 伤害/治疗/无敌帧，可复用于任意角色 |
| `hitbox.gd` | 攻击判定框 | 检测命中，支持击退与冷却 |
| `hurtbox.gd` | 受击判定框 | 接收伤害，配合 HealthComponent 使用 |
| `layers.gd` | 碰撞层常量 | 物理层位掩码与工具函数 |
| `faction.gd` | 阵营工具类 | 枚举定义与阵营转换 |
| `resource_loader_utils.gd` | 资源加载工具 | 带 fallback 的场景/纹理加载 |
| `camera_shake.gd` | 屏幕震动组件 | 附加到 Camera2D 使用 |
