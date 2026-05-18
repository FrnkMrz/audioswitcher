$ErrorActionPreference = "Stop"

$testsPath = Join-Path $PSScriptRoot "AudioSwitcher.Tests.ps1"
if (-not (Test-Path -LiteralPath $testsPath)) {
    throw "Pester test file not found: $testsPath"
}

$invokePester = Get-Command Invoke-Pester -ErrorAction SilentlyContinue
if ($null -eq $invokePester) {
    throw "Pester is required to run tests. Install Pester and retry."
}

if ($invokePester.Parameters.ContainsKey("Configuration")) {
    $pesterConfiguration = New-PesterConfiguration
    $pesterConfiguration.Run.Path = $testsPath
    $pesterConfiguration.Run.PassThru = $true
    $pesterConfiguration.Output.Verbosity = "Detailed"

    if ($env:GITHUB_ACTIONS -eq "true" -and $pesterConfiguration.Output.PSObject.Properties.Name -contains "CIFormat") {
        $pesterConfiguration.Output.CIFormat = "GithubActions"
    }

    $result = Invoke-Pester -Configuration $pesterConfiguration
}
elseif ($invokePester.Parameters.ContainsKey("Path")) {
    $result = Invoke-Pester -Path $testsPath -PassThru
}
elseif ($invokePester.Parameters.ContainsKey("Script")) {
    $result = Invoke-Pester -Script $testsPath -PassThru
}
else {
    $result = Invoke-Pester $testsPath -PassThru
}

if ($null -ne $result -and $result.FailedCount -gt 0) {
    if ($result.PSObject.Properties.Name -contains "Failed" -and $result.Failed) {
        Write-Host "Failed Pester tests:"
        foreach ($failure in $result.Failed) {
            $failureName = if ($failure.ExpandedPath) { $failure.ExpandedPath } elseif ($failure.Name) { $failure.Name } else { "<unknown>" }
            $failureMessage = if ($failure.ErrorRecord -and $failure.ErrorRecord.Exception) {
                $failure.ErrorRecord.Exception.Message
            }
            elseif ($failure.ErrorRecord) {
                [string]$failure.ErrorRecord
            }
            elseif ($failure.FailureMessage) {
                $failure.FailureMessage
            }
            else {
                "<no failure message>"
            }

            Write-Host (" - {0}: {1}" -f $failureName, $failureMessage)
        }
    }

    throw ("Pester tests failed: {0}" -f $result.FailedCount)
}

Write-Host "Audio Switcher Pester tests passed."
