// ============================================================
// PAYMENT EVENT INTEGRATION
// Kafka chain: Order service -> PAYMENT -> Delivery service
//
// LISTENS TO:  orders.created   (published by the Order service)
//   Message contains: orderId, customerId, totalAmount
//   Action: creates ONE payment row with status PENDING.
//   The id is "payment-<orderId>", so a repeated message never
//   creates a duplicate (idempotent). The offset is committed
//   only after the row is saved, so a crash means the message is
//   redelivered, not lost.
//
// PUBLISHES TO: payments.completed or payments.failed
//   Triggered when a payment is decided through
//   POST /payments/{id}/process (a simulated gateway decision).
//   Message contains the full payment record; the order id is the
//   Kafka key so events for one order stay in order.
//
// WHY EVENT-DRIVEN: if this service is down, the Order service
// keeps accepting orders. The events wait in Kafka and are
// processed when we recover.
// ============================================================

import ballerina/io;

function runPaymentMenu(ClientSession session) {
    boolean menuOpen = true;
    while menuOpen {
        printHeading("Payment Menu");
        io:println("1. List payments\n2. List payments by order\n3. View payment\n4. Create payment request\n5. Process payment\n0. Back");
        match io:readln("Select an option: ").trim() {
            "1" => {
                renderResult(getServiceData(paymentServiceClient, "/payments"), "Payments loaded");
                pauseForUser();
            }
            "2" => {
                listPaymentsForOrder(session);
                pauseForUser();
            }
            "3" => {
                viewPayment(session);
                pauseForUser();
            }
            "4" => {
                createPayment(session);
                pauseForUser();
            }
            "5" => {
                processPayment(session);
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

function listPaymentsForOrder(ClientSession session) {
    string orderId = preferredIdentifier("Order ID", session.orderId);
    session.orderId = orderId;
    renderResult(getServiceData(paymentServiceClient, string `/payments?orderId=${orderId}`), "Payments loaded");
}

function viewPayment(ClientSession session) {
    string paymentId = preferredIdentifier("Payment ID", session.paymentId);
    json|error result = getServiceData(paymentServiceClient, string `/payments/${paymentId}`);
    if result is json {
        session.paymentId = paymentId;
    }
    renderResult(result, "Payment loaded");
}

function createPayment(ClientSession session) {
    string orderId = preferredIdentifier("Order ID", session.orderId);
    string customerId = preferredIdentifier("Customer ID", session.customerId);
    PaymentRequest request = {
        paymentId: generateIdentifier("payment"),
        orderId: orderId,
        customerId: customerId,
        amount: readDecimalValue("Amount: ", 0.01d),
        currency: readWithDefault("Currency", "NAD").toUpperAscii(),
        requestedAt: currentUtcTimestamp()
    };
    json|error result = postServiceData(paymentServiceClient, "/payments", request);
    if result is json {
        session.paymentId = request.paymentId;
        session.orderId = orderId;
        session.customerId = customerId;
    }
    renderResult(result, string `Payment ${request.paymentId} created`);
}

function processPayment(ClientSession session) {
    string paymentId = preferredIdentifier("Payment ID", session.paymentId);
    boolean approved = readBooleanValue("Approve payment?", true);
    string? failureReason = approved ? () : readRequired("Failure reason: ");
    json|error result = postServiceData(paymentServiceClient, string `/payments/${paymentId}/process`,
            {approved: approved, processedAt: currentUtcTimestamp(), failureReason: failureReason});
    if result is json {
        session.paymentId = paymentId;
    }
    renderResult(result, approved ? "Payment approved" : "Payment declined");
}
