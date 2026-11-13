param([switch]$MigrateOnly)
. "$PSScriptRoot\Environment.ps1"
New-Item -ItemType Directory -Path '.local' -Force | Out-Null
$configPath = Join-Path $depoRoot 'backend\Depo.Api\appsettings.Local.json'
function RandomSecret { $bytes=New-Object byte[] 48;  $rng=[Security.Cryptography.RandomNumberGenerator]::Create(); try {$rng.GetBytes($bytes)} finally {$rng.Dispose()}; [Convert]::ToBase64String($bytes) }
if (-not (Test-Path $configPath)) {
 $password=RandomSecret
 $config=@{ConnectionStrings=@{Database="Host=127.0.0.1;Port=54329;Database=mobildepo;Username=depo;Password=$password"};Jwt=@{Key=(RandomSecret)};Demo=@{Seed=$true}}
 $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
}
$config=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$pg=Join-Path $depoRoot '.tools\pgsql\bin'
if (Test-Path (Join-Path $pg 'pg_ctl.exe')) {
 $dataPath=Join-Path $depoRoot '.local\postgres'
 $env:PGPASSWORD=([regex]::Match($config.ConnectionStrings.Database,'Password=([^;]+)')).Groups[1].Value
 if (-not (Test-Path (Join-Path $dataPath 'PG_VERSION'))) {
  $pwfile=Join-Path $depoRoot '.local\pg-password.txt'
  try {
   Set-Content -LiteralPath $pwfile -Value $env:PGPASSWORD -Encoding Ascii
   & "$pg\initdb.exe" -D $dataPath -U depo "--pwfile=$pwfile" --auth=scram-sha-256 --encoding=UTF8 --locale=C
   if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL başlatılamadı.' }
  } finally { if(Test-Path $pwfile){Remove-Item -LiteralPath $pwfile} }
 }
 & "$pg\pg_ctl.exe" -D $dataPath status *> $null
 if ($LASTEXITCODE -ne 0) {
  & "$pg\pg_ctl.exe" -D $dataPath -l (Join-Path $depoRoot '.local\postgres.log') -o '-p 54329 -h 127.0.0.1' start
  if($LASTEXITCODE -ne 0){throw 'PostgreSQL sunucusu açılamadı.'}
 }
 $exists=& "$pg\psql.exe" -h 127.0.0.1 -p 54329 -U depo -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='mobildepo'"
 if ($exists -ne '1') { & "$pg\createdb.exe" -h 127.0.0.1 -p 54329 -U depo mobildepo; if($LASTEXITCODE -ne 0){throw 'Veritabanı oluşturulamadı.'} }
 Remove-Item Env:\PGPASSWORD
}
$env:ASPNETCORE_ENVIRONMENT='Development'
if($MigrateOnly){& $depoDotnet run --project backend/Depo.Api -c Release --no-launch-profile -- --migrate-only; exit $LASTEXITCODE}
try { $health=Invoke-RestMethod 'http://127.0.0.1:5080/health' -TimeoutSec 2; if($health.status -eq 'healthy'){Write-Host 'Mobil Depo API zaten çalışıyor: http://127.0.0.1:5080/swagger';exit 0} } catch {}
Write-Host 'API: http://127.0.0.1:5080   Swagger: http://127.0.0.1:5080/swagger'
& $depoDotnet run --project backend/Depo.Api -c Release --no-launch-profile --urls http://127.0.0.1:5080
exit $LASTEXITCODE
