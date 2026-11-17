#Requires -Version 5.1
<#
.SYNOPSIS
  Install opencode-statuskit for OpenCode 2 on Windows.

.DESCRIPTION
  Copies the two TUI plugins into the OpenCode config directory and sets
  terminal.title to false when the title plugin is installed. Idempotent.
  No Node.js is required.

.PARAMETER WithoutTitle
  Install only the done plugin and leave terminal.title untouched.

.PARAMETER ConfigDir
  Override the OpenCode config directory. Defaults to OPENCODE_CONFIG_DIR,
  then XDG_CONFIG_HOME\opencode, then %USERPROFILE%\.config\opencode.

.PARAMETER DryRun
  Print the actions without changing any file.
#>
[CmdletBinding()]
param(
  [switch]$WithoutTitle,
  [string]$ConfigDir,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$KitDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $ConfigDir) {
  if ($env:OPENCODE_CONFIG_DIR) {
    $ConfigDir = $env:OPENCODE_CONFIG_DIR
  } elseif ($env:XDG_CONFIG_HOME) {
    $ConfigDir = Join-Path $env:XDG_CONFIG_HOME "opencode"
  } else {
    $ConfigDir = Join-Path $env:USERPROFILE ".config\opencode"
  }
}
$ConfigDir = [System.IO.Path]::GetFullPath($ConfigDir)
$PluginDir = Join-Path $ConfigDir "plugins"
$LegacyDir = Join-Path $ConfigDir "tui-plugins"
$CliJson = Join-Path $ConfigDir "cli.json"
$TuiJson = Join-Path $ConfigDir "tui.json"
$StaleEntries = @("./tui-plugins/status-title.js", "./tui-plugins/status-done.tsx")

function Write-JsonFile {
  param([string]$Path, $Object)
  $json = $Object | ConvertTo-Json -Depth 100
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $json + "`n", $utf8)
}

function Read-JsonFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $raw = Get-Content -LiteralPath $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  # PowerShell 7's ConvertFrom-Json accepts comments and trailing commas.
  # The installer intentionally supports strict JSON only, so validate with
  # System.Text.Json before parsing. Windows PowerShell 5.1 rejects JSONC itself.
  if ($PSVersionTable.PSVersion.Major -ge 6) {
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
    $options.AllowTrailingCommas = $false
    $document = [System.Text.Json.JsonDocument]::Parse($raw, $options)
    $document.Dispose()
  }
  return ($raw | ConvertFrom-Json -ErrorAction Stop)
}

function Update-CliJson {
  param([bool]$WriteTitle)
  $cfg = $null
  if (Test-Path -LiteralPath $CliJson) {
    try {
      $cfg = Read-JsonFile $CliJson
    } catch {
      Write-Warning "cli.json is not strict JSON (comments/trailing commas detected). Edit manually:"
      if ($WriteTitle) {
        Write-Warning '  set terminal.title to false (keep other terminal keys)'
        Write-Warning '  remove legacy "./tui-plugins/status-*.js(x)" entries'
      }
      Write-Warning "  plugins are already copied to $PluginDir"
      return $false
    }
  }
  if ($null -eq $cfg) {
    $cfg = [pscustomobject]@{}
  }

  if ($WriteTitle) {
    $terminalProperty = $cfg.PSObject.Properties["terminal"]
    if ($null -eq $terminalProperty -or $null -eq $terminalProperty.Value -or $terminalProperty.Value -isnot [pscustomobject]) {
      $terminal = [pscustomobject]@{}
      if ($null -eq $terminalProperty) {
        $cfg | Add-Member -NotePropertyName "terminal" -NotePropertyValue $terminal
      } else {
        $terminalProperty.Value = $terminal
      }
    } else {
      $terminal = $terminalProperty.Value
    }
    if ($null -eq $terminal.PSObject.Properties["title"]) {
      $terminal | Add-Member -NotePropertyName "title" -NotePropertyValue $false
    } else {
      $terminal.title = $false
    }
  }

  $pluginsProperty = $cfg.PSObject.Properties["plugins"]
  if ($null -ne $pluginsProperty) {
    $items = @($pluginsProperty.Value)
    $next = @($items | Where-Object { $StaleEntries -notcontains $_ })
    if ($next.Count -ne $items.Count) {
      if ($next.Count -eq 0) {
        $cfg.PSObject.Properties.Remove("plugins")
      } else {
        $pluginsProperty.Value = $next
      }
    }
  }

  if ($null -eq $cfg.PSObject.Properties['$schema']) {
    $cfg | Add-Member -NotePropertyName '$schema' -NotePropertyValue "https://opencode.ai/v2/cli.json"
  }
  Write-JsonFile -Path $CliJson -Object $cfg
  return $true
}

function Remove-StaleEntries {
  param([string]$Path, [string]$Key)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  try {
    $cfg = Read-JsonFile $Path
  } catch {
    Write-Warning "not strict JSON; remove legacy entries manually: $Path"
    return
  }
  if ($null -eq $cfg) { return }
  $property = $cfg.PSObject.Properties[$Key]
  if ($null -eq $property) { return }
  $items = @($property.Value)
  $next = @($items | Where-Object { $StaleEntries -notcontains $_ })
  if ($next.Count -eq $items.Count) { return }
  if ($next.Count -eq 0) {
    $cfg.PSObject.Properties.Remove($Key)
  } else {
    $property.Value = $next
  }
  Write-JsonFile -Path $Path -Object $cfg
}

Write-Host "==> config dir: $ConfigDir"
if ($DryRun) {
  Write-Host "    would copy: status-done\tui.tsx"
  if (-not $WithoutTitle) {
    Write-Host "    would copy: status-title\tui.ts"
    Write-Host "    would set terminal.title=false in $CliJson"
  }
  exit 0
}

New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null

Write-Host "==> copying plugins"
$doneSource = Join-Path $KitDir "plugins\v2\status-done\tui.tsx"
$doneTargetDir = Join-Path $PluginDir "status-done"
New-Item -ItemType Directory -Force -Path $doneTargetDir | Out-Null
Copy-Item -LiteralPath $doneSource -Destination (Join-Path $doneTargetDir "tui.tsx") -Force

if (-not $WithoutTitle) {
  $titleSource = Join-Path $KitDir "plugins\v2\status-title\tui.ts"
  $titleTargetDir = Join-Path $PluginDir "status-title"
  New-Item -ItemType Directory -Force -Path $titleTargetDir | Out-Null
  Copy-Item -LiteralPath $titleSource -Destination (Join-Path $titleTargetDir "tui.ts") -Force
}

Write-Host "==> removing legacy v1 files"
foreach ($name in @("status-title.js", "status-done.tsx")) {
  $path = Join-Path $LegacyDir $name
  if (Test-Path -LiteralPath $path) {
    $text = Get-Content -LiteralPath $path -Raw
    if ($text -match 'local\.status-(title|done)') {
      Remove-Item -LiteralPath $path -Force
      Write-Host "    removed legacy v1 plugin: $path"
    } else {
      Write-Host "    left unrecognized file alone: $path"
    }
  }
}
if (Test-Path -LiteralPath $LegacyDir) {
  $remaining = @(Get-ChildItem -LiteralPath $LegacyDir -Force)
  if ($remaining.Count -eq 0) {
    Remove-Item -LiteralPath $LegacyDir -Force
  }
}

Write-Host "==> updating cli.json"
$cliUpdated = Update-CliJson -WriteTitle (-not $WithoutTitle)

Write-Host "==> cleaning legacy tui.json entries"
Remove-StaleEntries -Path $TuiJson -Key "plugin"

Write-Host ""
Write-Host "done. notes:"
Write-Host "  - OpenCode 2 discovers plugins from $PluginDir\<name>\tui.ts(x)"
Write-Host "    and hot-reloads them; no restart or shell environment variables are needed."
if (-not $WithoutTitle) {
  if ($cliUpdated) {
    Write-Host '  - terminal.title=false was set so the built-in "OC | ..." writer'
    Write-Host "    does not overwrite the status title."
  } else {
    Write-Host "  - terminal.title was NOT changed. Set it manually to false."
  }
}
Write-Host "  - if cli.json contains comments and could not be updated, set"
Write-Host '    "terminal": { "title": false } manually.'
Write-Host "  - this installer does not modify shell profiles."
