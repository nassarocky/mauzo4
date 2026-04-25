# Shopping Manager -> Hesabu Mauzo (gmanproducts/). Requires two service account JSON files.
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to Shopping Manager SA JSON (read source bucket)")]
    [string] $SourceKey,
    [Parameter(Mandatory = $true, HelpMessage = "Path to Hesabu Mauzo SA JSON (read+write dest bucket)")]
    [string] $DestKey,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$py = Join-Path $here ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    Write-Error "Virtual env missing. Run: cd tools\storage_migrate ; python -m venv .venv ; .\.venv\Scripts\pip install -r requirements.txt"
}

$args = @(
    (Join-Path $here "copy_buckets_no_clobber.py"),
    "--source-bucket", "shopping-manager-a938a.appspot.com",
    "--dest-bucket", "hesabumauzo.firebasestorage.app",
    "--source-key", $SourceKey,
    "--dest-key", $DestKey,
    "--prefix", "gmanproducts/"
)
if ($DryRun) { $args += "--dry-run" }

& $py @args
exit $LASTEXITCODE
