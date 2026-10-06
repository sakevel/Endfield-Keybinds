# 原生按键绑定库 / Endfield-Keybinds

适用于《明日方舟：终末地》的通用按键设置扩展库模组。将模组注册的自定义按键动作无缝集成到游戏的「设置 → 按键绑定」原生界面中，支持主键与备用键配置、热键保存与冲突检测。

---

## 功能特性

- **原生界面无缝融合**：复用游戏原生的 `GameSettingItemCell` 控件、按键图标与录入弹窗，按模组名称自动分组呈现。
- **完善的按键录入能力**：支持单键、鼠标允许按键及 `Ctrl+Alt+Shift` 组合键录入，支持主键与备用键双槽位独立配置与清除。
- **集中式生命周期管理**：提供安全的按键绑定租约（Lease）与状态监听机制，自动处理菜单失焦、打字输入拦截与销毁解绑。

---

## 玩家使用指南

1. 安装本库后，在游戏内打开「设置」→「按键绑定」，底部会自动显示已安装模组注册的按键选项。
2. 点击任意动作的主键或备用键即可进入录入状态，按下目标按键完成设定；鼠标悬停可点击清除。
3. 点击右下角原生的「保存设置」即时应用新按键；退出未保存则还原为先前配置。
4. 按键设置保存在 `%LOCALAPPDATA%\EndfieldModLoader\mods\keybinds\bindings.ini`。

---

## 开发者接入说明

### 依赖声明

在模组的 `mod.ini` 中声明依赖：

```ini
[mod]
depends=keybinds
```

### Lua 接口使用示例

```lua
local K = rawget(_G, "ZMLKeybinds")
if not K or K.api ~= 1 then return end

-- 1. 注册动作（带默认按键）
local action = K.find("my-mod", "summon") or assert(K.register("my-mod", {
    id = "summon",
    name = "召唤摩托车",
    primary = "F8",
    secondary = "None"
}))

-- 2. 绑定到原生输入组（例如面板处于活动状态时触发）
local unbind = action.bind(self.view.inputGroup.groupId, function()
    print("触发了召唤功能")
end, { gameplay = true, timing = "OnClick" })

-- 3. 面板关闭或销毁时解除绑定
-- unbind()
```

### Native C++ 接口

若模组为纯 C++ 插件，可包含 [`sdk/include/keybinds_native.h`](sdk/include/keybinds_native.h)，获取 `ZML_KeybindsV1` 结构指针以进行按键状态查询与事件监听。

---

## 构建与安装

### 构建

```powershell
.\tools\build.ps1
.\tools\package.ps1
```

构建产物位于 `build/package/Release/keybinds`。

### 安装

退出游戏后，通过 ModLoader 的安装工具进行部署：

```powershell
..\Endfield-ModLoader\tools\install-mod.ps1 -ModPackage .\build\package\Release\keybinds
```
