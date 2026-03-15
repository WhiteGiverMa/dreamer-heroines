# AGENTS.md - Godot 4.6.1 Project Guidelines

> **Project**: WarHeroesStyleShooter - 2D横板射击游戏
> **Engine**: Godot 4.6.1
> **Languages**: GDScript + C# (混用架构)
> **Version**: 1.0

---

## Build & Run Commands

```bash
# Open project in Godot editor
godot --editor --path .

# Run specific scene
godot --scene scenes/test_level.tscn

# Run main scene
godot --scene scenes/main.tscn

# Export (requires export presets configured)
godot --export-release "Windows Desktop" ./build/

# C# build (if using dotnet)
dotnet build StrikeForceLike.csproj
```

---

## Code Style Guidelines

### GDScript

```gdscript
# Naming conventions
class_name Player          # PascalCase for classes
extends CharacterBody2D

const MAX_SPEED := 300.0   # UPPER_SNAKE_CASE for constants
@export var max_speed: float = 300.0  # snake_case for variables

# Type hints (required)
var health: int = 100
var velocity: Vector2 = Vector2.ZERO

# Private methods with underscore
func _ready() -> void:
func _physics_process(delta: float) -> void:
func _handle_input() -> void:

# Signals (snake_case)
signal health_changed(current: int, max: int)
signal died

# Comments in Chinese (项目标准)
# 玩家移动逻辑
func move(direction: Vector2) -> void:
```

### C#

```csharp
// Naming conventions
namespace StrikeForceLike.Core  // PascalCase namespace
{
    public class PlayerData : INotifyPropertyChanged  // PascalCase class
    {
        private int _health;  // _camelCase private fields
        public int Health { get; set; }  // PascalCase public properties
        
        public void TakeDamage(int amount) { }  // PascalCase methods
    }
}
```

### Language Usage Rules

| Use Case | Language | Reason |
|----------|----------|--------|
| Player/Enemy/Weapon logic | GDScript | Hot reload for tuning |
| Data classes (Save/PlayerData) | C# | Type safety |
| Math utilities | C# | Performance |
| UI/Scene logic | GDScript | Godot integration |
| State machines | GDScript | Easy iteration |

---

## Project Structure

```
src/
├── autoload/       # Singletons (GDScript)
├── characters/     # Player/NPC
├── weapons/        # Weapon system
├── enemies/        # Enemy AI
├── levels/         # Level management
├── ui/             # UI scripts
├── utils/          # Utilities
└── cs/             # C# code
    ├── Core/       # Math/Utils
    ├── Data/       # Data classes
    └── Systems/    # Managers
```

---

## Key Conventions

1. **Physics Layers** (defined in project.godot):
   - Layer 1: Player
   - Layer 2: Enemies
   - Layer 3: World
   - Layer 4: Projectiles
   - Layer 5: Items
   - Layer 6: Platforms

2. **AutoLoad Singletons**:
   - GameManager
   - AudioManager
   - InputManager
   - SaveManager (C#)
   - LevelManager

3. **Configuration Files** (JSON in `config/`):
   - `gameplay_params.json` - Movement/jump/combat values
   - `weapon_stats.json` - Weapon balance
   - `enemy_stats.json` - Enemy stats

4. **Error Handling**:
   - GDScript: Use `push_error()` and `push_warning()`
   - C#: Use `GD.PushError()` and try-catch

---

## Testing

```bash
# Run scene tests
godot --headless --scene scenes/test_level.tscn

# C# unit tests (if added)
dotnet test
```

---

## Documentation References

- `docs/GDD.md` - Game Design Document
- `docs/TECH_SPEC.md` - Technical Specification
- `docs/ASSET_GUIDE.md` - Asset Guidelines
