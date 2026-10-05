type DeliveryAddressRequest record {|
    readonly string addressId;
    string label;
    string street;
    string city;
    string? deliveryInstructions = ();
|};

type CustomerRequest record {|
    readonly string customerId;
    string fullName;
    string email;
    string phoneNumber;
    DeliveryAddressRequest[] addresses = [];
    string[] historicalOrderIds = [];
|};

type CustomerUpdateRequest record {|
    string fullName;
    string email;
    string phoneNumber;
|};

type RestaurantRequest record {|
    readonly string restaurantId;
    string name;
    string address;
    boolean acceptingOrders = true;
    json[] openingHours = [];
    MenuItemRequest[] menu = [];
|};

type MenuItemRequest record {|
    readonly string menuItemId;
    string name;
    string description;
    decimal price;
    int availableQuantity;
    boolean available = true;
|};

type OrderItemRequest record {|
    readonly string menuItemId;
    string itemName;
    int quantity;
    decimal unitPrice;
|};

type OrderRequest record {|
    readonly string orderId;
    string customerId;
    string restaurantId;
    string deliveryAddressId;
    OrderItemRequest[] items;
    decimal totalAmount;
    string createdAt;
|};

type PaymentRequest record {|
    readonly string paymentId;
    string orderId;
    string customerId;
    decimal amount;
    string currency = "NAD";
    string requestedAt;
|};

type DriverRequest record {|
    readonly string driverId;
    string fullName;
    string phoneNumber;
    string vehicleRegistration;
    string status = "AVAILABLE";
|};

type DeliveryAssignmentRequest record {|
    readonly string deliveryId;
    string orderId;
    string driverId;
    string restaurantAddress;
    string customerAddress;
    string assignedAt;
|};

type NotificationRequest record {|
    readonly string notificationId;
    string recipientType;
    string recipientId;
    string channel;
    string subject;
    string message;
    string createdAt;
|};

type RestaurantStatisticsRequest record {|
    readonly string restaurantId;
    string restaurantName;
    int totalOrders;
    int completedOrders;
    int cancelledOrders;
    decimal grossRevenue;
|};

type DeliveryPerformanceRequest record {|
    readonly string driverId;
    string driverName;
    int assignedDeliveries;
    int completedDeliveries;
    decimal averageDeliveryMinutes;
|};
