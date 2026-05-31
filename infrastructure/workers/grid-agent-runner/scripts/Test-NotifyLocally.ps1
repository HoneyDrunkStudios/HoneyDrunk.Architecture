param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$runnerRoot = Split-Path -Parent $PSScriptRoot
$libRoot = Join-Path $runnerRoot "lib"

Import-Module (Join-Path $libRoot "Notify.psm1") -Force -Global
Import-Module (Join-Path $libRoot "Secrets.psm1") -Force -Global

Invoke-RunnerSecretSelfTest
Invoke-RunnerNotifySelfTest

Write-Host "Runner notification self-tests passed."
