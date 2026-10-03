import ballerina/http;

// Each URL points to a public REST service; the client never connects to infrastructure directly.
configurable string customerServiceUrl = "http://localhost:9101";
configurable string restaurantServiceUrl = "http://localhost:9102";
configurable string orderServiceUrl = "http://localhost:9103";
configurable string paymentServiceUrl = "http://localhost:9104";
configurable string deliveryServiceUrl = "http://localhost:9105";
configurable string notificationServiceUrl = "http://localhost:9106";
configurable string adminServiceUrl = "http://localhost:9107";

final http:Client customerServiceClient = checkpanic new (customerServiceUrl, {timeout: 10});
final http:Client restaurantServiceClient = checkpanic new (restaurantServiceUrl, {timeout: 10});
final http:Client orderServiceClient = checkpanic new (orderServiceUrl, {timeout: 10});
final http:Client paymentServiceClient = checkpanic new (paymentServiceUrl, {timeout: 10});
final http:Client deliveryServiceClient = checkpanic new (deliveryServiceUrl, {timeout: 10});
final http:Client notificationServiceClient = checkpanic new (notificationServiceUrl, {timeout: 10});
final http:Client adminServiceClient = checkpanic new (adminServiceUrl, {timeout: 10});
