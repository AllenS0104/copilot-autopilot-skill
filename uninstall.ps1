#requires -Version 5.1
<#
.SYNOPSIS
    Remove the Copilot CLI autopilot wrapper block from both PowerShell profiles.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$beginMarker = '# >>> copilot-autopilot-default >>>'
$endMarker   = '# <<< copilot-autopilot-default <<<'
$pattern = [regex]::Escape($beginMarker) + '.*?' + [regex]::Escape($endMarker)

$docs = [Environment]::GetFolderPath('MyDocuments')
$targets = @(
    (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)

foreach ($profilePath in $targets) {
    if (-not (Test-Path $profilePath)) { continue }
    $existing = Get-Content -LiteralPath $profilePath -Raw
    if ([regex]::IsMatch($existing, $pattern, 'Singleline')) {
        $updated = [regex]::Replace($existing, $pattern, '', 'Singleline').Trim()
        Set-Content -LiteralPath $profilePath -Value ($updated + "`r`n") -Encoding UTF8
        Write-Host "Removed block from $profilePath" -ForegroundColor Yellow
    }
    else {
        Write-Host "No block found in $profilePath" -ForegroundColor DarkGray
    }
}

Write-Host "`nDone. The ~/.copilot-autopilot/ folder (logs, forged tools) was left intact." -ForegroundColor Cyan
