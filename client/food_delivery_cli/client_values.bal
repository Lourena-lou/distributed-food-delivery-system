import ballerina/time;
import ballerina/uuid;

// Creates readable, globally unique identifiers without relying on a database sequence.
function generateIdentifier(string entityPrefix) returns string =>
    string `${entityPrefix}-${uuid:createType4AsString()}`;

// Uses one ISO-8601 UTC representation for every timestamp sent to the services.
function currentUtcTimestamp() returns string => time:utcNow().toString();
