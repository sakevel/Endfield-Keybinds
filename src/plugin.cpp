#include "zml_plugin.h"
#include "patch.hpp"
#include "zml_lua_service.h"
#include "native.hpp"
#include <filesystem>
#include <fstream>
#include <iterator>
#include <array>
namespace {
const ZmlHost* host = nullptr;
kb::Native native;
bool bridgeReady=false;
int provide(void*,const char* path,ZmlSink sink,void* writer) {
    try {if(!path||!sink)return 0;auto source=native.module(path);sink(writer,source.data(),source.size());return 1;}catch(...){return 0;}
}
struct Transform { int kind; std::string extension; };
std::array<Transform,4> transforms;
std::string read(const std::filesystem::path& p) {
    auto size=std::filesystem::file_size(p);
    if (!size || size>128*1024) throw std::runtime_error("Invalid library Lua asset size");
    std::ifstream file(p,std::ios::binary);
    std::string s{std::istreambuf_iterator<char>(file),{}};
    if (s.size()!=size || s.find('\0')!=s.npos) throw std::runtime_error("Invalid library Lua asset");
    return s;
}
int transform(void* data,const char* source,size_t size,ZmlSink sink,void* writer) {
    try {
        auto& t=*static_cast<Transform*>(data);std::string result;
        if (!kb::patch({source,size},t.kind,t.extension,result)) {
            if(host && host->log) host->log(host->owner,"Keybind patch rejected");
            return 0;
        }
        sink(writer,result.data(),result.size());return 1;
    } catch (...) { return 0; }
}
int start(const ZmlHost* h) {
    if (!h || h->abi!=1 || h->size!=sizeof(ZmlHost) || !h->mod_directory || !h->state_directory ||
        !h->transform_lua || !h->log || !*h->state_directory) return 0;
    try {
        host = h;
        auto path=std::filesystem::path(std::u8string(reinterpret_cast<const char8_t*>(h->mod_directory)));
        auto core=read(path/"keybinds.lua"), platform=read(path/"platform.lua"), ui=read(path/"settings.lua");
        size_t at;
        if (!kb::unique(platform,"__ZML_STATE_FILE__",at)) return 0;
        auto state=std::filesystem::path(std::u8string(reinterpret_cast<const char8_t*>(h->state_directory)))/"bindings.ini";
        auto u=state.u8string();platform.replace(at,18,kb::literal({reinterpret_cast<const char*>(u.data()),u.size()}));
        auto boot="if not rawget(_G,'ZMLKeybinds') then\ndo\nlocal ZMLKBOK = pcall(function()\nlocal ZMLKBFactory = (function()\n"+core+"\nend)();\n(function(UIUtils)\n"+platform+"\nend)(UIUtils)\nend)\nif not ZMLKBOK then logger.error('Keybinds library startup failed') end\nend\nend\n";
        transforms[0]={0,boot};
        transforms[1]={1,ui};
        transforms[2]={2,"-- popup"};
        // Lazy bootstrap for GameSettingCtrl
        // in a source shared with model-heavy consumers under the 768KiB cap.
        transforms[3]={3,"do\nlocal ok=pcall(function()\nrequire_ex('Common/Utils/UIUtils')\nif not rawget(_G,'ZMLKeybinds') then require_ex('UI/Panels/GameSetting/GameSettingCtrl') end\nif _G.ZMLKeybinds and _G.ZMLKeybinds._attachGate then _G.ZMLKeybinds._attachGate() end\nend)\nif not ok then logger.error('Keybinds late input bootstrap failed') end\nend\n"};
        const char* paths[]{"Common/Utils/UIUtils","UI/Panels/GameSetting/GameSettingCtrl","UI/Panels/GameSettingKeycodePopup/GameSettingKeycodePopupCtrl","UI/Panels/BattleAction/BattleActionCtrl"};
        for (int i=0;i<4;++i) if (!h->transform_lua(h->owner,paths[i],transform,&transforms[i])) return 0;
        auto runtime=GetModuleHandleW(L"ZMLRuntime.dll");
        auto get=runtime?reinterpret_cast<ZmlLuaServicesEntry>(GetProcAddress(runtime,"ZML_GetLuaServicesV1")):nullptr;
        auto services=get?get():nullptr;
        bridgeReady=services && services->abi==1 && services->size==sizeof(ZmlLuaServicesV1) && services->register_source &&
            services->register_source(h->owner,provide,nullptr);
        native.init(state,bridgeReady);
        return 1;
    } catch (...) { return 0; }
}
const ZmlPlugin plugin{sizeof(ZmlPlugin),1,"keybinds",start};
}
extern "C" __declspec(dllexport) const ZmlPlugin* ZML_PluginV1(){return &plugin;}
namespace {
uint64_t add(const ZmlKeyActionV1* d){try{return native.add(d);}catch(...){return 0;}}
void remove(uint64_t h){native.remove(h);}
int down(uint64_t h){try{return native.query(h,false);}catch(...){return 0;}}
int pressed(uint64_t h){try{return native.query(h,true);}catch(...){return 0;}}
const ZmlKeybindsV1 keyApi{sizeof(ZmlKeybindsV1),1,add,remove,down,pressed};
}
extern "C" __declspec(dllexport) const ZmlKeybindsV1* ZML_KeybindsV1(){return bridgeReady?&keyApi:nullptr;}
