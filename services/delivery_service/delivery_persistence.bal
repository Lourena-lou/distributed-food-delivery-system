import ballerina/sql;
import ballerinax/mongodb;
import ballerinax/mysql;

public isolated function listDrivers(DriverStatus? status = ()) returns Driver[]|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("drivers");
        map<json> filter = status is DriverStatus ? {status} : {};
        stream<Driver, error?> driverStream = check collection->find(filter, targetType = Driver);
        return from Driver driver in driverStream
            select driver;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        if status is DriverStatus {
            stream<Driver, sql:Error?> driverStream = database->query(
                `SELECT driver_id AS driverId, full_name AS fullName,
                phone_number AS phoneNumber, vehicle_registration AS vehicleRegistration,
                status FROM drivers WHERE status = ${status}`);
            return from Driver driver in driverStream
                select driver;
        }
        stream<Driver, sql:Error?> driverStream = database->query(
            `SELECT driver_id AS driverId, full_name AS fullName,
            phone_number AS phoneNumber, vehicle_registration AS vehicleRegistration,
            status FROM drivers`);
        return from Driver driver in driverStream
            select driver;
    }
    return memoryListDrivers(status);
}

public isolated function registerDriver(Driver driver) returns Driver|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("drivers");
        Driver? existing = check collection->findOne({driverId: driver.driverId}, targetType = Driver);
        if existing is Driver {
            return error(string `Driver '${driver.driverId}' already exists`);
        }
        check collection->insertOne(driver);
        return driver;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        _ = check database->execute(`INSERT INTO drivers
            (driver_id, full_name, phone_number, vehicle_registration, status)
            VALUES (${driver.driverId}, ${driver.fullName}, ${driver.phoneNumber},
            ${driver.vehicleRegistration}, ${driver.status})`);
        return driver;
    }
    return memoryRegisterDriver(driver);
}

public isolated function listDeliveries(string? driverId = ()) returns Delivery[]|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("deliveries");
        map<json> filter = driverId is string ? {driverId} : {};
        stream<Delivery, error?> deliveryStream =
            check collection->find(filter, targetType = Delivery);
        return from Delivery delivery in deliveryStream
            select delivery;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        if driverId is string {
            stream<Delivery, sql:Error?> deliveryStream = database->query(
                `SELECT delivery_id AS deliveryId, order_id AS orderId, driver_id AS driverId,
                restaurant_address AS restaurantAddress, customer_address AS customerAddress,
                status, assigned_at AS assignedAt, updated_at AS updatedAt
                FROM delivery_assignments WHERE driver_id = ${driverId}`);
            return from Delivery delivery in deliveryStream
                select delivery;
        }
        stream<Delivery, sql:Error?> deliveryStream = database->query(
            `SELECT delivery_id AS deliveryId, order_id AS orderId, driver_id AS driverId,
            restaurant_address AS restaurantAddress, customer_address AS customerAddress,
            status, assigned_at AS assignedAt, updated_at AS updatedAt FROM delivery_assignments`);
        return from Delivery delivery in deliveryStream
            select delivery;
    }
    return memoryListDeliveries(driverId);
}

public isolated function findDelivery(string deliveryId) returns Delivery?|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("deliveries");
        return collection->findOne({deliveryId}, targetType = Delivery);
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        Delivery|sql:Error result = database->queryRow(
            `SELECT delivery_id AS deliveryId, order_id AS orderId, driver_id AS driverId,
            restaurant_address AS restaurantAddress, customer_address AS customerAddress,
            status, assigned_at AS assignedAt, updated_at AS updatedAt
            FROM delivery_assignments WHERE delivery_id = ${deliveryId}`);
        if result is sql:NoRowsError {
            return ();
        }
        return result;
    }
    return memoryFindDelivery(deliveryId);
}

public isolated function assignDelivery(DeliveryAssignmentRequest request)
        returns Delivery|error {
    Delivery delivery = deliveryFromRequest(request);
    if databaseBackend == MONGODB {
        mongodb:Collection drivers = check configuredMongoCollection("drivers");
        mongodb:UpdateResult reservation = check drivers->updateOne(
            {driverId: request.driverId, status: AVAILABLE}, {set: {status: ASSIGNED}});
        if reservation.matchedCount == 0 {
            return driverAssignmentFailure(request.driverId);
        }
        mongodb:Collection deliveries = check configuredMongoCollection("deliveries");
        error? insertionError = deliveries->insertOne(delivery);
        if insertionError is error {
            mongodb:UpdateResult|error rollbackResult = drivers->updateOne(
                {driverId: request.driverId}, {set: {status: AVAILABLE}});
            if rollbackResult is error {
                return error("Delivery insertion and driver reservation rollback both failed",
                    insertionError, driverId = request.driverId);
            }
            return insertionError;
        }
        return delivery;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        transaction {
            sql:ExecutionResult reservation = check database->execute(`UPDATE drivers
                SET status = 'ASSIGNED' WHERE driver_id = ${request.driverId}
                AND status = 'AVAILABLE'`);
            if reservation.affectedRowCount == 0 {
                rollback;
                return error(string `Driver '${request.driverId}' is not available or was not found`);
            } else {
                _ = check database->execute(`INSERT INTO delivery_assignments
                    (delivery_id, order_id, driver_id, restaurant_address, customer_address,
                    status, assigned_at, updated_at) VALUES (${request.deliveryId}, ${request.orderId},
                    ${request.driverId}, ${request.restaurantAddress}, ${request.customerAddress},
                    'ASSIGNED', ${request.assignedAt}, ${request.assignedAt})`);
                check commit;
            }
        } on fail error persistenceError {
            return persistenceError;
        }
        return delivery;
    }
    return memoryAssignDelivery(request);
}

public isolated function updateDeliveryStatus(string deliveryId, DeliveryStatusUpdate update)
        returns Delivery|error {
    if databaseBackend == MEMORY {
        return memoryUpdateDeliveryStatus(deliveryId, update);
    }
    Delivery? currentDelivery = check findDelivery(deliveryId);
    if currentDelivery is () {
        return error(string `Delivery '${deliveryId}' was not found`);
    }
    if !validDeliveryTransition(currentDelivery.status, update.status) {
        return error(string `Delivery cannot move from ${currentDelivery.status} to ${update.status}`);
    }
    boolean terminal = update.status == DELIVERED || update.status == CANCELLED;
    if databaseBackend == MONGODB {
        mongodb:Collection deliveries = check configuredMongoCollection("deliveries");
        mongodb:UpdateResult statusUpdate = check deliveries->updateOne(
            {deliveryId, status: currentDelivery.status},
            {set: {status: update.status, updatedAt: update.occurredAt}});
        if statusUpdate.matchedCount == 0 {
            return error("Delivery state changed concurrently; reload and retry");
        }
        if terminal {
            mongodb:Collection drivers = check configuredMongoCollection("drivers");
            _ = check drivers->updateOne({driverId: currentDelivery.driverId},
                {set: {status: AVAILABLE}});
        }
    } else {
        mysql:Client database = check configuredMysqlClient();
        transaction {
            sql:ExecutionResult statusUpdate = check database->execute(
                `UPDATE delivery_assignments SET status = ${update.status},
                updated_at = ${update.occurredAt} WHERE delivery_id = ${deliveryId}
                AND status = ${currentDelivery.status}`);
            if statusUpdate.affectedRowCount == 0 {
                rollback;
                return error("Delivery state changed concurrently; reload and retry");
            } else {
                if terminal {
                    _ = check database->execute(`UPDATE drivers SET status = 'AVAILABLE'
                        WHERE driver_id = ${currentDelivery.driverId}`);
                }
                check commit;
            }
        } on fail error persistenceError {
            return persistenceError;
        }
    }
    Delivery? updatedDelivery = check findDelivery(deliveryId);
    return updatedDelivery is Delivery ? updatedDelivery :
        error(string `Delivery '${deliveryId}' was not found`);
}

isolated function deliveryFromRequest(DeliveryAssignmentRequest request) returns Delivery => {
    deliveryId: request.deliveryId,
    orderId: request.orderId,
    driverId: request.driverId,
    restaurantAddress: request.restaurantAddress,
    customerAddress: request.customerAddress,
    status: ASSIGNED,
    assignedAt: request.assignedAt,
    updatedAt: request.assignedAt
};

isolated function validDeliveryTransition(DeliveryStatus currentStatus,
        DeliveryStatus requestedStatus) returns boolean =>
    (currentStatus == ASSIGNED && (requestedStatus == PICKED_UP || requestedStatus == CANCELLED)) ||
    (currentStatus == PICKED_UP && requestedStatus == IN_TRANSIT) ||
    (currentStatus == IN_TRANSIT && requestedStatus == DELIVERED);

isolated function driverAssignmentFailure(string driverId) returns Delivery|error {
    Driver[] matchingDrivers = check listDrivers();
    foreach Driver driver in matchingDrivers {
        if driver.driverId == driverId {
            return error(string `Driver '${driverId}' is not available`);
        }
    }
    return error(string `Driver '${driverId}' was not found`);
}
