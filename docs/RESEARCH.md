# 原生按键设置契约与组件接入

本文档说明游戏设置面板中的按键设置分页结构、按键录入弹窗及底层 `InputManager` 绑定契约。

---

## 1. 原生按键设置页面结构

### 1.1 数据与列表构建
- 游戏设置主控制器：`UI/Panels/GameSetting/GameSettingCtrl`。
- `_BuildSettingTabData`：遍历所有设置项分类。按键设置分页通过 `_InitKeyActionScopeMap` 初始化按键作用域，并按排序优先级生成设置列表。
- 自定义按键行追加在原生按键列表末尾，复用原生滚动视图容器的高度计算。

### 1.2 单元格与行控件复用
- 列表项单元格：`UI/Widgets/GameSettingItemCell`。
- 调用原生 `InitGameSettingItemCell(itemData, controlConfigs, extraArgs)` 完成按键行的初始化，复用官方的标题文本、热键展示按钮以及 Normal / Empty / Locked / Warning 等视觉状态。

---

## 2. 按键录入弹窗 (Keycode Popup)

### 2.1 弹窗调用契约
- 录键弹窗控制器：`UI/Panels/GameSettingKeycodePopup/GameSettingKeycodePopupCtrl`。
- 接收 `settingItemData`、主副键标识与按键输入回调。
- 弹窗通过在 `LuaUpdate` 中注册 `_ListenInput` 监听全局按键，调用 `AnyKeyboardKey(scopes)` 捕获玩家按下的实体按键。

### 2.2 脏数据标记与持久化
- 修改按键后，将对应行标记为 Dirty 状态，触发游戏原生的保存按钮与退出确认对话框。
- 玩家确认保存后，模组按键配置被写入本地独立配置文件。

---

## 3. 底层输入绑定契约 (InputManager)

- 核心绑定接口：
  ```lua
  UIUtils.bindInputEvent(key, action, modifyKeys, timing, groupId)
  ```
  底层调用 `InputManagerInst:CreateBinding`，将实体按键或修饰键组合绑定到指定动作。
- 按键枚举：采用原生 `Beyond.Input.KeyboardKeyCode` 强类型枚举，支持字母、数字、小键盘、功能键（F1–F15）及鼠标按键。
- 组合键支持：支持 Ctrl、Shift、Alt 修饰键组合，并复用原生图标获取接口展示按键图标。
