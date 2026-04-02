# Tooltip 组件设计说明

> 适用范围：DreamerHeroines 中所有需要 hover / focus 提示文案的 UI Control。
> 当前实现：Godot 4.6.1 / GDScript。

---

## 1. 设计目标

Tooltip 系统当前定位为一个**轻量、可复用、可本地化**的 UI primitive，专门解决以下需求：

- 鼠标 hover 显示提示
- 键盘 / 手柄 focus 显示提示
- 每个控件独立配置启用状态与文案 key
- Tooltip 锚定到目标控件，而不是跟随鼠标
- 每个场景只显示一个 tooltip 实例
- 文案随 `LocalizationManager.locale_changed` 即时刷新
- 支持单元测试与 runtime harness 验证

第一版刻意限制为**正文文本-only**，不处理富文本、图标、交互式弹层或复杂主题变体。

---

## 2. 当前架构

系统拆成三个明确角色：

### `TooltipTrigger`

路径：`src/ui/tooltip_trigger.gd`

职责：

- 挂在目标 `Control` 下
- 监听 `mouse_entered / mouse_exited / focus_entered / focus_exited`
- 根据 `tooltip_enabled` 与 `tooltip_translation_key` 决定是否显示
- 解析本地化文本
- 调用统一 host 契约：
  - `show_tooltip(trigger, target, body_text)`
  - `hide_tooltip()`

这个节点只负责“**什么时候显示 / 隐藏**”和“**显示什么文本**”。

### `TooltipHost`

路径：`src/ui/tooltip_host.gd`

职责：

- 作为每个场景的 tooltip 容器（`CanvasLayer`）
- 管理单个活动 tooltip
- 记录 `current_trigger` 与 `current_target`
- 按需实例化一个 `TooltipView`
- 在 `_process()` 中持续更新 tooltip 位置

这个节点只负责“**哪个 tooltip 正在显示**”和“**它挂在哪个 target 上**”。

### `TooltipView`

路径：

- `src/ui/tooltip_view.gd`
- `scenes/ui/tooltip_view.tscn`

职责：

- 渲染 body text
- 维护基础样式
- 计算并更新 tooltip 在 viewport 内的最终位置

这个节点只负责“**长什么样**”和“**放在哪里**”。

---

## 3. 为什么保留三段式，而不是继续合并

这套设计在本项目里是一个折中的最优点：

- `Trigger` 与具体控件强绑定，适合做局部配置
- `Host` 天然适合表达“一个 scene 只显示一个 tooltip”
- `View` 独立出来后，样式和布局调整不会污染触发逻辑

收敛重构后，复杂度主要已经从“架构层”降回“实现层”：

- 删除了多种 host 形态兼容逻辑
- 删除了 host / view 双份定位逻辑
- 删除了反射式 `has_method` / `call` 分派

因此现在**不建议再继续把三者硬合并**，除非未来确认 tooltip 永远只会是极小功能、且不再需要独立场景和可测性。

---

## 4. 场景树约定

推荐在使用 tooltip 的 UI 场景里显式放置一个 `TooltipHost`：

```text
YourUIScreen (Control)
├── ... your controls ...
└── TooltipLayer (CanvasLayer, script = tooltip_host.gd)
```

`TooltipTrigger` 会优先查找当前 scene 下名为 `TooltipLayer` 的 host。

如果场景里没有现成 host，trigger 仍然会懒创建一个 `TooltipHost`，但**推荐优先显式挂载**，原因是：

- 场景结构更直观
- 调试时更容易定位
- runtime harness 与测试路径更清晰
- 避免复用时忘记 host 来源

---

## 5. 复用方式

### 5.1 给任意按钮/控件加 Tooltip

1. 确保当前 UI 场景存在 `TooltipLayer`
2. 在目标 `Control` 下添加一个子节点：`TooltipTrigger`
3. 配置导出属性：
   - `tooltip_enabled = true`
   - `tooltip_translation_key = "your.translation.key"`

示例：

```text
Button
└── TooltipTrigger
    - tooltip_enabled = true
    - tooltip_translation_key = "ui.main_menu.button.settings"
```

### 5.2 文案来源

Tooltip 文案来自：

- `tooltip_translation_key`
- `LocalizationManager.tr(...)`

所以复用时应优先：

1. 先补 `localization/en.po`
2. 再补 `localization/zh_CN.po`
3. 最后在 trigger 上绑定 translation key

不要把 tooltip 文案直接硬编码进 trigger。

---

## 6. 行为约定

### 显示

- hover 进入：立即显示
- focus 进入：立即显示
- locale 改变且 tooltip 正在显示：立即刷新文本

### 隐藏

- hover 离开：立即隐藏
- focus 离开：立即隐藏
- target 无效或离开场景树：host 自动隐藏

### 定位

当前策略由 `TooltipView._compute_position()` 定义：

1. 优先显示在目标控件上方中间
2. 上方放不下则翻到下方中间
3. 再根据 viewport 做 clamp

如果以后要改 tooltip 位置策略，应优先改 `TooltipView`，不要把定位逻辑再复制回 `TooltipHost`。

---

## 7. 可扩展建议

未来如果要增强 tooltip，推荐按以下方向扩展，而不是推翻结构：

### 低风险扩展

- 增加最大宽度 / 自动换行
- 增加主题色、边框、阴影等样式导出项
- 增加显示延迟 / 隐藏延迟
- 增加偏移量配置

### 中风险扩展

- 支持标题 + 正文双文本布局
- 支持 icon + body 组合
- 支持不同 tooltip 样式 variant

### 高风险扩展

- 改造成可交互 popover
- 支持多个 tooltip 同时显示
- 改为全局 autoload 管理跨 scene tooltip

如果需求升级到交互式弹层，那通常已经不再是 tooltip，而应该重新设计为 `Popover` / `ContextHelpPanel`。

---

## 8. 测试与验证

相关文件：

- 单测：`tests/unit/test_tooltip.gd`
- runtime scene：`tests/scenes/tooltip_test.tscn`
- runtime harness：`tests/scripts/tooltip_test.gd`

覆盖点：

- hover 显示
- focus 显示
- 立即隐藏
- disabled suppression
- 单实例替换
- viewport-safe placement
- locale refresh

建议复用或改造 tooltip 时，优先补这三类验证：

1. 单测先守契约
2. 再跑 runtime harness
3. 再接真实 UI 场景

---

## 9. 复用时的注意事项

- `TooltipTrigger` 的父节点**必须是 `Control`**
- 优先显式放置 `TooltipLayer`，不要过度依赖懒创建
- tooltip 文案优先走本地化 key，不要直接写死文本
- 如果改定位策略，只改 `TooltipView`
- 如果改显示/隐藏策略，只改 `TooltipTrigger`
- 如果改单实例或 scene 级管理策略，只改 `TooltipHost`

这条分层边界尽量不要混用，否则复杂度会重新长回来。
