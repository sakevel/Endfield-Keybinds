$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$source=Join-Path $root 'build/package/Release/keybinds'
$files=@((Get-Content "$source/zml-package.json" -Raw|ConvertFrom-Json).files)+@('zml-package.json')
$dist=Join-Path $root 'dist';New-Item -ItemType Directory -Force $dist|Out-Null
$zip=Join-Path $dist ('EndfieldKeybinds-0.2.1-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.zip')
Compress-Archive -LiteralPath @($files|ForEach-Object {Join-Path $source $_}) -DestinationPath $zip
Get-FileHash -LiteralPath $zip -Algorithm SHA256
