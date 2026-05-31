function Get-RunnerSecret {
    param(
        [hashtable]$HostConfig,
        [string]$SecretName
    )

    if ([string]::IsNullOrWhiteSpace($SecretName)) {
        throw "Secret name is required."
    }

    if ($null -eq $HostConfig) {
        throw "Host config is required for runner secret resolution."
    }

    if (-not $HostConfig.ContainsKey("Vault") -or $null -eq $HostConfig.Vault) {
        throw "Host config must include a Vault block for runner secret resolution."
    }

    $vaultName = $HostConfig.Vault.Name
    if ([string]::IsNullOrWhiteSpace([string]$vaultName)) {
        throw "Host config Vault.Name is required for runner secret resolution."
    }

    $azPath = if ($HostConfig.Vault.ContainsKey("AzCliPath") -and -not [string]::IsNullOrWhiteSpace([string]$HostConfig.Vault.AzCliPath)) {
        $HostConfig.Vault.AzCliPath
    }
    else {
        "az"
    }
    $value = & $azPath keyvault secret show --vault-name $vaultName --name $SecretName --query value -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
        throw "Failed to read Vault secret '$SecretName'."
    }

    return $value
}

function Invoke-RunnerSecretSelfTest {
    $cases = @(
        @{ HostConfig = $null; SecretName = "secret"; Message = "Host config is required" },
        @{ HostConfig = @{}; SecretName = "secret"; Message = "must include a Vault block" },
        @{ HostConfig = @{ Vault = @{} }; SecretName = "secret"; Message = "Vault.Name is required" },
        @{ HostConfig = @{ Vault = @{ Name = "vault" } }; SecretName = ""; Message = "Secret name is required" }
    )

    foreach ($case in $cases) {
        try {
            [void](Get-RunnerSecret -HostConfig $case.HostConfig -SecretName $case.SecretName)
            throw "Expected Get-RunnerSecret to fail for invalid input."
        }
        catch {
            if ($_.Exception.Message -notmatch [regex]::Escape($case.Message)) {
                throw "Expected error containing '$($case.Message)', got '$($_.Exception.Message)'."
            }
        }
    }
}

Export-ModuleMember -Function Get-RunnerSecret, Invoke-RunnerSecretSelfTest
