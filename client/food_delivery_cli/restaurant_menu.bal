import ballerina/io;

function runRestaurantMenu(ClientSession session) {
    boolean menuOpen = true;
    while menuOpen {
        printHeading("Restaurant Menu");
        io:println("1. List restaurants\n2. Register restaurant\n3. View restaurant\n4. Add menu item\n5. Update menu inventory\n0. Back");
        match io:readln("Select an option: ").trim() {
            "1" => {
                renderResult(getServiceData(restaurantServiceClient, "/restaurants"), "Restaurants loaded");
                pauseForUser();
            }
            "2" => {
                registerRestaurant(session);
                pauseForUser();
            }
            "3" => {
                viewRestaurant(session);
                pauseForUser();
            }
            "4" => {
                addRestaurantMenuItem(session);
                pauseForUser();
            }
            "5" => {
                updateRestaurantInventory(session);
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

function registerRestaurant(ClientSession session) {
    RestaurantRequest request = {
        restaurantId: generateIdentifier("restaurant"),
        name: readRequired("Restaurant name: "),
        address: readRequired("Restaurant address: "),
        acceptingOrders: readBooleanValue("Accepting orders?", true)
    };
    json|error result = postServiceData(restaurantServiceClient, "/restaurants", request);
    if result is json {
        session.restaurantId = request.restaurantId;
    }
    renderResult(result, string `Restaurant ${request.restaurantId} registered`);
}

function viewRestaurant(ClientSession session) {
    string restaurantId = preferredIdentifier("Restaurant ID", session.restaurantId);
    json|error result = getServiceData(restaurantServiceClient, string `/restaurants/${restaurantId}`);
    if result is json {
        session.restaurantId = restaurantId;
    }
    renderResult(result, "Restaurant loaded");
}

function addRestaurantMenuItem(ClientSession session) {
    string restaurantId = preferredIdentifier("Restaurant ID", session.restaurantId);
    MenuItemRequest request = {
        menuItemId: generateIdentifier("menu-item"),
        name: readRequired("Item name: "),
        description: readRequired("Description: "),
        price: readDecimalValue("Price: ", 0.01d),
        availableQuantity: readIntValue("Available quantity: "),
        available: readBooleanValue("Available?", true)
    };
    json|error result = postServiceData(restaurantServiceClient,
            string `/restaurants/${restaurantId}/menu`, request);
    if result is json {
        session.restaurantId = restaurantId;
    }
    renderResult(result, string `Menu item ${request.menuItemId} added`);
}

function updateRestaurantInventory(ClientSession session) {
    string restaurantId = preferredIdentifier("Restaurant ID", session.restaurantId);
    string menuItemId = readRequired("Menu item ID: ");
    int quantity = readIntValue("Available quantity: ");
    boolean available = readBooleanValue("Available?", quantity > 0);
    json|error result = putServiceData(restaurantServiceClient,
            string `/restaurants/${restaurantId}/menu/${menuItemId}/inventory`,
            {availableQuantity: quantity, available: available});
    renderResult(result, "Inventory updated");
}
