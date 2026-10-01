param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("mongodb", "mysql")]
    [string]$Backend
)

$ErrorActionPreference = "Stop"
$dockerDirectory = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $dockerDirectory ".env"
$composeFile = Join-Path $dockerDirectory "compose.$Backend.yml"

& docker compose --env-file $environmentFile --file $composeFile down
if ($LASTEXITCODE -ne 0) {
    throw "The $Backend stack failed to stop cleanly."
}

Write-Host "The $Backend stack stopped. Its database and Kafka volumes were preserved."
