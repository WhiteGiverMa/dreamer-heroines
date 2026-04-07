# godot-mcp 本地修改记录

> **最近更新**: 2026-04-07
> **当前源码位置**: `G:\dev\godot-mcp-fc-a`
> **目的**: 记录 MCP fork 的历史本地修改与当前维护方式

## 仓库说明

当前统一维护的仓库是：

- **上游增强版**: [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp)
- **当前团队 fork**: [WhiteGiverMa/godot-mcp-full-control-adaptive](https://github.com/WhiteGiverMa/godot-mcp-full-control-adaptive)
- **本地工作目录**: `G:\dev\godot-mcp-fc-a`

本项目中的 `addons/godot_mcp/` 运行时脚本采用 **vendor** 方式同步自该 fork 的 `build/scripts/` 产物，而不是继续在项目内长期分叉维护。

参考版本关系：

| 版本 | 工具数量 | 说明 |
|------|---------|------|
| Coding-Solo/godot-mcp | 20 | 原版 |
| tugcantopaloglu/godot-mcp | **149+** | 增强版，扩展了运行时代码执行、节点操作、网络、3D/2D 渲染等 |
| WhiteGiverMa/godot-mcp-full-control-adaptive | 基于上游增强版 | 当前使用 fork，追加 GUIDE 兼容与下游同步流程 |

**端口配置**: MCP 交互服务器使用端口 **9090** (默认)

---

## 修改 1: ~~端口号~~ (已移除)

~~端口从 9090 改为 19090（因 Clash 占用）~~

**当前状态**: 端口保持 **9090**，无需修改。如果端口被占用，请关闭 Clash 或修改端口。

**同步修改**: 
- `G:\dev\DreamerHeroines\mcp_interaction_server.gd` 第 12 行: `const PORT: int = 19090`

---

## 修改 2: game_call_method 的 args schema

**位置**: 约 1198-1207 行  
**原因**: JSON Schema 不支持联合类型数组，需用 `anyOf`

```typescript
// 修改前
args: {
  type: 'array',
  description: 'Optional array of arguments to pass to the method',
},

// 修改后
args: {
  type: 'array',
  items: {
    anyOf: [
      { type: 'string' },
      { type: 'number' },
      { type: 'boolean' },
      { type: 'object' },
      { type: 'array', items: {} },
      { type: 'null' }
    ],
    description: 'Argument value (can be any type)',
  },
  description: 'Optional array of arguments to pass to the method',
},
```

---

## 修改 3: game_emit_signal 的 args schema

**位置**: 约 1479-1492 行  
**原因**: 同上，array 类型必须有 items

```typescript
// 修改前
args: { type: 'array', description: 'Optional arguments to pass with the signal' },

// 修改后
args: {
  type: 'array',
  items: {
    anyOf: [
      { type: 'string' },
      { type: 'number' },
      { type: 'boolean' },
      { type: 'object' },
      { type: 'array', items: {} },
      { type: 'null' }
    ],
    description: 'Argument value (can be any type)',
  },
  description: 'Optional arguments to pass with the signal',
},
```

---

## 修改 4: game_tilemap 的 cells schema

**位置**: 约 1915 行

```typescript
// 修改前
cells: { type: 'array', description: 'Array of cell objects for set_cells/erase_cells' },

// 修改后
cells: {
  type: 'array',
  items: { type: 'object' },
  description: 'Array of cell objects for set_cells/erase_cells',
},
```

---

## 修改 5: game_create_animation 的 tracks schema

**位置**: 约 2024 行

```typescript
// 修改前
tracks: { type: 'array', description: 'Array of track definitions' },

// 修改后
tracks: {
  type: 'array',
  items: { type: 'object' },
  description: 'Array of track definitions',
},
```

---

## 修改 6: game_rpc 的 args schema

**位置**: 约 2214 行

```typescript
// 修改前
args: { type: 'array', description: 'Arguments for the RPC call' },

// 修改后
args: {
  type: 'array',
  items: {
    anyOf: [
      { type: 'string' },
      { type: 'number' },
      { type: 'boolean' },
      { type: 'object' },
      { type: 'array', items: {} },
      { type: 'null' }
    ],
  },
  description: 'Arguments for the RPC call',
},
```

---

## 修改 7: game_procedural_mesh 的顶点数据 schema

**位置**: 约 2437-2453 行

```typescript
// 修改前
vertices: { type: 'array', description: 'Vertex positions [[x,y,z],...]' },
normals: { type: 'array', description: 'Vertex normals [[x,y,z],...]' },
uvs: { type: 'array', description: 'UV coordinates [[u,v],...]' },
indices: { type: 'array', description: 'Triangle indices [i0,i1,i2,...]' },

// 修改后
vertices: {
  type: 'array',
  items: { type: 'array', items: { type: 'number' } },
  description: 'Vertex positions [[x,y,z],...]',
},
normals: {
  type: 'array',
  items: { type: 'array', items: { type: 'number' } },
  description: 'Vertex normals [[x,y,z],...]',
},
uvs: {
  type: 'array',
  items: { type: 'array', items: { type: 'number' } },
  description: 'UV coordinates [[u,v],...]',
},
indices: {
  type: 'array',
  items: { type: 'number' },
  description: 'Triangle indices [i0,i1,i2,...]',
},
```

---

## 修改 8: game_path_3d 的 points schema

**位置**: 约 2554 行

```typescript
// 修改前
points: { type: 'array', description: 'Array of points [{x,y,z},...]' },

// 修改后
points: {
  type: 'array',
  items: { type: 'object' },
  description: 'Array of points [{x,y,z},...]',
},
```

---

## 修改 9: game_canvas_draw 的 points schema

**位置**: 约 2660 行

```typescript
// 修改前
points: { type: 'array', description: 'Polygon points [{x,y},...]' },

// 修改后
points: {
  type: 'array',
  items: { type: 'object' },
  description: 'Polygon points [{x,y},...]',
},
```

---

## 修改 10: game_shape_2d 的 points schema

**位置**: 约 2715 行

```typescript
// 修改前
points: { type: 'array', description: 'Array of points [{x,y},...]' },

// 修改后
points: {
  type: 'array',
  items: { type: 'object' },
  description: 'Array of points [{x,y},...]',
},
```

---

## 修改 11: game_path_2d 的 points schema

**位置**: 约 2736 行

```typescript
// 修改前
points: { type: 'array', description: 'Array of points [{x,y},...]' },

// 修改后
points: {
  type: 'array',
  items: { type: 'object' },
  description: 'Array of points [{x,y},...]',
},
```

---

## 修改 12: create_script 的 methods schema

**位置**: 约 2872 行

```typescript
// 修改前
methods: { type: 'array', description: 'Method stubs to include' },

// 修改后
methods: {
  type: 'array',
  items: { type: 'string' },
  description: 'Method stubs to include',
},
```

---

## 当前维护方式

### fork 开发

在以下仓库中修改源码：

```powershell
cd G:\dev\godot-mcp-fc-a
npm run build
npm test
```

### 下游同步

使用 fork 仓库中的同步脚本，将 `build/scripts/*.gd` vendor 到项目：

```powershell
cd G:\dev\godot-mcp-fc-a
.\scripts\sync-downstream.ps1
```

### 项目内保留文件

下列内容保留在项目中本地维护，不随 fork 整目录覆盖：

- `addons/godot_mcp/plugin.cfg`
- `addons/godot_mcp/mcp_editor_plugin.gd`
- `addons/godot_mcp/README.md`
- `config/mcp_server.json`
- `src/autoload/project_mcp_commands.gd`

## 历史更新方法（归档）

以下流程是旧阶段保留的历史记录，对应当时手动维护的旧本地仓库（**现已废弃**）：

```bash
cd C:\Users\A1337\godot-mcp

# 1. 更新上游代码
git fetch origin
git checkout main
git pull origin main

# 2. 变基到最新版本
git checkout local-schema-fixes
git rebase origin/main

# 3. 推送到个人 fork
git push myfork local-schema-fixes

# 4. 重新构建
npm run build
```

当前请优先参考 fork 仓库中的 `docs/upstream-sync.md`。
