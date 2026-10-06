-- Keybinds dependency adapter for consumer mods.
return function()
    require_ex("Common/Utils/UIUtils")
    if not rawget(_G,"ZMLKeybinds") then
        -- Lazy bootstrap via GameSettingCtrl
        require_ex("UI/Panels/GameSetting/GameSettingCtrl")
    end
    local api=rawget(_G,"ZMLKeybinds")
    if type(api)~="table" or api.api~=1 then return nil,"需要启用原生按键绑定库 keybinds API1" end
    return api
end
