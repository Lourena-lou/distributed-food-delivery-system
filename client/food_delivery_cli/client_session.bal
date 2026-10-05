class ClientSession {
    string? customerId = ();
    string? restaurantId = ();
    string? orderId = ();
    string? paymentId = ();
    string? driverId = ();
    string? deliveryId = ();
    string? notificationId = ();
}

function preferredIdentifier(string prompt, string? rememberedIdentifier = ()) returns string {
    if rememberedIdentifier is string {
        return readWithDefault(prompt, rememberedIdentifier);
    }
    return readRequired(string `${prompt}: `);
}
