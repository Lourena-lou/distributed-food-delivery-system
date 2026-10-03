import ballerina/io;

function runDeliveryMenu(ClientSession session) {
    boolean menuOpen = true;
    while menuOpen {
        printHeading("Delivery and Driver Menu");
        io:println("1. List drivers\n2. List available drivers\n3. Register driver\n4. List assignments\n5. List a driver's assignments\n6. Create assignment\n7. View assignment\n8. Change delivery status\n0. Back");
        match io:readln("Select an option: ").trim() {
            "1" => {
                renderResult(getServiceData(deliveryServiceClient, "/delivery/drivers"), "Drivers loaded");
                pauseForUser();
            }
            "2" => {
                renderResult(getServiceData(deliveryServiceClient, "/delivery/drivers?status=AVAILABLE"), "Available drivers loaded");
                pauseForUser();
            }
            "3" => {
                registerDriver(session);
                pauseForUser();
            }
            "4" => {
                renderResult(getServiceData(deliveryServiceClient, "/delivery/assignments"), "Assignments loaded");
                pauseForUser();
            }
            "5" => {
                listDriverAssignments(session);
                pauseForUser();
            }
            "6" => {
                createDeliveryAssignment(session);
                pauseForUser();
            }
            "7" => {
                viewDeliveryAssignment(session);
                pauseForUser();
            }
            "8" => {
                updateDeliveryStatus(session);
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

function registerDriver(ClientSession session) {
    DriverRequest request = {
        driverId: generateIdentifier("driver"),
        fullName: readRequired("Driver name: "),
        phoneNumber: readRequired("Phone number: "),
        vehicleRegistration: readRequired("Vehicle registration: "),
        status: readWithDefault("Status", "AVAILABLE").toUpperAscii()
    };
    json|error result = postServiceData(deliveryServiceClient, "/delivery/drivers", request);
    if result is json {
        session.driverId = request.driverId;
    }
    renderResult(result, string `Driver ${request.driverId} registered`);
}

function listDriverAssignments(ClientSession session) {
    string driverId = preferredIdentifier("Driver ID", session.driverId);
    session.driverId = driverId;
    renderResult(getServiceData(deliveryServiceClient,
                    string `/delivery/assignments?driverId=${driverId}`), "Assignments loaded");
}

function createDeliveryAssignment(ClientSession session) {
    string orderId = preferredIdentifier("Order ID", session.orderId);
    string driverId = preferredIdentifier("Driver ID", session.driverId);
    DeliveryAssignmentRequest request = {
        deliveryId: generateIdentifier("delivery"),
        orderId: orderId,
        driverId: driverId,
        restaurantAddress: readRequired("Restaurant address: "),
        customerAddress: readRequired("Customer address: "),
        assignedAt: currentUtcTimestamp()
    };
    json|error result = postServiceData(deliveryServiceClient, "/delivery/assignments", request);
    if result is json {
        session.deliveryId = request.deliveryId;
        session.orderId = orderId;
        session.driverId = driverId;
    }
    renderResult(result, string `Delivery ${request.deliveryId} assigned`);
}

function viewDeliveryAssignment(ClientSession session) {
    string deliveryId = preferredIdentifier("Delivery ID", session.deliveryId);
    json|error result = getServiceData(deliveryServiceClient, string `/delivery/assignments/${deliveryId}`);
    if result is json {
        session.deliveryId = deliveryId;
    }
    renderResult(result, "Delivery loaded");
}

function updateDeliveryStatus(ClientSession session) {
    string deliveryId = preferredIdentifier("Delivery ID", session.deliveryId);
    io:println("Statuses: PICKED_UP, IN_TRANSIT, DELIVERED, CANCELLED");
    string status = readRequired("New status: ").toUpperAscii();
    json|error result = postServiceData(deliveryServiceClient,
            string `/delivery/assignments/${deliveryId}/status`,
            {status: status, occurredAt: currentUtcTimestamp()});
    if result is json {
        session.deliveryId = deliveryId;
    }
    renderResult(result, string `Delivery moved to ${status}`);
}
