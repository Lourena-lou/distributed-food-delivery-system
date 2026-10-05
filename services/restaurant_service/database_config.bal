import ballerinax/mongodb;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

public enum DatabaseBackend {
    MEMORY = "memory",
    MONGODB = "mongodb",
    MYSQL = "mysql"
}

configurable DatabaseBackend databaseBackend = MEMORY;
configurable string mongodbConnectionUri = "mongodb://localhost:27017";
configurable string mongodbDatabase = "food_delivery";
configurable string mysqlHost = "localhost";
configurable int mysqlPort = 3306;
configurable string mysqlUser = "food_delivery";
configurable string mysqlPassword = "";
configurable string mysqlDatabase = "food_delivery";

// Only the selected connector is created. Unit tests use the memory backend.
final mongodb:Client? mongoClient = databaseBackend == MONGODB
    ? checkpanic new ({connection: mongodbConnectionUri})
    : ();

final mysql:Client? relationalClient = databaseBackend == MYSQL
    ? checkpanic new (mysqlHost, mysqlUser, mysqlPassword, mysqlDatabase, mysqlPort,
        options = {ssl: {mode: mysql:SSL_DISABLED, allowPublicKeyRetrieval: true}}
    )
    : ();

isolated function configuredMongoCollection(string collectionName)
        returns mongodb:Collection|error {
    mongodb:Client? configuredClient = mongoClient;
    if configuredClient is () {
        return error("MongoDB is not the configured persistence backend");
    }
    mongodb:Database database = check configuredClient->getDatabase(mongodbDatabase);
    return database->getCollection(collectionName);
}

isolated function configuredMysqlClient() returns mysql:Client|error {
    mysql:Client? configuredClient = relationalClient;
    if configuredClient is () {
        return error("MySQL is not the configured persistence backend");
    }
    return configuredClient;
}