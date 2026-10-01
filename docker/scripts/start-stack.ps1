param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("mongodb", "mysql")]
    [string]$Backend
)

$ErrorActionPreference = "Stop"
$dockerDirectory = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $dockerDirectory ".env"
$composeFile = Join-Path $dockerDirectory "compose.$Backend.yml"

if (-not (Test-Path -LiteralPath $environmentFile)) {
    throw "Create docker/.env from docker/.env.example and replace its passwords first."
}

& docker compose --env-file $environmentFile --file $composeFile up --detach
if ($LASTEXITCODE -ne 0) {
    throw "The $Backend stack failed to start."
}

Write-Host "The $Backend stack is starting. Run smoke-test.ps1 and verify-kafka.ps1 -Backend $Backend."
