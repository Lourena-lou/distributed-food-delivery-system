import ballerina/sql;
import ballerinax/mongodb;
import ballerinax/mysql;

public isolated function listNotifications(string? recipientId = ()) returns Notification[]|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("notifications");
        map<json> filter = recipientId is string ? {recipientId} : {};
        stream<Notification, error?> notificationStream =
            check collection->find(filter, targetType = Notification);
        return from Notification notification in notificationStream
            select notification;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        if recipientId is string {
            stream<Notification, sql:Error?> notificationStream = database->query(
                `SELECT notification_id AS notificationId, recipient_type AS recipientType,
                recipient_id AS recipientId, channel, subject, message, status,
                created_at AS createdAt, sent_at AS sentAt FROM notifications
                WHERE recipient_id = ${recipientId}`);
            return from Notification notification in notificationStream
                select notification;
        }
        stream<Notification, sql:Error?> notificationStream = database->query(
            `SELECT notification_id AS notificationId, recipient_type AS recipientType,
            recipient_id AS recipientId, channel, subject, message, status,
            created_at AS createdAt, sent_at AS sentAt FROM notifications`);
        return from Notification notification in notificationStream
            select notification;
    }
    return memoryListNotifications(recipientId);
}

public isolated function queueNotification(NotificationRequest request)
        returns Notification|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("notifications");
        Notification? existing = check collection->findOne(
            {notificationId: request.notificationId}, targetType = Notification);
        if existing is Notification {
            return error(string `Notification '${request.notificationId}' already exists`);
        }
        Notification notification = notificationFromRequest(request);
        check collection->insertOne(notification);
        return notification;
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        Notification notification = notificationFromRequest(request);
        _ = check database->execute(`INSERT INTO notifications
            (notification_id, recipient_type, recipient_id, channel, subject, message, status, created_at)
            VALUES (${notification.notificationId}, ${notification.recipientType},
            ${notification.recipientId}, ${notification.channel}, ${notification.subject},
            ${notification.message}, ${notification.status}, ${notification.createdAt})`);
        return notification;
    }
    return memoryQueueNotification(request);
}

public isolated function recordDeliveryResult(string notificationId, DeliveryResult result)
        returns Notification|error {
    if databaseBackend == MONGODB {
        mongodb:Collection collection = check configuredMongoCollection("notifications");
        NotificationStatus status = result.successful ? SENT : FAILED;
        mongodb:UpdateResult update = check collection->updateOne(
            {notificationId, status: PENDING}, {set: {status, sentAt: result.occurredAt}});
        if update.matchedCount == 0 {
            return notificationUpdateFailure(collection, notificationId);
        }
        Notification? notification = check collection->findOne({notificationId}, targetType = Notification);
        return notification is Notification ? notification :
            error(string `Notification '${notificationId}' was not found`);
    }
    if databaseBackend == MYSQL {
        mysql:Client database = check configuredMysqlClient();
        NotificationStatus status = result.successful ? SENT : FAILED;
        sql:ExecutionResult update = check database->execute(`UPDATE notifications
            SET status = ${status}, sent_at = ${result.occurredAt}
            WHERE notification_id = ${notificationId} AND status = 'PENDING'`);
        if update.affectedRowCount == 0 {
            return mysqlNotificationUpdateFailure(database, notificationId);
        }
        Notification notification = check database->queryRow(
            `SELECT notification_id AS notificationId, recipient_type AS recipientType,
            recipient_id AS recipientId, channel, subject, message, status,
            created_at AS createdAt, sent_at AS sentAt FROM notifications
            WHERE notification_id = ${notificationId}`);
        return notification;
    }
    return memoryRecordDeliveryResult(notificationId, result);
}

isolated function notificationFromRequest(NotificationRequest request) returns Notification => {
    notificationId: request.notificationId,
    recipientType: request.recipientType,
    recipientId: request.recipientId,
    channel: request.channel,
    subject: request.subject,
    message: request.message,
    status: PENDING,
    createdAt: request.createdAt
};

isolated function notificationUpdateFailure(mongodb:Collection collection, string notificationId)
        returns Notification|error {
    Notification? existing = check collection->findOne({notificationId}, targetType = Notification);
    return existing is () ? error(string `Notification '${notificationId}' was not found`) :
        error(string `Notification '${notificationId}' has already been handled`);
}

isolated function mysqlNotificationUpdateFailure(mysql:Client database, string notificationId)
        returns Notification|error {
    int count = check database->queryRow(
        `SELECT COUNT(*) FROM notifications WHERE notification_id = ${notificationId}`);
    return count == 0 ? error(string `Notification '${notificationId}' was not found`) :
        error(string `Notification '${notificationId}' has already been handled`);
}
