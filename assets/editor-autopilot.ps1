# >>> copilot-autopilot-editors >>>
# Extend "autopilot" (auto-approve agent actions by default) from the Copilot
# CLI to GUI agentic editors: VS Code, VS Code Insiders, VSCodium, plus the
# VS Code forks Antigravity (Google), Cursor and Windsurf.
#
# GUI editors are configured through their User settings.json, not a shell
# profile, so this block adds helper functions instead of a wrapper:
#   Set-EditorAutopilot   -> merge auto-approve settings into detected editors.
#   Get-EditorAutopilot   -> show the current autopilot-related settings.
#   Reset-EditorAutopilot -> remove the keys this tool added (restores prompts).
#
# VS Code + Copilot Chat is fully driven by verified settings keys, so it is
# automated end to end. The forks (Antigravity/Cursor/Windsurf) gate full
# autonomy behind an in-app toggle that has no publicly documented JSON key, so
# this tool ensures their settings file exists and prints the exact in-app steps
# instead of writing unverified keys.

# Registry of known agentic editors: display name, User-data dir, agent flavor.
$script:CopilotEditorRegistry = @(
    [pscustomobject]@{ Name = 'VS Code';          Dir = 'Code';            Flavor = 'copilot' }
    [pscustomobject]@{ Name = 'VS Code Insiders'; Dir = 'Code - Insiders'; Flavor = 'copilot' }
    [pscustomobject]@{ Name = 'VSCodium';         Dir = 'VSCodium';        Flavor = 'copilot' }
    [pscustomobject]@{ Name = 'Cursor';           Dir = 'Cursor';          Flavor = 'cursor' }
    [pscustomobject]@{ Name = 'Windsurf';         Dir = 'Windsurf';        Flavor = 'windsurf' }
    [pscustomobject]@{ Name = 'Antigravity';      Dir = 'Antigravity';     Flavor = 'antigravity' }
)

# Resolve the platform-specific User/settings.json path for an editor data dir.
function Get-EditorSettingsPath {
    param([Parameter(Mandatory)][string]$Dir)
    if ($IsMacOS) {
        return Join-Path $HOME "Library/Application Support/$Dir/User/settings.json"
    }
    elseif ($IsLinux) {
        return Join-Path $HOME ".config/$Dir/User/settings.json"
    }
    else {
        return Join-Path $env:APPDATA "$Dir\User\settings.json"
    }
}

# Parse a JSONC settings.json (tolerates // and /* */ comments + trailing commas).
function ConvertFrom-EditorSettings {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return [ordered]@{} }
    $noBlock = [regex]::Replace($Raw, '/\*.*?\*/', '', 'Singleline')
    $noLine  = [regex]::Replace($noBlock, '(?m)^\s*//.*$', '')
    $noTrail = [regex]::Replace($noLine, ',(\s*[}\]])', '$1')
    try {
        $obj = $noTrail | ConvertFrom-Json -ErrorAction Stop
        $ordered = [ordered]@{}
        foreach ($p in $obj.PSObject.Properties) { $ordered[$p.Name] = $p.Value }
        return $ordered
    }
    catch { return $null }
}

# The verified VS Code / Copilot Chat autopilot settings.
function Get-CopilotAutopilotSettings {
    param([switch]$Aggressive)
    $settings = [ordered]@{
        'chat.agent.enabled'        = $true
        'chat.permissions.default'  = 'autopilot'
    }
    if ($Aggressive) {
        # Blanket auto-approve every tool + terminal command (mirrors the CLI's
        # "approve everything" behavior). Use only in trusted environments.
        $settings['chat.tools.autoApprove'] = $true
        $settings['chat.tools.terminal.autoApprove'] = @{ '/.*/' = $true }
    }
    return $settings
}

# Keys this tool manages, so Reset can cleanly remove them.
$script:CopilotEditorManagedKeys = @(
    'chat.agent.enabled', 'chat.permissions.default',
    'chat.tools.autoApprove', 'chat.tools.terminal.autoApprove'
)

function Set-EditorAutopilot {
    [CmdletBinding()]
    param(
        [string]$Editor = 'All',
        [switch]$Aggressive
    )

    $targets = $script:CopilotEditorRegistry
    if ($Editor -ne 'All') {
        $targets = $targets | Where-Object { $_.Name -like "*$Editor*" -or $_.Dir -like "*$Editor*" }
    }
    if (-not $targets) { Write-Warning "No known editor matched '$Editor'."; return }

    foreach ($ed in $targets) {
        $path = Get-EditorSettingsPath -Dir $ed.Dir
        $dir  = Split-Path -Parent $path
        $installed = Test-Path $dir
        if (-not $installed -and -not (Test-Path $path)) {
            Write-Host ("skip   {0,-16} (not installed)" -f $ed.Name) -ForegroundColor DarkGray
            continue
        }

        if ($ed.Flavor -ne 'copilot') {
            # Fork with a UI-gated autonomy toggle and no documented JSON key.
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            if (-not (Test-Path $path)) { Set-Content -LiteralPath $path -Value "{}" -Encoding UTF8 }
            Write-Host ("manual {0,-16} settings.json ready -> enable in-app autonomy:" -f $ed.Name) -ForegroundColor Yellow
            switch ($ed.Flavor) {
                'antigravity' {
                    Write-Host "         Settings > Agent > 'Terminal Command Auto Execution' = Turbo" -ForegroundColor Yellow
                    Write-Host "         (review the Allow/Deny lists; or use the CLI '/permissions')" -ForegroundColor DarkYellow
                }
                'cursor'   { Write-Host "         Agent panel > enable Auto-Run (YOLO) mode; edit the allowlist there" -ForegroundColor Yellow }
                'windsurf' { Write-Host "         Cascade panel > set autonomy to Turbo (auto-run commands)" -ForegroundColor Yellow }
            }
            Write-CopilotAutopilotLog ("editors   | {0}: ensured settings.json, printed manual autonomy steps" -f $ed.Name)
            continue
        }

        # Copilot family: merge verified keys into settings.json.
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $raw = if (Test-Path $path) { Get-Content -LiteralPath $path -Raw } else { '' }
        $current = ConvertFrom-EditorSettings -Raw $raw
        if ($null -eq $current) {
            Write-Warning ("{0}: settings.json is not parseable JSON; leaving it untouched. Edit it by hand." -f $ed.Name)
            continue
        }
        if (Test-Path $path) { Copy-Item -LiteralPath $path -Destination ($path + '.autopilot.bak') -Force }

        $apply = Get-CopilotAutopilotSettings -Aggressive:$Aggressive
        foreach ($k in $apply.Keys) { $current[$k] = $apply[$k] }

        $json = $current | ConvertTo-Json -Depth 8
        Set-Content -LiteralPath $path -Value $json -Encoding UTF8
        Write-Host ("ok     {0,-16} autopilot settings applied{1}" -f $ed.Name, $(if ($Aggressive) { ' (aggressive)' } else { '' })) -ForegroundColor Green
        Write-CopilotAutopilotLog ("editors   | {0}: applied autopilot settings{1}" -f $ed.Name, $(if ($Aggressive) { ' (aggressive)' } else { '' }))
    }
    Write-Host "`nReload each editor window (Developer: Reload Window) to pick up the changes." -ForegroundColor Cyan
}

function Get-EditorAutopilot {
    [CmdletBinding()]
    param([string]$Editor = 'All')
    $targets = $script:CopilotEditorRegistry
    if ($Editor -ne 'All') {
        $targets = $targets | Where-Object { $_.Name -like "*$Editor*" -or $_.Dir -like "*$Editor*" }
    }
    foreach ($ed in $targets) {
        $path = Get-EditorSettingsPath -Dir $ed.Dir
        if (-not (Test-Path $path)) { continue }
        $current = ConvertFrom-EditorSettings -Raw (Get-Content -LiteralPath $path -Raw)
        $view = [ordered]@{ Editor = $ed.Name; Flavor = $ed.Flavor; Path = $path }
        foreach ($k in $script:CopilotEditorManagedKeys) {
            if ($current -and $current.Contains($k)) { $view[$k] = $current[$k] }
        }
        [pscustomobject]$view
    }
}

function Reset-EditorAutopilot {
    [CmdletBinding()]
    param([string]$Editor = 'All')
    $targets = $script:CopilotEditorRegistry
    if ($Editor -ne 'All') {
        $targets = $targets | Where-Object { $_.Name -like "*$Editor*" -or $_.Dir -like "*$Editor*" }
    }
    foreach ($ed in $targets) {
        if ($ed.Flavor -ne 'copilot') { continue }
        $path = Get-EditorSettingsPath -Dir $ed.Dir
        if (-not (Test-Path $path)) { continue }
        $current = ConvertFrom-EditorSettings -Raw (Get-Content -LiteralPath $path -Raw)
        if ($null -eq $current) { Write-Warning "$($ed.Name): settings.json not parseable; skipping."; continue }
        $removed = $false
        foreach ($k in $script:CopilotEditorManagedKeys) {
            if ($current.Contains($k)) { $current.Remove($k); $removed = $true }
        }
        if ($removed) {
            Copy-Item -LiteralPath $path -Destination ($path + '.autopilot.bak') -Force
            Set-Content -LiteralPath $path -Value ($current | ConvertTo-Json -Depth 8) -Encoding UTF8
            Write-Host ("reset  {0,-16} autopilot keys removed" -f $ed.Name) -ForegroundColor Yellow
            Write-CopilotAutopilotLog ("editors   | {0}: reset autopilot settings" -f $ed.Name)
        }
    }
}
# <<< copilot-autopilot-editors <<<
