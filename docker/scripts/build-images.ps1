$ErrorActionPreference = "Stop"

$projectDirectory = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$serviceNames = @(
    "customer_service",
    "restaurant_service",
    "order_service",
    "payment_service",
    "delivery_service",
    "notification_service",
    "admin_service"
)

foreach ($serviceName in $serviceNames) {
    $serviceDirectory = Join-Path $projectDirectory "services\$serviceName"
    Write-Host "Building container image for $serviceName"
    Push-Location $serviceDirectory
    try {
        & bal build --cloud=docker
        if ($LASTEXITCODE -ne 0) {
            throw "Container image build failed for $serviceName"
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host "All Ballerina service images were built successfully."

