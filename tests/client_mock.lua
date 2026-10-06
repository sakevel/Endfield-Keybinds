local function event()
    local e={listeners={}}
    function e:RemoveAllListeners() self.listeners={} end
    function e:AddListener(fn) self.listeners[#self.listeners+1]=fn end
    function e:fire(...) local s={} for i,f in ipairs(self.listeners)do s[i]=f end for _,f in ipairs(s)do f(...)end end
    return e
end
function go()
    return {active=true,SetActive=function(self,v)self.active=v end}
end
function control()
    local c={button={onClick=event(),onHoverChange=event()},delBtn={onClick=event(),gameObject=go()},
        icon={gameObject=go(),LoadSpriteWithOutFormat=function(self,p)self.path=p end},
        modifyIcon={gameObject=go(),LoadSpriteWithOutFormat=function(self,p)self.path=p end},text={}}
    c.stateCtrl={SetState=function(_,s)c.state=s end};return c
end
function keyview() return {gameObject=go(),rectTransform={},keyAction1=control(),keyAction2=control()} end
Vector2=function(x,y)return {x=x,y=y}end;Vector2=setmetatable({zero={x=0,y=0}},{__call=function(_,x,y)return {x=x,y=y}end})
UIConst={GameSettingItemState={Normal='Normal',Disabled='Disabled'}}
GEnums={SettingItemType={Key=7}}
GameSettingConst={TAB_ID_VIDEO='video',TAB_ID_KEY_HINT='keys'}
GameSetting={IsSettingItemValid=function()return true end,IsSettingItemVisible=function()return true end}
GameSettingHelper={IsQualitySubSetting=function(id)assert(id:sub(1,7)~='zmlkb__','own IDs must not enter native setting helpers');return false end}
UIUtils={setSizeDeltaY=function(rect,h)rect.height=h end}
CSUtils={CreateObject=function(template,parent)return keyview()end}
Utils={wrapLuaNode=function(object)return object end}
string.isEmpty=function(s)return s==nil or s==''end
Language={LUA_GAME_SETTING_KEY_SAVE_SUCCESS='已保存',LUA_GAME_SETTING_KEY_SAVE_FAILED_WARNING='警告',LUA_GAME_SETTING_KEY_CODE_IN_BLACK_LIST='禁止键',
    LUA_GAME_SETTING_KEY_RESET_ALL_ACTIONS='恢复默认',ui_set_gamesetting_keyhint1='主键',ui_set_gamesetting_keyhint2='备用键'}
MessageConst={SHOW_TOAST='toast',SHOW_POP_UP='popup'}
PanelId={GameSettingKeycodePopup=10,GameSetting=11}
KEY_ACTION_STATE={None=0,Dirty=1,Warning=2}
KEY_ACTION_STATE_BITS=2;KEY_ACTION_STATE_MASK=3;KEY_ACTION_STATE_MAX_LEVEL=3
function PackKeyActionState(p,s)return (p&3)+((s&3)<<2)end
function UnpackKeyActionState(n)return n&3,(n>>2)&3 end
function HasKeyActionState(n,v)return (n&v)==v end
lume={clear=function(t)for k in pairs(t)do t[k]=nil end end}
nativeSave=0;nativeReset=0;nativeClear=0
GameInstance={isInGameplay=true,player={gameSettingSystem={
    SaveSetting=function(self,fn)nativeSave=nativeSave+1;fn()end,
    ResetAllKeySettings=function()nativeReset=nativeReset+1 end,
    ClearAllPendingKeySettings=function()nativeClear=nativeClear+1 end}}}
InputDeviceFlags={Keyboard='Keyboard'}
lastToast=nil;confirmPopup=nil
function Notify(message,arg)
    if message=='toast' then lastToast=arg elseif message=='popup' then confirmPopup=arg end
end
logger={error=function()end}
InputManagerInst={CheckActionKeyCodeConflict=function(self,action,code)return code.name=='Space' end,
    AnyKeyboardKey=function()return keySuccess,keyValue,keyBlacklist end,
    GetPlayerActionInfo=function()return {primaryKeyboardInput='Space',needSecond=true,secondaryKeyboardInput=''}end}
InputManager={GetKeyIconPath=function(input)return input end,GetKeyboardIconPath=function(k)return 'native/'..k end}
CS={Beyond={Input={KeyboardKeyCode=setmetatable({},{__index=function(t,k)
    local e={name=k,ToString=function(self)return self.name end};rawset(t,k,e);return e end}),
    InputManager={GetStringByKeyboardKeyCode=function(code)return code.name end,GetKeyboardIconPath=InputManager.GetKeyboardIconPath}}}}
CS.UnityEngine={Input={GetKey=function(key)return heldModifiers and heldModifiers[key] or false end},KeyCode=setmetatable({},{__index=function(_,k)return k end})}
ticks={};tickId=0
LuaUpdate={Add=function(self,name,fn)tickId=tickId+1;ticks[tickId]=fn;return tickId end,
    Remove=function(self,id)ticks[id]=nil;return -1 end}
GameSettingCtrl={};GameSettingItemCell={};GameSettingKeycodePopupCtrl={}
UIManager={persistentInputBindingKey=99}
function UIManager:Open(id,args) openedArgs=args end
function UIManager:Close(id) closedPopup=true end
disk=nil;writes=0;live={};nextId=0
P={owner=function(id)if id=='demo' or id=='keybinds' then return id end end,
    validKey=function(k)return k=='None' or k=='F8' or k=='F9' or k=='F10' or k=='F11' or k=='F12' or k=='Space' end,
    read=function()return disk end,write=function(s)if writeFail then return false,'写入失败' end disk=s;writes=writes+1;return true end,
    bind=function(g,k,fn,opts)nextId=nextId+1;live[nextId]={key=k,fn=fn};return nextId end,
    enable=function()end,unbind=function(id)live[id]=nil end,allowed=function()return true end}
ZMLKeybinds=factory(P)
demo=assert(ZMLKeybinds.register('demo',{id='action',name='演示功能',primary='F8'}))
assert(ZMLKeybinds.register('keybinds',{id='test',name='测试按键绑定'}))
lease=assert(demo.bind(12,function()end))
