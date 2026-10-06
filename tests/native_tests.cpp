#include "zml_plugin.h"
#include "keybinds_native.h"
#include <Windows.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
void check(bool b){if(!b)throw std::runtime_error("Native API fixture failed");}
template<class T>T symbol(HMODULE d,const char* n){auto p=reinterpret_cast<T>(GetProcAddress(d,n));check(p!=nullptr);return p;}
int transform(void*,const char*,ZmlLuaTransform,void*){return 1;}
void log(void*,const char*){}
void sink(void* d,const char* s,size_t n){*static_cast<std::string*>(d)=std::string(s,n);}
int main(int argc,char** argv){try{
    check(argc==3);auto bridge=LoadLibraryW(std::filesystem::absolute(argv[1]).c_str());check(bridge!=nullptr);
    auto dllPath=std::filesystem::absolute(argv[2]);auto dll=LoadLibraryW(dllPath.c_str());check(dll!=nullptr);
    auto get=symbol<ZmlKeybindsEntry>(dll,"ZML_KeybindsV1");check(!get());
    auto dir=dllPath.parent_path().u8string();std::string directory(reinterpret_cast<const char*>(dir.data()),dir.size());
    auto state=std::filesystem::temp_directory_path()/ ("zml-keybind-native-"+std::to_string(GetCurrentProcessId()));std::filesystem::create_directories(state);
    struct Cleanup{std::filesystem::path p;~Cleanup(){std::error_code e;std::filesystem::remove_all(p,e);}}cleanup{state};
    auto u=state.u8string();std::string path(reinterpret_cast<const char*>(u.data()),u.size());
    ZmlHost host{sizeof(ZmlHost),1,nullptr,directory.c_str(),path.c_str(),log,transform};
    check(symbol<ZmlPluginEntry>(dll,"ZML_PluginV1")()->start(&host)!=0);
    auto api=get();check(api && api->abi==1 && api->size==sizeof(*api));
    ZmlKeyActionV1 def{sizeof(ZmlKeyActionV1),"consumer","test","Test native action","Ctrl+Shift+F12","None"};
    auto h=api->register_action(&def);check(h && !api->register_action(&def));
    auto source=symbol<int(*)(const char*,ZmlSink,void*)>(bridge,"FixtureSource");std::string text;
    check(source("Actions",sink,&text) && text.find("Ctrl+Shift+F12")!=text.npos && text.find("consumer")!=text.npos);
    check(source("Valid/Ctrl_Shift_F12",sink,&text) && text=="return true");
    check(source("Valid/Shift_Ctrl_F12",sink,&text) && text=="return false");
    check(source("Valid/Mouse6",sink,&text) && text=="return false");
    check(source("Editing/1",sink,&text));check(api->down(h)==0 && api->pressed(h)==0);
    api->unregister_action(h);check(api->down(h)==0 && api->pressed(h)==0);
    check(source("Actions",sink,&text) && text=="return {}");
    def.owner="../bad";check(!api->register_action(&def));def.owner="consumer";def.primary="Shift+Ctrl+F12";check(!api->register_action(&def));
    std::cout<<"PASS actual library DLL/native API/owned virtual source/deep-copy/missing capability/unregister\n";return 0;
}catch(std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
