-- Injected into UIUtils on the main Lua thread.
if rawget(_G,"ZMLKeybinds") then error("Keybinds API namespace occupied") end
local path = __ZML_STATE_FILE__
local U,IO=CS.UnityEngine,CS.System.IO
local function report(event)
    pcall(function()
        local f=assert(loadstring(LuaManagerInst:LoadLua("ZML/Api"),"@ZML/Api"))
        f().report("keybinds",event)
    end)
end
local function enum(name)
    if type(name)~="string" or not name:match("^[A-Za-z][A-Za-z0-9]*$") then return nil end
    local ok,value=pcall(function() return CS.Beyond.Input.KeyboardKeyCode[name] end)
    return ok and value or nil
end
local P={}
local function spec(name)
    if type(name)~="string" or #name>48 then return nil end
    local key,mods,order=name,{},0
    while key:find("+",1,true) do
        local prefix,rest=key:match("^([^+]+)%+(.+)$")
        local n=prefix=="Ctrl" and 1 or prefix=="Alt" and 2 or prefix=="Shift" and 3 or 0
        if n<=order then return nil end
        order=n;mods[prefix]=true;key=rest
    end
    if not enum(key) or (key=="None" and order>0) then return nil end
    return key,mods
end
function P.validKey(name) return spec(name)~=nil end
local function service(path)
    local f=assert(loadstring(LuaManagerInst:LoadLua("ZML/Mod/keybinds/"..path),"@ZML/Mod/keybinds"));return f()
end
function P.nativeValid(code) local ok,value=pcall(service,"Valid/"..code:gsub("%+","_"));return ok and value==true end
function P.down(code)
    local name,mods=spec(code);if not name or name=="None" then return false end
    local input,keyCode=U.Input,U.KeyCode
    local function held(k)return input.GetKey(keyCode[k]) end
    return held(name) and (not mods.Ctrl or held("LeftControl") or held("RightControl")) and
        (not mods.Alt or held("LeftAlt") or held("RightAlt")) and
        (not mods.Shift or held("LeftShift") or held("RightShift"))
end
function P.owner(id)
    if id=="keybinds" then return "永动接线器" end
    local ok,result=pcall(function()
        local f=assert(loadstring(LuaManagerInst:LoadLua("ZML/Api"),"@ZML/Api"))
        local mod=f().mod(id);return mod and mod.name
    end)
    return ok and result or nil
end
function P.read()
    local ok,text=pcall(function()
        if not IO.File.Exists(path) then return nil end
        if IO.FileInfo(path).Length>32768 then error("size") end
        return IO.File.ReadAllText(path,CS.System.Text.Encoding.UTF8)
    end)
    if not ok then return nil,"无法读取按键配置" end
    return text
end
function P.write(text)
    local tmp=path..".tmp."..CS.System.Guid.NewGuid():ToString("N")
    local ok=pcall(function()
        IO.Directory.CreateDirectory(IO.Path.GetDirectoryName(path))
        IO.File.WriteAllText(tmp,text,CS.System.Text.UTF8Encoding(false))
        if IO.File.Exists(path) then IO.File.Replace(tmp,path,nil) else IO.File.Move(tmp,path) end
    end)
    if IO.File.Exists(tmp) then pcall(IO.File.Delete,tmp) end
    return ok,not ok and "无法原子保存按键配置" or nil
end
function P.bind(group,code,fn,options)
    local name,mods=spec(code);assert(name,"key enum unavailable")
    local native=assert(enum(name),"key enum unavailable")
    local timing=assert(CS.Beyond.Input.InputTimingType[options.timing],"input timing unavailable")
    local modify=""
    if next(mods) then
        local keyboard=CS.Beyond.Input.KeyboardInput()
        keyboard.key=native;keyboard.useCtrl=mods.Ctrl==true;keyboard.useAlt=mods.Alt==true;keyboard.useShift=mods.Shift==true
        modify=keyboard.modifyString -- Native modifier string serialization
    end
    local id=UIUtils.bindInputEvent(native,fn,modify,timing,group)
    assert(type(id)=="number" and id>=0,"native binding rejected")
    local ok=pcall(function() InputManagerInst:ToggleBinding(id,false) end)
    if not ok then pcall(function() InputManagerInst:DeleteBinding(id) end);error("native binding disable failed") end
    return id
end
function P.enable(id,on) InputManagerInst:ToggleBinding(id,on) end
function P.unbind(id) InputManagerInst:DeleteBinding(id) end
function P.allowed(options)
    if not U.Application.isFocused then return false end
    if options.gameplay and not GameInstance.isInGameplay then return false end
    if UIManager:IsOpen(PanelId.GameSetting) or UIManager:IsOpen(PanelId.GameSettingKeycodePopup) then return false end
    local es=U.EventSystems.EventSystem.current
    if es and es.currentSelectedGameObject then
        local go=es.currentSelectedGameObject
        if go:GetComponent(typeof(CS.TMPro.TMP_InputField)) or go:GetComponent(typeof(U.UI.InputField)) then return false end
    end
    return true
end
P.report=report
_G.ZMLKeybinds=ZMLKBFactory(P)
-- Diagnostic action definition
_G.ZMLKeybinds.register("keybinds",{id="test",name="测试按键绑定",primary="None",secondary="None"})
function _G.ZMLKeybinds._nativeEditing(editing) pcall(service,editing and "Editing/1" or "Editing/0") end
function _G.ZMLKeybinds._syncNative()
    local ok,rows=pcall(service,"Actions");if not ok or type(rows)~="table" then return end
    local present={}
    for _,row in ipairs(rows) do
        if type(row)=="table" and type(row.owner)=="string" and type(row.id)=="string" then
            present[row.owner..":"..row.id]=true
            if not _G.ZMLKeybinds.find(row.owner,row.id) then _G.ZMLKeybinds.register(row.owner,row) end
        end
    end
    for _,action in ipairs(_G.ZMLKeybinds.list()) do
        if action.native and not present[action.id] then
            local owner,id=action.id:match("^([^:]+):([^:]+)$");_G.ZMLKeybinds.unregister(owner,id)
        end
    end
end
_G.ZMLKeybinds._syncNative()
local gateId,lastBlocked
function _G.ZMLKeybinds._attachGate()
    if gateId or not LuaUpdate then return end
    gateId=LuaUpdate:Add("Tick",function()
        local ok,allowed=pcall(P.allowed,{gameplay=false})
        local blocked=not ok or not allowed
        if blocked~=lastBlocked then
            local sent=pcall(service,blocked and "Gate/1" or "Gate/0")
            -- Throttle error logging
            lastBlocked=blocked
            if not sent then report("native_gate_unavailable") end
        end
    end)
end
_G.ZMLKeybinds._attachGate()
