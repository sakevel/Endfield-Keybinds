-- Actual platform/native settings adapter is already installed by client.py.
local K=ZMLKeybinds
local h=assert(K.register('demo',{id='chord',name='组合键',primary='Ctrl+Shift+F12',migrate=true}))
assert(fileDisk:find('demo:chord=Ctrl+Shift+F12,None',1,true))
local stop=assert(h.bind(12,function()end))
assert(nativeCalls.key=='F12' and nativeCalls.mods=='CS','use actual KeyboardInput.modifyString, not a guessed separator')
heldKeys={LeftControl=true,LeftShift=true,F12=true}
assert(h.down() and h.pressed() and not h.pressed())
CS.UnityEngine.Application.isFocused=false;assert(not h.down() and not h.pressed())
CS.UnityEngine.Application.isFocused=true;assert(not h.pressed(),'held key cannot retrigger when focus returns')
heldKeys={};assert(not h.pressed());heldKeys={LeftControl=true,LeftShift=true,F12=true};assert(h.pressed())
heldKeys={LeftControl=true,F12=true};assert(not h.down(),'both modifiers required')
assert(not K._stage(h.id,1,'Shift+Ctrl+F12') and not K._stage(h.id,1,'Ctrl+Ctrl+F12'))
assert(K._stage(h.id,1,'Ctrl+F11'));local before=K._draft(h.id)
local migrated=assert(K.register('demo',{id='legacy',name='旧键',primary='F7',migrate=true}))
assert(K._dirty() and K._draft(h.id)[1]==before[1] and h.get()[1]=='Ctrl+Shift+F12','migration does not commit existing drafts')
local fresh=ZMLKBFactory({owner=function()return 'Demo'end,validKey=function()return true end,read=function()return fileDisk end})
assert(fresh.register('demo',{id='legacy',name='Defaults changed',primary='F8',migrate=true}).get()[1]=='F7','saved legacy selection wins at next boot')
K.discard();stop()
-- Modifier-only selection is deferred until release; chords wait for base key.
local S=ZMLKeybindsUI;local popup={}
local cell={itemData={zmlKeybindId=h.id},itemControl={keyAction1=control(),keyAction2=control()}}
assert(S.control({},cell))
assert(cell.itemControl.keyAction1.icon.path=='native/F12' and cell.itemControl.keyAction1.modifyIcon.path=='native/CS')
assert(cell.itemControl.keyAction1.modifyIcon.gameObject.active and cell.itemControl.keyAction1.text.text==nil,'same native modifier/base icons as original settings')
heldKeys={LeftControl=true};local ctrl=CS.Beyond.Input.KeyboardKeyCode.LeftControl
local ok=S.popupKey(popup,true,ctrl);assert(not ok)
heldKeys.LeftShift=true;local shift=CS.Beyond.Input.KeyboardKeyCode.LeftShift
assert(not S.popupKey(popup,true,shift))
local f12=CS.Beyond.Input.KeyboardKeyCode.F12
assert(S.popupKey(popup,true,f12) and S.capture('F12')=='Ctrl+Shift+F12')
heldKeys={LeftControl=true};assert(not S.popupKey(popup,true,ctrl))
heldKeys={};local ok,value=S.popupKey(popup,false,nil);assert(ok and value==ctrl and S.capture('LeftControl')=='LeftControl')
S.popupClose(popup)
-- Native declarations enter the same model, retain migrated preferences and
-- are removed from the UI when the owner unregisters its native handle.
local apiSource="return {mod=function(id)if id=='demo' then return {name='Demo'} end end,report=function()end}"
local nativeRows="return {{owner='demo',id='native-thread',name='原生动作',primary='Ctrl+Shift+F9',secondary='None',native=true,migrate=true}}"
local editing
LuaManagerInst.LoadLua=function(_,path)
    if path=='ZML/Mod/keybinds/Actions' then return nativeRows end
    if path:find('ZML/Mod/keybinds/Valid/',1,true) then return 'return true' end
    if path:find('ZML/Mod/keybinds/Editing/',1,true) then editing=path:sub(-1)=='1';return 'return true' end
    return apiSource
end
K._syncNative();local nh=assert(K.find('demo','native-thread'))
assert(nh.get()[1]=='Ctrl+Shift+F9' and fileDisk:find('demo:native-thread=Ctrl+Shift+F9,None',1,true))
K._nativeEditing(true);assert(editing);K._nativeEditing(false);assert(not editing)
assert(K._stage(nh.id,1,'Ctrl+F10'));assert(K._save());assert(nh.get()[1]=='Ctrl+F10')
nativeRows='return {}';K._syncNative();assert(not K.find('demo','native-thread') and not nh.get())
