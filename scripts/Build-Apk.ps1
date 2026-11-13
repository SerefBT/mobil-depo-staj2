param([ValidateSet('release','debug')][string]$Mode='release',[string]$ApiUrl='http://10.0.2.2:5080/api')
. "$PSScriptRoot\Environment.ps1"
Push-Location mobile
try {
 & $depoFlutter pub get; if($LASTEXITCODE -ne 0){throw 'Flutter paketleri alınamadı.'}
 & $depoFlutter analyze; if($LASTEXITCODE -ne 0){throw 'Flutter analizi başarısız.'}
 & $depoFlutter build apk "--$Mode" "--dart-define=API_BASE_URL=$ApiUrl"
 if($LASTEXITCODE -ne 0){throw 'APK derlenemedi.'}
 Copy-Item -LiteralPath "build\app\outputs\flutter-apk\app-$Mode.apk" -Destination "..\artifacts\MobilDepo-$Mode.apk" -Force
 Get-FileHash -LiteralPath "..\artifacts\MobilDepo-$Mode.apk" -Algorithm SHA256
} finally {Pop-Location}
