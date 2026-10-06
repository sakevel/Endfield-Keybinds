-- Keybinding registry and binding manager.
return function(P)
    local A = {api=1, version="0.2.1"}
    local actions, store, pending, listeners = {}, {}, {}, {}
    local storageError, serial, listenerId = nil, 0, 0
    local function component(s)
        return type(s)=="string" and #s>0 and #s<=64 and s:match("^[a-z0-9][a-z0-9_.%-]*$") and s~=".."
    end
    local function title(s)
        return type(s)=="string" and #s>0 and #s<=192 and not s:find("[%c<>]")
    end
    local function key(s) return type(s)=="string" and #s<=48 and P.validKey(s) end
    local function pair(v) return {v[1],v[2]} end
    local function copy(t) local c={} for k,v in pairs(t) do c[k]=pair(v) end return c end
    local function sorted(t) local result={} for k in pairs(t) do result[#result+1]=k end table.sort(result) return result end
    local function report(event) if P.report then pcall(P.report,event) end end
    local function read()
        local text,err=P.read()
        if not text then if err then storageError=err;report("storage_read_failed") end return end
        if #text>32768 or text:find("\0") then storageError="按键配置文件过大或损坏";return end
        text=text:gsub("\r\n","\n")
        local first=true;local count=0
        for line in (text.."\n"):gmatch("([^\n]*)\n") do
            if first then
                if line~="ZML_KEYBINDS=1" then storageError="按键配置版本不支持";return end
                first=false
            elseif line~="" then
                local id,k1,k2=line:match("^([a-z0-9_.%-]+:[a-z0-9_.%-]+)=([A-Za-z0-9+]+),([A-Za-z0-9+]+)$")
                local owner,action=(id or ""):match("^([^:]+):([^:]+)$")
                count=count+1
                if not component(owner) or not component(action) or not key(k1) or not key(k2) or store[id] or count>256 then
                    store={};storageError="按键配置文件格式无效";report("storage_invalid");return
                end
                store[id]={k1,k2}
            end
        end
    end
    read()
    local function values(id, draft)
        local action=actions[id]; if not action then return nil end
        return pair((draft and pending[id]) or store[id] or action.defaults)
    end
    local function dispose(ids)
        for _,id in ipairs(ids or {}) do pcall(P.unbind,id) end
    end
    local function prepare(lease,v)
        local ids,seen={},{}
        for _,code in ipairs(v) do
            if code~="None" and not seen[code] then
                seen[code]=true
                local ok,id=pcall(P.bind,lease.group,code,function()
                    if lease.closed then return end
                    local safe,allowed=pcall(P.allowed,lease.options)
                    if not safe or not allowed then return end
                    local ran=pcall(lease.callback)
                    if not ran then report("callback_failed") end
                end,lease.options)
                if not ok or type(id)~="number" or id<0 then dispose(ids);return nil,"原生输入绑定失败" end
                ids[#ids+1]=id
            end
        end
        return ids
    end
    local function notify(id,v)
        for _,fn in pairs(listeners[id] or {}) do if not pcall(fn,pair(v)) then report("subscriber_failed") end end
    end
    function A.register(owner,def)
        if not component(owner) or type(def)~="table" or not component(def.id) or not title(def.name) then return nil,"动作声明无效" end
        local ownerName=P.owner(owner)
        if not ownerName then return nil,"依赖方模组未加载" end
        local id=owner..":"..def.id
        if actions[id] then return nil,"动作 ID 已注册" end
        local n,own=0,0
        for _,a in pairs(actions) do n=n+1;if a.owner==owner then own=own+1 end end
        if n>=128 or own>=32 then return nil,"动作注册数量已达上限" end
        local defaults={def.primary or "None",def.secondary or "None"}
        if not key(defaults[1]) or not key(defaults[2]) then return nil,"默认按键不受支持" end
        local a={owner=owner,ownerName=ownerName,name=def.name,id=id,defaults=defaults,leases={},native=def.native==true}
        actions[id]=a
        local H={id=id}
        function H.get() if actions[id]~=a then return nil end return values(id,false) end
        -- Continuous input polling
        function H.down(options)
            if actions[id]~=a or not P.down then return false end
            local opts={gameplay=not options or options.gameplay~=false}
            local ok,allowed=pcall(P.allowed,opts);if not ok or not allowed then return false end
            for _,code in ipairs(values(id,false)) do
                local ran,held=pcall(P.down,code);if ran and held then return true end
            end
            return false
        end
        function H.pressed(options)
            local ok,allowed=pcall(P.allowed,{gameplay=not options or options.gameplay~=false})
            if not ok or not allowed then
                local held=false
                if P.down then for _,code in ipairs(values(id,false)) do local ran,v=pcall(P.down,code);held=held or (ran and v==true) end end
                a.previous=held;return false
            end
            local held=H.down(options);local edge=held and not a.previous;a.previous=held;return edge==true
        end
        function H.release() a.previous=true end -- Rising edge debounce
        function H.bind(group,callback,options)
            if actions[id]~=a then return nil,"动作已注销" end
            if type(group)~="number" or group<0 or group%1~=0 or type(callback)~="function" then return nil,"需要原生输入组和回调" end
            options=options or {}
            if type(options)~="table" then return nil,"输入选项无效" end
            local opts={gameplay=options.gameplay~=false, timing=options.timing or "OnClick"}
            if opts.timing~="OnClick" and opts.timing~="OnPress" and opts.timing~="OnRelease" and opts.timing~="OnLongPress" then return nil,"输入时机不支持" end
            local lease={group=group,callback=callback,options=opts,closed=false}
            local ids,err=prepare(lease,values(id,false));if not ids then return nil,err end
            lease.ids=ids
            for _,bid in ipairs(ids) do
                if not pcall(P.enable,bid,true) then dispose(ids);return nil,"原生输入启用失败" end
            end
            serial=serial+1;local leaseId=serial;a.leases[leaseId]=lease
            return function()
                if lease.closed then return end
                lease.closed=true;dispose(lease.ids);a.leases[leaseId]=nil
            end
        end
        function H.subscribe(fn)
            if type(fn)~="function" or actions[id]~=a then return nil,"订阅无效" end
            listenerId=listenerId+1;local lid=listenerId
            listeners[id]=listeners[id] or {};listeners[id][lid]=fn
            return function() if listeners[id] then listeners[id][lid]=nil end end
        end
        a.handle=H
        -- Migrate legacy key preferences
        if def.migrate and not store[id] then
            local otherDrafts=pending
            pending={}
            pending[id]=pair(defaults)
            local ok=A._save()
            pending=otherDrafts
            if not ok then report("migration_save_failed") end
        end
        return H
    end
    function A.find(owner,id) local a=actions[tostring(owner)..":"..tostring(id)];return a and a.handle end
    function A.unregister(owner,id)
        local full=tostring(owner)..":"..tostring(id);local a=actions[full]
        if not a then return false end
        for _,l in pairs(a.leases) do l.closed=true;dispose(l.ids) end
        actions[full],pending[full],listeners[full]=nil,nil,nil
        return true
    end
    function A.list()
        local result={}
        for _,id in ipairs(sorted(actions)) do
            local a=actions[id]
            result[#result+1]={id=id,owner=a.owner,ownerName=a.ownerName,name=a.name,keys=values(id,false),native=a.native}
        end
        return result
    end
    function A._draft(id) return values(id,true) end
    function A._dirty() return next(pending)~=nil end
    function A._stage(id,slot,code)
        if not actions[id] or (slot~=1 and slot~=2) or not key(code) then return false,"按键无效" end
        if actions[id].native and P.nativeValid and not P.nativeValid(code) then return false,"此按键不支持原生线程动作" end
        local v=values(id,true);v[slot]=code
        if code~="None" then
            for other in pairs(actions) do
                local ov=other==id and v or values(other,true)
                for i=1,2 do
                    if (other~=id or i~=slot) and ov[i]==code then return false,"与另一个模组按键重复" end
                end
            end
        end
        local current=values(id,false)
        pending[id]=(v[1]~=current[1] or v[2]~=current[2]) and v or nil
        return true
    end
    function A.discard() pending={} end
    function A._reset() for id,a in pairs(actions) do pending[id]=pair(a.defaults) end end
    function A._save()
        if not A._dirty() then return true end
        if storageError then return false,storageError end
        local candidate=copy(store)
        for id,v in pairs(pending) do candidate[id]=pair(v) end
        local keys=sorted(candidate)
        if #keys>256 then return false,"保存动作数量已达上限" end
        local lines={"ZML_KEYBINDS=1"}
        for _,id in ipairs(keys) do local v=candidate[id];lines[#lines+1]=id.."="..v[1]..","..v[2] end
        local text=table.concat(lines,"\n").."\n"
        if #text>32768 then return false,"按键配置过大" end
        -- Atomic update of active bindings
        local staged={}
        for _,id in ipairs(sorted(pending)) do
            for _,l in pairs(actions[id].leases) do
                local ids,err=prepare(l,pending[id])
                if not ids then for _,s in ipairs(staged) do dispose(s.ids) end return false,err end
                staged[#staged+1]={lease=l,ids=ids}
            end
        end
        local called,ok,err=pcall(P.write,text)
        if not called or not ok then
            for _,s in ipairs(staged) do dispose(s.ids) end
            report("storage_write_failed");return false,called and (err or "按键保存失败") or "按键保存失败"
        end
        local changed=pending;store=candidate;pending={}
        for _,s in ipairs(staged) do
            dispose(s.lease.ids);s.lease.ids=s.ids
            for _,id in ipairs(s.ids) do if not pcall(P.enable,id,true) then report("binding_enable_failed") end end
        end
        for id in pairs(changed) do notify(id,values(id,false)) end
        return true
    end
    return A
end
