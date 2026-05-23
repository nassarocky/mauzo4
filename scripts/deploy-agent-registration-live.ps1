# Deploy agent registration counts (Cloud Function + agent-portal UI).
# Requires: Node.js 20+, Firebase CLI (`npm install -g firebase-tools`), `firebase login`
# Run from repo root:  .\scripts\deploy-agent-registration-live.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Missing '$name' on PATH. Install it, then run this script again."
  }
}

Write-Host "==> Checking tools..."
Require-Command flutter
Require-Command firebase
Require-Command node

Write-Host "==> Flutter web release build (main app + hosting root)..."
& flutter build web --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$portals = @(
  @{ Src = "web\agent-portal"; Dst = "build\web\agent-portal" },
  @{ Src = "web\admin-hub"; Dst = "build\web\admin-hub" },
  @{ Src = "web\support-reset"; Dst = "build\web\support-reset" }
)

foreach ($p in $portals) {
  $src = Join-Path $Root $p.Src
  $dst = Join-Path $Root $p.Dst
  if (-not (Test-Path $src)) {
    throw "Missing folder: $src"
  }
  Write-Host "==> Copy $($p.Src) -> $($p.Dst)"
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
}

Write-Host "==> Deploy Cloud Function (commissionAdminListAgents)..."
& firebase deploy --only functions:commissionAdminListAgents --project hesabumauzo
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Deploy Firebase Hosting (includes agent-portal)..."
& firebase deploy --only hosting --project hesabumauzo
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Done. Open your site:"
Write-Host "  https://hesabumauzo.web.app/agent-portal/"
Write-Host "  (or your custom domain /admin-hub/)"
Write-Host "Sign in as commission admin -> Agents -> Refresh list."
