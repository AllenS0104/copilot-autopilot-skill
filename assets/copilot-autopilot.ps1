# >>> copilot-autopilot-default >>>
# Make the GitHub Copilot CLI start in autopilot mode by default, so shell/tool
# commands run automatically without stopping for a "Do you want to run this
# command?" confirmation each time.
#
# Note: the CLI has no "5s countdown then Yes" feature; autopilot is the native
# mechanism that auto-approves and keeps going. Injection is skipped for
# subcommands, help/version, and when a mode or prompt is already specified.
#
# Enhancements:
#   1. Escape valve   -> `copilot --no-auto ...` or env COPILOT_NO_AUTOPILOT=1
#                        temporarily disables autopilot injection.
#   2. Profile sync   -> this identical block lives in both the PowerShell 7
#                        and Windows PowerShell 5.1 profiles.
#   3. Execution log  -> every invocation is timestamped to autopilot.log.
#   4. Tool forge     -> a self-created tools dir is put on PATH, and
#                        New-AutopilotTool lets autopilot invent a missing tool
#                        on the fly when web search yields no ready solution.

# --- Shared autopilot home (same for both PowerShell editions) -----------------
$script:CopilotAutopilotHome = Join-Path $env:USERPROFILE '.copilot-autopilot'
$script:CopilotToolsBin      = Join-Path $script:CopilotAutopilotHome 'tools'
$script:CopilotLog           = Join-Path $script:CopilotAutopilotHome 'autopilot.log'
$script:CopilotManifest      = Join-Path $script:CopilotToolsBin 'manifest.json'

if (-not (Test-Path $script:CopilotToolsBin)) {
    New-Item -ItemType Directory -Path $script:CopilotToolsBin -Force | Out-Null
}

# Put self-created tools on PATH so a bare `toolname` resolves in any shell.
if ($env:PATH -notlike "*$script:CopilotToolsBin*") {
    $env:PATH = "$script:CopilotToolsBin;$env:PATH"
}

function Write-CopilotAutopilotLog {
    param([Parameter(Mandatory)][string]$Message)
    try {
        $line = ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
        Add-Content -LiteralPath $script:CopilotLog -Value $line -Encoding UTF8
    }
    catch { }  # never let logging break the command
}

# Manifest helpers: always read/write a JSON array, robust to 0/1 entries.
function Read-CopilotToolManifest {
    if (-not (Test-Path $script:CopilotManifest)) { return @() }
    $raw = Get-Content -LiteralPath $script:CopilotManifest -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    try { return @($raw | ConvertFrom-Json) } catch { return @() }
}

function Write-CopilotToolManifest {
    param([object[]]$Tools)
    $Tools = @($Tools)
    $json = if ($Tools.Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject $Tools -Depth 5 }
    Set-Content -LiteralPath $script:CopilotManifest -Value $json -Encoding UTF8
}

function copilot {
    $shim = Join-Path $env:APPDATA 'npm\copilot.cmd'
    $skip = @(
        'billing', 'commands', 'config', 'permissions', 'providers', 'help',
        '--autopilot', '--plan', '--mode', '--interactive', '-i',
        '-p', '--prompt', '--acp', '--help', '-h', '--version', '-V',
        '--yolo', '--allow-all'
    )

    # Enhancement 1: escape valve. Strip our own --no-auto flag before forwarding.
    $forwarded = @()
    $forceNoAuto = $false
    foreach ($a in $args) {
        if ($a -eq '--no-auto') { $forceNoAuto = $true; continue }
        $forwarded += $a
    }

    $inject = $true
    if ($forceNoAuto) {
        $inject = $false
    }
    elseif ($env:COPILOT_NO_AUTOPILOT -and $env:COPILOT_NO_AUTOPILOT -notin @('0', 'false', 'False')) {
        $inject = $false
    }
    else {
        foreach ($a in $forwarded) {
            if ($skip -contains $a) { $inject = $false; break }
        }
    }

    if ($inject) {
        Write-CopilotAutopilotLog ("autopilot | copilot {0}" -f ($forwarded -join ' '))
        & $shim --autopilot @forwarded
    }
    else {
        Write-CopilotAutopilotLog ("manual    | copilot {0}" -f ($forwarded -join ' '))
        & $shim @forwarded
    }
}

# --- Enhancement 4: the tool forge --------------------------------------------
# During autopilot, when a required tool is missing and neither the package
# managers nor a web search yield a usable one, autopilot can synthesize a
# purpose-built tool with New-AutopilotTool. The tool lands in $CopilotToolsBin
# (already on PATH) with a .cmd launcher, so it is immediately callable by name.
function New-AutopilotTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Mandatory, Position = 1)][string]$Body,
        [ValidateSet('powershell', 'python', 'batch')][string]$Language = 'powershell',
        [string]$Description = '',
        [switch]$Force
    )

    if ($Name -notmatch '^[A-Za-z0-9._-]+$') {
        throw "Tool name '$Name' is invalid. Use letters, digits, dot, dash or underscore."
    }
    if (-not (Test-Path $script:CopilotToolsBin)) {
        New-Item -ItemType Directory -Path $script:CopilotToolsBin -Force | Out-Null
    }

    $launcher = Join-Path $script:CopilotToolsBin ($Name + '.cmd')
    if ((Test-Path $launcher) -and -not $Force) {
        throw "Tool '$Name' already exists. Pass -Force to overwrite."
    }

    switch ($Language) {
        'powershell' {
            $src = Join-Path $script:CopilotToolsBin ($Name + '.ps1')
            Set-Content -LiteralPath $src -Value $Body -Encoding UTF8
            $cmd = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0$Name.ps1`" %*"
            Set-Content -LiteralPath $launcher -Value $cmd -Encoding ASCII
        }
        'python' {
            $src = Join-Path $script:CopilotToolsBin ($Name + '.py')
            Set-Content -LiteralPath $src -Value $Body -Encoding UTF8
            $cmd = "@echo off`r`npython `"%~dp0$Name.py`" %*"
            Set-Content -LiteralPath $launcher -Value $cmd -Encoding ASCII
        }
        'batch' {
            $src = $launcher
            $content = $Body
            if ($content -notmatch '(?im)^\s*@echo') { $content = "@echo off`r`n" + $content }
            Set-Content -LiteralPath $launcher -Value $content -Encoding ASCII
        }
    }

    # Record in a manifest for discoverability.
    $tools = @(Read-CopilotToolManifest | Where-Object { $_.name -ne $Name })
    $tools += [pscustomobject]@{
        name        = $Name
        language    = $Language
        description = $Description
        launcher    = $launcher
        created     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
    Write-CopilotToolManifest -Tools $tools

    Write-CopilotAutopilotLog ("forge     | created tool '{0}' ({1}) - {2}" -f $Name, $Language, $Description)
    Write-Host "Forged tool '$Name' ($Language) -> $launcher" -ForegroundColor Green
    return $launcher
}

function Get-AutopilotTool {
    [CmdletBinding()]
    param([string]$Name)
    $tools = Read-CopilotToolManifest
    if ($Name) { $tools = @($tools | Where-Object { $_.name -like $Name }) }
    return $tools
}

function Remove-AutopilotTool {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Name)
    Get-ChildItem -LiteralPath $script:CopilotToolsBin -Filter ($Name + '.*') -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'manifest.json' } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    $tools = @(Read-CopilotToolManifest | Where-Object { $_.name -ne $Name })
    Write-CopilotToolManifest -Tools $tools
    Write-CopilotAutopilotLog ("forge     | removed tool '{0}'" -f $Name)
}
# <<< copilot-autopilot-default <<<
