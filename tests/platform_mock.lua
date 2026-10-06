ZMLKeybinds=nil
CS.UnityEngine={Application={isFocused=true},EventSystems={EventSystem={current={currentSelectedGameObject={
    GetComponent=function()if typing then return {}end end}}}},UI={InputField={}}}
CS.TMPro={TMP_InputField={}}
CS.UnityEngine.Input={GetKey=function(k)return heldKeys and heldKeys[k] or false end}
CS.UnityEngine.KeyCode=setmetatable({},{__index=function(_,k)return k end})
CS.Beyond.Input.KeyboardInput=function()
    return setmetatable({},{__index=function(t,k)
        if k=='modifyString' then return (t.useCtrl and 'C' or '')..(t.useAlt and 'A' or '')..(t.useShift and 'S' or '') end
    end})
end
CS.Beyond.Input.InputManager.GetKeyIconPath=function(input,modify)
    assert(type(input.key)=='table' and input.key.name)
    return modify and ('native/'..input.modifyString) or ('native/'..input.key.name)
end
typeof=function(t)return t end
CS.Beyond.Input.InputTimingType={OnClick='OnClick',OnPress='OnPress',OnRelease='OnRelease',OnLongPress='OnLongPress'}
fileDisk=nil;fileTemp={};fileMoves=0;fileReplaces=0;guid=0
CS.System={IO={File={
    Exists=function(p)if p=='C:/fixture/bindings.ini'then return fileDisk~=nil else return fileTemp[p]~=nil end end,
    ReadAllText=function()return fileDisk end,
    WriteAllText=function(p,s,encoding)if failFileWrite then error('denied')end fileTemp[p]=s end,
    Move=function(p,dest)assert(fileDisk==nil);fileMoves=fileMoves+1;fileDisk=fileTemp[p];fileTemp[p]=nil end,
    Replace=function(p,dest,backup)assert(fileDisk~=nil and backup==nil);fileReplaces=fileReplaces+1;fileDisk=fileTemp[p];fileTemp[p]=nil end,
    Delete=function(p)fileTemp[p]=nil end},
    FileInfo=function(p)return {Length=fileDisk and #fileDisk or 0}end,
    Directory={CreateDirectory=function()end},Path={GetDirectoryName=function()return 'C:/fixture' end}},
    Text={Encoding={UTF8={}},UTF8Encoding=function()return {}end},
    Guid={NewGuid=function()guid=guid+1;return {ToString=function()return tostring(guid)end}end}}
loadstring=load
LuaManagerInst={LoadLua=function()return "return {mod=function(id)if id=='demo'then return {name='Demo'}end end,report=function()end}" end}
UIManager.IsOpen=function(self,id)return openSettings==true end
nativeCalls={};nativeId=0
InputManagerInst.CreateBinding=function(self,key,mods,timing,fn,group)
    assert(group==12)
    assert(type(key)=='table' and key.name,'actual CreateBinding requires KeyboardKeyCode enum, not serialized icon name')
    nativeCalls={key=key.name,mods=mods,timing=timing,callback=fn,group=group};nativeId=nativeId+1;return nativeId
end
InputManagerInst.ToggleBinding=function(self,id,on)nativeCalls.enabled=on end
InputManagerInst.DeleteBinding=function()end
UIUtils.bindInputEvent=function(key,callback,mods,timing,group)
    return InputManagerInst:CreateBinding(key,mods or '',timing or 'OnClick',callback,group)
end
