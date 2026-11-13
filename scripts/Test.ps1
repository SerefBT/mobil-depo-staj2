. "$PSScriptRoot\Environment.ps1"
$config=Get-Content 'backend\Depo.Api\appsettings.Local.json' -Raw | ConvertFrom-Json
$env:TEST_DATABASE_CONNECTION=$config.ConnectionStrings.Database
& $depoDotnet test backend/Depo.Tests -c Release --logger 'trx;LogFileName=integration.trx' --results-directory artifacts/test-results
if($LASTEXITCODE -ne 0){throw 'Backend testleri başarısız.'}
Push-Location mobile
try {
 & $depoFlutter analyze; if($LASTEXITCODE -ne 0){throw 'Flutter analizi başarısız.'}
 & $depoFlutter test; if($LASTEXITCODE -ne 0){throw 'Flutter testleri başarısız.'}
} finally {Pop-Location;Remove-Item Env:\TEST_DATABASE_CONNECTION -ErrorAction SilentlyContinue}
