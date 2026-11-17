#Requires -Version 5.1
# Installer acceptance test for Windows PowerShell 5.1 and PowerShell 7.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$InstallScript = Join-Path $Root "install.ps1"
$UninstallScript = Join-Path $Root "uninstall.ps1"
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("statuskit-installer-" + [guid]::NewGuid().ToString("N"))

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "FAIL: $Message" }
}

function Read-Json {
  param([string]$Path)
  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Write-Json {
  param([string]$Path, $Object)
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, (($Object | ConvertTo-Json -Depth 100) + "`n"), $utf8)
}

try {
  New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

  # 1. Fresh install preserves unrelated keys and removes stale entries.
  $cfg1 = Join-Path $Tmp "c1\opencode"
  New-Item -ItemType Directory -Force -Path $cfg1 | Out-Null
  $cli1 = Join-Path $cfg1 "cli.json"
  Write-Json -Path $cli1 -Object ([pscustomobject]@{
    '$schema' = "https://opencode.ai/v2/cli.json"
    terminal = [pscustomobject]@{ title = $true; theme = "dark" }
    keybinds = [pscustomobject]@{ leader = "ctrl+x" }
    plugins = @("./tui-plugins/status-title.js", "keep-me")
  })

  & $InstallScript -ConfigDir $cfg1 3>$null | Out-Null
  Assert-True (Test-Path -LiteralPath (Join-Path $cfg1 "plugins\status-title\tui.ts")) "title plugin missing"
  Assert-True (Test-Path -LiteralPath (Join-Path $cfg1 "plugins\status-done\tui.tsx")) "done plugin missing"
  $json1 = Read-Json $cli1
  Assert-True ($json1.terminal.title -eq $false) "terminal.title was not false"
  Assert-True ($json1.terminal.theme -eq "dark") "terminal.theme was lost"
  Assert-True ($json1.keybinds.leader -eq "ctrl+x") "keybinds were lost"
  Assert-True (($json1.plugins -join ",") -eq "keep-me") "stale plugin entry was not removed"

  # 2. Idempotent rerun.
  & $InstallScript -ConfigDir $cfg1 3>$null | Out-Null
  Assert-True (Test-Path -LiteralPath (Join-Path $cfg1 "plugins\status-title\tui.ts")) "idempotent rerun lost the title plugin"

  # 3. Legacy files and tui.json entries are removed.
  $cfg2 = Join-Path $Tmp "c2\opencode"
  $legacy = Join-Path $cfg2 "tui-plugins"
  New-Item -ItemType Directory -Force -Path $legacy | Out-Null
  Set-Content -LiteralPath (Join-Path $legacy "status-title.js") -Value 'const x = "local.status-title"'
  Set-Content -LiteralPath (Join-Path $legacy "status-done.tsx") -Value 'const x = "local.status-done"'
  Write-Json -Path (Join-Path $cfg2 "tui.json") -Object ([pscustomobject]@{
    plugin = @("./tui-plugins/status-title.js", "keep-this")
  })
  & $InstallScript -ConfigDir $cfg2 3>$null | Out-Null
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $legacy "status-title.js"))) "legacy title file was not removed"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $legacy "status-done.tsx"))) "legacy done file was not removed"
  $tui2 = Read-Json (Join-Path $cfg2 "tui.json")
  Assert-True (($tui2.plugin -join ",") -eq "keep-this") "tui.json stale entry was not removed"

  # 4. -WithoutTitle copies only done and leaves terminal.title alone.
  $cfg3 = Join-Path $Tmp "c3\opencode"
  New-Item -ItemType Directory -Force -Path $cfg3 | Out-Null
  Write-Json -Path (Join-Path $cfg3 "cli.json") -Object ([pscustomobject]@{
    terminal = [pscustomobject]@{ title = $true }
  })
  & $InstallScript -ConfigDir $cfg3 -WithoutTitle 3>$null | Out-Null
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $cfg3 "plugins\status-title\tui.ts"))) "title plugin should not be installed with -WithoutTitle"
  Assert-True (Test-Path -LiteralPath (Join-Path $cfg3 "plugins\status-done\tui.tsx")) "done plugin missing with -WithoutTitle"
  Assert-True ((Read-Json (Join-Path $cfg3 "cli.json")).terminal.title -eq $true) "-WithoutTitle changed terminal.title"

  # 5. JSONC prints manual instructions and still copies the plugins.
  $cfg4 = Join-Path $Tmp "c4\opencode"
  New-Item -ItemType Directory -Force -Path $cfg4 | Out-Null
  $jsonc = Join-Path $cfg4 "cli.json"
  Set-Content -LiteralPath $jsonc -Value "{`n  // comment`n  `"terminal`": { `"title`": true }`n}"
  $warnings = & $InstallScript -ConfigDir $cfg4 3>&1 4>&1 5>&1 6>&1 | Out-String
  Assert-True (Test-Path -LiteralPath (Join-Path $cfg4 "plugins\status-title\tui.ts")) "JSONC install did not copy the title plugin"
  Assert-True (Test-Path -LiteralPath (Join-Path $cfg4 "plugins\status-done\tui.tsx")) "JSONC install did not copy the done plugin"
  Assert-True ($warnings -match "not strict JSON") "JSONC warning missing"
  Assert-True ((Get-Content -LiteralPath $jsonc -Raw) -match "// comment") "JSONC file was changed"

  # 6. Uninstall removes plugin directories and leaves cli.json otherwise intact.
  & $UninstallScript -ConfigDir $cfg1 3>$null | Out-Null
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $cfg1 "plugins\status-title\tui.ts"))) "uninstall left the title plugin"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $cfg1 "plugins\status-done\tui.tsx"))) "uninstall left the done plugin"
  $json1 = Read-Json $cli1
  Assert-True ($json1.terminal.title -eq $false) "uninstall changed terminal.title"
  Assert-True ($json1.terminal.theme -eq "dark") "uninstall lost terminal.theme"
  Assert-True ($json1.keybinds.leader -eq "ctrl+x") "uninstall lost keybinds"
  Assert-True (($json1.plugins -join ",") -eq "keep-me") "uninstall lost unrelated plugin entry"

  Write-Host "PowerShell installer tests: ok"
} finally {
  if (Test-Path -LiteralPath $Tmp) {
    Remove-Item -LiteralPath $Tmp -Recurse -Force
  }
}
