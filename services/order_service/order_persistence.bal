import ballerina/sql;
import ballerinax/mongodb;
import ballerinax/mysql;

type OrderRow record {|
    readonly string orderId;
    string customerId;
    string restaurantId;
    string deliveryAddressId;
    decimal totalAmount;
    OrderStatus status;
    string createdAt;
    string updatedAt;
|};

public isolated function listOrders(string? customerId = (), string? restaurantId = ())
        returns FoodOrder[]|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("orders");
        map<json> filter = {};
        if customerId is string {
            filter["customerId"] = customerId;
        }
        if restaurantId is string {
            filter["restaurantId"] = restaurantId;
        }
        stream<FoodOrder, error?> orderStream = check collection->find(filter, targetType = FoodOrder);
        return from FoodOrder foodOrder in orderStream
            select foodOrder;
    }
    if databaseBackend == MYSQL {
        return mysqlListOrders(customerId, restaurantId);
    }
    return memoryListOrders(customerId, restaurantId);
}

public isolated function findOrder(string orderId) returns FoodOrder?|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("orders");
        return collection->findOne({orderId}, targetType = FoodOrder);
    }
    if databaseBackend == MYSQL {
        return mysqlFindOrder(orderId);
    }
    return memoryFindOrder(orderId);
}

public isolated function createOrder(OrderCreateRequest request) returns FoodOrder|error {
    check validateOrderRequest(request);
    if databaseBackend == MONGODB {
        FoodOrder? existing = check findOrder(request.orderId);
        if existing is FoodOrder {
            return error(string `Order '${request.orderId}' already exists`);
        }
        FoodOrder foodOrder = orderFromRequest(request);
        mongodb:Collection collection = check configuredMongoCollection("orders");
        check collection->insertOne(foodOrder);
        return foodOrder;
    }
    if databaseBackend == MYSQL {
        return mysqlCreateOrder(request);
    }
    return memoryCreateOrder(request);
}

public isolated function transitionOrder(string orderId, OrderTransitionRequest transition)
        returns FoodOrder|error {
    if databaseBackend == MEMORY {
        return memoryTransitionOrder(orderId, transition);
    }
    FoodOrder? currentOrder = check findOrder(orderId);
    if currentOrder is () {
        return error(string `Order '${orderId}' was not found`);
    }
    if !isValidOrderTransition(currentOrder.status, transition.status) {
        return error(string `Order cannot move from ${currentOrder.status} to ${transition.status}`);
    }
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("orders");
        mongodb:UpdateResult result = check collection->updateOne(
            {orderId, status: currentOrder.status},
            {set: {status: transition.status, updatedAt: transition.occurredAt}}
        );
        if result.matchedCount == 0 {
            return error("Order state changed concurrently; reload the order and retry");
        }
    } else {
        mysql:Client database = check configuredMysqlClient();
        sql:ExecutionResult result = check database->execute(`UPDATE food_orders
            SET status = ${transition.status}, updated_at = ${transition.occurredAt}
            WHERE order_id = ${orderId} AND status = ${currentOrder.status}`);
        if result.affectedRowCount == 0 {
            return error("Order state changed concurrently; reload the order and retry");
        }
    }
    FoodOrder? updatedOrder = check findOrder(orderId);
    return updatedOrder is FoodOrder ? updatedOrder : error(string `Order '${orderId}' was not found`);
}

isolated function validateOrderRequest(OrderCreateRequest request) returns error? {
    if request.items.length() == 0 {
        return error("An order must contain at least one item");
    }
    foreach OrderItem item in request.items {
        if item.quantity <= 0 || item.unitPrice < 0d {
            return error(string `Order item '${item.menuItemId}' has an invalid quantity or price`);
        }
    }
}

isolated function orderFromRequest(OrderCreateRequest request) returns FoodOrder => {
    orderId: request.orderId,
    customerId: request.customerId,
    restaurantId: request.restaurantId,
    deliveryAddressId: request.deliveryAddressId,
    items: request.items.clone(),
    totalAmount: request.totalAmount,
    status: CREATED,
    createdAt: request.createdAt,
    updatedAt: request.createdAt
};

isolated function mysqlListOrders(string? customerId, string? restaurantId)
        returns FoodOrder[]|error {
    mysql:Client database = check configuredMysqlClient();
    stream<OrderRow, sql:Error?> rowStream;
    if customerId is string && restaurantId is string {
        rowStream = database->query(`SELECT order_id AS orderId, customer_id AS customerId,
            restaurant_id AS restaurantId, delivery_address_id AS deliveryAddressId,
            total_amount AS totalAmount, status, created_at AS createdAt, updated_at AS updatedAt
            FROM food_orders WHERE customer_id = ${customerId} AND restaurant_id = ${restaurantId}`);
    } else if customerId is string {
        rowStream = database->query(`SELECT order_id AS orderId, customer_id AS customerId,
            restaurant_id AS restaurantId, delivery_address_id AS deliveryAddressId,
            total_amount AS totalAmount, status, created_at AS createdAt, updated_at AS updatedAt
            FROM food_orders WHERE customer_id = ${customerId}`);
    } else if restaurantId is string {
        rowStream = database->query(`SELECT order_id AS orderId, customer_id AS customerId,
            restaurant_id AS restaurantId, delivery_address_id AS deliveryAddressId,
            total_amount AS totalAmount, status, created_at AS createdAt, updated_at AS updatedAt
            FROM food_orders WHERE restaurant_id = ${restaurantId}`);
    } else {
        rowStream = database->query(`SELECT order_id AS orderId, customer_id AS customerId,
            restaurant_id AS restaurantId, delivery_address_id AS deliveryAddressId,
            total_amount AS totalAmount, status, created_at AS createdAt, updated_at AS updatedAt
            FROM food_orders`);
    }
    OrderRow[] rows = check from OrderRow row in rowStream
        select row;
    FoodOrder[] orders = [];
    foreach OrderRow row in rows {
        orders.push(check mysqlHydrateOrder(database, row));
    }
    return orders;
}

isolated function mysqlFindOrder(string orderId) returns FoodOrder?|error {
    mysql:Client database = check configuredMysqlClient();
    OrderRow|sql:Error result = database->queryRow(`SELECT order_id AS orderId,
        customer_id AS customerId, restaurant_id AS restaurantId,
        delivery_address_id AS deliveryAddressId, total_amount AS totalAmount,
        status, created_at AS createdAt, updated_at AS updatedAt
        FROM food_orders WHERE order_id = ${orderId}`);
    if result is sql:NoRowsError {
        return ();
    }
    OrderRow row = check result;
    return mysqlHydrateOrder(database, row);
}

isolated function mysqlHydrateOrder(mysql:Client database, OrderRow row)
        returns FoodOrder|error {
    stream<OrderItem, sql:Error?> itemStream = database->query(
        `SELECT menu_item_id AS menuItemId, item_name AS itemName, quantity, unit_price AS unitPrice
        FROM order_items WHERE order_id = ${row.orderId}`);
    OrderItem[] items = check from OrderItem item in itemStream
        select item;
    return {
        orderId: row.orderId,
        customerId: row.customerId,
        restaurantId: row.restaurantId,
        deliveryAddressId: row.deliveryAddressId,
        items,
        totalAmount: row.totalAmount,
        status: row.status,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt
    };
}

isolated function mysqlCreateOrder(OrderCreateRequest request) returns FoodOrder|error {
    FoodOrder? existing = check mysqlFindOrder(request.orderId);
    if existing is FoodOrder {
        return error(string `Order '${request.orderId}' already exists`);
    }
    mysql:Client database = check configuredMysqlClient();
    transaction {
        _ = check database->execute(`INSERT INTO food_orders
            (order_id, customer_id, restaurant_id, delivery_address_id, total_amount,
            status, created_at, updated_at) VALUES (${request.orderId}, ${request.customerId},
            ${request.restaurantId}, ${request.deliveryAddressId}, ${request.totalAmount},
            'CREATED', ${request.createdAt}, ${request.createdAt})`);
        sql:ParameterizedQuery[] itemQueries = from OrderItem item in request.items
            select `INSERT INTO order_items
                (order_id, menu_item_id, item_name, quantity, unit_price)
                VALUES (${request.orderId}, ${item.menuItemId}, ${item.itemName},
                ${item.quantity}, ${item.unitPrice})`;
        _ = check database->batchExecute(itemQueries);
        check commit;
    } on fail error persistenceError {
        return persistenceError;
    }
    FoodOrder? foodOrder = check mysqlFindOrder(request.orderId);
    return foodOrder is FoodOrder ? foodOrder : error("Order was not persisted");
}
