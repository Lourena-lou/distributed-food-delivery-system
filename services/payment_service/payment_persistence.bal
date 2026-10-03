import ballerina/sql;
import ballerinax/mongodb;
import ballerinax/mysql;

public isolated function listPayments(string? orderId = ()) returns Payment[]|error {
    if databaseBackend == MONGODB {
        return mongoListPayments(orderId);
    }
    if databaseBackend == MYSQL {
        return mysqlListPayments(orderId);
    }
    return memoryListPayments(orderId);
}

public isolated function findPayment(string paymentId) returns Payment?|error {
    if databaseBackend == MONGODB {
        return mongoFindPayment(paymentId);
    }
    if databaseBackend == MYSQL {
        return mysqlFindPayment(paymentId);
    }
    return memoryFindPayment(paymentId);
}

public isolated function createPayment(PaymentRequest request) returns Payment|error {
    if databaseBackend == MONGODB {
        return mongoCreatePayment(request);
    }
    if databaseBackend == MYSQL {
        return mysqlCreatePayment(request);
    }
    return memoryCreatePayment(request);
}

public isolated function processPayment(string paymentId, PaymentDecision decision)
        returns Payment|error {
    if databaseBackend == MONGODB {
        return mongoProcessPayment(paymentId, decision);
    }
    if databaseBackend == MYSQL {
        return mysqlProcessPayment(paymentId, decision);
    }
    return memoryProcessPayment(paymentId, decision);
}

isolated function mongoListPayments(string? orderId) returns Payment[]|error {
    mongodb:Collection collection = check configuredMongoCollection("payments");
    map<json> filter = orderId is string ? {orderId} : {};
    stream<Payment, error?> paymentStream = check collection->find(filter, targetType = Payment);
    return from Payment payment in paymentStream
        select payment;
}

isolated function mongoFindPayment(string paymentId) returns Payment?|error {
    mongodb:Collection collection = check configuredMongoCollection("payments");
    return collection->findOne({paymentId}, targetType = Payment);
}

isolated function mongoCreatePayment(PaymentRequest request) returns Payment|error {
    if request.amount <= 0d {
        return error("Payment amount must be greater than zero");
    }
    Payment? existingPayment = check mongoFindPayment(request.paymentId);
    if existingPayment is Payment {
        return error(string `Payment '${request.paymentId}' already exists`);
    }
    Payment payment = {
        paymentId: request.paymentId,
        orderId: request.orderId,
        customerId: request.customerId,
        amount: request.amount,
        currency: request.currency,
        status: PENDING,
        requestedAt: request.requestedAt
    };
    mongodb:Collection collection = check configuredMongoCollection("payments");
    check collection->insertOne(payment);
    return payment;
}

isolated function mongoProcessPayment(string paymentId, PaymentDecision decision)
        returns Payment|error {
    mongodb:Collection collection = check configuredMongoCollection("payments");
    PaymentStatus resultingStatus = decision.approved ? COMPLETED : FAILED;
    string? failureReason = decision.approved ? () : decision.failureReason ?: "Payment was declined";
    mongodb:UpdateResult result = check collection->updateOne(
        {paymentId, status: PENDING},
        {set: {status: resultingStatus, processedAt: decision.processedAt, failureReason}}
    );
    if result.matchedCount == 0 {
        Payment? existingPayment = check mongoFindPayment(paymentId);
        if existingPayment is () {
            return error(string `Payment '${paymentId}' was not found`);
        }
        return error(string `Payment '${paymentId}' has already been processed`);
    }
    Payment? payment = check mongoFindPayment(paymentId);
    return payment is Payment ? payment : error(string `Payment '${paymentId}' was not found`);
}

// Reads all payments, or only those for one order. Table: payments.
isolated function mysqlListPayments(string? orderId) returns Payment[]|error {
    mysql:Client database = check configuredMysqlClient();
    if orderId is string {
        stream<Payment, sql:Error?> paymentStream = database->query(
            `SELECT payment_id AS paymentId, order_id AS orderId,
            customer_id AS customerId, amount, currency, status,
            requested_at AS requestedAt, processed_at AS processedAt,
            failure_reason AS failureReason FROM payments WHERE order_id = ${orderId}`);
        return from Payment payment in paymentStream
            select payment;
    }
    stream<Payment, sql:Error?> paymentStream = database->query(
        `SELECT payment_id AS paymentId, order_id AS orderId,
        customer_id AS customerId, amount, currency, status,
        requested_at AS requestedAt, processed_at AS processedAt,
        failure_reason AS failureReason FROM payments`);
    return from Payment payment in paymentStream
        select payment;
}

// Reads one payment by its id. Returns () if no row exists.
isolated function mysqlFindPayment(string paymentId) returns Payment?|error {
    mysql:Client database = check configuredMysqlClient();
    Payment|sql:Error result = database->queryRow(`SELECT payment_id AS paymentId,
        order_id AS orderId, customer_id AS customerId, amount, currency, status,
        requested_at AS requestedAt, processed_at AS processedAt,
        failure_reason AS failureReason FROM payments WHERE payment_id = ${paymentId}`);
    if result is sql:NoRowsError {
        return ();
    }
    return result;
}

// Validates amount > 0, rejects duplicates, then INSERTs a PENDING payment.
isolated function mysqlCreatePayment(PaymentRequest request) returns Payment|error {
    if request.amount <= 0d {
        return error("Payment amount must be greater than zero");
    }
    Payment? existingPayment = check mysqlFindPayment(request.paymentId);
    if existingPayment is Payment {
        return error(string `Payment '${request.paymentId}' already exists`);
    }
    mysql:Client database = check configuredMysqlClient();
    _ = check database->execute(`INSERT INTO payments
        (payment_id, order_id, customer_id, amount, currency, status, requested_at)
        VALUES (${request.paymentId}, ${request.orderId}, ${request.customerId},
        ${request.amount}, ${request.currency}, 'PENDING', ${request.requestedAt})`);
    Payment? payment = check mysqlFindPayment(request.paymentId);
    return payment is Payment ? payment : error("Payment was not persisted");
}

// UPDATEs a payment to COMPLETED or FAILED only if it is still PENDING, so a payment is decided exactly once.
isolated function mysqlProcessPayment(string paymentId, PaymentDecision decision)
        returns Payment|error {
    mysql:Client database = check configuredMysqlClient();
    PaymentStatus resultingStatus = decision.approved ? COMPLETED : FAILED;
    string? failureReason = decision.approved ? () : decision.failureReason ?: "Payment was declined";
    sql:ExecutionResult result = check database->execute(`UPDATE payments
        SET status = ${resultingStatus}, processed_at = ${decision.processedAt},
            failure_reason = ${failureReason}
        WHERE payment_id = ${paymentId} AND status = 'PENDING'`);
    if result.affectedRowCount == 0 {
        Payment? existingPayment = check mysqlFindPayment(paymentId);
        if existingPayment is () {
            return error(string `Payment '${paymentId}' was not found`);
        }
        return error(string `Payment '${paymentId}' has already been processed`);
    }
    Payment? payment = check mysqlFindPayment(paymentId);
    return payment is Payment ? payment : error(string `Payment '${paymentId}' was not found`);
}
