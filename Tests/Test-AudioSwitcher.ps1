$ErrorActionPreference = "Stop"

$testsPath = Join-Path $PSScriptRoot "AudioSwitcher.Tests.ps1"
if (-not (Test-Path -LiteralPath $testsPath)) {
    throw "Pester test file not found: $testsPath"
}

$invokePester = Get-Command Invoke-Pester -ErrorAction SilentlyContinue
if ($null -eq $invokePester) {
    throw "Pester is required to run tests. Install Pester and retry."
}

if ($invokePester.Parameters.ContainsKey("Path")) {
    $result = Invoke-Pester -Path $testsPath -PassThru
}
elseif ($invokePester.Parameters.ContainsKey("Script")) {
    $result = Invoke-Pester -Script $testsPath -PassThru
}
else {
    $result = Invoke-Pester $testsPath -PassThru
}

if ($null -ne $result -and $result.FailedCount -gt 0) {
    throw ("Pester tests failed: {0}" -f $result.FailedCount)
}

Write-Host "Audio Switcher Pester tests passed."
