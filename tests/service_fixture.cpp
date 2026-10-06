#include "zml_lua_service.h"
namespace {ZmlLuaSource provider=nullptr;void* data=nullptr;
int add(void*,ZmlLuaSource p,void* d){if(provider||!p)return 0;provider=p;data=d;return 1;}
const ZmlLuaServicesV1 api{sizeof(ZmlLuaServicesV1),1,add};}
extern "C" __declspec(dllexport) const ZmlLuaServicesV1* ZML_GetLuaServicesV1(){return &api;}
extern "C" __declspec(dllexport) int FixtureSource(const char* path,ZmlSink sink,void* writer){return provider?provider(data,path,sink,writer):0;}
