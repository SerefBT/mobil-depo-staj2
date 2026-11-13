$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$markerDirectory = Join-Path $projectRoot '.local'
New-Item -ItemType Directory -Path $markerDirectory -Force | Out-Null
$markerPath = Join-Path $markerDirectory 'project-id'
if (-not (Test-Path $markerPath)) { [Guid]::NewGuid().ToString() | Set-Content -LiteralPath $markerPath -Encoding Ascii }
$projectId = (Get-Content -LiteralPath $markerPath -Raw).Trim()
$projectDrive = $null
foreach ($letter in @('M','R','S','T','V')) {
 $candidate = $letter + ':\.local\project-id'
 if ((Test-Path $candidate) -and (Get-Content -LiteralPath $candidate -Raw).Trim() -eq $projectId) { $projectDrive=$letter+':';break }
}
if (-not $projectDrive) {
 foreach ($letter in @('M','R','S','T','V')) {
  if (-not (Test-Path ($letter + ':\'))) {
   & subst ($letter + ':') $projectRoot
   if ($LASTEXITCODE -ne 0) { throw 'Proje için kısa sürücü yolu oluşturulamadı.' }
   $projectDrive = $letter + ':'; break
  }
 }
}
if (-not $projectDrive) { throw 'Boş sürücü harfi bulunamadı. Projeyi ASCII karakterli kısa bir yoldan çalıştırın.' }
$depoRoot = $projectDrive + '\'
$env:DOTNET_CLI_HOME = $depoRoot + '.tools\dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'
$env:PUB_CACHE = $depoRoot + '.tools\pub-cache'
$env:GRADLE_USER_HOME = $depoRoot + '.tools\gradle'
$env:NUGET_PACKAGES = $depoRoot + '.tools\nuget'
if (Test-Path ($depoRoot + '.tools\dotnet\dotnet.exe')) { $env:DOTNET_ROOT=$depoRoot+'.tools\dotnet'; $env:PATH=$env:DOTNET_ROOT+';'+$env:PATH }
$depoDotnet = (Get-Command dotnet -ErrorAction Stop).Source
if (Test-Path ($depoRoot + '.tools\flutter\bin\flutter.bat')) { $depoFlutter=$depoRoot+'.tools\flutter\bin\flutter.bat' } else { $depoFlutter=(Get-Command flutter -ErrorAction Stop).Source }
Set-Location $depoRoot
