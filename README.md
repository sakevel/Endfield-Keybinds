# 按键绑定 (Keybinds)

为《明日方舟：终末地》提供原生按键设置扩展库，将模组注册的自定义按键无缝接入游戏的「设置 → 按键绑定」原生界面。

## 功能特性

- **原生界面融合**：直接在游戏原生按键设置面板中按模组分组呈现，样式与交互完全一致。
- **双槽位与组合键**：支持主键与备用键独立配置，支持单键、鼠标按键以及 `Ctrl+Alt+Shift` 组合键录入。
- **冲突检测与保存**：支持按键冲突提示，点击原生「保存设置」即时生效并持久化。

## 玩家使用指南

1. 安装本库模组后启动游戏。
2. 打开「设置」→「按键绑定」，在页面下方即可看到各模组注册的自定义动作。
3. 点击主键或备用键槽位按下目标按键即可绑定，悬停可清空。

## 开发者快速接入 (Lua)

在模组中声明 `depends=keybinds` 后即可直接使用全局 API：

```lua
local K = rawget(_G, "ZMLKeybinds")
if not K then return end

-- 注册动作（带默认主键）
local action = K.find("my-mod", "action_id") or K.register("my-mod", {
    id = "action_id",
    name = "动作名称",
    primary = "F8",
    secondary = "None"
})

-- 监听触发事件
action.bind(self.view.inputGroup.groupId, function()
    print("按键被触发")
end, { gameplay = true, timing = "OnClick" })
```
