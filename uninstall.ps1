#Requires -Version 5.1
<#
.SYNOPSIS
  Uninstall opencode-statuskit for OpenCode 2 on Windows.

.DESCRIPTION
  Removes the two plugin directories, legacy v1 files, and stale legacy
  plugin entries. It leaves terminal.title untouched, because the user may
  want to keep the built-in title disabled for another reason.

.PARAMETER ConfigDir
  Override the OpenCode config directory. Defaults to OPENCODE_CONFIG_DIR,
  then XDG_CONFIG_HOME\opencode, then %USERPROFILE%\.config\opencode.

.PARAMETER DryRun
  Print the actions without changing any file.
#>
[CmdletBinding()]
param(
  [string]$ConfigDir,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

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
  if ($PSVersionTable.PSVersion.Major -ge 6) {
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
    $options.AllowTrailingCommas = $false
    $document = [System.Text.Json.JsonDocument]::Parse($raw, $options)
    $document.Dispose()
  }
  return ($raw | ConvertFrom-Json -ErrorAction Stop)
}

function Remove-StaleEntries {
  param([string]$Path, [string[]]$Keys)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  try {
    $cfg = Read-JsonFile $Path
  } catch {
    Write-Warning "not strict JSON; remove legacy entries manually: $Path"
    return
  }
  if ($null -eq $cfg) { return }
  $changed = $false
  foreach ($key in $Keys) {
    $property = $cfg.PSObject.Properties[$key]
    if ($null -eq $property) { continue }
    $items = @($property.Value)
    $next = @($items | Where-Object { $StaleEntries -notcontains $_ })
    if ($next.Count -eq $items.Count) { continue }
    $changed = $true
    if ($next.Count -eq 0) {
      $cfg.PSObject.Properties.Remove($key)
    } else {
      $property.Value = $next
    }
  }
  if ($changed) {
    Write-JsonFile -Path $Path -Object $cfg
  }
}

Write-Host "==> config dir: $ConfigDir"
if ($DryRun) {
  Write-Host "    would remove: $PluginDir\status-title"
  Write-Host "    would remove: $PluginDir\status-done"
  Write-Host "    would remove legacy: $LegacyDir\status-title.js, status-done.tsx"
  Write-Host "    would clean legacy entries in $CliJson and $TuiJson"
  exit 0
}

Write-Host "==> removing plugin files"
foreach ($name in @("status-title", "status-done")) {
  $path = Join-Path $PluginDir $name
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Recurse -Force
  }
}
if (Test-Path -LiteralPath $PluginDir) {
  $remaining = @(Get-ChildItem -LiteralPath $PluginDir -Force)
  if ($remaining.Count -eq 0) {
    Remove-Item -LiteralPath $PluginDir -Force
  }
}

foreach ($name in @("status-title.js", "status-done.tsx")) {
  $path = Join-Path $LegacyDir $name
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Force
  }
}
if (Test-Path -LiteralPath $LegacyDir) {
  $remaining = @(Get-ChildItem -LiteralPath $LegacyDir -Force)
  if ($remaining.Count -eq 0) {
    Remove-Item -LiteralPath $LegacyDir -Force
  }
}

Write-Host "==> removing legacy v1 entries"
Remove-StaleEntries -Path $CliJson -Keys @("plugins", "plugin")
Remove-StaleEntries -Path $TuiJson -Keys @("plugin", "plugins")

Write-Host ""
Write-Host "done. cli.json was left otherwise untouched."
Write-Host "  - if terminal.title is still false and you want the built-in title"
Write-Host "    back, remove that line from cli.json."
