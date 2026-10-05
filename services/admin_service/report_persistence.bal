import ballerina/sql;
import ballerinax/mongodb;
import ballerinax/mysql;

public isolated function saveRestaurantStatistics(RestaurantStatistics statistics)
        returns RestaurantStatistics|error {
    check validateRestaurantStatistics(statistics);
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("restaurant_statistics");
        _ = check collection->updateOne({restaurantId: statistics.restaurantId},
            {
            set: {
                restaurantId: statistics.restaurantId,
                restaurantName: statistics.restaurantName,
                totalOrders: statistics.totalOrders,
                completedOrders: statistics.completedOrders,
                cancelledOrders: statistics.cancelledOrders,
                grossRevenue: statistics.grossRevenue
            }
        }, {upsert: true});
        return statistics;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        _ = check database->execute(`INSERT INTO restaurant_statistics
            (restaurant_id, restaurant_name, total_orders, completed_orders,
            cancelled_orders, gross_revenue) VALUES (${statistics.restaurantId},
            ${statistics.restaurantName}, ${statistics.totalOrders}, ${statistics.completedOrders},
            ${statistics.cancelledOrders}, ${statistics.grossRevenue})
            ON DUPLICATE KEY UPDATE restaurant_name = VALUES(restaurant_name),
            total_orders = VALUES(total_orders), completed_orders = VALUES(completed_orders),
            cancelled_orders = VALUES(cancelled_orders), gross_revenue = VALUES(gross_revenue)`);
        return statistics;
    }
    return memorySaveRestaurantStatistics(statistics);
}

public isolated function saveDeliveryPerformance(DeliveryPerformance performance)
        returns DeliveryPerformance|error {
    check validateDeliveryPerformance(performance);
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("delivery_performance");
        _ = check collection->updateOne({driverId: performance.driverId},
            {
            set: {
                driverId: performance.driverId,
                driverName: performance.driverName,
                assignedDeliveries: performance.assignedDeliveries,
                completedDeliveries: performance.completedDeliveries,
                averageDeliveryMinutes: performance.averageDeliveryMinutes
            }
        }, {upsert: true});
        return performance;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        _ = check database->execute(`INSERT INTO delivery_performance
            (driver_id, driver_name, assigned_deliveries, completed_deliveries,
            average_delivery_minutes) VALUES (${performance.driverId}, ${performance.driverName},
            ${performance.assignedDeliveries}, ${performance.completedDeliveries},
            ${performance.averageDeliveryMinutes}) ON DUPLICATE KEY UPDATE
            driver_name = VALUES(driver_name), assigned_deliveries = VALUES(assigned_deliveries),
            completed_deliveries = VALUES(completed_deliveries),
            average_delivery_minutes = VALUES(average_delivery_minutes)`);
        return performance;
    }
    return memorySaveDeliveryPerformance(performance);
}

public isolated function getRestaurantStatistics() returns RestaurantStatistics[]|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("restaurant_statistics");
        stream<RestaurantStatistics, error?> results =
            check collection->find({}, targetType = RestaurantStatistics);
        return from RestaurantStatistics statistics in results
            select statistics;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        stream<RestaurantStatistics, sql:Error?> results = database->query(
            `SELECT restaurant_id AS restaurantId, restaurant_name AS restaurantName,
            total_orders AS totalOrders, completed_orders AS completedOrders,
            cancelled_orders AS cancelledOrders, gross_revenue AS grossRevenue
            FROM restaurant_statistics`);
        return from RestaurantStatistics statistics in results
            select statistics;
    }
    return memoryGetRestaurantStatistics();
}

public isolated function getDeliveryPerformance() returns DeliveryPerformance[]|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("delivery_performance");
        stream<DeliveryPerformance, error?> results =
            check collection->find({}, targetType = DeliveryPerformance);
        return from DeliveryPerformance performance in results
            select performance;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        stream<DeliveryPerformance, sql:Error?> results = database->query(
            `SELECT driver_id AS driverId, driver_name AS driverName,
            assigned_deliveries AS assignedDeliveries,
            completed_deliveries AS completedDeliveries,
            average_delivery_minutes AS averageDeliveryMinutes FROM delivery_performance`);
        return from DeliveryPerformance performance in results
            select performance;
    }
    return memoryGetDeliveryPerformance();
}

public isolated function getPlatformSummary() returns PlatformSummary|error {
    if databaseBackend == MEMORY {
        return memoryGetPlatformSummary();
    }
    RestaurantStatistics[] restaurantData = check getRestaurantStatistics();
    DeliveryPerformance[] deliveryData = check getDeliveryPerformance();
    int totalOrders = 0;
    int completedOrders = 0;
    int cancelledOrders = 0;
    decimal grossRevenue = 0d;
    foreach RestaurantStatistics statistics in restaurantData {
        totalOrders += statistics.totalOrders;
        completedOrders += statistics.completedOrders;
        cancelledOrders += statistics.cancelledOrders;
        grossRevenue += statistics.grossRevenue;
    }
    int completedDeliveries = 0;
    foreach DeliveryPerformance performance in deliveryData {
        completedDeliveries += performance.completedDeliveries;
    }
    return {
        restaurantCount: restaurantData.length(),
        totalOrders,
        completedOrders,
        cancelledOrders,
        grossRevenue,
        activeDriverCount: deliveryData.length(),
        completedDeliveries
    };
}

isolated function validateRestaurantStatistics(RestaurantStatistics statistics) returns error? {
    if statistics.totalOrders < 0 || statistics.completedOrders < 0 ||
            statistics.cancelledOrders < 0 || statistics.grossRevenue < 0d {
        return error("Restaurant statistics cannot contain negative values");
    }
}

isolated function validateDeliveryPerformance(DeliveryPerformance performance) returns error? {
    if performance.assignedDeliveries < 0 || performance.completedDeliveries < 0 ||
            performance.averageDeliveryMinutes < 0d {
        return error("Delivery performance cannot contain negative values");
    }
}
