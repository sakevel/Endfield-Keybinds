param([Parameter(Mandatory=$true)][string]$SourceRoot,
      [Parameter(Mandatory=$true)][string]$PackageRoot)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$source=Join-Path $SourceRoot 'mod/icon.png'
$package=Join-Path $PackageRoot 'icon.png'
$ini=Get-Content (Join-Path $SourceRoot 'mod/mod.ini') -Raw -Encoding utf8
if($ini -notmatch '(?m)^icon=icon\.png\r?$'){throw 'Manifest must reference the bundled icon'}
foreach($root in @((Join-Path $SourceRoot 'mod'), $PackageRoot)){
    $manifest=Get-Content (Join-Path $root 'zml-package.json') -Raw | ConvertFrom-Json
    if($manifest.id -ne 'keybinds' -or @($manifest.files | Where-Object {$_ -eq 'icon.png'}).Count -ne 1){
        throw 'Icon missing or duplicated in package whitelist'
    }
}
function Hash([string]$path){
    $sha=[Security.Cryptography.SHA256]::Create()
    try {[Convert]::ToBase64String($sha.ComputeHash([IO.File]::ReadAllBytes($path)))}
    finally {$sha.Dispose()}
}
if((Hash $source) -ne (Hash $package)){throw 'Packaged icon differs from source'}
if((Get-Item $source).Length -gt 64KB){throw 'Icon exceeds public API limit'}
$image=[Drawing.Bitmap]::new($source)
try {
    if($image.Width -ne 256 -or $image.Height -ne 256){throw 'Expected 256x256 icon'}
    if($image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid){throw 'Expected PNG'}
    $transparent=0;$solid=0;$yellow=0;$white=0
    for($y=0;$y -lt 256;$y++){for($x=0;$x -lt 256;$x++){
        $c=$image.GetPixel($x,$y)
        if($c.A -eq 0){$transparent++;continue}
        # Generated artwork and bicubic edges can carry alpha 253/254, visually solid.
        if($c.A -ge 250){$solid++}
        if($c.R -eq 255 -and $c.G -eq 239 -and $c.B -eq 0){$yellow++;continue}
        if($c.R -ne $c.G -or $c.G -ne $c.B -or $c.R -notin @(49,128,180,255)){
            throw 'Unexpected palette color'
        }
        if($c.R -eq 255){$white++}
    }}
    if($transparent -lt 10000 -or $solid -lt 10000 -or $yellow -lt 100 -or $white -lt 1000){
        throw 'Missing transparency, silhouette, white glyph or yellow accent'
    }
    Write-Output "PNG/size/alpha/palette/metadata/package hash checks passed ($((Get-Item $source).Length) bytes)"
} finally {$image.Dispose()}
