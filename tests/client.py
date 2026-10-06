"""Fresh native function-body + DLL patch integration, NOT real Unity/UI proof."""
import argparse,pathlib,re,sys
p=argparse.ArgumentParser();p.add_argument('--lupa-dir',default='');p.add_argument('--client',type=pathlib.Path,required=True);p.add_argument('--patched',type=pathlib.Path,required=True);a=p.parse_args()
if a.lupa_dir:sys.path.insert(0,a.lupa_dir)
from lupa.lua54 import LuaRuntime
r=pathlib.Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
compile_=lua.eval('function(s,n)local f,e=load(s,n);assert(f,e);return f end')
sources=[(a.patched/f'{i}.lua').read_text(encoding='utf8') for i in range(4)]
for i,s in enumerate(sources):compile_(s,'@native.patched.'+str(i))
item=(a.client/'UI/Widgets/GameSettingItemCell.lua').read_text(encoding='utf8')
assert 'InitGameSettingItemCell = HL.Method(HL.Any, HL.Table, HL.Opt(HL.Table))' in item
popup_source=sources[2]
assert 'm_settingItemData = HL.Field(HL.Userdata)' in popup_source
lua.globals().factory=lua.execute((r/'mod/keybinds.lua').read_text(encoding='utf8'))
lua.execute((r/'tests/client_mock.lua').read_text(encoding='utf8'))

def install(source,cls,methods):
    table=lua.globals()[cls]
    for name in methods:
        head=cls+'.'+name+' = '
        assert source.count(head)==1,head
        start=source.index(head)
        end=source.find('\n'+cls+'.',start+len(head))
        if end<0:end=source.index('\nHL.Commit(',start)
        region=source[start:end]
        pos=region.index('<<')+2
        pos=region.index('function',pos)
        # Some methods are followed by local helper functions before the next
        # Class.member. Match the actual column-zero closing end, not the last.
        closing=re.search(r'^end[ \t]*$',region[pos:],re.M)
        assert closing,name
        body=region[pos:pos+closing.start()+3]
        table[name]=lua.execute('return '+body)

install(sources[1],'GameSettingCtrl',['_BuildSettingTabData','_InitKeyActionScopeMap','_RefreshSettingItemCell','_InitSettingItemControlKey',
    '_InitSettingItemControlKeyAction','_GetKeyActionState','_SetKeyActionState','_GetKeyActionStateLevel','_AddKeyActionState','_RemoveKeyActionState',
    '_ClearAllKeyActionStates','_KeyClearPendingActions','_KeySaveActions','_KeyResetActions'])
install(item,'GameSettingItemCell',['InitGameSettingItemCell','Refresh','_GetItemState','_InitItemControl'])
install((a.client/'UI/Panels/GameSettingKeycodePopup/GameSettingKeycodePopupCtrl.lua').read_text(encoding='utf8'),
        'GameSettingKeycodePopupCtrl',['_ListenInput'])
lua.globals().originalListen=lua.globals().GameSettingKeycodePopupCtrl['_ListenInput']
install(popup_source,'GameSettingKeycodePopupCtrl',['OnCreate','OnShow','OnClose','_UpdateView','_ListenInput'])
lua.execute((r/'mod/settings.lua').read_text(encoding='utf8'))

# Verify userdata seed parameter
class Seed:
    settingId='native.jump';settingText='跳跃';settingGroupTitle='原生';settingSortOrder=1;settingItemType=7
    validateFunction='';settingRedDot=''
seed=Seed();seed.keyActionScopes=lua.eval('{Count=1,[0]="battle"}')
seed.keyActionIds1=lua.eval('{Count=1,[0]="jump"}');seed.keyActionIds2=lua.eval('{Count=0}')
seed.keyIcon1='';seed.keyIcon2='';seed.keyIsMutable1=True;seed.keyIsMutable2=True
seed.keyIsLongPress1=False;seed.keyIsLongPress2=False
lua.globals().nativeSeed=seed
lua.execute((r/'tests/client_scenarios.lua').read_text(encoding='utf8'))

# Execute platform facade independently: covers actual native CreateBinding
# signature, atomic .NET File.Replace/Move contract, foreground/typing/settings.
lua.execute((r/'tests/platform_mock.lua').read_text(encoding='utf8'))
platform=(r/'mod/platform.lua').read_text(encoding='utf8').replace('__ZML_STATE_FILE__','"C:/fixture/bindings.ini"')
lua.globals().ZMLKBFactory=lua.globals().factory
lua.execute(platform)
lua.execute('''
    local h=assert(ZMLKeybinds.register('demo',{id='native',name='Native',primary='F8'}))
    local hits=0
    local stop=assert(h.bind(12,function()hits=hits+1 end,{timing='OnPress'}))
    assert(nativeCalls.key=='F8' and nativeCalls.group==12 and nativeCalls.timing=='OnPress')
    nativeCalls.callback();assert(hits==1)
    CS.UnityEngine.Application.isFocused=false;nativeCalls.callback();assert(hits==1)
    CS.UnityEngine.Application.isFocused=true;GameInstance.isInGameplay=false;nativeCalls.callback();assert(hits==1)
    GameInstance.isInGameplay=true;openSettings=true;nativeCalls.callback();assert(hits==1);openSettings=false
    typing=true;nativeCalls.callback();assert(hits==1);typing=false
    assert(ZMLKeybinds._stage(h.id,1,'F10'));assert(ZMLKeybinds._save())
    assert(fileMoves==1 and fileReplaces==0 and fileDisk:find('demo:native=F10,None',1,true))
    assert(ZMLKeybinds._stage(h.id,1,'F11'));assert(ZMLKeybinds._save())
    assert(fileMoves==1 and fileReplaces==1 and fileDisk:find('demo:native=F11,None',1,true))
    assert(ZMLKeybinds._stage(h.id,1,'F12'));failFileWrite=true;assert(not ZMLKeybinds._save())
    assert(h.get()[1]=='F11' and ZMLKeybinds._dirty());failFileWrite=false
    stop()
''')
boot=sources[1].split('-- ZML_KEYBINDS_V1\n',1)[1].split('-- Adapter for the actual GameSetting',1)[0]
lua.globals().late_boot=compile_(boot,'@actual.dll.lazy-bootstrap')
lua.globals().get_sdk=lua.execute((r/'sdk/keybinds.lua').read_text(encoding='utf8'))
lua.execute('''
    ZMLKeybinds=nil; required={}
    require_ex=function(path)
        required[#required+1]=path
        if path=='UI/Panels/GameSetting/GameSettingCtrl' then late_boot() end
        return {} -- UIUtils was already cached before injection, does not reexecute
    end
    local api=assert(get_sdk());assert(api.api==1 and api.find('keybinds','test'))
    assert(#required==2 and required[2]=='UI/Panels/GameSetting/GameSettingCtrl')
    late_boot();assert(ZMLKeybinds==api) -- never replace registry/leases on second bootstrap
    local again=assert(get_sdk());assert(again==api)
''')
lua.globals().ZMLKeybinds=None
lua.execute(platform) # reset facade to the synthetic filesystem's actual root
lua.execute((r/'mod/settings.lua').read_text(encoding='utf8'))
lua.execute((r/'tests/migration.lua').read_text(encoding='utf8'))
print('PASS fresh native row/layout/cache, popup userdata/key capture/blacklist, save/reset/discard/conflicts, original functions, platform native binding/atomic storage/input suppression; compiled all three actual patched modules')
