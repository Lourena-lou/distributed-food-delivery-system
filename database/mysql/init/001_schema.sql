-- ============================================================
-- FOOD DELIVERY SCHEMA: one MySQL instance, 14 tables.
-- Each table is owned by ONE service. A service reads and writes
-- only its own tables; services exchange data through Kafka
-- events, never by querying each other's tables.
-- No foreign key crosses a service boundary.
--
-- Customer service:     customers, customer_addresses, customer_order_history
-- Restaurant service:   restaurants, restaurant_opening_hours, menu_items
-- Order service:        food_orders, order_items
-- Payment service:      payments
-- Delivery service:     drivers, delivery_assignments
-- Notification service: notifications
-- Admin service:        restaurant_statistics, delivery_performance
--
-- In production each service would get its own database; one
-- instance keeps the assignment simple to run on one laptop.
-- ============================================================
CREATE DATABASE IF NOT EXISTS food_delivery
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE food_delivery;

-- Owned by: CUSTOMER service. PK customer_id.
CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(64) PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    phone_number VARCHAR(32) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Owned by: CUSTOMER service. PK address_id. FK customer_id -> customers (same service); addresses are deleted with their customer.
CREATE TABLE IF NOT EXISTS customer_addresses (
    address_id VARCHAR(64) PRIMARY KEY,
    customer_id VARCHAR(64) NOT NULL,
    label VARCHAR(80) NOT NULL,
    street VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    delivery_instructions VARCHAR(500),
    CONSTRAINT fk_address_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id) ON DELETE CASCADE,
    INDEX idx_customer_addresses_customer (customer_id)
);

-- Owned by: CUSTOMER service. PK (customer_id, order_id). FK customer_id -> customers. order_id is a plain copy of the id, with no FK, because the order lives in the order service.
CREATE TABLE IF NOT EXISTS customer_order_history (
    customer_id VARCHAR(64) NOT NULL,
    order_id VARCHAR(64) NOT NULL,
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id, order_id),
    CONSTRAINT fk_history_customer FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id) ON DELETE CASCADE
);

-- Owned by: RESTAURANT service. PK restaurant_id.
CREATE TABLE IF NOT EXISTS restaurants (
    restaurant_id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    address VARCHAR(255) NOT NULL,
    accepting_orders BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_restaurants_accepting_orders (accepting_orders)
);

-- Owned by: RESTAURANT service. PK (restaurant_id, day_of_week). FK restaurant_id -> restaurants (same service).
CREATE TABLE IF NOT EXISTS restaurant_opening_hours (
    restaurant_id VARCHAR(64) NOT NULL,
    day_of_week VARCHAR(16) NOT NULL,
    opens_at CHAR(5) NOT NULL,
    closes_at CHAR(5) NOT NULL,
    closed BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (restaurant_id, day_of_week),
    CONSTRAINT fk_hours_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurants(restaurant_id) ON DELETE CASCADE
);

-- Owned by: RESTAURANT service. PK menu_item_id. FK restaurant_id -> restaurants (same service).
CREATE TABLE IF NOT EXISTS menu_items (
    menu_item_id VARCHAR(64) PRIMARY KEY,
    restaurant_id VARCHAR(64) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NOT NULL,
    price DECIMAL(12,2) NOT NULL,
    available_quantity INT NOT NULL,
    available BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_menu_price CHECK (price >= 0),
    CONSTRAINT chk_menu_quantity CHECK (available_quantity >= 0),
    CONSTRAINT fk_menu_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    INDEX idx_menu_restaurant_available (restaurant_id, available)
);

-- Owned by: ORDER service. PK order_id. status holds the lifecycle CREATED -> ... -> DELIVERED or CANCELLED. customer_id, restaurant_id and delivery_address_id are plain ids from other services, with no FK on purpose.
CREATE TABLE IF NOT EXISTS food_orders (
    order_id VARCHAR(64) PRIMARY KEY,
    customer_id VARCHAR(64) NOT NULL,
    restaurant_id VARCHAR(64) NOT NULL,
    delivery_address_id VARCHAR(64) NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    status ENUM('CREATED','CONFIRMED','PREPARING','READY','OUT_FOR_DELIVERY','DELIVERED','CANCELLED') NOT NULL,
    created_at VARCHAR(40) NOT NULL,
    updated_at VARCHAR(40) NOT NULL,
    CONSTRAINT chk_order_total CHECK (total_amount >= 0),
    INDEX idx_orders_customer (customer_id, created_at),
    INDEX idx_orders_restaurant_status (restaurant_id, status)
);

-- Owned by: ORDER service. PK (order_id, menu_item_id). FK order_id -> food_orders (same service). menu_item_id is a plain copy, with no FK.
CREATE TABLE IF NOT EXISTS order_items (
    order_id VARCHAR(64) NOT NULL,
    menu_item_id VARCHAR(64) NOT NULL,
    item_name VARCHAR(150) NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (order_id, menu_item_id),
    CONSTRAINT chk_order_item_quantity CHECK (quantity > 0),
    CONSTRAINT chk_order_item_price CHECK (unit_price >= 0),
    CONSTRAINT fk_item_order FOREIGN KEY (order_id)
        REFERENCES food_orders(order_id) ON DELETE CASCADE
);

-- Owned by: PAYMENT service. PK payment_id. status starts PENDING, then COMPLETED or FAILED. order_id and customer_id are plain ids with no FK on purpose, because those rows live in other services.
CREATE TABLE IF NOT EXISTS payments (
    payment_id VARCHAR(64) PRIMARY KEY,
    order_id VARCHAR(64) NOT NULL,
    customer_id VARCHAR(64) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'NAD',
    status ENUM('PENDING','COMPLETED','FAILED','REFUNDED') NOT NULL,
    requested_at VARCHAR(40) NOT NULL,
    processed_at VARCHAR(40),
    failure_reason VARCHAR(500),
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    INDEX idx_payments_order (order_id),
    INDEX idx_payments_customer (customer_id)
);

-- Owned by: DELIVERY service. PK driver_id. status: AVAILABLE, ASSIGNED or OFFLINE.
CREATE TABLE IF NOT EXISTS drivers (
    driver_id VARCHAR(64) PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(32) NOT NULL,
    vehicle_registration VARCHAR(32) NOT NULL UNIQUE,
    status ENUM('AVAILABLE','ASSIGNED','OFFLINE') NOT NULL DEFAULT 'AVAILABLE',
    INDEX idx_drivers_status (status)
);

-- Owned by: DELIVERY service. PK delivery_id. FK driver_id -> drivers (same service). order_id is UNIQUE (one delivery per order) but has no FK, because the order lives in another service.
CREATE TABLE IF NOT EXISTS delivery_assignments (
    delivery_id VARCHAR(64) PRIMARY KEY,
    order_id VARCHAR(64) NOT NULL UNIQUE,
    driver_id VARCHAR(64) NOT NULL,
    restaurant_address VARCHAR(255) NOT NULL,
    customer_address VARCHAR(255) NOT NULL,
    status ENUM('ASSIGNED','PICKED_UP','IN_TRANSIT','DELIVERED','CANCELLED') NOT NULL,
    assigned_at VARCHAR(40) NOT NULL,
    updated_at VARCHAR(40) NOT NULL,
    CONSTRAINT fk_delivery_driver FOREIGN KEY (driver_id)
        REFERENCES drivers(driver_id),
    INDEX idx_deliveries_driver_status (driver_id, status)
);

-- Owned by: NOTIFICATION service. PK notification_id. recipient_id is a plain id (customer, restaurant or driver), with no FK.
CREATE TABLE IF NOT EXISTS notifications (
    notification_id VARCHAR(64) PRIMARY KEY,
    recipient_type ENUM('CUSTOMER','RESTAURANT','DRIVER') NOT NULL,
    recipient_id VARCHAR(64) NOT NULL,
    channel ENUM('EMAIL','SMS','PUSH') NOT NULL,
    subject VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    status ENUM('PENDING','SENT','FAILED') NOT NULL,
    created_at VARCHAR(40) NOT NULL,
    sent_at VARCHAR(40),
    INDEX idx_notifications_recipient (recipient_id, created_at),
    INDEX idx_notifications_status (status)
);

-- Owned by: ADMIN service (report table). PK restaurant_id, a plain copy with no FK.
CREATE TABLE IF NOT EXISTS restaurant_statistics (
    restaurant_id VARCHAR(64) PRIMARY KEY,
    restaurant_name VARCHAR(150) NOT NULL,
    total_orders INT NOT NULL,
    completed_orders INT NOT NULL,
    cancelled_orders INT NOT NULL,
    gross_revenue DECIMAL(14,2) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_restaurant_statistics_nonnegative CHECK (
        total_orders >= 0 AND completed_orders >= 0 AND
        cancelled_orders >= 0 AND gross_revenue >= 0
    )
);

-- Owned by: ADMIN service (report table). PK driver_id, a plain copy with no FK.
CREATE TABLE IF NOT EXISTS delivery_performance (
    driver_id VARCHAR(64) PRIMARY KEY,
    driver_name VARCHAR(150) NOT NULL,
    assigned_deliveries INT NOT NULL,
    completed_deliveries INT NOT NULL,
    average_delivery_minutes DECIMAL(10,2) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_delivery_performance_nonnegative CHECK (
        assigned_deliveries >= 0 AND completed_deliveries >= 0 AND
        average_delivery_minutes >= 0
    )
);

