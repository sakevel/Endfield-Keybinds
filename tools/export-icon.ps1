param(
 [Parameter(Mandatory=$true)][string]$Source,
 [Parameter(Mandatory=$true)][string]$Destination,
 [switch]$Monochrome
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$sourcePath=(Resolve-Path -LiteralPath $Source).Path
$destinationPath=[IO.Path]::GetFullPath($Destination)
if($sourcePath.Equals($destinationPath,[StringComparison]::OrdinalIgnoreCase)){throw 'Keep the generated master separate from the export'}
$src=[Drawing.Image]::FromFile($sourcePath)
$output=[Drawing.Bitmap]::new(256,256,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
try {
 $graphics=[Drawing.Graphics]::FromImage($output)
 try {
  $graphics.Clear([Drawing.Color]::Transparent)
  $graphics.CompositingMode=[Drawing.Drawing2D.CompositingMode]::SourceCopy
  $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.DrawImage($src,0,0,256,256)
 } finally {$graphics.Dispose()}
 # Technical palette export only; creative geometry comes from image_gen.
 for($y=0;$y -lt 256;$y++){for($x=0;$x -lt 256;$x++){
  $c=$output.GetPixel($x,$y)
  if($c.A -eq 0){continue}
  if($Monochrome){$rgb=@(255,255,255)}
  elseif($c.R -gt 120 -and $c.G -gt 110 -and $c.B -lt 100 -and ([Math]::Max($c.R,$c.G)-$c.B) -gt 30){$rgb=@(255,239,0)}
  else{
   $value=($c.R+$c.G+$c.B)/3
   $q=if($value -gt 220){255}elseif($value -gt 160){180}elseif($value -gt 95){128}else{49}
   $rgb=@($q,$q,$q)
  }
  $output.SetPixel($x,$y,[Drawing.Color]::FromArgb($c.A,$rgb[0],$rgb[1],$rgb[2]))
 }}
 $output.Save($destinationPath,[Drawing.Imaging.ImageFormat]::Png)
 if((Get-Item -LiteralPath $destinationPath).Length -gt 64KB){throw 'PNG exceeds public API limit'}
} finally {$output.Dispose();$src.Dispose()}
Write-Output $destinationPath
