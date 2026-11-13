param([string]$DeviceId)
. "$PSScriptRoot\Environment.ps1"
$adb=Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if(-not(Test-Path $adb)){$adb=(Get-Command adb -ErrorAction Stop).Source}
$arguments=@();if($DeviceId){$arguments+=@('-s',$DeviceId)}
& $adb @arguments reverse tcp:5080 tcp:5080
if($LASTEXITCODE -ne 0){throw 'Telefon bağlanamadı. USB hata ayıklamayı açın ve telefondaki bilgisayar iznini onaylayın.'}
$apk=Join-Path $depoRoot 'artifacts\MobilDepo-release.apk'
if(Test-Path $apk){& $adb @arguments install -r $apk;if($LASTEXITCODE -ne 0){throw 'APK yüklenemedi.'}}
Write-Host 'Uygulamada Sunucu bağlantısı: http://127.0.0.1:5080/api olarak ayarlayın.'
