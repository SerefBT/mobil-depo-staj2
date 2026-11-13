param([switch]$NoBrowser)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$base=Join-Path $env:LOCALAPPDATA 'SerafettinStaj\MobilDepo'
if(-not [Environment]::Is64BitOperatingSystem){throw 'Bu paket Windows64 içindir.'}
$null=New-Item -ItemType Directory -Path $base -Force
$identity=Join-Path $base '.instance-id'
if(-not(Test-Path -LiteralPath $identity)){[Guid]::NewGuid().ToString()|Set-Content -LiteralPath $identity -Encoding Ascii}
$instanceId=(Get-Content -LiteralPath $identity -Raw).Trim()
$drive=$null
foreach($letter in @('N','O','P','Q','R','S','T','U','V','W','X','Y','Z')){
 $marker=$letter+':\.instance-id'
 if((Test-Path -LiteralPath $marker) -and (Get-Content -LiteralPath $marker -Raw).Trim() -eq $instanceId){$drive=$letter+':';break}
}
if(-not $drive){foreach($letter in @('N','O','P','Q','R','S','T','U','V','W','X','Y','Z')){if(-not(Test-Path -LiteralPath ($letter+':\'))){& subst ($letter+':') $base;if($LASTEXITCODE -ne 0){throw 'Kısa çalışma yolu oluşturulamadı.'};$drive=$letter+':';break}}}
if(-not $drive){throw 'Boş sürücü harfi bulunamadı.'}
$work=$drive+'\';$install=Join-Path $work 'Uygulama';$pg=Join-Path $install 'pgsql\bin';$data=Join-Path $work 'Veritabani';$logs=Join-Path $work 'Kayitlar';$settings=Join-Path $work 'YerelAyarlar'
$null=New-Item -ItemType Directory -Path $logs,$settings -Force
$statePath=Join-Path $base 'calisma-durumu.json'
if(Test-Path -LiteralPath $statePath){throw 'Önce 2_DURDUR.cmd ile önceki oturumu kapatın.'}
function PortOpen([int]$port){$client=[Net.Sockets.TcpClient]::new();try{$task=$client.ConnectAsync('127.0.0.1',$port);if($task.Wait(300)){return $client.Connected};return $false}catch{return $false}finally{$client.Dispose()}}
foreach($port in @(5081,54331)){if(PortOpen $port){throw "Yerel $port portu başka bir süreçte kullanılıyor; hiçbir süreç kapatılmadı."}}
function RandomText([int]$size){$bytes=New-Object byte[] $size;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($bytes);return [Convert]::ToBase64String($bytes)}finally{$rng.Dispose()}}
$configPath=Join-Path $settings 'ayarlar.json'
if(-not(Test-Path -LiteralPath $configPath)){@{DbPassword=(RandomText 32);JwtKey=(RandomText 64)}|ConvertTo-Json|Set-Content -LiteralPath $configPath -Encoding UTF8}
$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
$state=[ordered]@{InstanceId=$instanceId;Drive=$drive;PgPid=0;PgTicks=0;ApiPid=0;ApiTicks=0}
function SaveState {$state|ConvertTo-Json|Set-Content -LiteralPath $statePath -Encoding UTF8}
function RunPg([string]$exe,[string[]]$arguments,[string]$name){
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=Join-Path $pg $exe;$info.Arguments=$arguments -join ' ';$info.WorkingDirectory=$pg;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
 $process=[Diagnostics.Process]::new();$process.StartInfo=$info
 try{$null=$process.Start();$process.WaitForExit();if($process.ExitCode -ne 0){throw "$name başarısız. Ayrıntı: $base\Kayitlar"}}finally{$process.Dispose()}
}
$oldPw=$env:PGPASSWORD
try{
 if(-not(Test-Path -LiteralPath (Join-Path $data 'PG_VERSION'))){
  $pwfile=Join-Path $settings 'ilk-kurulum.pw'
  [IO.File]::WriteAllText($pwfile,[string]$config.DbPassword,[Text.UTF8Encoding]::new($false))
  try{RunPg 'initdb.exe' @('-D',$data,'-U','mobildepo_cd',('--pwfile='+$pwfile),'--auth=scram-sha-256','--encoding=UTF8','--locale=C') 'veritabani-kurulum'}finally{if(Test-Path -LiteralPath $pwfile){Remove-Item -LiteralPath $pwfile}}
 }
 RunPg 'pg_ctl.exe' @('-D',$data,'-l',(Join-Path $logs 'postgres.log'),'-o','"-p 54331 -h 127.0.0.1"','-w','-t','30','start') 'postgres-baslat'
 $pgId=[int](Get-Content -LiteralPath (Join-Path $data 'postmaster.pid') -TotalCount 1);$process=Get-Process -Id $pgId -ErrorAction Stop
 $state.PgPid=$pgId;$state.PgTicks=$process.StartTime.ToUniversalTime().Ticks;SaveState
 $env:PGPASSWORD=[string]$config.DbPassword
 $exists=& (Join-Path $pg 'psql.exe') -h 127.0.0.1 -p 54331 -U mobildepo_cd -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='mobildepo_cd'"
 if($LASTEXITCODE -ne 0){throw 'Yerel veritabanına bağlanılamadı.'}
 if("$exists" -notmatch '^\s*1\s*$'){RunPg 'createdb.exe' @('-h','127.0.0.1','-p','54331','-U','mobildepo_cd','mobildepo_cd') 'veritabani-olustur'}
 $values=@{ASPNETCORE_ENVIRONMENT='Development';DOTNET_ENVIRONMENT='Development';ASPNETCORE_URLS='http://127.0.0.1:5081';Demo__Seed='true';ConnectionStrings__Database=('Host=127.0.0.1;Port=54331;Database=mobildepo_cd;Username=mobildepo_cd;Password='+$config.DbPassword);Jwt__Key=[string]$config.JwtKey;DOTNET_ROOT=(Join-Path $install 'dotnet')}
 $old=@{}
 try{
  foreach($key in $values.Keys){$old[$key]=[Environment]::GetEnvironmentVariable($key,'Process');[Environment]::SetEnvironmentVariable($key,$values[$key],'Process')}
  $api=Start-Process -FilePath (Join-Path $install 'dotnet\dotnet.exe') -ArgumentList (Join-Path $install 'api\Depo.Api.dll') -WorkingDirectory (Join-Path $install 'api') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'api.log') -RedirectStandardError (Join-Path $logs 'api-hata.log')
 }finally{foreach($key in $values.Keys){[Environment]::SetEnvironmentVariable($key,$old[$key],'Process')}}
 $state.ApiPid=$api.Id;$state.ApiTicks=$api.StartTime.ToUniversalTime().Ticks;SaveState
 $ready=$false
 for($i=0;$i -lt 60;$i++){try{$health=Invoke-RestMethod 'http://127.0.0.1:5081/health' -TimeoutSec 1;if($health.status -eq 'healthy'){$ready=$true;break}}catch{};if($api.HasExited){throw 'API başlamadı. Kayitlar klasörüne bakın.'};Start-Sleep -Milliseconds 500}
 if(-not $ready){throw 'Başlangıç zaman aşımı. Kayitlar klasörüne bakın.'}
 Write-Host 'Mobil Depo hazır: http://127.0.0.1:5081'
 Write-Host 'Girişler: CD içindeki GIRIS_BILGILERI.txt'
 if(-not $NoBrowser){Start-Process 'http://127.0.0.1:5081'}
}catch{if(Test-Path -LiteralPath $statePath){& (Join-Path $install 'Durdur.ps1') -Quiet};throw}finally{$env:PGPASSWORD=$oldPw}
