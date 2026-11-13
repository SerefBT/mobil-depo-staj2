. "$PSScriptRoot\Environment.ps1"
Write-Host 'API çalıştırılan terminalde Ctrl+C ile kapatılır.'
$pg=Join-Path $depoRoot '.tools\pgsql\bin\pg_ctl.exe'
if(Test-Path $pg){& $pg -D (Join-Path $depoRoot '.local\postgres') stop -m fast}
