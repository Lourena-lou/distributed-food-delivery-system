import ballerina/io;

function runAdminMenu(ClientSession session) {
    boolean menuOpen = true;
    while menuOpen {
        printHeading("Administration Menu");
        io:println("1. Platform summary\n2. Restaurant statistics\n3. Save restaurant statistics\n4. Delivery performance\n5. Save delivery performance\n0. Back");
        match io:readln("Select an option: ").trim() {
            "1" => {
                renderResult(getServiceData(adminServiceClient, "/admin/reports/summary"), "Platform summary loaded");
                pauseForUser();
            }
            "2" => {
                renderResult(getServiceData(adminServiceClient, "/admin/reports/restaurant_statistics"), "Restaurant statistics loaded");
                pauseForUser();
            }
            "3" => {
                saveRestaurantStatistics(session);
                pauseForUser();
            }
            "4" => {
                renderResult(getServiceData(adminServiceClient, "/admin/reports/delivery_performance"), "Delivery performance loaded");
                pauseForUser();
            }
            "5" => {
                saveDeliveryPerformance(session);
                pauseForUser();
            }
            "0" => {
                menuOpen = false;
            }
            _ => {
                printWarning("Choose one of the displayed options.");
            }
        }
    }
}

function saveRestaurantStatistics(ClientSession session) {
    string restaurantId = preferredIdentifier("Restaurant ID", session.restaurantId);
    RestaurantStatisticsRequest request = {
        restaurantId: restaurantId,
        restaurantName: readRequired("Restaurant name: "),
        totalOrders: readIntValue("Total orders: "),
        completedOrders: readIntValue("Completed orders: "),
        cancelledOrders: readIntValue("Cancelled orders: "),
        grossRevenue: readDecimalValue("Gross revenue: ")
    };
    json|error result = putServiceData(adminServiceClient,
            string `/admin/reports/restaurant_statistics/${restaurantId}`, request);
    if result is json {
        session.restaurantId = restaurantId;
    }
    renderResult(result, "Restaurant statistics saved");
}

function saveDeliveryPerformance(ClientSession session) {
    string driverId = preferredIdentifier("Driver ID", session.driverId);
    DeliveryPerformanceRequest request = {
        driverId: driverId,
        driverName: readRequired("Driver name: "),
        assignedDeliveries: readIntValue("Assigned deliveries: "),
        completedDeliveries: readIntValue("Completed deliveries: "),
        averageDeliveryMinutes: readDecimalValue("Average delivery minutes: ")
    };
    json|error result = putServiceData(adminServiceClient,
            string `/admin/reports/delivery_performance/${driverId}`, request);
    if result is json {
        session.driverId = driverId;
    }
    renderResult(result, "Delivery performance saved");
}
