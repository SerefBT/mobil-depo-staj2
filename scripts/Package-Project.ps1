param([switch]$IncludeApk)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$target=Join-Path $projectRoot 'artifacts\MobilDepo-Teslim.zip'
New-Item -ItemType Directory (Split-Path $target) -Force | Out-Null
$roots=@('backend','mobile','docs','scripts','.config','web','deploy')
$files=@()
foreach($name in $roots){$files+=Get-ChildItem -LiteralPath (Join-Path $projectRoot $name) -Recurse -File -Force}
$files+=Get-ChildItem -LiteralPath $projectRoot -File -Force | Where-Object {$_.Name -notin @('.env')}
if($IncludeApk){$files+=Get-Item -LiteralPath (Join-Path $projectRoot 'artifacts\MobilDepo-release.apk')}
$stream=[IO.File]::Open($target,[IO.FileMode]::Create)
$archive=New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create)
try {
 foreach($file in $files){
  $relative=$file.FullName.Substring($projectRoot.Length+1)
  if($relative -match '(^|[\\/])(build|bin|obj|\.git|\.dart_tool|\.gradle|\.idea|\.kotlin|\.tools|\.local|dist)([\\/]|$)'){continue}
  if($file.Name -match '^(appsettings\.Local\.json|key\.properties|local\.properties|\.flutter-plugins.*)$' -or $file.Extension -in @('.jks','.keystore','.log')){continue}
  $entry='MobilDepo/'+$relative.Replace('\','/')
  [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file.FullName,$entry,[IO.Compression.CompressionLevel]::Optimal) | Out-Null
 }
} finally {$archive.Dispose();$stream.Dispose()}
Write-Host "Teslim paketi: $target"
Get-FileHash -LiteralPath $target -Algorithm SHA256
