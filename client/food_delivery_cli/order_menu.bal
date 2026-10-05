import ballerina/io;

function runOrderMenu(ClientSession session) {
    boolean menuOpen = true;
    while menuOpen {
        printHeading("Order Menu");
        io:println("1. List orders\n2. List orders by customer\n3. List orders by restaurant\n4. Place order\n5. View order\n6. Change order status\n0. Back");
        match io:readln("Select an option: ").trim() {
            "1" => {
                renderResult(getServiceData(orderServiceClient, "/orders"), "Orders loaded");
                pauseForUser();
            }
            "2" => {
                listOrdersForCustomer(session);
                pauseForUser();
            }
            "3" => {
                listOrdersForRestaurant(session);
                pauseForUser();
            }
            "4" => {
                placeOrder(session);
                pauseForUser();
            }
            "5" => {
                viewOrder(session);
                pauseForUser();
            }
            "6" => {
                transitionOrder(session);
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

function listOrdersForCustomer(ClientSession session) {
    string customerId = preferredIdentifier("Customer ID", session.customerId);
    session.customerId = customerId;
    renderResult(getServiceData(orderServiceClient, string `/orders?customerId=${customerId}`), "Orders loaded");
}

function listOrdersForRestaurant(ClientSession session) {
    string restaurantId = preferredIdentifier("Restaurant ID", session.restaurantId);
    session.restaurantId = restaurantId;
    renderResult(getServiceData(orderServiceClient, string `/orders?restaurantId=${restaurantId}`), "Orders loaded");
}

function placeOrder(ClientSession session) {
    string customerId = preferredIdentifier("Customer ID", session.customerId);
    string restaurantId = preferredIdentifier("Restaurant ID", session.restaurantId);
    string deliveryAddressId = readRequired("Delivery address ID: ");
    int itemCount = readIntValue("Number of different items: ", 1);
    OrderItemRequest[] items = [];
    decimal totalAmount = 0d;
    foreach int itemNumber in 1 ... itemCount {
        io:println(string `\nItem ${itemNumber}`);
        int quantity = readIntValue("Quantity: ", 1);
        decimal unitPrice = readDecimalValue("Unit price: ", 0.01d);
        items.push({
            menuItemId: readRequired("Menu item ID: "),
            itemName: readRequired("Item name: "),
            quantity: quantity,
            unitPrice: unitPrice
        });
        totalAmount += unitPrice * quantity;
    }
    OrderRequest request = {
        orderId: generateIdentifier("order"),
        customerId: customerId,
        restaurantId: restaurantId,
        deliveryAddressId: deliveryAddressId,
        items: items,
        totalAmount: totalAmount,
        createdAt: currentUtcTimestamp()
    };
    json|error result = postServiceData(orderServiceClient, "/orders", request);
    if result is json {
        session.customerId = customerId;
        session.restaurantId = restaurantId;
        session.orderId = request.orderId;
    }
    renderResult(result, string `Order ${request.orderId} placed; total ${totalAmount} NAD`);
    if result is json {
        printWarning("The order service publishes the creation event; payment processing continues asynchronously through Kafka.");
    }
}

function viewOrder(ClientSession session) {
    string orderId = preferredIdentifier("Order ID", session.orderId);
    json|error result = getServiceData(orderServiceClient, string `/orders/${orderId}`);
    if result is json {
        session.orderId = orderId;
    }
    renderResult(result, "Order loaded");
}

function transitionOrder(ClientSession session) {
    string orderId = preferredIdentifier("Order ID", session.orderId);
    io:println("Statuses: CONFIRMED, PREPARING, READY, OUT_FOR_DELIVERY, DELIVERED, CANCELLED");
    string status = readRequired("New status: ").toUpperAscii();
    json|error result = postServiceData(orderServiceClient, string `/orders/${orderId}/transitions`,
            {status: status, occurredAt: currentUtcTimestamp()});
    if result is json {
        session.orderId = orderId;
    }
    renderResult(result, string `Order moved to ${status}`);
}
