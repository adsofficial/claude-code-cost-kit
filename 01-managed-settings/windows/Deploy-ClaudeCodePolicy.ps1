<#
.SYNOPSIS
  Installs the Claude Code managed settings (company policy) on a Windows machine.

.DESCRIPTION
  Copies managed-settings.json to C:\Program Files\ClaudeCode\ (the path Claude Code
  reads on Windows). Run as Administrator / SYSTEM, for example as an Intune
  platform script or a Group Policy startup script.

  Developers cannot override these settings. To check on a machine afterwards, open
  Claude Code and run /status: the "Setting sources" line should show
  "Enterprise managed settings (file)".

.PARAMETER SourcePath
  Path to the managed-settings.json to deploy. Defaults to the file next to this script
  (..\managed-settings.json).

.EXAMPLE
  powershell.exe -ExecutionPolicy Bypass -File .\Deploy-ClaudeCodePolicy.ps1
#>
[CmdletBinding()]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\managed-settings.json')
)

$ErrorActionPreference = 'Stop'
$TargetDir  = 'C:\Program Files\ClaudeCode'
$TargetFile = Join-Path $TargetDir 'managed-settings.json'

# 1. Must run elevated: Program Files is admin-only, which is what stops developers editing it.
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script as Administrator (or SYSTEM via Intune / GPO).'
}

# 2. Validate JSON first. A managed file that is not valid JSON stops Claude Code from starting.
if (-not (Test-Path $SourcePath)) { throw "Policy file not found: $SourcePath" }
$json = Get-Content -Raw -Path $SourcePath
try { $null = $json | ConvertFrom-Json } catch { throw "managed-settings.json is not valid JSON: $($_.Exception.Message)" }

# 3. Copy into place (UTF-8 without BOM).
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
[System.IO.File]::WriteAllText($TargetFile, $json, (New-Object System.Text.UTF8Encoding($false)))

# 4. Remove the legacy path, which Claude Code no longer reads, so nobody edits the wrong file.
$legacy = 'C:\ProgramData\ClaudeCode\managed-settings.json'
if (Test-Path $legacy) { Remove-Item $legacy -Force }

Write-Output "Claude Code policy installed at $TargetFile"
exit 0
