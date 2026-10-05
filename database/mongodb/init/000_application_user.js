// Docker supplies these values only during first-time database initialization.
const applicationUsername = process.env.MONGODB_APP_USERNAME;
const applicationPassword = process.env.MONGODB_APP_PASSWORD;

if (!applicationUsername || !applicationPassword) {
    throw new Error("MONGODB_APP_USERNAME and MONGODB_APP_PASSWORD are required");
}

const applicationDatabase = db.getSiblingDB("food_delivery");
if (applicationDatabase.getUser(applicationUsername) === null) {
    applicationDatabase.createUser({
        user: applicationUsername,
        pwd: applicationPassword,
        roles: [{role: "readWrite", db: "food_delivery"}]
    });
}
