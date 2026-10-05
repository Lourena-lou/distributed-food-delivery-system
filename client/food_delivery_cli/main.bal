import ballerina/http;
import ballerina/io;

public function main() {
    ClientSession session = new;
    printHeading("Distributed Food Delivery Platform");
    io:println("Terminal client connected through the services' REST APIs.");

    boolean running = true;
    while running {
        io:println("\n1. Service health dashboard");
        io:println("2. Customer menu");
        io:println("3. Restaurant menu");
        io:println("4. Order menu");
        io:println("5. Payment menu");
        io:println("6. Delivery and driver menu");
        io:println("7. Notification menu");
        io:println("8. Administration menu");
        io:println("0. Exit");

        match io:readln("Select an option: ").trim() {
            "1" => {
                showServiceHealth();
            }
            "2" => {
                runCustomerMenu(session);
            }
            "3" => {
                runRestaurantMenu(session);
            }
            "4" => {
                runOrderMenu(session);
            }
            "5" => {
                runPaymentMenu(session);
            }
            "6" => {
                runDeliveryMenu(session);
            }
            "7" => {
                runNotificationMenu(session);
            }
            "8" => {
                runAdminMenu(session);
            }
            "0" => {
                running = false;
            }
            _ => {
                printWarning("Choose one of the displayed options.");
            }
        }
    }
    printSuccess("Goodbye.");
}

function showServiceHealth() {
    printHeading("Service Health");
    [string, http:Client, string][] healthChecks = [
        ["Customer", customerServiceClient, "/customers/health"],
        ["Restaurant", restaurantServiceClient, "/restaurants/health"],
        ["Order", orderServiceClient, "/orders/health"],
        ["Payment", paymentServiceClient, "/payments/health"],
        ["Delivery", deliveryServiceClient, "/delivery/health"],
        ["Notification", notificationServiceClient, "/notifications/health"],
        ["Admin", adminServiceClient, "/admin/reports/health"]
    ];
    foreach [string, http:Client, string] healthCheck in healthChecks {
        json|error result = getServiceData(healthCheck[1], healthCheck[2]);
        if result is error {
            printFailure(string `${healthCheck[0]}: unavailable (${result.message()})`);
        } else {
            printSuccess(string `${healthCheck[0]}: UP`);
        }
    }
    pauseForUser();
}
