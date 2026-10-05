-- Sample data for demos. MySQL runs this once, right after 001_schema.sql,
-- when the mysql-data volume is first created. Orders, payments, deliveries and
-- notifications are not seeded: the live demo creates them through the client.
-- INSERT IGNORE keeps the script safe to re-run by hand.

USE food_delivery;

-- Customers and their delivery addresses
INSERT IGNORE INTO customers (customer_id, full_name, email, phone_number) VALUES
    ('CUS-001', 'Ndapewa Shikongo', 'ndapewa.shikongo@example.com', '+264811234501'),
    ('CUS-002', 'Johannes van Wyk', 'johannes.vanwyk@example.com', '+264811234502'),
    ('CUS-003', 'Selma Nangolo', 'selma.nangolo@example.com', '+264811234503'),
    ('CUS-004', 'Tuhafeni Amukoto', 'tuhafeni.amukoto@example.com', '+264811234504');

INSERT IGNORE INTO customer_addresses
    (address_id, customer_id, label, street, city, delivery_instructions) VALUES
    ('ADDR-001', 'CUS-001', 'Home', '12 Nelson Mandela Avenue, Klein Windhoek', 'Windhoek', 'Blue gate, ring twice'),
    ('ADDR-002', 'CUS-001', 'Campus', 'NUST, 13 Jackson Kaujeua Street', 'Windhoek', 'Meet at the main entrance'),
    ('ADDR-003', 'CUS-002', 'Home', '45 Sam Nujoma Drive, Eros', 'Windhoek', NULL),
    ('ADDR-004', 'CUS-003', 'Work', '8 Independence Avenue, CBD', 'Windhoek', 'Reception on 3rd floor'),
    ('ADDR-005', 'CUS-004', 'Home', '21 Omuthiya Street, Katutura', 'Windhoek', 'Call on arrival');

-- Restaurants (RES-004 is closed for orders, to demo rejection)
INSERT IGNORE INTO restaurants (restaurant_id, name, address, accepting_orders) VALUES
    ('RES-001', 'Kapana Corner', 'Single Quarters Market, Katutura, Windhoek', TRUE),
    ('RES-002', 'Joe''s Grill House', '160 Beethoven Street, Windhoek West', TRUE),
    ('RES-003', 'Green Leaf Cafe', '5 Fidel Castro Street, CBD, Windhoek', TRUE),
    ('RES-004', 'Late Night Pizza', '77 Hosea Kutako Drive, Pionierspark', FALSE);

INSERT IGNORE INTO restaurant_opening_hours
    (restaurant_id, day_of_week, opens_at, closes_at, closed) VALUES
    ('RES-001', 'MONDAY', '10:00', '22:00', FALSE),
    ('RES-001', 'TUESDAY', '10:00', '22:00', FALSE),
    ('RES-001', 'WEDNESDAY', '10:00', '22:00', FALSE),
    ('RES-001', 'THURSDAY', '10:00', '22:00', FALSE),
    ('RES-001', 'FRIDAY', '10:00', '23:00', FALSE),
    ('RES-001', 'SATURDAY', '09:00', '23:00', FALSE),
    ('RES-001', 'SUNDAY', '09:00', '20:00', FALSE),
    ('RES-002', 'MONDAY', '11:00', '21:00', FALSE),
    ('RES-002', 'TUESDAY', '11:00', '21:00', FALSE),
    ('RES-002', 'WEDNESDAY', '11:00', '21:00', FALSE),
    ('RES-002', 'THURSDAY', '11:00', '21:00', FALSE),
    ('RES-002', 'FRIDAY', '11:00', '22:00', FALSE),
    ('RES-002', 'SATURDAY', '11:00', '22:00', FALSE),
    ('RES-002', 'SUNDAY', '00:00', '00:00', TRUE),
    ('RES-003', 'MONDAY', '07:00', '17:00', FALSE),
    ('RES-003', 'TUESDAY', '07:00', '17:00', FALSE),
    ('RES-003', 'WEDNESDAY', '07:00', '17:00', FALSE),
    ('RES-003', 'THURSDAY', '07:00', '17:00', FALSE),
    ('RES-003', 'FRIDAY', '07:00', '17:00', FALSE),
    ('RES-003', 'SATURDAY', '08:00', '13:00', FALSE),
    ('RES-003', 'SUNDAY', '00:00', '00:00', TRUE),
    ('RES-004', 'FRIDAY', '18:00', '02:00', FALSE),
    ('RES-004', 'SATURDAY', '18:00', '02:00', FALSE);

-- Menu items, prices in NAD (ITEM-007 is out of stock, to demo rejection)
INSERT IGNORE INTO menu_items
    (menu_item_id, restaurant_id, name, description, price, available_quantity, available) VALUES
    ('ITEM-001', 'RES-001', 'Kapana Plate', 'Grilled beef strips with salsa and vetkoek', 75.00, 50, TRUE),
    ('ITEM-002', 'RES-001', 'Chicken Braai Quarter', 'Flame-grilled chicken quarter with pap', 65.00, 40, TRUE),
    ('ITEM-003', 'RES-001', 'Oshifima and Stew', 'Mahangu porridge with beef stew', 55.00, 30, TRUE),
    ('ITEM-004', 'RES-002', 'Game Platter', 'Oryx, kudu and springbok cuts with chips', 245.00, 15, TRUE),
    ('ITEM-005', 'RES-002', 'Beef Burger', '200g beef patty, cheddar and fries', 120.00, 35, TRUE),
    ('ITEM-006', 'RES-002', 'Chocolate Brownie', 'Warm brownie with vanilla ice cream', 60.00, 20, TRUE),
    ('ITEM-007', 'RES-002', 'Lamb Shank', 'Slow-cooked lamb shank with mash', 210.00, 0, FALSE),
    ('ITEM-008', 'RES-003', 'Avocado Toast', 'Sourdough with smashed avocado and feta', 85.00, 25, TRUE),
    ('ITEM-009', 'RES-003', 'Chicken Caesar Salad', 'Grilled chicken, cos lettuce, parmesan', 95.00, 25, TRUE),
    ('ITEM-010', 'RES-003', 'Flat White', 'Double-shot espresso with steamed milk', 35.00, 100, TRUE),
    ('ITEM-011', 'RES-004', 'Margherita Pizza', 'Tomato, mozzarella and basil', 110.00, 30, TRUE);

-- Drivers (DRV-004 is offline, so it cannot be assigned)
INSERT IGNORE INTO drivers (driver_id, full_name, phone_number, vehicle_registration, status) VALUES
    ('DRV-001', 'Petrus Hamutenya', '+264812345601', 'N12345W', 'AVAILABLE'),
    ('DRV-002', 'Maria Iipinge', '+264812345602', 'N23456W', 'AVAILABLE'),
    ('DRV-003', 'Kevin Beukes', '+264812345603', 'N34567W', 'AVAILABLE'),
    ('DRV-004', 'Hilma Nghipondoka', '+264812345604', 'N45678W', 'OFFLINE');
