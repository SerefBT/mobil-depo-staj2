$ErrorActionPreference='Stop'
$target=Join-Path $env:LOCALAPPDATA 'SerafettinStaj\MobilDepo\Uygulama\Durdur.ps1'
if(Test-Path -LiteralPath $target){& $target}else{Write-Host 'Bu CD için yerel kurulum bulunamadı.'}
