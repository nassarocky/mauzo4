# Build Mauzo Windows desktop app and create an Inno Setup installer (.exe).
# Requires: Flutter SDK, Inno Setup 6 (ISCC.exe)
# Run from repo root:  .\scripts\build-windows-installer.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing '$name' on PATH. Install it, then run this script again."
  }
}

function Find-InnoSetupCompiler {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
  )
  foreach ($path in $candidates) {
    if (Test-Path $path) { return $path }
  }
  throw "Inno Setup 6 not found. Install from https://jrsoftware.org/isinfo.php"
}

Write-Host "==> Checking tools..."
Require-Command flutter
$iscc = Find-InnoSetupCompiler
Write-Host "    Using Inno Setup: $iscc"

Write-Host "==> Flutter Windows release build..."
& flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Creating installer..."
New-Item -ItemType Directory -Force -Path "dist\windows" | Out-Null
& $iscc "windows\installer\mauzo.iss"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$installer = Join-Path $Root "dist\windows\MauzoSetup.exe"
Write-Host ""
Write-Host "Done. Installer created at:"
Write-Host "  $installer"
