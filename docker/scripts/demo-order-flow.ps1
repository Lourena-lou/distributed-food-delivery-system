<#
End-to-end demo: one order from placing to delivered, through all seven services.

Run from the docker folder with the stack already running:
    .\scripts\demo-order-flow.ps1
    .\scripts\demo-order-flow.ps1 -Pause     # wait for Enter between steps (live demo)

Every run creates its own customer, restaurant, menu item and driver with unique IDs,
so it can be run again and again without clashing with earlier data or seed data.

Steps marked [KAFKA] happen on their own - the script only waits and shows the result.
Steps marked [HTTP] are calls the script makes itself.
#>
param(
    [switch]$Pause
)

$ErrorActionPreference = "Stop"

$customerApi     = "http://localhost:9101/customers"
$restaurantApi   = "http://localhost:9102/restaurants"
$orderApi        = "http://localhost:9103/orders"
$paymentApi      = "http://localhost:9104/payments"
$deliveryApi     = "http://localhost:9105/delivery"
$notificationApi = "http://localhost:9106/notifications"
$adminApi        = "http://localhost:9107/admin/reports"

$run = Get-Date -Format "MMddHHmmss"
$customerId   = "cust-$run"
$addressId    = "addr-$run"
$restaurantId = "rest-$run"
$menuItemId   = "item-$run"
$orderId      = "order-$run"
$paymentId    = "payment-$orderId"   # the payment service builds this id from the order id
$driverId     = "driver-$run"
$deliveryId   = "del-$run"

function Get-Now { (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }

function Show-Step([string]$text) {
    if ($Pause) { Read-Host "`nPress Enter for the next step" | Out-Null }
    Write-Host "`n=== $text" -ForegroundColor Cyan
}

function Send-Json([string]$method, [string]$url, $body) {
    $json = ConvertTo-Json -InputObject $body -Depth 6
    Invoke-RestMethod -Method $method -Uri $url -ContentType "application/json" -Body $json
}

function Wait-Until([string]$what, [scriptblock]$condition, [int]$seconds = 40) {
    for ($i = 0; $i -lt $seconds; $i++) {
        try { if (& $condition) { return } } catch { }
        Start-Sleep -Seconds 1
    }
    throw "Timed out after $seconds seconds waiting for: $what"
}

function Get-OrderStatus { (Invoke-RestMethod -Uri "$orderApi/$orderId").status }

try {
    # 0. All seven services must be up.
    Show-Step "0. Health check of all seven services"
    $health = [ordered]@{
        customer     = "$customerApi/health"
        restaurant   = "$restaurantApi/health"
        order        = "$orderApi/health"
        payment      = "$paymentApi/health"
        delivery     = "$deliveryApi/health"
        notification = "$notificationApi/health"
        admin        = "$adminApi/health"
    }
    foreach ($name in $health.Keys) {
        $r = Invoke-RestMethod -Uri $health[$name] -TimeoutSec 3
        Write-Host ("  {0,-13} {1}" -f $name, $r.status)
    }

    # 1. Customer service
    Show-Step "1. [HTTP] Customer registers and adds a delivery address (customer service)"
    Send-Json Post $customerApi @{
        customerId = $customerId; fullName = "Demo Customer"
        email = "demo$run@example.com"; phoneNumber = "0811234567"
    } | Out-Null
    Send-Json Post "$customerApi/$customerId/addresses" @{
        addressId = $addressId; label = "Home"; street = "12 Independence Ave"; city = "Windhoek"
    } | Out-Null
    Write-Host "  Customer $customerId with address $addressId"

    # 2. Restaurant service
    Show-Step "2. [HTTP] Restaurant with one menu item (restaurant service)"
    Send-Json Post $restaurantApi @{
        restaurantId = $restaurantId; name = "Demo Kitchen"
        address = "5 Sam Nujoma Dr, Windhoek"; acceptingOrders = $true
    } | Out-Null
    Send-Json Post "$restaurantApi/$restaurantId/menu" @{
        menuItemId = $menuItemId; name = "Chicken Burger"; description = "Chicken burger with chips"
        price = 45.00; availableQuantity = 50; available = $true
    } | Out-Null
    Write-Host "  Restaurant $restaurantId, item $menuItemId"

    # 3. Delivery service: a driver to assign later
    Show-Step "3. [HTTP] Register an available driver (delivery service)"
    Send-Json Post "$deliveryApi/drivers" @{
        driverId = $driverId; fullName = "Demo Driver"; phoneNumber = "0817654321"
        vehicleRegistration = "N$run W"; status = "AVAILABLE"
    } | Out-Null
    Write-Host "  Driver $driverId is AVAILABLE"

    # 4. Order service
    Show-Step "4. [HTTP] Customer places the order (order service publishes orders.created)"
    $order = Send-Json Post $orderApi @{
        orderId = $orderId; customerId = $customerId; restaurantId = $restaurantId
        deliveryAddressId = $addressId
        items = @(@{ menuItemId = $menuItemId; itemName = "Chicken Burger"; quantity = 2; unitPrice = 45.00 })
        totalAmount = 90.00; createdAt = (Get-Now)
    }
    Write-Host "  Order $orderId is $($order.status)"
    try { Invoke-RestMethod -Method Post -Uri "$customerApi/$customerId/orders/$orderId" | Out-Null }
    catch { Write-Host "  (could not add the order to the customer's history: $($_.Exception.Message))" -ForegroundColor Yellow }

    # 5. Payment service reacts to orders.created
    Show-Step "5. [KAFKA] Payment service sees orders.created and creates a pending payment"
    Wait-Until "a pending payment for $orderId" {
        $p = @(Invoke-RestMethod -Uri "${paymentApi}?orderId=$orderId")
        $p.Count -ge 1 -and $p[0].status -eq "PENDING"
    }
    Write-Host "  $paymentId is PENDING"

    # 6. Payment goes through
    Show-Step "6. [HTTP] Payment is approved (payment service publishes payments.completed)"
    $pay = Send-Json Post "$paymentApi/$paymentId/process" @{ approved = $true; processedAt = (Get-Now) }
    Write-Host "  $paymentId is $($pay.status)"

    # 7. Order service reacts to payments.completed
    Show-Step "7. [KAFKA] Order service sees payments.completed and confirms the order"
    Wait-Until "order to reach CONFIRMED" { (Get-OrderStatus) -eq "CONFIRMED" }
    Write-Host "  Order is CONFIRMED"

    # 8. Restaurant prepares the food
    Show-Step "8. [HTTP] Restaurant prepares the food, then marks it ready"
    foreach ($status in "PREPARING", "READY") {
        $o = Send-Json Post "$orderApi/$orderId/transitions" @{ status = $status; occurredAt = (Get-Now) }
        Write-Host "  Order is $($o.status)"
    }

    # 9. Delivery service assigns the driver
    Show-Step "9. [HTTP] Driver is assigned (delivery service publishes delivery.assigned)"
    $d = Send-Json Post "$deliveryApi/assignments" @{
        deliveryId = $deliveryId; orderId = $orderId; driverId = $driverId
        restaurantAddress = "5 Sam Nujoma Dr, Windhoek"; customerAddress = "12 Independence Ave, Windhoek"
        assignedAt = (Get-Now)
    }
    Write-Host "  Delivery $deliveryId is $($d.status) to $driverId"

    # 10. Order service reacts to delivery.assigned
    Show-Step "10. [KAFKA] Order service sees delivery.assigned and sends the order out"
    Wait-Until "order to reach OUT_FOR_DELIVERY" { (Get-OrderStatus) -eq "OUT_FOR_DELIVERY" }
    Write-Host "  Order is OUT_FOR_DELIVERY"

    # 11. Driver completes the delivery
    Show-Step "11. [HTTP] Driver picks up and delivers (delivery.completed is published at the end)"
    foreach ($status in "PICKED_UP", "IN_TRANSIT", "DELIVERED") {
        $d = Send-Json Post "$deliveryApi/assignments/$deliveryId/status" @{ status = $status; occurredAt = (Get-Now) }
        Write-Host "  Delivery is $($d.status)"
    }

    # 12. Order service reacts to delivery.completed
    Show-Step "12. [KAFKA] Order service sees delivery.completed and closes the order"
    Wait-Until "order to reach DELIVERED" { (Get-OrderStatus) -eq "DELIVERED" }
    Write-Host "  Order is DELIVERED"

    # 13. Notifications written by the notification service
    Show-Step "13. [KAFKA] Notifications saved along the way (notification service)"
    try {
        Wait-Until "notifications for the customer" { @(Invoke-RestMethod -Uri "${notificationApi}?recipientId=$customerId").Count -ge 3 } 20
    }
    catch { Write-Host "  (notifications are still arriving; showing what exists so far)" -ForegroundColor Yellow }
    Start-Sleep -Seconds 2
    foreach ($who in @(@("Restaurant", $restaurantId), @("Driver", $driverId), @("Customer", $customerId))) {
        Write-Host "  $($who[0]):"
        foreach ($n in @(Invoke-RestMethod -Uri "${notificationApi}?recipientId=$($who[1])")) {
            Write-Host "    - $($n.subject): $($n.message)"
        }
    }

    # 14. Admin reports
    Show-Step "14. [HTTP] Admin platform summary (admin service)"
    $summary = Invoke-RestMethod -Uri "$adminApi/summary"
    $summary | Format-List | Out-String | Write-Host
    Write-Host "  (The admin service keeps its own report tables; it does not listen to Kafka.)" -ForegroundColor DarkGray

    Write-Host "`nDone: order $orderId went from CREATED to DELIVERED through all seven services." -ForegroundColor Green
}
catch {
    Write-Host "`nDEMO FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
        Write-Host "Service replied: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}
