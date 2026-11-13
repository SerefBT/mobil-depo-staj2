param([switch]$Quiet)
$ErrorActionPreference='Stop'
$base=Join-Path $env:LOCALAPPDATA 'SerafettinStaj\MobilDepo';$statePath=Join-Path $base 'calisma-durumu.json'
if(-not(Test-Path -LiteralPath $statePath)){if(-not $Quiet){Write-Host 'Bu CD için çalışan oturum bulunamadı.'};return}
$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
if((Get-Content -LiteralPath (Join-Path $base '.instance-id') -Raw).Trim() -ne $state.InstanceId){throw 'Kurulum kimliği eşleşmedi; hiçbir süreç kapatılmadı.'}
function OwnProcess([int]$processId,[long]$ticks,[string]$name){if($processId -lt 1){return $false};try{$p=Get-Process -Id $processId -ErrorAction Stop;return $p.ProcessName -eq $name -and $p.StartTime.ToUniversalTime().Ticks -eq $ticks}catch{return $false}}
if(OwnProcess ([int]$state.ApiPid) ([long]$state.ApiTicks) 'dotnet'){Stop-Process -Id ([int]$state.ApiPid) -ErrorAction Stop;Wait-Process -Id ([int]$state.ApiPid) -Timeout 15 -ErrorAction SilentlyContinue}
$work=[string]$state.Drive+'\';$marker=Join-Path $work '.instance-id'
$ownMapping=(Test-Path -LiteralPath $marker) -and (Get-Content -LiteralPath $marker -Raw).Trim() -eq $state.InstanceId
if(OwnProcess ([int]$state.PgPid) ([long]$state.PgTicks) 'postgres'){
 if(-not $ownMapping){throw 'Kısa çalışma yolu eşleşmiyor; veritabanı süreci kapatılmadı.'}
 $p=Start-Process -FilePath (Join-Path $work 'Uygulama\pgsql\bin\pg_ctl.exe') -ArgumentList @('-D',(Join-Path $work 'Veritabani'),'-m','fast','-w','-t','30','stop') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $work 'Kayitlar\postgres-durdur.log') -RedirectStandardError (Join-Path $work 'Kayitlar\postgres-durdur-hata.log')
 if($p.ExitCode -ne 0){throw 'Yerel veritabanı kapanmadı; kayıtlar korundu.'}
}
Remove-Item -LiteralPath $statePath
if($ownMapping){& subst ([string]$state.Drive) /d}
if(-not $Quiet){Write-Host 'Yalnız bu CD oturumunun API ve veritabanı durduruldu. Veriler korundu.'}
