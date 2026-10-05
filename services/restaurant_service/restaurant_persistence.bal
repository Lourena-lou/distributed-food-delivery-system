import ballerina/sql;
import ballerinax/mongodb;
import ballerinax/mysql;

type RestaurantRow record {|
    readonly string restaurantId;
    string name;
    string address;
    boolean acceptingOrders;
|};

public isolated function listRestaurants() returns Restaurant[]|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("restaurants");
        stream<Restaurant, error?> restaurantStream =
            check collection->find({}, targetType = Restaurant);
        return from Restaurant restaurant in restaurantStream
            select restaurant;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        stream<RestaurantRow, sql:Error?> rowStream = database->query(
            `SELECT restaurant_id AS restaurantId, name, address,
            accepting_orders AS acceptingOrders FROM restaurants`);
        RestaurantRow[] rows = check from RestaurantRow row in rowStream
            select row;
        Restaurant[] restaurants = [];
        foreach RestaurantRow row in rows {
            restaurants.push(check mysqlHydrateRestaurant(database, row));
        }
        return restaurants;
    }
    return memoryListRestaurants();
}

public isolated function findRestaurant(string restaurantId) returns Restaurant?|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("restaurants");
        return collection->findOne({restaurantId}, targetType = Restaurant);
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        RestaurantRow|sql:Error result = database->queryRow(
            `SELECT restaurant_id AS restaurantId, name, address,
            accepting_orders AS acceptingOrders FROM restaurants
            WHERE restaurant_id = ${restaurantId}`);
        if result is sql:NoRowsError {
            return ();
        }
        RestaurantRow row = check result;
        return mysqlHydrateRestaurant(database, row);
    }
    return memoryFindRestaurant(restaurantId);
}

public isolated function createRestaurant(Restaurant restaurant) returns Restaurant|error {
    check validateInitialMenu(restaurant.menu);
    if databaseBackend == MONGODB {
        Restaurant? existing = check findRestaurant(restaurant.restaurantId);
        if existing is Restaurant {
            return error(string `Restaurant '${restaurant.restaurantId}' already exists`);
        }
        mongodb:Collection collection = check configuredMongoCollection("restaurants");
        check collection->insertOne(restaurant);
        return restaurant;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        _ = check database->execute(`INSERT INTO restaurants
            (restaurant_id, name, address, accepting_orders) VALUES
            (${restaurant.restaurantId}, ${restaurant.name}, ${restaurant.address},
            ${restaurant.acceptingOrders})`);
        foreach OpeningHours hours in restaurant.openingHours {
            _ = check database->execute(`INSERT INTO restaurant_opening_hours
                (restaurant_id, day_of_week, opens_at, closes_at, closed) VALUES
                (${restaurant.restaurantId}, ${hours.dayOfWeek}, ${hours.opensAt},
                ${hours.closesAt}, ${hours.closed})`);
        }
        foreach MenuItem menuItem in restaurant.menu {
            check mysqlInsertMenuItem(database, restaurant.restaurantId, menuItem);
        }
        return restaurant;
    }
    return memoryCreateRestaurant(restaurant);
}

public isolated function addMenuItem(string restaurantId, MenuItem menuItem)
        returns MenuItem|error {
    if menuItem.price < 0d || menuItem.availableQuantity < 0 {
        return error("Menu item price and inventory cannot be negative");
    }
    Restaurant? restaurant = check findRestaurant(restaurantId);
    if restaurant is () {
        return error(string `Restaurant '${restaurantId}' was not found`);
    }
    foreach MenuItem existingItem in restaurant.menu {
        if existingItem.menuItemId == menuItem.menuItemId {
            return error(string `Menu item '${menuItem.menuItemId}' already exists`);
        }
    }
    if databaseBackend == MONGODB {
        restaurant.menu.push(menuItem.clone());
        mongodb:Collection collection = check configuredMongoCollection("restaurants");
        _ = check collection->updateOne({restaurantId}, {set: {menu: restaurant.menu}});
    } else if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        check mysqlInsertMenuItem(database, restaurantId, menuItem);
    } else {
        return memoryAddMenuItem(restaurantId, menuItem);
    }
    return menuItem;
}

public isolated function updateInventory(string restaurantId, string menuItemId,
        int availableQuantity) returns MenuItem|error {
    if availableQuantity < 0 {
        return error("Available quantity cannot be negative");
    }
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("restaurants");
        mongodb:UpdateResult result = check collection->updateOne(
            {restaurantId, "menu.menuItemId": menuItemId},
            {
            set: {
                "menu.$.availableQuantity": availableQuantity,
                "menu.$.available": availableQuantity > 0
            }
        }
        );
        if result.matchedCount == 0 {
            return restaurantOrMenuNotFound(restaurantId, menuItemId);
        }
    } else if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        sql:ExecutionResult result = check database->execute(`UPDATE menu_items
            SET available_quantity = ${availableQuantity}, available = ${availableQuantity > 0}
            WHERE restaurant_id = ${restaurantId} AND menu_item_id = ${menuItemId}`);
        if result.affectedRowCount == 0 {
            return restaurantOrMenuNotFound(restaurantId, menuItemId);
        }
    } else {
        return memoryUpdateInventory(restaurantId, menuItemId, availableQuantity);
    }
    Restaurant? restaurant = check findRestaurant(restaurantId);
    if restaurant is Restaurant {
        foreach MenuItem menuItem in restaurant.menu {
            if menuItem.menuItemId == menuItemId {
                return menuItem;
            }
        }
    }
    return error(string `Menu item '${menuItemId}' was not found`);
}

isolated function mysqlHydrateRestaurant(mysql:Client database, RestaurantRow row)
        returns Restaurant|error {
    stream<OpeningHours, sql:Error?> hoursStream = database->query(
        `SELECT day_of_week AS dayOfWeek, opens_at AS opensAt, closes_at AS closesAt,
        closed FROM restaurant_opening_hours WHERE restaurant_id = ${row.restaurantId}`);
    OpeningHours[] openingHours = check from OpeningHours hours in hoursStream
        select hours;
    stream<MenuItem, sql:Error?> menuStream = database->query(
        `SELECT menu_item_id AS menuItemId, name, description, price,
        available_quantity AS availableQuantity, available FROM menu_items
        WHERE restaurant_id = ${row.restaurantId}`);
    MenuItem[] menu = check from MenuItem menuItem in menuStream
        select menuItem;
    return {
        restaurantId: row.restaurantId,
        name: row.name,
        address: row.address,
        acceptingOrders: row.acceptingOrders,
        openingHours,
        menu
    };
}

isolated function mysqlInsertMenuItem(mysql:Client database, string restaurantId,
        MenuItem menuItem) returns error? {
    _ = check database->execute(`INSERT INTO menu_items
        (menu_item_id, restaurant_id, name, description, price, available_quantity, available)
        VALUES (${menuItem.menuItemId}, ${restaurantId}, ${menuItem.name},
        ${menuItem.description}, ${menuItem.price}, ${menuItem.availableQuantity},
        ${menuItem.available})`);
}

isolated function validateInitialMenu(MenuItem[] menu) returns error? {
    map<boolean> identifiers = {};
    foreach MenuItem menuItem in menu {
        if menuItem.price < 0d || menuItem.availableQuantity < 0 {
            return error(string `Menu item '${menuItem.menuItemId}' has invalid price or inventory`);
        }
        if identifiers.hasKey(menuItem.menuItemId) {
            return error(string `Menu item '${menuItem.menuItemId}' is duplicated`);
        }
        identifiers[menuItem.menuItemId] = true;
    }
}

isolated function restaurantOrMenuNotFound(string restaurantId, string menuItemId)
        returns MenuItem|error {
    Restaurant? restaurant = check findRestaurant(restaurantId);
    return restaurant is () ? error(string `Restaurant '${restaurantId}' was not found`) :
        error(string `Menu item '${menuItemId}' was not found`);
}