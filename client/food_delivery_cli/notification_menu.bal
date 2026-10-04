import ballerina/io;

function runNotificationMenu(ClientSession session) {
    boolean menuOpen = true;
    while menuOpen {
        printHeading("Notification Menu");
        io:println("1. List notifications\n2. List notifications by recipient\n3. Queue notification\n4. Record delivery result\n0. Back");
        match io:readln("Select an option: ").trim() {
            "1" => {
                renderResult(getServiceData(notificationServiceClient, "/notifications"), "Notifications loaded");
                pauseForUser();
            }
            "2" => {
                listRecipientNotifications(session);
                pauseForUser();
            }
            "3" => {
                queueNotification(session);
                pauseForUser();
            }
            "4" => {
                recordNotificationResult(session);
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

function listRecipientNotifications(ClientSession session) {
    string recipientId = readWithDefault("Recipient ID",
                session.customerId is string ? <string>session.customerId : "");
    if recipientId == "" {
        printWarning("A recipient ID is required.");
        return;
    }
    renderResult(getServiceData(notificationServiceClient,
                    string `/notifications?recipientId=${recipientId}`), "Notifications loaded");
}

function queueNotification(ClientSession session) {
    string recipientType = readWithDefault("Recipient type (CUSTOMER/RESTAURANT/DRIVER)", "CUSTOMER").toUpperAscii();
    string recipientId = readRequired("Recipient ID: ");
    NotificationRequest request = {
        notificationId: generateIdentifier("notification"),
        recipientType: recipientType,
        recipientId: recipientId,
        channel: readWithDefault("Channel (EMAIL/SMS/PUSH)", "EMAIL").toUpperAscii(),
        subject: readRequired("Subject: "),
        message: readRequired("Message: "),
        createdAt: currentUtcTimestamp()
    };
    json|error result = postServiceData(notificationServiceClient, "/notifications", request);
    if result is json {
        session.notificationId = request.notificationId;
    }
    renderResult(result, string `Notification ${request.notificationId} queued`);
}

function recordNotificationResult(ClientSession session) {
    string notificationId = preferredIdentifier("Notification ID", session.notificationId);
    boolean successful = readBooleanValue("Was delivery successful?", true);
    json|error result = postServiceData(notificationServiceClient,
            string `/notifications/${notificationId}/delivery_result`,
            {successful: successful, occurredAt: currentUtcTimestamp()});
    if result is json {
        session.notificationId = notificationId;
    }
    renderResult(result, "Notification delivery result recorded");
}
