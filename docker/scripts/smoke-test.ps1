$ErrorActionPreference = "Stop"

$healthEndpoints = @{
    customer_service = "http://localhost:9101/customers/health"
    restaurant_service = "http://localhost:9102/restaurants/health"
    order_service = "http://localhost:9103/orders/health"
    payment_service = "http://localhost:9104/payments/health"
    delivery_service = "http://localhost:9105/delivery/health"
    notification_service = "http://localhost:9106/notifications/health"
    admin_service = "http://localhost:9107/admin/reports/health"
}

$pendingServices = @{}
foreach ($entry in $healthEndpoints.GetEnumerator()) {
    $pendingServices[$entry.Key] = $entry.Value
}

for ($attempt = 1; $attempt -le 45 -and $pendingServices.Count -gt 0; $attempt++) {
    foreach ($serviceName in @($pendingServices.Keys)) {
        try {
            $response = Invoke-RestMethod -Uri $pendingServices[$serviceName] -TimeoutSec 2
            if ($response.status -eq "UP") {
                Write-Host "$serviceName is ready"
                $pendingServices.Remove($serviceName)
            }
        }
        catch {
            # A service may still be starting; retry all pending services together.
        }
    }
    if ($pendingServices.Count -gt 0) {
        Start-Sleep -Seconds 2
    }
}

if ($pendingServices.Count -gt 0) {
    throw "Services did not become ready: $($pendingServices.Keys -join ', ')"
}

Write-Host "All seven service health checks passed."

