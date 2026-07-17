#requires -Version 5.1
<#
.SYNOPSIS
    Remove the Copilot CLI autopilot wrapper block from both PowerShell profiles.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$patterns = @(
    ([regex]::Escape('# >>> copilot-autopilot-default >>>') + '.*?' + [regex]::Escape('# <<< copilot-autopilot-default <<<')),
    ([regex]::Escape('# >>> copilot-autopilot-editors >>>') + '.*?' + [regex]::Escape('# <<< copilot-autopilot-editors <<<'))
)

$docs = [Environment]::GetFolderPath('MyDocuments')
$targets = @(
    (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)

foreach ($profilePath in $targets) {
    if (-not (Test-Path $profilePath)) { continue }
    $existing = Get-Content -LiteralPath $profilePath -Raw
    $found = $false
    foreach ($pattern in $patterns) {
        if ([regex]::IsMatch($existing, $pattern, 'Singleline')) {
            $existing = [regex]::Replace($existing, $pattern, '', 'Singleline')
            $found = $true
        }
    }
    if ($found) {
        Set-Content -LiteralPath $profilePath -Value ($existing.Trim() + "`r`n") -Encoding UTF8
        Write-Host "Removed autopilot blocks from $profilePath" -ForegroundColor Yellow
    }
    else {
        Write-Host "No block found in $profilePath" -ForegroundColor DarkGray
    }
}

Write-Host "`nDone. The ~/.copilot-autopilot/ folder (logs, forged tools) was left intact." -ForegroundColor Cyan
