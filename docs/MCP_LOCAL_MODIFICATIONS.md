# godot-mcp 本地修改记录

> **修改日期**: 2025-03-22
> **源码位置**: `C:\Users\A1337\godot-mcp\src\index.ts`
> **目的**: 修复 JSON Schema 验证错误，使 MCP 工具能正常使用

## 仓库说明

当前使用的是 [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp)，这是 [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) (2.4k stars) 的**增强版 fork**：

| 版本 | 工具数量 | 说明 |
|------|---------|------|
| Coding-Solo/godot-mcp | 20 | 原版 |
| tugcantopaloglu/godot-mcp | **149** | 增强版，扩展了运行时代码执行、节点操作、网络、3D/2D 渲染等 |

**个人 Fork**: [WhiteGiverMa/godot-mcp-whitegiver-adapted](https://github.com/WhiteGiverMa/godot-mcp-whitegiver-adapted)

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

## 更新方法

如果上游更新，执行以下步骤保留本地修改：

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
