db = db.getSiblingDB("food_delivery");

function ensureCollection(name, validator) {
    if (!db.getCollectionNames().includes(name)) {
        db.createCollection(name, {validator});
        return;
    }
    db.runCommand({collMod: name, validator});
}

ensureCollection("customers", {$jsonSchema: {
    bsonType: "object",
    required: ["customerId", "fullName", "email", "phoneNumber", "addresses", "historicalOrderIds"],
    properties: {
        customerId: {bsonType: "string"},
        email: {bsonType: "string"},
        addresses: {bsonType: "array"},
        historicalOrderIds: {bsonType: "array"}
    }
}});

ensureCollection("restaurants", {$jsonSchema: {
    bsonType: "object",
    required: ["restaurantId", "name", "address", "acceptingOrders", "openingHours", "menu"],
    properties: {
        restaurantId: {bsonType: "string"},
        acceptingOrders: {bsonType: "bool"},
        openingHours: {bsonType: "array"},
        menu: {bsonType: "array"}
    }
}});

ensureCollection("orders", {$jsonSchema: {
    bsonType: "object",
    required: ["orderId", "customerId", "restaurantId", "items", "totalAmount", "status"],
    properties: {
        orderId: {bsonType: "string"},
        status: {enum: ["CREATED", "CONFIRMED", "PREPARING", "READY", "OUT_FOR_DELIVERY", "DELIVERED", "CANCELLED"]},
        items: {bsonType: "array"}
    }
}});

ensureCollection("payments", {$jsonSchema: {
    bsonType: "object",
    required: ["paymentId", "orderId", "customerId", "amount", "currency", "status"],
    properties: {
        paymentId: {bsonType: "string"},
        status: {enum: ["PENDING", "COMPLETED", "FAILED", "REFUNDED"]}
    }
}});

ensureCollection("drivers", {$jsonSchema: {
    bsonType: "object",
    required: ["driverId", "fullName", "phoneNumber", "vehicleRegistration", "status"],
    properties: {
        driverId: {bsonType: "string"},
        status: {enum: ["AVAILABLE", "ASSIGNED", "OFFLINE"]}
    }
}});

ensureCollection("deliveries", {$jsonSchema: {
    bsonType: "object",
    required: ["deliveryId", "orderId", "driverId", "status", "assignedAt", "updatedAt"],
    properties: {
        deliveryId: {bsonType: "string"},
        status: {enum: ["ASSIGNED", "PICKED_UP", "IN_TRANSIT", "DELIVERED", "CANCELLED"]}
    }
}});

ensureCollection("notifications", {$jsonSchema: {
    bsonType: "object",
    required: ["notificationId", "recipientType", "recipientId", "channel", "status"],
    properties: {
        notificationId: {bsonType: "string"},
        recipientType: {enum: ["CUSTOMER", "RESTAURANT", "DRIVER"]},
        channel: {enum: ["EMAIL", "SMS", "PUSH"]},
        status: {enum: ["PENDING", "SENT", "FAILED"]}
    }
}});

ensureCollection("restaurant_statistics", {$jsonSchema: {
    bsonType: "object",
    required: ["restaurantId", "restaurantName", "totalOrders", "completedOrders", "cancelledOrders", "grossRevenue"]
}});

ensureCollection("delivery_performance", {$jsonSchema: {
    bsonType: "object",
    required: ["driverId", "driverName", "assignedDeliveries", "completedDeliveries", "averageDeliveryMinutes"]
}});

db.customers.createIndex({customerId: 1}, {unique: true});
db.customers.createIndex({email: 1}, {unique: true});
db.restaurants.createIndex({restaurantId: 1}, {unique: true});
db.restaurants.createIndex({acceptingOrders: 1});
db.orders.createIndex({orderId: 1}, {unique: true});
db.orders.createIndex({customerId: 1, createdAt: -1});
db.orders.createIndex({restaurantId: 1, status: 1});
db.payments.createIndex({paymentId: 1}, {unique: true});
db.payments.createIndex({orderId: 1});
db.drivers.createIndex({driverId: 1}, {unique: true});
db.drivers.createIndex({status: 1});
db.deliveries.createIndex({deliveryId: 1}, {unique: true});
db.deliveries.createIndex({orderId: 1}, {unique: true});
db.deliveries.createIndex({driverId: 1, status: 1});
db.notifications.createIndex({notificationId: 1}, {unique: true});
db.notifications.createIndex({recipientId: 1, createdAt: -1});
db.restaurant_statistics.createIndex({restaurantId: 1}, {unique: true});
db.delivery_performance.createIndex({driverId: 1}, {unique: true});