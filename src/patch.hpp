#pragma once
#include <string>
#include <string_view>
#include <vector>
#include <algorithm>
namespace kb {
inline constexpr auto marker = "-- ZML_KEYBINDS_V1";
struct Change { size_t at; std::string text; };
inline bool unique(std::string_view text, std::string_view anchor, size_t& at) {
    at = text.find(anchor);
    return at != text.npos && text.find(anchor, at + anchor.size()) == text.npos;
}
// All contracts validated on the original source before any output is published.
inline bool patch(std::string_view in, int kind, std::string_view extension, std::string& out) {
    if (in.find(marker) != in.npos || extension.empty()) return false;
    std::vector<Change> changes;
    auto before = [&](std::string_view anchor, std::string text) {
        size_t p; if (!unique(in, anchor, p)) return false;
        changes.push_back({p, std::move(text)}); return true;
    };
    auto inside = [&](std::string_view name, std::string_view anchor, std::string text, bool after) {
        std::string head = std::string(kind == 1 ? "GameSettingCtrl." : "GameSettingKeycodePopupCtrl.") + std::string(name) + " = ";
        size_t start; if (!unique(in, head, start)) return false;
        auto finish = in.find(kind == 1 ? "\nGameSettingCtrl." : "\nGameSettingKeycodePopupCtrl.", start + head.size());
        if (finish == in.npos) finish = in.find("\nHL.Commit(", start);
        if (finish == in.npos) return false;
        size_t p; if (!unique(in.substr(start, finish-start), anchor, p)) return false;
        changes.push_back({start + p + (after ? anchor.size() : 0), std::move(text)}); return true;
    };
    if (kind == 0) {
        size_t p;
        if (!unique(in, "function UIUtils.bindInputEvent(key, action, modifyKeys, timing, groupId)", p) ||
            !before("_G.UIUtils = UIUtils", std::string(marker)+"\n"+std::string(extension)+"\n")) return false;
    } else if (kind == 1) {
        if (!inside("OnCreate", "function(self, arg)", "\n    if _G.ZMLKeybindsUI then _G.ZMLKeybindsUI.open() end\n", true) ||
            !inside("_BuildSettingTabData", "    return itemDataList", "    if tabData.tabId == GameSettingConst.TAB_ID_KEY_HINT and _G.ZMLKeybindsUI then\n        _G.ZMLKeybindsUI.append(self, itemDataList)\n    end\n", false) ||
            !inside("_RefreshSettingItemCell", "GameSettingHelper.IsQualitySubSetting(settingId)", "(not _G.ZMLKeybindsUI or not _G.ZMLKeybindsUI.isOwn(settingId)) and ", false) ||
            !inside("_InitSettingItemControlKey", "    local itemControl = itemCell.itemControl", "\n    if _G.ZMLKeybindsUI and _G.ZMLKeybindsUI.control(self, itemCell) then return end\n", true) ||
            !inside("_KeyClearPendingActions", "function(self)", "\n    if _G.ZMLKeybinds then _G.ZMLKeybinds.discard() end\n", true) ||
            !inside("_KeyResetActions", "        onConfirm = function()", "\n            if _G.ZMLKeybindsUI and not _G.ZMLKeybindsUI.reset(self) then return end\n", true) ||
            !inside("_KeySaveActions", "    local stateLevel = self:_GetKeyActionStateLevel()", "\n    if _G.ZMLKeybindsUI and _G.ZMLKeybindsUI.save(self, stateLevel) then return end\n", true) ||
            !inside("OnClose", "function(self)", "\n    if _G.ZMLKeybindsUI then _G.ZMLKeybindsUI.close(self) end\n", true) ||
            !before("HL.Commit(GameSettingCtrl)", std::string(marker)+"\n"+std::string(extension)+"\n")) return false;
    } else if (kind == 2) {
        if (!inside("_ListenInput", "    if isBlackList then", "    -- Allow captured keys for native and Mod actions; keep conflict/save checks.\n    isBlackList = false\n", false) ||
            !inside("OnCreate", "    self.m_settingItemData = arg.settingItemData", "\n    if _G.ZMLKeybindsUI then _G.ZMLKeybindsUI.popupNames[self] = arg.zmlKeybindName end\n", true) ||
            !inside("_UpdateView", "    self.view.actionNameText.text = settingItemData.settingText", "\n    if _G.ZMLKeybindsUI and _G.ZMLKeybindsUI.popupNames[self] then\n        self.view.actionNameText.text = _G.ZMLKeybindsUI.popupNames[self]\n    end\n", true) ||
            !inside("OnClose", "function(self)", "\n    if _G.ZMLKeybindsUI then _G.ZMLKeybindsUI.popupClose(self) end\n", true) ||
            !inside("_ListenInput", "    local success, keyCode, isBlackList = InputManagerInst:AnyKeyboardKey(self.m_actionScopes)", "\n    if _G.ZMLKeybindsUI and _G.ZMLKeybindsUI.popupNames[self] then\n        success, keyCode = _G.ZMLKeybindsUI.popupKey(self, success, keyCode)\n    end\n", true) ||
            !before("HL.Commit(GameSettingKeycodePopupCtrl)", std::string(marker)+"\n")) return false;
    } else if (kind == 3) {
        if (!before("HL.Commit(BattleActionCtrl)",std::string(marker)+"\n"+std::string(extension)+"\n"))return false;
    } else return false;
    std::sort(changes.begin(), changes.end(), [](auto& a, auto& b){return a.at > b.at;});
    std::string value(in);
    for (auto& change : changes) value.insert(change.at, change.text);
    if (value.size() > 768*1024) return false;
    out = std::move(value); return true;
}
inline std::string literal(std::string_view input) {
    std::string result = "\"";
    for (unsigned char c : input) {
        if (c == '\\' || c == '"') { result += '\\'; result += static_cast<char>(c); }
        else if (c < 32 || c == 127) {
            result += '\\'; result += static_cast<char>('0'+c/100);
            result += static_cast<char>('0'+(c/10)%10); result += static_cast<char>('0'+c%10);
        } else result += static_cast<char>(c);
    }
    return result+'"';
}
}
