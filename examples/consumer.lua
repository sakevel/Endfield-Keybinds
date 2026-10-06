-- Inside the consumer mod's transformed controller module, on the game's thread.
-- Replace example-mod with your successfully loaded mod.ini id.
require_ex("Common/Utils/UIUtils")
if not rawget(_G,"ZMLKeybinds") then require_ex("UI/Panels/GameSetting/GameSettingCtrl") end
local K=assert(rawget(_G,"ZMLKeybinds"),"Missing keybinds API1 dependency")
assert(K.api==1,"Unsupported keybinds API")
local action=K.find("example-mod","do-something") or assert(K.register("example-mod",{
    id="do-something",name="执行功能",primary="F8",secondary="None"}))

-- Call from OnShow / a gameplay lifecycle on the MAIN thread.
local function activate(ctrl)
    return assert(action.bind(ctrl.view.inputGroup.groupId,function()
        -- Handler executed on game input thread
        Notify(MessageConst.SHOW_TOAST,"模组功能已触发")
    end,{gameplay=true,timing="OnClick"}))
end

-- Save the returned cleanup function, call it in OnHide/OnClose.
-- Unregister input binding on lifecycle exit
return activate
