local ctrl=setmetatable({m_itemDataMap={},m_keyActionScope2ItemDataList={},m_keyActionStateMap={},
    m_contentHeight=0,m_itemCellMap={},m_itemCellHeight=100,m_itemCellHeightWithoutTitle=60,
    m_qualitySubSettingItemCellMap={},m_itemControlConfigs={},m_itemCellExtraArgs={},
    view={config={SETTING_ITEM_TITLE_PADDING_TOP=12,SETTING_ITEM_VERTICAL_SPACE=8}}}, {__index=GameSettingCtrl})
ctrl._IsSettingItemValid=function()return true end
ctrl._RefreshCurrentSettingTab=function(self)self.refreshed=(self.refreshed or 0)+1 end
ctrl.m_itemControlConfigs[7]={template={},initializer=function(cell)ctrl:_InitSettingItemControlKey(cell)end}
local tab={tabId='keys',tabItems={native=nativeSeed}}
local list=ctrl:_BuildSettingTabData(tab)
assert(#list==3 and list[1]==nativeSeed)
assert(list[2].zmlKeybindId=='demo:action' and list[3].zmlKeybindId=='keybinds:test')
assert(list[2].settingGroupTitle=='模组 · demo' and list[3].settingGroupTitle=='模组 · keybinds')
assert(ctrl.m_itemDataMap[list[2].settingId]==list[2])
assert(#ctrl.m_keyActionScope2ItemDataList.battle==1 and ctrl.m_keyActionScope2ItemDataList.battle[1]==nativeSeed)
ctrl.m_itemDataList={list}
local cell=setmetatable({rectTransform={anchoredPosition={x=20,y=0}},
    view={gameObject={},titleNode={gameObject=go()},titleText={},titleKey={gameObject=go()},itemText={},
        stateCtrl={SetState=function()end},redDot={gameObject=go()},controlNode={}}}, {__index=GameSettingItemCell})
cell._FirstTimeInit=function(self)self.m_itemControlCache=self.m_itemControlCache or {}end
ctrl:_RefreshSettingItemCell(cell,2,1)
assert(cell.itemData==list[2] and cell.view.itemText.text=='演示功能' and cell.view.titleText.text=='模组 · demo')
assert(cell.itemControl.keyAction1.state=='Normal' and cell.itemControl.keyAction2.state=='Empty')
assert(cell.itemControl.keyAction1.icon.path=='native/F8' and not cell.itemControl.keyAction1.modifyIcon.gameObject.active)
assert(ctrl.m_contentHeight==120 and cell.rectTransform.anchoredPosition.y==-120)
local view=cell.itemControl.keyAction1
view.button.onClick:fire()
assert(openedArgs.settingItemData==nativeSeed and type(openedArgs.settingItemData)=='userdata')
assert(openedArgs.zmlKeybindName=='演示功能' and openedArgs.isPrimary)
local popup=setmetatable({m_listenInputTick=-1,view={closeBtn={onClick={AddListener=function()end}},
    inputGroup={groupEnabled=true},actionNameText={},actionPriorityText={}},
    PlayAnimationOutAndClose=function(self)self.closed=true;self:OnClose()end}, {__index=GameSettingKeycodePopupCtrl,
    __newindex=function(t,k,v)if k=='m_settingItemData' then assert(type(v)=='userdata','HL.Userdata contract')end rawset(t,k,v)end})
popup:OnCreate(openedArgs);popup:OnShow()
assert(popup.view.actionNameText.text=='演示功能' and popup.view.actionPriorityText.text=='主键')
keySuccess=true;keyValue=CS.Beyond.Input.KeyboardKeyCode.F10;keyBlacklist=true
originalListen(popup);assert(not popup.closed and not ZMLKeybinds._dirty() and lastToast=='禁止键')
lastToast=nil
popup:_ListenInput();assert(lastToast==nil,'Mod keys bypass only the popup blacklist')
assert(popup.closed and next(ticks)==nil and ZMLKeybindsUI.popupNames[popup]==nil)
assert(ZMLKeybinds._draft('demo:action')[1]=='F10' and demo.get()[1]=='F8' and ctrl:_GetKeyActionStateLevel()==1)
ctrl:_KeySaveActions()
assert(demo.get()[1]=='F10' and writes==1 and nativeSave==0 and ctrl:_GetKeyActionStateLevel()==0)
-- Secondary and native row refresh reuse the real key control cache.
ctrl:_RefreshSettingItemCell(cell,2,1)
cell.itemControl.keyAction2.button.onClick:fire()
assert(not openedArgs.isPrimary and openedArgs.onKeyCodeInput(CS.Beyond.Input.KeyboardKeyCode.F11))
ctrl:_KeyClearPendingActions();assert(nativeClear==1 and demo.get()[2]=='None' and not ZMLKeybinds._dirty())
-- Native conflict handling preserves bindings
ctrl:_RefreshSettingItemCell(cell,2,1);cell.itemControl.keyAction1.button.onClick:fire()
assert(not openedArgs.onKeyCodeInput(CS.Beyond.Input.KeyboardKeyCode.Space))
assert(confirmPopup and not ZMLKeybinds._dirty());confirmPopup.onConfirm()
assert(closedPopup and ZMLKeybinds._draft('demo:action')[1]=='Space')
-- I/O failure leaves draft, native Save and active key unchanged.
writeFail=true;ctrl:_KeySaveActions();assert(demo.get()[1]=='F10' and ZMLKeybinds._dirty() and nativeSave==0)
writeFail=false;ctrl:_KeySaveActions();assert(demo.get()[1]=='Space' and nativeSave==0)
-- Mixed dirty native/mod keys still run native saving once.
assert(ZMLKeybinds._stage('demo:action',1,'F12'))
ctrl:_SetKeyActionState('zmlkb__demo:action',1,true);ctrl:_SetKeyActionState('native.jump',1,true)
ctrl:_KeySaveActions();assert(nativeSave==1 and demo.get()[1]=='F12' and ctrl:_GetKeyActionStateLevel()==0)
-- Native warning cancels draft commit
assert(ZMLKeybinds._stage('demo:action',1,'F9'));ctrl:_SetKeyActionState('native.jump',2,true)
ctrl:_KeySaveActions();assert(demo.get()[1]=='F12' and ZMLKeybinds._dirty() and lastToast=='警告')
ctrl:_KeyClearPendingActions()
-- Restore defaults includes Mod keys, retains native confirmation/save.
ctrl:_KeyResetActions();assert(confirmPopup);confirmPopup.onConfirm()
assert(nativeReset==1 and nativeSave==2 and demo.get()[1]=='F8')
-- Original row enters native initializer
ctrl:_RefreshSettingItemCell(cell,1,1)
assert(cell.itemData==nativeSeed and cell.itemControl.keyAction1.state=='Normal')
assert(cell.itemControl.keyAction1.icon.path=='Space')
local before=ctrl.m_contentHeight;ctrl:_RefreshSettingItemCell(cell,3,1)
assert(cell.itemData.zmlKeybindId=='keybinds:test' and cell.itemControl.keyAction1.state=='Empty' and ctrl.m_contentHeight>before)
local rebuilt=ctrl:_BuildSettingTabData(tab);assert(#rebuilt==3)
ZMLKeybindsUI.close(ctrl);assert(not ZMLKeybinds._dirty())

-- Native actions use relaxed capture
local calls=0
local nativePopup=setmetatable({view={inputGroup={groupEnabled=true}},
    m_actionScopes={'battle'},m_onKeyCodeInput=function(code)
        calls=calls+1;assert(code==keyValue);return false -- e.g. native conflict confirmation
    end,PlayAnimationOutAndClose=function(self)self.closed=true end}, {__index=GameSettingKeycodePopupCtrl})
keyBlacklist=true;keySuccess=true;lastToast=nil
nativePopup:_ListenInput();assert(calls==1 and not nativePopup.closed and lastToast==nil)
nativePopup.view.inputGroup.groupEnabled=false
nativePopup:_ListenInput();assert(calls==1,'disabled input group must remain blocked')
nativePopup.view.inputGroup.groupEnabled=true;keySuccess=false
nativePopup:_ListenInput();assert(calls==1,'no captured input must not be invented')
keySuccess=true;nativePopup.m_onKeyCodeInput=function()calls=calls+1;return true end
nativePopup:_ListenInput();assert(calls==2 and nativePopup.closed,'native callback still decides close/save')
nativePopup.closed=nil;nativePopup.m_onKeyCodeInput=function()error('fixture callback failure')end
nativePopup:_ListenInput();assert(nativePopup.closed,'callback failure still closes safely')
-- Disabling/removing the library leaves the original blacklist untouched.
nativePopup.closed=nil;lastToast=nil
originalListen(nativePopup);assert(lastToast=='禁止键' and not nativePopup.closed)
keyBlacklist=false
