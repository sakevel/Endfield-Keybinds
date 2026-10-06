param([string]$LupaPath='', [string]$ClientLua='')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$opts=@()
if($LupaPath){$opts+="-DZML_LUPA_PATH=$LupaPath"}
if($ClientLua){$opts+="-DZML_CLIENT_LUA=$ClientLua"}
cmake -S $root -B "$root/build" -G 'Visual Studio 17 2022' -A x64 @opts
if($LASTEXITCODE){throw 'Configure failed'}
cmake --build "$root/build" --config Release --parallel 6
if($LASTEXITCODE){throw 'Build failed'}
ctest --test-dir "$root/build" -C Release --output-on-failure
if($LASTEXITCODE){throw 'Tests failed'}
