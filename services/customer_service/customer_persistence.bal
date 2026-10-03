import ballerina/sql;
import ballerinax/mongodb;
import ballerinax/mysql;

type CustomerRow record {|
    readonly string customerId;
    string fullName;
    string email;
    string phoneNumber;
|};

type HistoricalOrderRow record {|
    string orderId;
|};

public isolated function listCustomers() returns Customer[]|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("customers");
        stream<Customer, error?> customerStream = check collection->find({}, targetType = Customer);
        return from Customer customer in customerStream
            select customer;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        stream<CustomerRow, sql:Error?> rowStream = database->query(
            `SELECT customer_id AS customerId, full_name AS fullName, email, phone_number AS phoneNumber
            FROM customers`);
        CustomerRow[] rows = check from CustomerRow row in rowStream
            select row;
        Customer[] customers = [];
        foreach CustomerRow row in rows {
            customers.push(check mysqlHydrateCustomer(database, row));
        }
        return customers;
    }
    return memoryListCustomers();
}

public isolated function findCustomer(string customerId) returns Customer?|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("customers");
        return collection->findOne({customerId}, targetType = Customer);
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        CustomerRow|sql:Error result = database->queryRow(
            `SELECT customer_id AS customerId, full_name AS fullName, email,
            phone_number AS phoneNumber FROM customers WHERE customer_id = ${customerId}`);
        if result is sql:NoRowsError {
            return ();
        }
        CustomerRow row = check result;
        return mysqlHydrateCustomer(database, row);
    }
    return memoryFindCustomer(customerId);
}

public isolated function createCustomer(Customer customer) returns Customer|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("customers");
        Customer? existing = check collection->findOne(
            {"$or": [{customerId: customer.customerId}, {email: customer.email}]}, targetType = Customer);
        if existing is Customer {
            return error("Customer identifier or email is already registered");
        }
        check collection->insertOne(customer);
        return customer;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        _ = check database->execute(`INSERT INTO customers
            (customer_id, full_name, email, phone_number) VALUES (${customer.customerId},
            ${customer.fullName}, ${customer.email}, ${customer.phoneNumber})`);
        foreach DeliveryAddress address in customer.addresses {
            _ = check database->execute(`INSERT INTO customer_addresses
                (address_id, customer_id, label, street, city, delivery_instructions)
                VALUES (${address.addressId}, ${customer.customerId}, ${address.label},
                ${address.street}, ${address.city}, ${address.deliveryInstructions})`);
        }
        foreach string orderId in customer.historicalOrderIds {
            _ = check database->execute(`INSERT IGNORE INTO customer_order_history
                (customer_id, order_id) VALUES (${customer.customerId}, ${orderId})`);
        }
        return customer;
    }
    return memoryCreateCustomer(customer);
}

public isolated function updateCustomer(string customerId, CustomerUpdate update)
        returns Customer|error {
    Customer? customer = check findCustomer(customerId);
    if customer is () {
        return error(string `Customer '${customerId}' was not found`);
    }
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("customers");
        Customer? emailOwner = check collection->findOne({email: update.email}, targetType = Customer);
        if emailOwner is Customer && emailOwner.customerId != customerId {
            return error(string `Email '${update.email}' is already registered`);
        }
        _ = check collection->updateOne({customerId}, {
            set: {
                fullName: update.fullName,
                email: update.email,
                phoneNumber: update.phoneNumber
            }
        });
    } else if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        _ = check database->execute(`UPDATE customers SET full_name = ${update.fullName},
            email = ${update.email}, phone_number = ${update.phoneNumber}
            WHERE customer_id = ${customerId}`);
    } else {
        return memoryUpdateCustomer(customerId, update);
    }
    Customer? updated = check findCustomer(customerId);
    return updated is Customer ? updated : error(string `Customer '${customerId}' was not found`);
}

public isolated function addDeliveryAddress(string customerId, DeliveryAddress address)
        returns DeliveryAddress|error {
    Customer? customer = check findCustomer(customerId);
    if customer is () {
        return error(string `Customer '${customerId}' was not found`);
    }
    if customer.addresses.indexOf(address) is int {
        return error(string `Address '${address.addressId}' already exists`);
    }
    foreach DeliveryAddress existingAddress in customer.addresses {
        if existingAddress.addressId == address.addressId {
            return error(string `Address '${address.addressId}' already exists`);
        }
    }
    if databaseBackend == MONGODB {
        customer.addresses.push(address.clone());
        mongodb:Collection collection = check configuredMongoCollection("customers");
        _ = check collection->updateOne({customerId}, {set: {addresses: customer.addresses}});
    } else if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        _ = check database->execute(`INSERT INTO customer_addresses
            (address_id, customer_id, label, street, city, delivery_instructions)
            VALUES (${address.addressId}, ${customerId}, ${address.label}, ${address.street},
            ${address.city}, ${address.deliveryInstructions})`);
    } else {
        return memoryAddDeliveryAddress(customerId, address);
    }
    return address;
}

public isolated function recordHistoricalOrder(string customerId, string orderId)
        returns Customer|error {
    Customer? customer = check findCustomer(customerId);
    if customer is () {
        return error(string `Customer '${customerId}' was not found`);
    }
    if customer.historicalOrderIds.indexOf(orderId) is () {
        customer.historicalOrderIds.push(orderId);
        if databaseBackend == MONGODB {
            mongodb:Collection collection = check configuredMongoCollection("customers");
            _ = check collection->updateOne({customerId},
                {set: {historicalOrderIds: customer.historicalOrderIds}});
        } else if databaseBackend == MYSQL {
            mysql:Client database = check configuredMysqlClient();
            _ = check database->execute(`INSERT IGNORE INTO customer_order_history
                (customer_id, order_id) VALUES (${customerId}, ${orderId})`);
        } else {
            return memoryRecordHistoricalOrder(customerId, orderId);
        }
    }
    Customer? updated = check findCustomer(customerId);
    return updated is Customer ? updated : error(string `Customer '${customerId}' was not found`);
}

isolated function mysqlHydrateCustomer(mysql:Client database, CustomerRow row)
        returns Customer|error {
    stream<DeliveryAddress, sql:Error?> addressStream = database->query(
        `SELECT address_id AS addressId, label, street, city,
        delivery_instructions AS deliveryInstructions FROM customer_addresses
        WHERE customer_id = ${row.customerId}`);
    DeliveryAddress[] addresses = check from DeliveryAddress address in addressStream
        select address;
    stream<HistoricalOrderRow, sql:Error?> historyStream = database->query(
        `SELECT order_id AS orderId FROM customer_order_history
        WHERE customer_id = ${row.customerId} ORDER BY recorded_at`);
    HistoricalOrderRow[] historyRows = check from HistoricalOrderRow history in historyStream
        select history;
    string[] historicalOrderIds = from HistoricalOrderRow history in historyRows
        select history.orderId;
    return {
        customerId: row.customerId,
        fullName: row.fullName,
        email: row.email,
        phoneNumber: row.phoneNumber,
        addresses,
        historicalOrderIds
    };
}
