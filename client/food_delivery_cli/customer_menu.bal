import ballerina/io;

function runCustomerMenu(ClientSession session) {
    boolean menuOpen = true;
    while menuOpen {
        printHeading("Customer Menu");
        io:println("1. List customers\n2. Register customer\n3. View customer\n4. Update customer\n5. Add delivery address\n6. Record an order in customer history\n0. Back");
        match io:readln("Select an option: ").trim() {
            "1" => {
                renderResult(getServiceData(customerServiceClient, "/customers"), "Customers loaded");
                pauseForUser();
            }
            "2" => {
                registerCustomer(session);
                pauseForUser();
            }
            "3" => {
                viewCustomer(session);
                pauseForUser();
            }
            "4" => {
                updateCustomer(session);
                pauseForUser();
            }
            "5" => {
                addCustomerAddress(session);
                pauseForUser();
            }
            "6" => {
                recordCustomerOrder(session);
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

function registerCustomer(ClientSession session) {
    CustomerRequest request = {
        customerId: generateIdentifier("customer"),
        fullName: readRequired("Full name: "),
        email: readRequired("Email: "),
        phoneNumber: readRequired("Phone number: ")
    };
    json|error result = postServiceData(customerServiceClient, "/customers", request);
    if result is json {
        session.customerId = request.customerId;
    }
    renderResult(result, string `Customer ${request.customerId} registered`);
}

function viewCustomer(ClientSession session) {
    string customerId = preferredIdentifier("Customer ID", session.customerId);
    json|error result = getServiceData(customerServiceClient, string `/customers/${customerId}`);
    if result is json {
        session.customerId = customerId;
    }
    renderResult(result, "Customer loaded");
}

function updateCustomer(ClientSession session) {
    string customerId = preferredIdentifier("Customer ID", session.customerId);
    CustomerUpdateRequest request = {
        fullName: readRequired("Full name: "),
        email: readRequired("Email: "),
        phoneNumber: readRequired("Phone number: ")
    };
    json|error result = putServiceData(customerServiceClient, string `/customers/${customerId}`, request);
    if result is json {
        session.customerId = customerId;
    }
    renderResult(result, "Customer updated");
}

function addCustomerAddress(ClientSession session) {
    string customerId = preferredIdentifier("Customer ID", session.customerId);
    DeliveryAddressRequest request = {
        addressId: generateIdentifier("address"),
        label: readWithDefault("Address label", "Home"),
        street: readRequired("Street address: "),
        city: readRequired("City: "),
        deliveryInstructions: readOptional("Delivery instructions (optional): ")
    };
    json|error result = postServiceData(customerServiceClient, string `/customers/${customerId}/addresses`, request);
    if result is json {
        session.customerId = customerId;
    }
    renderResult(result, string `Address ${request.addressId} added`);
}

function recordCustomerOrder(ClientSession session) {
    string customerId = preferredIdentifier("Customer ID", session.customerId);
    string orderId = preferredIdentifier("Order ID", session.orderId);
    json|error result = postServiceData(customerServiceClient,
            string `/customers/${customerId}/orders/${orderId}`, {});
    if result is json {
        session.customerId = customerId;
        session.orderId = orderId;
    }
    renderResult(result, "Customer order history updated");
}
