-- GameSetting controller and widget adapter.
local K=rawget(_G,"ZMLKeybinds")
if type(K)=="table" and K.api==1 then
    local S={popupNames=setmetatable({},{__mode="k"})}
    local seeds=setmetatable({},{__mode="k"})
    local modifiers=setmetatable({},{__mode="k"})
    local testLease,testGroup
    local function toast(text)
        Notify(MessageConst.SHOW_TOAST,tostring(text))
    end
    local function isOwn(id) return type(id)=="string" and id:sub(1,7)=="zmlkb__" end
    S.isOwn=isOwn
    local function settingId(id) return "zmlkb__"..id end
    function S.append(ctrl,list)
        if K._attachGate then K._attachGate() end
        if K._syncNative then K._syncNative() end
        if K._nativeEditing then K._nativeEditing(true) end
        local seed
        for _,data in ipairs(list) do
            if data.settingItemType==GEnums.SettingItemType.Key and data.keyActionScopes.Count>0 then seed=data;break end
        end
        if not seed then return end -- Validate seed entry
        seeds[ctrl]=seed
        if testLease and testGroup~=UIManager.persistentInputBindingKey then testLease();testLease=nil end
        if not testLease and UIManager.persistentInputBindingKey>=0 then
            local action=K.find("keybinds","test")
            if action then
                testGroup=UIManager.persistentInputBindingKey
                testLease=action.bind(testGroup,function() toast("模组按键绑定测试成功") end)
            end
        end
        local previous
        for _,a in ipairs(K.list()) do
            local group=a.owner~=previous and ("模组 · "..a.ownerName) or ""
            previous=a.owner
            local row={settingId=settingId(a.id),settingItemType=GEnums.SettingItemType.Key,
                settingText=a.name,settingGroupTitle=group,settingRedDot="",zmlKeybindId=a.id}
            list[#list+1]=row
            ctrl.m_itemDataMap[row.settingId]=row
        end
    end
    local function baseConflict(ctrl,code)
        if code=="None" then return nil end
        if code:find("+",1,true) then return nil end -- Single key check
        local keyCode=CS.Beyond.Input.KeyboardKeyCode[code]
        for _,rows in pairs(ctrl.m_keyActionScope2ItemDataList) do
            for _,row in ipairs(rows) do
                for _,ids in ipairs({row.keyActionIds1,row.keyActionIds2}) do
                    if ids.Count>0 then
                        local conflict=InputManagerInst:CheckActionKeyCodeConflict(ids[0],keyCode)
                        if conflict then return row.settingText end
                    end
                end
            end
        end
    end
    local function change(ctrl,row,slot,code,confirmed)
        local conflict=not confirmed and baseConflict(ctrl,code)
        if conflict then
            Notify(MessageConst.SHOW_POP_UP,{
                content="与原生按键「"..conflict.."」重复。继续将同时触发两个功能，不会删除原生绑定。",
                onConfirm=function()
                    if change(ctrl,row,slot,code,true) then UIManager:Close(PanelId.GameSettingKeycodePopup) end
                end})
            return false
        end
        local ok,err=K._stage(row.zmlKeybindId,slot,code)
        if not ok then toast(err);return false end
        -- Mark dirty bits for settings save
        local owner,id=row.zmlKeybindId:match("^([^:]+):([^:]+)$")
        local value=K._draft(row.zmlKeybindId);local saved=K.find(owner,id).get()
        ctrl:_SetKeyActionState(row.settingId,value[slot]~=saved[slot] and KEY_ACTION_STATE.Dirty or KEY_ACTION_STATE.None,slot==1)
        ctrl:_RefreshCurrentSettingTab()
        return true
    end
    function S.control(ctrl,cell)
        local row=cell.itemData
        if type(row)~="table" or not row.zmlKeybindId then return false end
        local draft=K._draft(row.zmlKeybindId)
        if not draft then return true end
        for slot,view in ipairs({cell.itemControl.keyAction1,cell.itemControl.keyAction2}) do
            local code=draft[slot]
            view.button.onClick:RemoveAllListeners();view.button.onHoverChange:RemoveAllListeners();view.delBtn.onClick:RemoveAllListeners()
            view.delBtn.gameObject:SetActive(false)
            view.text.text=nil
            view.modifyIcon.gameObject:SetActive(false)
            local hasKey=code~="None"
            local chord=hasKey and code:find("+",1,true)~=nil
            view.icon.gameObject:SetActive(hasKey and not chord)
            if hasKey then
                if chord then
                    local ok,modifier,icon=pcall(function()
                        local keyboard=CS.Beyond.Input.KeyboardInput()
                        keyboard.key=CS.Beyond.Input.KeyboardKeyCode[code:match("([^+]+)$")]
                        keyboard.useCtrl=code:find("Ctrl+",1,true)~=nil
                        keyboard.useAlt=code:find("Alt+",1,true)~=nil
                        keyboard.useShift=code:find("Shift+",1,true)~=nil
                        return CS.Beyond.Input.InputManager.GetKeyIconPath(keyboard,true,false,true),
                            CS.Beyond.Input.InputManager.GetKeyIconPath(keyboard,false,false,true)
                    end)
                    if ok and type(icon)=="string" and icon~="" then
                        view.icon.gameObject:SetActive(true);view.icon:LoadSpriteWithOutFormat(icon)
                        if type(modifier)=="string" and modifier~="" then
                            view.modifyIcon.gameObject:SetActive(true);view.modifyIcon:LoadSpriteWithOutFormat(modifier)
                        end
                    else view.text.text=code:gsub("%+"," + ") end
                else
                    local name=CS.Beyond.Input.InputManager.GetStringByKeyboardKeyCode(CS.Beyond.Input.KeyboardKeyCode[code])
                    view.icon:LoadSpriteWithOutFormat(CS.Beyond.Input.InputManager.GetKeyboardIconPath(name,false,true))
                end
                view.button.onHoverChange:AddListener(function(hover) view.delBtn.gameObject:SetActive(hover) end)
                view.delBtn.onClick:AddListener(function() change(ctrl,row,slot,"None") end)
            end
            view.stateCtrl:SetState(hasKey and "Normal" or "Empty")
            view.button.onClick:AddListener(function()
                -- Pass native seed for popup dialog
                UIManager:Open(PanelId.GameSettingKeycodePopup,{
                    settingItemData=seeds[ctrl],isPrimary=slot==1,zmlKeybindName=row.settingText,
                    onKeyCodeInput=function(codeValue) return change(ctrl,row,slot,S.capture(codeValue:ToString())) end})
            end)
        end
        return true
    end
    function S.save(ctrl,level)
        if not K._dirty() or HasKeyActionState(level,KEY_ACTION_STATE.Warning) then return false end
        local ok,err=K._save()
        if not ok then toast(err);return true end
        -- Clear dirty state after save
        for id in pairs(ctrl.m_keyActionStateMap) do if isOwn(id) then ctrl.m_keyActionStateMap[id]=nil end end
        if ctrl:_GetKeyActionStateLevel()==0 then
            ctrl:_RefreshCurrentSettingTab();toast(Language.LUA_GAME_SETTING_KEY_SAVE_SUCCESS);return true
        end
        return false
    end
    function S.reset(ctrl)
        K._reset()
        local ok,err=K._save();if not ok then toast(err);return false end
        return true
    end
    function S.modifier(code) return code=="LeftControl" or code=="RightControl" or code=="LeftShift" or code=="RightShift" or code=="LeftAlt" or code=="RightAlt" end
    function S.popupKey(ctrl,success,code)
        if success then
            if not S.modifier(code:ToString()) then modifiers[ctrl]=nil;return success,code end
            modifiers[ctrl]=code;return false,code
        end
        local pending=modifiers[ctrl]
        if pending and not CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode[pending:ToString()]) then
            modifiers[ctrl]=nil;return true,pending
        end
        return success,code
    end
    function S.capture(code)
        local U=CS.UnityEngine;local function held(name)return U.Input.GetKey(U.KeyCode[name]) end
        local value=""
        if held("LeftControl") or held("RightControl") then value=value.."Ctrl+" end
        if held("LeftAlt") or held("RightAlt") then value=value.."Alt+" end
        if held("LeftShift") or held("RightShift") then value=value.."Shift+" end
        -- Standalone modifier key support
        if S.modifier(code) then return code end
        return value..code
    end
    function S.open() if K._attachGate then K._attachGate() end;if K._nativeEditing then K._nativeEditing(true) end end
    function S.popupClose(ctrl) S.popupNames[ctrl]=nil;modifiers[ctrl]=nil end
    function S.close(ctrl) seeds[ctrl]=nil;K.discard();if K._nativeEditing then K._nativeEditing(false) end end
    _G.ZMLKeybindsUI=S
end
