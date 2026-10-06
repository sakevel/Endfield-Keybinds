"""Executable Lua API/storage/input transaction model, not Unity visual QA."""
import argparse, pathlib, sys
p=argparse.ArgumentParser();p.add_argument('--lupa-dir',default='');a=p.parse_args()
if a.lupa_dir:sys.path.insert(0,a.lupa_dir)
from lupa.lua54 import LuaRuntime
r=pathlib.Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
compile_=lua.eval('function(s,n)local f,e=load(s,n);assert(f,e);return f end')
for name in ['keybinds.lua','settings.lua','platform.lua']:
    source=(r/'mod'/name).read_text(encoding='utf8').replace('__ZML_STATE_FILE__','"C:/fixture/bindings.ini"')
    compile_(source,'@'+name)
lua.globals().factory=lua.execute((r/'mod/keybinds.lua').read_text(encoding='utf8'))
lua.execute('''
    live={};nextId=0;writes=0;events=0;allow=true;failedWrite=false;failedBind=false;deleted=0
    disk='ZML_KEYBINDS=1\\nremoved:feature=F7,None\\n'
    P={validKey=function(k)return k=='None' or k=='F7' or k=='F8' or k=='F9' or k=='F10' or k=='F11' or k=='F12' end,
       owner=function(id)if id=='demo' or id=='other' or id=='keybinds' then return id end end,
       read=function()return disk end,write=function(s)if failedWrite then return false,'write failed' end disk=s;writes=writes+1;return true end,
       allowed=function()return allow end,report=function(e)events=events+1 end,
       bind=function(group,key,fn,opts)
           if failedBind then error('binding failure') end
           nextId=nextId+1;live[nextId]={group=group,key=key,fn=fn,enabled=false,options=opts};return nextId
       end,
       unbind=function(id)assert(live[id]);live[id]=nil;deleted=deleted+1 end,
       enable=function(id,on)assert(live[id]);live[id].enabled=on end}
    function count()local n=0 for _ in pairs(live)do n=n+1 end return n end
    K=factory(P)
    assert(K.api==1 and K.find('demo','test')==nil)
    assert(not K.register('../bad',{id='test',name='Bad'}))
    assert(not K.register('absent',{id='test',name='Bad'}))
    assert(not K.register('demo',{id='test',name='<b>Bad'}))
    assert(not K.register('demo',{id='test',name='Test',primary='INVALID'}))
    action=assert(K.register('demo',{id='test',name='测试按键',primary='F8',secondary='None'}))
    assert(not K.register('demo',{id='test',name='Duplicate'}))
    other=assert(K.register('other',{id='other',name='其他按键',primary='F9'}))
    local snapshot=K.list();snapshot[1].keys[1]='F12';assert(action.get()[1]=='F8')
    assert(not action.bind(-1,function()end) and not action.bind(1,nil))
    assert(not action.bind(1,function()end,{timing='spam'}))
    hits=0;cleanup=assert(action.bind(42,function()hits=hits+1 end,{timing='OnPress'}))
    assert(count()==1 and live[1].group==42 and live[1].options.timing=='OnPress' and live[1].enabled)
    allow=false;live[1].fn();assert(hits==0);allow=true;live[1].fn();assert(hits==1)
    changes=0;unsub=assert(action.subscribe(function(v)changes=changes+1;assert(v[1]=='F10' or v[1]=='F12' or v[1]=='None' or v[1]=='F8')end))
    assert(not K._stage(action.id,1,'F9') and not K._stage(action.id,2,'F8'))
    assert(not K._stage(action.id,3,'F10') and not K._stage('missing',1,'F10'))
    assert(K._stage(action.id,1,'F10'))
    assert(K._dirty() and action.get()[1]=='F8' and K._draft(action.id)[1]=='F10')
    assert(live[1].key=='F8') -- draft does not affect gameplay
    failedBind=true;assert(not K._save());failedBind=false
    assert(count()==1 and live[1] and writes==0 and changes==0 and K._dirty())
    failedWrite=true;assert(not K._save());failedWrite=false
    assert(count()==1 and live[1] and writes==0 and changes==0 and K._dirty())
    assert(K._save());assert(writes==1 and changes==1 and count()==1 and not live[1])
    assert(disk:find('removed:feature=F7,None',1,true)) -- removed mod data preserved
    assert(action.get()[1]=='F10' and not K._dirty())
    for _,b in pairs(live)do assert(b.key=='F10' and b.enabled)end
    assert(K._stage(action.id,1,'F12'));K.discard();assert(action.get()[1]=='F10' and not K._dirty())
    assert(K._stage(action.id,2,'F11'));assert(K._save());assert(count()==2)
    cleanup();cleanup();assert(count()==0) -- idempotent lease cleanup, caller group untouched
    K._reset();assert(K._save() and action.get()[1]=='F8' and action.get()[2]=='None')
    assert(changes==3);unsub()
    assert(K._stage(action.id,1,'None'));assert(K._save() and changes==3)
    fresh=factory(P);local reloaded=assert(fresh.register('demo',{id='test',name='测试按键',primary='F8'}))
    assert(reloaded.get()[1]=='None') -- explicit unbound survives defaults/restart
    assert(K.unregister('demo','test') and not K.unregister('demo','test'))
    assert(not action.get() and not action.bind(1,function()end))
    assert(K.register('demo',{id='test',name='Replacement'}));assert(not action.get())
    -- Bound callback failures are isolated. Other binding still runs.
    local c1=assert(other.bind(4,function()error('consumer failed')end))
    local c2=assert(other.bind(4,function()hits=hits+1 end))
    local before=hits;for _,b in pairs(live)do b.fn() end;assert(hits==before+1 and events>=2)
    c1();c2();assert(count()==0)
    disk='ZML_KEYBINDS=99\\n';corrupt=factory(P)
    local ca=assert(corrupt.register('demo',{id='test',name='Test',primary='F8'}))
    assert(corrupt._stage(ca.id,1,'F10'));local beforeDisk=disk
    assert(not corrupt._save() and disk==beforeDisk)
    disk='ZML_KEYBINDS=1\\ndemo:test=F8,None\\ndemo:test=F9,None\\n';assert(factory(P))
    disk='ZML_KEYBINDS=1\\n../evil:test=F8,None\\n';assert(factory(P))
    disk=nil;bounded=factory(P)
    for i=1,32 do assert(bounded.register('demo',{id='a'..i,name='Action'}))end
    assert(not bounded.register('demo',{id='a33',name='Action'}))
''')
print('PASS Lua registry, namespace/defaults/secondary, native leases, staged save/discard/reset, callback isolation, write/bind rollback, private storage bounds/reload')
