# C# 项目结构说明

本项目实现了 Godot 4.6.1 的 GDScript/C# 混用架构。

## 项目结构

```
src/cs/
├── Core/                    # 核心工具类
│   ├── MathUtils.cs         # 游戏数学工具（缓动函数、随机数等）
│   ├── SpatialHashGrid.cs   # 空间哈希网格（优化碰撞检测）
│   └── ObjectPool.cs        # 对象池（减少GC压力）
├── Data/                    # 数据管理
│   ├── PlayerData.cs        # 玩家数据（等级、经验、金币等）
│   ├── SaveData.cs          # 存档数据结构
│   ├── WeaponData.cs        # 武器数据定义
│   └── GameConfig.cs        # 游戏配置
├── Systems/                 # 系统管理
│   ├── GameStateManager.cs  # 游戏状态管理器（单例）
│   └── SaveManager.cs       # 存档管理器（自动保存、多槽位）
├── Utils/                   # 工具类
│   └── Extensions.cs        # Godot/C# 扩展方法
└── Examples/                # 混用示例
    ├── GdScriptCaller.cs           # GDScript 调用 C# 示例
    ├── CSharpToGdScript.cs         # C# 调用 GDScript 示例
    ├── example_gdscript_caller.gd  # GDScript 调用 C# 示例
    └── example_csharp_from_gdscript.gd  # C# 可调用的 GDScript 示例
```

## 配置说明

### project.godot 更新

已添加以下配置：

```ini
[application]
config/features=PackedStringArray("4.6", "C#", "GL Compatibility")

[autoload]
GameStateManager="*res://src/cs/Systems/GameStateManager.cs"
SaveManager="*res://src/cs/Systems/SaveManager.cs"

[dotnet]
project/assembly_name="DreamerHeroines"
```

### .csproj 配置

- **项目名**: DreamerHeroines
- **目标框架**: .NET 8.0
- **Godot SDK**: 4.6.1
- **可空引用类型**: 已启用
- **调试符号**: 已配置

## 使用说明

### 1. GDScript 调用 C#

在 GDScript 中通过节点引用调用 C# 方法：

```gdscript
# 获取 C# 节点
@onready var cs_caller = $"../GdScriptCaller"

# 调用保存功能
cs_caller.save_game(0)

# 获取玩家数据
var player_data = cs_caller.get_player_data()
print("Level: ", player_data.level)

# 添加金币
cs_caller.add_gold(100)

# 解锁武器
cs_caller.unlock_weapon("weapon_rifle")
```

### 2. C# 调用 GDScript

在 C# 中使用 `Call` 方法调用 GDScript：

```csharp
// 获取 GDScript 节点
var gameManager = GetNode("/root/GameManager");

// 调用方法
gameManager.Call("play_sound", "shoot");
gameManager.Call("spawn_enemy", "enemy_basic", new Vector2(100, 200));

// 获取属性
var currentLevel = gameManager.Get("current_level");

// 设置属性
gameManager.Set("player_score", 1000);
```

### 3. 使用 SaveManager

```csharp
// 创建新存档
SaveManager.Instance.CreateNewSave(0, "My Save");

// 保存游戏
SaveManager.Instance.SaveToSlot(0);

// 加载游戏
SaveManager.Instance.LoadFromSlot(0);

// 获取玩家数据
var playerData = SaveManager.Instance.GetPlayerData();
playerData.AddGold(100);
playerData.AddExperience(500);
```

### 4. 使用 GameStateManager

```csharp
// 切换游戏状态
GameStateManager.Instance.ChangeState(GameState.Playing);

// 暂停游戏
GameStateManager.Instance.Pause();

// 恢复游戏
GameStateManager.Instance.Resume();

// 检查当前状态
if (GameStateManager.Instance.IsPlaying)
{
    // 游戏进行中
}
```

### 5. 使用 MathUtils

```csharp
// 缓动函数
float value = MathUtils.EaseOutQuad(t);
float smooth = MathUtils.SmoothStep(from, to, t);

// 随机数
float random = MathUtils.RandomRange(0f, 100f);
Vector2 randomPoint = MathUtils.RandomPointInCircle(10f);

// 角度计算
float angle = MathUtils.VectorToAngle(direction);
float delta = MathUtils.DeltaAngle(current, target);
```

### 6. 使用 ObjectPool

```csharp
// 创建对象池
var pool = new NodePool<Projectile>(this, projectileScene, 10, 50);

// 获取对象
var projectile = pool.Get();
projectile.Position = spawnPosition;

// 返回对象到池
pool.Return(projectile);
```

### 7. 使用 SpatialHashGrid

```csharp
// 创建空间哈希网格
var grid = new SpatialHashGrid(64f);

// 插入对象
grid.Insert(enemy, enemy.GlobalPosition, enemy.Radius);

// 查询范围内的对象
var nearby = grid.Query(playerPosition, 100f);

// 更新对象位置
grid.Update(enemy, newPosition, enemy.Radius);
```

## 编译说明

1. 确保已安装 .NET 8.0 SDK
2. 在 Godot 编辑器中打开项目
3. 点击 "Build" 按钮或按 Ctrl+Shift+B 编译 C# 代码
4. 编译成功后即可运行

## 注意事项

1. C# 和 GDScript 可以互相调用，但类型需要正确转换
2. C# 类需要继承 `Node` 或其子类才能在 Godot 中使用
3. 使用 `[Signal]` 特性定义信号
4. 使用 `public` 方法暴露给 GDScript 调用
5. 自动保存功能默认每5分钟触发一次
6. 存档文件存储在 `user://saves/` 目录
