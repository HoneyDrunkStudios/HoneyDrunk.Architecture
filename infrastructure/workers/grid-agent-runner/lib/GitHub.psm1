Import-Module (Join-Path $PSScriptRoot "Secrets.psm1") -Force

function Get-GitHubInstallationToken {
    param(
        [hashtable]$HostConfig,
        [string[]]$RequiredSecretNames,
        [hashtable]$Logger
    )

    if (-not $HostConfig.ContainsKey("Vault")) {
        throw "Host config must include a Vault block for GitHub App token minting."
    }

    $expectedSecretNames = @(
        "GitHub--AgentRunner--AppId",
        "GitHub--AgentRunner--PrivateKey",
        "GitHub--AgentRunner--InstallationId"
    )
    foreach ($secretName in $expectedSecretNames) {
        if ($secretName -notin @($RequiredSecretNames)) {
            throw "RequiredSecretNames must include GitHub App secret '$secretName'."
        }

        Write-RunnerLog -Logger $Logger -Level "DEBUG" -Message "GitHub App secret required." -Data @{ secret_name = $secretName }
    }

    $secrets = @{}
    foreach ($secretName in $expectedSecretNames) {
        $secrets[$secretName] = Get-RunnerSecret -HostConfig $HostConfig -SecretName $secretName
    }

    $appId = $secrets["GitHub--AgentRunner--AppId"]
    $privateKeyPem = $secrets["GitHub--AgentRunner--PrivateKey"]
    $installationId = $secrets["GitHub--AgentRunner--InstallationId"]
    $jwt = New-GitHubAppJwt -AppId $appId -PrivateKeyPem $privateKeyPem

    $headers = @{
        Authorization = "Bearer $jwt"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    $uri = "https://api.github.com/app/installations/$installationId/access_tokens"
    $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers
    return $response.token
}

function New-GitHubAppJwt {
    param(
        [string]$AppId,
        [string]$PrivateKeyPem
    )

    $now = [DateTimeOffset]::UtcNow
    $header = @{ alg = "RS256"; typ = "JWT" } | ConvertTo-Json -Compress
    $payload = @{
        iat = [int]$now.AddSeconds(-30).ToUnixTimeSeconds()
        exp = [int]$now.AddMinutes(9).ToUnixTimeSeconds()
        iss = $AppId
    } | ConvertTo-Json -Compress

    $encodedHeader = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($header))
    $encodedPayload = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes($payload))
    $unsigned = "$encodedHeader.$encodedPayload"

    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.ImportFromPem($PrivateKeyPem)
    $signature = $rsa.SignData([System.Text.Encoding]::UTF8.GetBytes($unsigned), [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    return "$unsigned.$(ConvertTo-Base64Url $signature)"
}

function ConvertTo-Base64Url {
    param([byte[]]$Bytes)

    return [Convert]::ToBase64String($Bytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

function Invoke-GitHubApi {
    param(
        [string]$Method = "GET",
        [string]$Uri,
        [string]$Token,
        [object]$Body = $null
    )

    $headers = @{
        Authorization = "Bearer $Token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
    }

    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 20) -ContentType "application/json"
}

Export-ModuleMember -Function Get-GitHubInstallationToken, Invoke-GitHubApi
