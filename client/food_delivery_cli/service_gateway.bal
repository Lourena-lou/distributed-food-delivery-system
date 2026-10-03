import ballerina/http;

// Executes a GET request and converts non-success responses into readable client errors.
function getServiceData(http:Client serviceClient, string path) returns json|error {
    http:Response response = check serviceClient->get(path);
    return check extractResponsePayload(response);
}

// Executes a POST request with a JSON-compatible Ballerina value.
function postServiceData(http:Client serviceClient, string path, anydata payload) returns json|error {
    http:Response response = check serviceClient->post(path, payload);
    return check extractResponsePayload(response);
}

// Executes a PUT request with a JSON-compatible Ballerina value.
function putServiceData(http:Client serviceClient, string path, anydata payload) returns json|error {
    http:Response response = check serviceClient->put(path, payload);
    return check extractResponsePayload(response);
}

function extractResponsePayload(http:Response response) returns json|error {
    json payload = check response.getJsonPayload();
    if response.statusCode < 200 || response.statusCode >= 300 {
        return error(string `Server returned HTTP ${response.statusCode}: ${payload.toJsonString()}`);
    }
    return payload;
}
