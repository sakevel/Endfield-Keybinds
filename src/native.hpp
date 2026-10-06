#pragma once
#include "keybinds_native.h"
#include "patch.hpp"
#include <Windows.h>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <map>
#include <sstream>
#include <set>
namespace kb {
struct Key {int vk=0;bool ctrl=false,shift=false,alt=false;};
inline int virtualKey(std::string name) {
    if(name=="None")return 0;
    if(name.size()==1 && name[0]>='A' && name[0]<='Z')return name[0];
    if(name.size()>1 && name[0]=='F')try {size_t n;int x=std::stoi(name.substr(1),&n);if(n==name.size()-1 && std::to_string(x)==name.substr(1) && x>=1 && x<=15)return VK_F1+x-1;}catch(...){}
    for(auto prefix:{"Alpha","Keypad"}) if(name.size()==strlen(prefix)+1 && name.starts_with(prefix) && isdigit(static_cast<unsigned char>(name.back())))
        return (std::string(prefix)=="Alpha"?'0':VK_NUMPAD0)+name.back()-'0';
    static const std::map<std::string,int> keys{
        {"Space",VK_SPACE},{"Return",VK_RETURN},{"KeypadEnter",VK_RETURN},{"Backspace",VK_BACK},{"Tab",VK_TAB},
        {"LeftControl",VK_LCONTROL},{"RightControl",VK_RCONTROL},{"LeftShift",VK_LSHIFT},{"RightShift",VK_RSHIFT},
        {"LeftAlt",VK_LMENU},{"RightAlt",VK_RMENU},{"EscapeOnly",VK_ESCAPE},{"UpArrow",VK_UP},{"DownArrow",VK_DOWN},
        {"LeftArrow",VK_LEFT},{"RightArrow",VK_RIGHT},{"Insert",VK_INSERT},{"Delete",VK_DELETE},{"Home",VK_HOME},{"End",VK_END},
        {"PageUp",VK_PRIOR},{"PageDown",VK_NEXT},{"Pause",VK_PAUSE},{"Clear",VK_CLEAR},{"Numlock",VK_NUMLOCK},
        {"CapsLock",VK_CAPITAL},{"ScrollLock",VK_SCROLL},{"Print",VK_SNAPSHOT},{"Menu",VK_APPS},
        {"LeftWindows",VK_LWIN},{"RightWindows",VK_RWIN},{"Mouse0",VK_LBUTTON},{"Mouse1",VK_RBUTTON},
        {"Mouse2",VK_MBUTTON},{"Mouse3",VK_XBUTTON1},{"Mouse4",VK_XBUTTON2},{"Minus",VK_OEM_MINUS},
        {"Equals",VK_OEM_PLUS},{"LeftBracket",VK_OEM_4},{"RightBracket",VK_OEM_6},{"Backslash",VK_OEM_5},
        {"Semicolon",VK_OEM_1},{"Quote",VK_OEM_7},{"BackQuote",VK_OEM_3},{"Comma",VK_OEM_COMMA},
        {"Period",VK_OEM_PERIOD},{"Slash",VK_OEM_2},{"KeypadDivide",VK_DIVIDE},{"KeypadMultiply",VK_MULTIPLY},
        {"KeypadMinus",VK_SUBTRACT},{"KeypadPlus",VK_ADD},{"KeypadPeriod",VK_DECIMAL}};
    auto it=keys.find(name);return it==keys.end()?-1:it->second;
}
inline bool parseKey(const std::string& s,Key& key) {
    if(s.empty() || s.size()>48)return false;
    Key k;size_t at=0;unsigned order=0;
    for(;;){auto end=s.find('+',at);if(end==s.npos)break;auto t=s.substr(at,end-at);
        unsigned n=t=="Ctrl"?1:t=="Alt"?2:t=="Shift"?3:0;
        if(!n || n<=order)return false;order=n;
        if(n==1)k.ctrl=true;if(n==2)k.alt=true;if(n==3)k.shift=true;at=end+1;
    }
    k.vk=virtualKey(s.substr(at));if(k.vk<0 || (!k.vk && at))return false;key=k;return true;
}
inline bool component(const std::string& s){return !s.empty() && s.size()<=64 && s!=".." && ((s.front()>='a' && s.front()<='z') || (s.front()>='0' && s.front()<='9')) && s.find_first_not_of("abcdefghijklmnopqrstuvwxyz0123456789.-_")==s.npos;}
class Native {
    struct Action {std::string owner,id,name,primary,secondary;bool previous=false;};
    std::mutex mutex,fileMutex; std::map<uint64_t,Action> actions;uint64_t serial=0;
    std::map<std::string,std::pair<std::string,std::string>> saved;
    std::filesystem::path file;ULONGLONG refresh=0;bool good=true,ready=false,editing=false,blocked=false;
    void read() {
        auto now=GetTickCount64();if(now<refresh)return;refresh=now+100;
        good=true;saved.clear();
        auto handle=CreateFileW(file.c_str(),GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,
            nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
        if(handle==INVALID_HANDLE_VALUE){auto error=GetLastError();good=error==ERROR_FILE_NOT_FOUND || error==ERROR_PATH_NOT_FOUND;return;}
        struct Close{HANDLE h;~Close(){CloseHandle(h);}}close{handle};
        LARGE_INTEGER size{};
        if(!GetFileSizeEx(handle,&size) || size.QuadPart<0 || size.QuadPart>32768){good=false;return;}
        std::string text(static_cast<size_t>(size.QuadPart),'\0');DWORD got=0;
        if(!ReadFile(handle,text.data(),static_cast<DWORD>(text.size()),&got,nullptr) || got!=text.size() || text.find('\0')!=text.npos){good=false;return;}
        std::istringstream lines(text);std::string line;bool first=true;size_t count=0;
        while(std::getline(lines,line)) {
            if(!line.empty() && line.back()=='\r')line.pop_back();
            if(first){first=false;if(line!="ZML_KEYBINDS=1"){good=false;return;}continue;}
            if(line.empty())continue;
            auto colon=line.find(':'),eq=line.find('='),comma=line.find(',',eq==line.npos?0:eq+1);
            if(colon==line.npos || eq==line.npos || colon>=eq || comma==line.npos || ++count>256){good=false;return;}
            auto owner=line.substr(0,colon),id=line.substr(colon+1,eq-colon-1),k1=line.substr(eq+1,comma-eq-1),k2=line.substr(comma+1);
            // Preserve records for keys outside current backend
            if(!component(owner) || !component(id) || k1.empty() || k2.empty() || k1.size()>48 || k2.size()>48 ||
                k1.find_first_not_of("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+")!=k1.npos ||
                k2.find_first_not_of("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+")!=k2.npos ||
                !saved.emplace(line.substr(0,eq),std::make_pair(k1,k2)).second){good=false;return;}
        }
        if(first)good=false;
    }
    static bool held(const std::string& code) {
        Key k;if(!parseKey(code,k) || !k.vk)return false;
        auto test=[](int key){return (GetAsyncKeyState(key)&0x8000)!=0;};
        return test(k.vk) && (!k.ctrl||test(VK_CONTROL)) && (!k.shift||test(VK_SHIFT)) && (!k.alt||test(VK_MENU));
    }
public:
    void init(std::filesystem::path p,bool bridge){std::scoped_lock lock(mutex,fileMutex);file=std::move(p);ready=bridge;refresh=0;}
    uint64_t add(const ZmlKeyActionV1* d) {
        if(!d || d->size!=sizeof(*d) || !d->owner || !d->id || !d->name || !d->primary || !d->secondary)return 0;
        Action a{d->owner,d->id,d->name,d->primary,d->secondary};Key key;
        if(!component(a.owner)||!component(a.id)||a.name.empty()||a.name.size()>192||a.name.find_first_of("\r\n<>\t")!=a.name.npos ||
            !MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,a.name.data(),static_cast<int>(a.name.size()),nullptr,0) ||
            !parseKey(a.primary,key)||!parseKey(a.secondary,key))return 0;
        std::lock_guard lock(mutex);if(!ready || actions.size()>=128)return 0;unsigned own=0;
        for(auto& [h,other]:actions){if(other.owner==a.owner){if(other.id==a.id)return 0;++own;}}
        if(own>=32)return 0;actions.emplace(++serial,std::move(a));return serial;
    }
    void remove(uint64_t h){std::lock_guard lock(mutex);actions.erase(h);}
    int query(uint64_t h,bool edge) {
        // Avoid holding locks during file I/O
        std::map<std::string,std::pair<std::string,std::string>> current;bool valid;
        {std::lock_guard lock(fileMutex);read();current=saved;valid=good;}
        std::lock_guard lock(mutex);auto it=actions.find(h);if(it==actions.end())return 0;
        DWORD pid=0;GetWindowThreadProcessId(GetForegroundWindow(),&pid);
        auto& a=it->second;bool down=false;
        if(valid) {
            auto found=current.find(a.owner+":"+a.id);
            auto keys=found==current.end()?std::make_pair(a.primary,a.secondary):found->second;
            Key one,two;
            if(parseKey(keys.first,one)&&parseKey(keys.second,two))down=held(keys.first)||held(keys.second);
        }
        if(!edge)return valid && !editing && !blocked && pid==GetCurrentProcessId() && down?1:0;
        if(!valid || editing || blocked || pid!=GetCurrentProcessId()){a.previous=!valid || down;return 0;}
        bool pressed=down&&!a.previous;a.previous=down;return pressed?1:0;
    }
    std::string module(const std::string& path) {
        std::lock_guard lock(mutex);
        if(path=="Editing/1" || path=="Editing/0") {editing=path=="Editing/1";return "return true";}
        if(path=="Gate/1" || path=="Gate/0") {blocked=path=="Gate/1";return "return true";}
        if(path.starts_with("Valid/")){Key k;auto s=path.substr(6);std::replace(s.begin(),s.end(),'_','+');return parseKey(s,k)?"return true":"return false";}
        if(path!="Actions")throw std::runtime_error("Unknown keybind module");
        std::string out="return {";
        for(auto& [h,a]:actions)out+="{owner="+literal(a.owner)+",id="+literal(a.id)+",name="+literal(a.name)+",primary="+literal(a.primary)+",secondary="+literal(a.secondary)+",native=true,migrate=true},";
        return out+"}";
    }
};
}
