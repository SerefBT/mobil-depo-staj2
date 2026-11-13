param([string]$ApiUrl='')
. "$PSScriptRoot\Environment.ps1"
Push-Location mobile
try {
 & $depoFlutter pub get; if($LASTEXITCODE -ne 0){throw 'Flutter paketleri alınamadı.'}
 $arguments=@('build','web','--release','--no-wasm-dry-run')
 if($ApiUrl){$arguments+="--dart-define=API_BASE_URL=$ApiUrl"}
 & $depoFlutter @arguments
 if($LASTEXITCODE -ne 0){throw 'Web derlemesi başarısız.'}
} finally {Pop-Location}
New-Item -ItemType Directory -Path 'backend\Depo.Api\wwwroot','web\dist','web\source\lib','web\source\web' -Force | Out-Null
Copy-Item -Path 'mobile\build\web\*' -Destination 'backend\Depo.Api\wwwroot' -Recurse -Force
Copy-Item -Path 'mobile\build\web\*' -Destination 'web\dist' -Recurse -Force
Copy-Item -Path 'mobile\lib\*' -Destination 'web\source\lib' -Recurse -Force
Copy-Item -Path 'mobile\web\*' -Destination 'web\source\web' -Recurse -Force
Copy-Item -LiteralPath 'mobile\pubspec.yaml','mobile\pubspec.lock','mobile\analysis_options.yaml' -Destination 'web\source' -Force
Write-Host 'Web hazır. Start-Demo.cmd ile açın: http://127.0.0.1:5080'
