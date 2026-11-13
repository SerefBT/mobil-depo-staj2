param([switch]$SkipPostgres)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
New-Item -ItemType Directory '.tools' -Force | Out-Null
$lock=Get-Content 'toolchain.json' -Raw | ConvertFrom-Json
if(-not(Test-Path '.tools\dotnet\dotnet.exe')) {
 $meta=Invoke-RestMethod 'https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json'
 $sdk=$meta.releases | ForEach-Object {$_.sdks} | Where-Object version -eq $lock.dotnet | Select-Object -First 1
 $file=$sdk.files | Where-Object name -eq 'dotnet-sdk-win-x64.zip' | Select-Object -First 1
 if(-not $file){throw 'Sabitlenen .NET SDK sürümü bulunamadı.'}
 Invoke-WebRequest $file.url -OutFile '.tools\dotnet.zip' -UseBasicParsing
 if((Get-FileHash '.tools\dotnet.zip' -Algorithm SHA512).Hash -ne $file.hash){throw '.NET SHA512 doğrulanamadı.'}
 New-Item -ItemType Directory '.tools\dotnet' -Force | Out-Null
 tar -xf '.tools\dotnet.zip' -C '.tools\dotnet'
 if($LASTEXITCODE -ne 0){throw '.NET arşivi açılamadı.'}
}
if(-not(Test-Path '.tools\flutter\bin\flutter.bat')) {
 $meta=Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
 $release=$meta.releases | Where-Object {$_.version -eq $lock.flutter -and $_.channel -eq 'stable'} | Select-Object -First 1
 if(-not $release){throw 'Sabitlenen Flutter sürümü bulunamadı.'}
 Invoke-WebRequest "$($meta.base_url)/$($release.archive)" -OutFile '.tools\flutter.zip' -UseBasicParsing
 if((Get-FileHash '.tools\flutter.zip' -Algorithm SHA256).Hash -ne $release.sha256){throw 'Flutter SHA256 doğrulanamadı.'}
 tar -xf '.tools\flutter.zip' -C '.tools'
 if($LASTEXITCODE -ne 0){throw 'Flutter arşivi açılamadı.'}
}
if(-not $SkipPostgres -and -not(Test-Path '.tools\pgsql\bin\postgres.exe')) {
 Invoke-WebRequest "https://get.enterprisedb.com/postgresql/postgresql-$($lock.postgresql)-1-windows-x64-binaries.zip" -OutFile '.tools\postgres.zip' -UseBasicParsing
 tar -xf '.tools\postgres.zip' -C '.tools'
 if($LASTEXITCODE -ne 0){throw 'PostgreSQL arşivi açılamadı.'}
}
. "$PSScriptRoot\Environment.ps1"
& $depoDotnet --version
& $depoFlutter --version
Write-Host 'Araçlar hazır. Android Studio SDK / JDK ve Android lisansları için flutter doctor -v çıktısını kontrol edin.'
