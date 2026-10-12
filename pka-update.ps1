param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Check', 'Install')]
    [string]$Mode,
    [Parameter(Mandatory = $true)]
    [string]$Repository,
    [Parameter(Mandatory = $true)]
    [string]$ResultFile,
    [string]$CurrentVersion,
    [string]$DownloadUrl,
    [string]$ExpectedSha256,
    [string]$Target,
    [int]$OldPid
)

$ErrorActionPreference = 'Stop'
$assetName = 'PKA-Busca-Instancias.exe'
$utf8 = New-Object System.Text.UTF8Encoding $false
$ready = $false

function Write-Result([string]$value) {
    $temporary = "$ResultFile.tmp"
    [System.IO.File]::WriteAllText($temporary, $value, $utf8)
    Move-Item -LiteralPath $temporary -Destination $ResultFile -Force
}

function Show-UpdateError([string]$message) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        'PKA - Atualizacao',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

try {
    if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw 'Repositorio GitHub invalido.'
    }

    if ($Mode -eq 'Check') {
        $headers = @{
            'Accept' = 'application/vnd.github+json'
            'User-Agent' = 'PKA-Busca-Instancias-Updater'
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" `
            -Headers $headers -TimeoutSec 8
        $versionText = ([string]$release.tag_name).TrimStart('v', 'V')
        $latest = [version]$versionText
        $current = [version]$CurrentVersion
        if ($latest -le $current) {
            Write-Result "CURRENT`t$versionText"
            exit 0
        }

        $asset = @($release.assets | Where-Object { $_.name -eq $assetName }) | Select-Object -First 1
        if (-not $asset) { throw "Release sem $assetName." }
        $expectedUrl = "https://github.com/$Repository/releases/download/"
        $url = [string]$asset.browser_download_url
        if (-not $url.StartsWith($expectedUrl, [StringComparison]::OrdinalIgnoreCase) -or
            -not $url.EndsWith("/$assetName", [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Endereco do executavel nao corresponde ao repositorio.'
        }
        $digest = [string]$asset.digest
        if ($digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
            throw 'Release sem verificacao SHA-256 valida.'
        }
        Write-Result "UPDATE`t$versionText`t$url`t$($digest.Substring(7).ToLowerInvariant())"
        exit 0
    }

    if (-not $Target -or -not $OldPid -or
        $ExpectedSha256 -notmatch '^[a-fA-F0-9]{64}$') {
        throw 'Parametros de instalacao invalidos.'
    }
    $expectedUrl = "https://github.com/$Repository/releases/download/"
    if (-not $DownloadUrl.StartsWith($expectedUrl, [StringComparison]::OrdinalIgnoreCase) -or
        -not $DownloadUrl.EndsWith("/$assetName", [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Endereco de download inesperado.'
    }
    if ([System.IO.Path]::GetFileName($Target) -notmatch '\.exe$') {
        throw 'O destino nao e um executavel.'
    }

    $staged = Join-Path $env:TEMP ("PKA-Update-$OldPid.exe")
    if (Test-Path -LiteralPath $staged) { Remove-Item -LiteralPath $staged -Force }
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $staged -UseBasicParsing -TimeoutSec 90
    $actual = (Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash
    if ($actual -ne $ExpectedSha256) { throw 'O arquivo baixado falhou na verificacao SHA-256.' }
    Write-Result 'READY'
    $ready = $true

    try { Wait-Process -Id $OldPid -Timeout 45 -ErrorAction Stop }
    catch {
        if (Get-Process -Id $OldPid -ErrorAction SilentlyContinue) {
            throw 'O programa antigo nao fechou a tempo.'
        }
    }

    $backup = "$Target.bak"
    Copy-Item -LiteralPath $Target -Destination $backup -Force
    try {
        Copy-Item -LiteralPath $staged -Destination $Target -Force
        Start-Process -FilePath $Target -WindowStyle Normal
    } catch {
        Copy-Item -LiteralPath $backup -Destination $Target -Force
        throw
    } finally {
        if (Test-Path -LiteralPath $staged) { Remove-Item -LiteralPath $staged -Force }
    }
} catch {
    $message = $_.Exception.Message -replace "[`r`n`t]", ' '
    try { Write-Result "ERROR`t$message" } catch {}
    if ($Mode -eq 'Install' -and $ready) { Show-UpdateError $message }
    exit 1
}
