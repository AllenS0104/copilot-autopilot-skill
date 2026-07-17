#requires -Version 5.1
<#
.SYNOPSIS
    Install/update the Copilot CLI autopilot wrapper into both PowerShell profiles.
.DESCRIPTION
    Idempotently inserts the marker-delimited blocks from
    assets/copilot-autopilot.ps1 (the CLI wrapper) and
    assets/editor-autopilot.ps1 (the VS Code / Antigravity / fork configurator)
    into the PowerShell 7 and Windows PowerShell 5.1 profiles. If a block already
    exists (between its markers) it is replaced; otherwise it is appended.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Each asset ships its own marker-delimited block. Install them all.
$assets = @(
    [pscustomobject]@{ File = 'copilot-autopilot.ps1'; Begin = '# >>> copilot-autopilot-default >>>'; End = '# <<< copilot-autopilot-default <<<' }
    [pscustomobject]@{ File = 'editor-autopilot.ps1';  Begin = '# >>> copilot-autopilot-editors >>>'; End = '# <<< copilot-autopilot-editors <<<' }
)

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

    foreach ($asset in $assets) {
        $assetPath = Join-Path $PSScriptRoot ('assets\' + $asset.File)
        if (-not (Test-Path $assetPath)) { throw "Missing asset: $assetPath" }
        $block = (Get-Content -LiteralPath $assetPath -Raw).TrimEnd()

        $pattern = [regex]::Escape($asset.Begin) + '.*?' + [regex]::Escape($asset.End)
        if ([regex]::IsMatch($existing, $pattern, 'Singleline')) {
            # Script-block replacement so backslashes/`$` in the block stay literal.
            $existing = [regex]::Replace($existing, $pattern, { param($m) $block }, 'Singleline')
            Write-Host "Updated $($asset.File) block in $profilePath" -ForegroundColor Yellow
        }
        else {
            $sep = if ([string]::IsNullOrWhiteSpace($existing)) { '' } else { "`r`n`r`n" }
            $existing = $existing.TrimEnd() + $sep + $block + "`r`n"
            Write-Host "Appended $($asset.File) block to $profilePath" -ForegroundColor Green
        }
    }

    Set-Content -LiteralPath $profilePath -Value $existing -Encoding UTF8
}

Write-Host "`nDone. Reload with:  . `$PROFILE" -ForegroundColor Cyan
Write-Host "Then configure editors with:  Set-EditorAutopilot" -ForegroundColor Cyan
