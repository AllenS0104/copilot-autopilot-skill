#requires -Version 5.1
<#
.SYNOPSIS
    Install/update the Copilot CLI autopilot wrapper into both PowerShell profiles.
.DESCRIPTION
    Idempotently inserts the marker-delimited block from
    assets/copilot-autopilot.ps1 into the PowerShell 7 and Windows PowerShell 5.1
    profiles. If the block already exists (between the markers) it is replaced;
    otherwise it is appended.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$beginMarker = '# >>> copilot-autopilot-default >>>'
$endMarker   = '# <<< copilot-autopilot-default <<<'

$assetPath = Join-Path $PSScriptRoot 'assets\copilot-autopilot.ps1'
if (-not (Test-Path $assetPath)) {
    throw "Missing asset: $assetPath"
}
$block = (Get-Content -LiteralPath $assetPath -Raw).TrimEnd()

# Both profile locations under Documents (works whether or not the profile exists yet).
$docs = [Environment]::GetFolderPath('MyDocuments')
$targets = @(
    (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)

foreach ($profilePath in $targets) {
    $dir = Split-Path -Parent $profilePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $existing = if (Test-Path $profilePath) { Get-Content -LiteralPath $profilePath -Raw } else { '' }

    $pattern = [regex]::Escape($beginMarker) + '.*?' + [regex]::Escape($endMarker)
    if ([regex]::IsMatch($existing, $pattern, 'Singleline')) {
        # Use a script-block replacement so backslashes/`$` in the block are treated literally.
        $updated = [regex]::Replace($existing, $pattern, { param($m) $block }, 'Singleline')
        Write-Host "Updated existing block in $profilePath" -ForegroundColor Yellow
    }
    else {
        $sep = if ([string]::IsNullOrWhiteSpace($existing)) { '' } else { "`r`n`r`n" }
        $updated = $existing.TrimEnd() + $sep + $block + "`r`n"
        Write-Host "Appended block to $profilePath" -ForegroundColor Green
    }

    Set-Content -LiteralPath $profilePath -Value $updated -Encoding UTF8
}

Write-Host "`nDone. Reload with:  . `$PROFILE" -ForegroundColor Cyan
