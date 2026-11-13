param([string]$PaketDizini=$PSScriptRoot,[switch]$NoBrowser)
$ErrorActionPreference='Stop'
if(-not [Environment]::Is64BitOperatingSystem){throw 'Bu paket Windows64 içindir.'}
$base=Join-Path $env:LOCALAPPDATA 'SerafettinStaj\MobilDepo';$install=Join-Path $base 'Uygulama'
if(Test-Path -LiteralPath (Join-Path $base 'calisma-durumu.json')){& (Join-Path $install 'Durdur.ps1') -Quiet}
$null=New-Item -ItemType Directory -Path $install -Force
Write-Host 'CD içeriği kullanıcı profilinize kopyalanıyor; veritabanınız korunur...'
& robocopy $PaketDizini $install /E /XJ /NFL /NDL /NJH /NJS /NP /R:2 /W:1
if($LASTEXITCODE -ge 8){throw 'Yerel çalışma dosyaları kopyalanamadı.'}
& (Join-Path $install 'Baslat.ps1') -NoBrowser:$NoBrowser
