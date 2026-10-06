#include "zml_plugin.h"
#include "patch.hpp"
#include <Windows.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <map>
#include <stdexcept>
namespace {
struct Callback {ZmlLuaTransform fn;void* data;};
std::map<std::string,Callback> callbacks;
void check(bool b,const char* m){if(!b)throw std::runtime_error(m);}
void log(void*,const char*){}
int subscribe(void*,const char* path,ZmlLuaTransform fn,void* data){return callbacks.emplace(path,Callback{fn,data}).second;}
void sink(void* p,const char* s,size_t n){*static_cast<std::string*>(p)=std::string(s,n);}
std::string read(const std::filesystem::path& p){std::ifstream f(p,std::ios::binary);check(f.good(),"fixture missing");return {std::istreambuf_iterator<char>(f),{}};}
const char* paths[]{"Common/Utils/UIUtils","UI/Panels/GameSetting/GameSettingCtrl","UI/Panels/GameSettingKeycodePopup/GameSettingKeycodePopupCtrl","UI/Panels/BattleAction/BattleActionCtrl"};
std::string synthetic(int k){
 if(k==3)return "BattleActionCtrl = HL.Class(\"BattleActionCtrl\")\nHL.Commit(BattleActionCtrl)";
 if(k==0)return "function UIUtils.bindInputEvent(key, action, modifyKeys, timing, groupId) end\n_G.UIUtils = UIUtils\nreturn UIUtils";
 if(k==2)return "GameSettingKeycodePopupCtrl.OnCreate = HL.Override() << function(self)\n    self.m_settingItemData = arg.settingItemData\nend\nGameSettingKeycodePopupCtrl._UpdateView = HL.Method() << function(self)\n    self.view.actionNameText.text = settingItemData.settingText\nend\nGameSettingKeycodePopupCtrl.OnClose = HL.Override() << function(self) end\nGameSettingKeycodePopupCtrl._ListenInput = HL.Method() << function(self)\n    local success, keyCode, isBlackList = InputManagerInst:AnyKeyboardKey(self.m_actionScopes)\n    if isBlackList then return end\nend\nHL.Commit(GameSettingKeycodePopupCtrl)";
 return "GameSettingCtrl.OnCreate = HL.Override() << function(self, arg) end\nGameSettingCtrl._BuildSettingTabData = HL.Method() << function(self)\n    return itemDataList\nend\nGameSettingCtrl._RefreshSettingItemCell = HL.Method() << function(self)\nif GameSettingHelper.IsQualitySubSetting(settingId) then end\nend\nGameSettingCtrl._InitSettingItemControlKey = HL.Method() << function(self)\n    local itemControl = itemCell.itemControl\nend\nGameSettingCtrl._KeyClearPendingActions = HL.Method() << function(self) end\nGameSettingCtrl._KeyResetActions = HL.Method() << function(self)\n        onConfirm = function() end\nend\nGameSettingCtrl._KeySaveActions = HL.Method() << function(self)\n    local stateLevel = self:_GetKeyActionStateLevel()\nend\nGameSettingCtrl.OnClose = HL.Override() << function(self) end\nHL.Commit(GameSettingCtrl)";
}
}
int main(int argc,char** argv){try{
 check(argc==2 || argc==4,"usage DLL [client-lua out-directory]");
 auto dllPath=std::filesystem::absolute(argv[1]);auto dll=LoadLibraryW(dllPath.c_str());check(dll!=nullptr,"DLL load");
 auto entry=reinterpret_cast<ZmlPluginEntry>(GetProcAddress(dll,"ZML_PluginV1"));check(entry!=nullptr,"entry");
 auto p=entry();check(p&&p->abi==1&&p->size==sizeof(ZmlPlugin)&&std::string(p->id)=="keybinds","ABI/id");
 auto u=dllPath.parent_path().u8string();std::string dir(reinterpret_cast<const char*>(u.data()),u.size());
 std::string state="C:\\test\\中文\\\"quoted\"";
 ZmlHost h{sizeof(ZmlHost),1,nullptr,dir.c_str(),state.c_str(),log,subscribe};
 check(!p->start(nullptr),"null host");auto bad=h;bad.abi=2;check(!p->start(&bad),"wrong ABI");
 bad=h;bad.state_directory="";check(!p->start(&bad),"empty private state rejected");
 auto absent=dir+"/missing";bad=h;bad.mod_directory=absent.c_str();check(!p->start(&bad)&&callbacks.empty(),"missing assets atomic");
 check(p->start(&h)&&callbacks.size()==4,"register four transforms");
 auto outputDir=argc==4?std::filesystem::absolute(argv[3]):std::filesystem::path{};
 if(argc==4)std::filesystem::create_directories(outputDir);
 for(int k=0;k<4;++k){
  auto input=argc==4?read(std::filesystem::path(argv[2])/(std::string(paths[k])+".lua")):synthetic(k);
  auto c=callbacks.at(paths[k]);std::string output;
  check(c.fn(c.data,input.data(),input.size(),sink,&output)==1,"actual transform");
  check(output.find(kb::marker)!=output.npos&&output.find("__ZML_STATE_FILE__")==output.npos,"marker/assets assembled");
  if(k==0)check(output.find("\\\"quoted\\\"")!=output.npos,"escaped private path");
  if(k==2){
   check(output.find("isBlackList = false")!=output.npos,"blacklist relaxed");
   auto missingBlacklist=input;auto at=missingBlacklist.find("    if isBlackList then");
   check(at!=missingBlacklist.npos,"blacklist contract present");
   missingBlacklist.replace(at,std::string("    if isBlackList then").size(),"    if otherFlag then");
   auto unchanged=output;
   check(!c.fn(c.data,missingBlacklist.data(),missingBlacklist.size(),sink,&output)&&output==unchanged,"missing blacklist contract atomic");
  }
  auto preserved=output;
  check(!c.fn(c.data,preserved.data(),preserved.size(),sink,&output)&&output==preserved,"idempotent no partial sink");
  std::string missing="invalid";check(!c.fn(c.data,missing.data(),missing.size(),sink,&output)&&output==preserved,"missing contract atomic");
  std::string duplicate=input+"\n"+input;check(!c.fn(c.data,duplicate.data(),duplicate.size(),sink,&output)&&output==preserved,"ambiguous contract atomic");
  if(argc==4){std::ofstream f(outputDir/(std::to_string(k)+".lua"),std::ios::binary);f<<preserved;}
 }
 FreeLibrary(dll);std::cout<<"PASS actual DLL ABI, assets, path escaping, four atomic/idempotent contracts\n";return 0;
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
