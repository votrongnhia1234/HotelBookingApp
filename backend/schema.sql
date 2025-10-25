create DATABASE hotel_booking
use hotel_booking

-- Tạo cơ sở dữ liệu
CREATE DATABASE IF NOT EXISTS hotel_booking;
USE hotel_booking;

-- Bảng Roles
CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) UNIQUE NOT NULL
);

-- Insert role mặc định
INSERT INTO roles (role_name) VALUES ('customer'), ('admin'), ('hotel_manager');

-- Bảng Users
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (role_id) REFERENCES roles(id)
);

-- Bảng Hotels
CREATE TABLE hotels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    rating DECIMAL(2,1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Bảng Rooms
CREATE TABLE rooms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL,
    room_number VARCHAR(20) NOT NULL,
    type VARCHAR(100) NOT NULL,
    price_per_night DECIMAL(10,2) NOT NULL,
    status ENUM('available', 'booked', 'maintenance') DEFAULT 'available',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE,
    UNIQUE (hotel_id, room_number)
);

-- Bảng Room Images
CREATE TABLE room_images (
    id INT AUTO_INCREMENT PRIMARY KEY,
    room_id INT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
);

-- Bảng Hotel Images
CREATE TABLE hotel_images (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
);

-- Bảng Bookings
CREATE TABLE bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    room_id INT NOT NULL,
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    status ENUM('pending', 'confirmed', 'cancelled', 'completed') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
);

-- Bảng Reviews
CREATE TABLE reviews (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    hotel_id INT NOT NULL,
    booking_id INT,
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);

-- Bảng Payments
CREATE TABLE payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    method VARCHAR(50) NOT NULL,
    status VARCHAR(30) DEFAULT 'pending',
    transaction_id VARCHAR(255) UNIQUE,
    currency VARCHAR(10) DEFAULT 'usd',
    provider VARCHAR(30) DEFAULT 'manual',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);

-- Audit logs for actions
CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  action VARCHAR(64) NOT NULL,
  target_type VARCHAR(64) NULL,
  target_id INT NULL,
  metadata JSON NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_user_created ON audit_logs(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_target ON audit_logs(target_type, target_id);

-- Idempotency for webhooks
CREATE TABLE IF NOT EXISTS webhook_events (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,s
  provider VARCHAR(32) NOT NULL,
  event_id VARCHAR(255) NOT NULL,
  type VARCHAR(64) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_provider_event (provider, event_id)
);
CREATE INDEX IF NOT EXISTS idx_webhook_provider_created ON webhook_events(provider, created_at);

-- Thêm dữ liệu vào bảng roles (đã có sẵn)
-- INSERT INTO roles (role_name) VALUES ('customer'), ('admin'), ('hotel_manager'); -- đã có

-- Thêm dữ liệu vào bảng users
INSERT INTO users (role_id, name, email, password, phone, address) VALUES
(1, 'Nguyễn Văn A', 'customer1@example.com', '$2b$10$examplehashedpassword1', '0123456789', 'Hà Nội'),
(1, 'Trần Thị B', 'customer2@example.com', '$2b$10$examplehashedpassword2', '0987654321', 'TP.HCM'),
(1, 'Lê Văn C', 'customer3@example.com', '$2b$10$examplehashedpassword3', '0912345678', 'Đà Nẵng'),
(2, 'Admin Hotel', 'admin@example.com', '$2b$10$examplehashedpassword4', '0111222333', 'Quản trị'),
(3, 'Quản lý KS ABC', 'manager@example.com', '$2b$10$examplehashedpassword5', '0222333444', 'Khách sạn ABC'),
(1, 'Phạm Thị D', 'customer4@example.com', '$2b$10$examplehashedpassword6', '0934567890', 'Cần Thơ'),
(1, 'Vũ Văn E', 'customer5@example.com', '$2b$10$examplehashedpassword7', '0945678901', 'Hải Phòng'),
(1, 'Hoàng Thị F', 'customer6@example.com', '$2b$10$examplehashedpassword8', '0956789012', 'Nha Trang'),
(3, 'Quản lý KS XYZ', 'manager2@example.com', '$2b$10$examplehashedpassword9', '0234567890', 'Khách sạn XYZ'),
(1, 'Nguyễn Minh G', 'customer7@example.com', '$2b$10$examplehashedpassword10', '0967890123', 'Vũng Tàu');

-- Thêm dữ liệu vào bảng hotels
INSERT INTO hotels (name, description, address, city, country, rating) VALUES
('Khách sạn ABC', 'Khách sạn 5 sao tại TP.HCM', '123 Đường ABC, Quận 1', 'TP.HCM', 'Việt Nam', 4.8),
('Khách sạn XYZ', 'Nằm ngay trung tâm Hà Nội', '456 Đường XYZ, Ba Đình', 'Hà Nội', 'Việt Nam', 4.6),
('Resort Sun Beach', 'Biệt thự nghỉ dưỡng ven biển', '789 Biển Xanh, Nha Trang', 'Nha Trang', 'Việt Nam', 4.9),
('Khách sạn Mường Thanh', 'Chuỗi khách sạn cao cấp', '101 Mường Thanh, Đà Nẵng', 'Đà Nẵng', 'Việt Nam', 4.5),
('Grand Palace Hotel', 'Sang trọng, hiện đại', '202 Grand, Quận 3', 'TP.HCM', 'Việt Nam', 4.7),
('Sunrise Resort', 'Nghỉ dưỡng gần biển', '303 Biển Đông, Vũng Tàu', 'Vũng Tàu', 'Việt Nam', 4.4),
('Lakeside Hotel', 'Khách sạn ven hồ yên tĩnh', '404 Hồ Tây, Tây Hồ', 'Hà Nội', 'Việt Nam', 4.3),
('Mountain View Resort', 'Khách sạn núi rừng', '505 Đỉnh Núi, Sapa', 'Lào Cai', 'Việt Nam', 4.6),
('City Central Hotel', 'Gần trung tâm thương mại', '606 Trung Tâm, Quận 1', 'TP.HCM', 'Việt Nam', 4.2),
('Luxury Suites', 'Phòng cao cấp, view đẹp', '707 Skyline, Quận 7', 'TP.HCM', 'Việt Nam', 4.9);

-- Thêm dữ liệu vào bảng rooms
INSERT INTO rooms (hotel_id, room_number, type, price_per_night, status) VALUES
(1, '101', 'Deluxe', 1500000, 'available'),
(1, '102', 'Suite', 2500000, 'available'),
(2, '201', 'Standard', 1000000, 'booked'),
(2, '202', 'Premium', 1800000, 'available'),
(3, '301', 'Villa', 5000000, 'available'),
(3, '302', 'Beachfront', 7000000, 'maintenance'),
(4, '401', 'Single', 800000, 'available'),
(4, '402', 'Double', 1200000, 'booked'),
(5, '501', 'Family Suite', 3000000, 'available'),
(5, '502', 'Presidential Suite', 10000000, 'available'),
(6, '601', 'Ocean View', 2000000, 'available'),
(6, '602', 'Standard', 1000000, 'booked'),
(7, '701', 'Lake View', 1800000, 'available'),
(8, '801', 'Mountain View', 2200000, 'available'),
(9, '901', 'Business', 1500000, 'booked'),
(10, '1001', 'Executive Suite', 5000000, 'available'),
(1, '103', 'Standard', 1000000, 'available'),
(2, '203', 'Deluxe', 1600000, 'available'),
(3, '303', 'Premium Villa', 6000000, 'available'),
(4, '403', 'Family Room', 2000000, 'booked');

-- Thêm dữ liệu vào bảng room_images
INSERT INTO room_images (room_id, image_url) VALUES
(1, 'https://example.com/room101_main.jpg'),
(1, 'https://example.com/room101_bath.jpg'),
(2, 'https://example.com/room102_main.jpg'),
(3, 'https://example.com/room201_main.jpg'),
(4, 'https://example.com/room202_main.jpg'),
(5, 'https://example.com/room301_main.jpg'),
(6, 'https://example.com/room302_main.jpg'),
(7, 'https://example.com/room401_main.jpg'),
(8, 'https://example.com/room402_main.jpg'),
(9, 'https://example.com/room501_main.jpg'),
(10, 'https://example.com/room502_main.jpg'),
(11, 'https://example.com/room601_main.jpg'),
(12, 'https://example.com/room602_main.jpg'),
(13, 'https://example.com/room701_main.jpg'),
(14, 'https://example.com/room801_main.jpg'),
(15, 'https://example.com/room901_main.jpg'),
(16, 'https://example.com/room1001_main.jpg'),
(17, 'https://example.com/room103_main.jpg'),
(18, 'https://example.com/room203_main.jpg'),
(19, 'https://example.com/room303_main.jpg'),
(20, 'https://example.com/room403_main.jpg');

-- Thêm dữ liệu vào bảng bookings
INSERT INTO bookings (user_id, room_id, check_in, check_out, total_price, status) VALUES
(1, 3, '2025-04-10', '2025-04-12', 2000000, 'completed'),
(2, 4, '2025-05-01', '2025-05-03', 3600000, 'confirmed'),
(1, 1, '2025-06-01', '2025-06-03', 3000000, 'pending'),
(3, 5, '2025-04-15', '2025-04-20', 25000000, 'completed'),
(6, 8, '2025-05-10', '2025-05-12', 2400000, 'confirmed'),
(7, 11, '2025-06-05', '2025-06-07', 4000000, 'pending'),
(8, 14, '2025-04-20', '2025-04-22', 4400000, 'completed'),
(9, 15, '2025-05-20', '2025-05-22', 3000000, 'cancelled'),
(10, 16, '2025-07-01', '2025-07-03', 10000000, 'confirmed'),
(4, 20, '2025-05-05', '2025-05-07', 4000000, 'pending');

-- Thêm dữ liệu vào bảng reviews
INSERT INTO reviews (user_id, hotel_id, booking_id, rating, comment) VALUES
(1, 1, 1, 5, 'Khách sạn rất sạch sẽ, phục vụ tận tình.'),
(2, 2, 2, 4, 'Phòng đẹp, nhưng wifi hơi yếu.'),
(3, 3, 3, 5, 'Resort tuyệt vời, sẽ quay lại.'),
(6, 4, 5, 3, 'Phòng ổn, nhưng giá hơi cao.'),
(7, 6, 6, 4, 'View biển đẹp, nhân viên thân thiện.'),
(8, 8, 7, 5, 'Phong cảnh tuyệt vời, không khí trong lành.'),
(9, 9, 8, 2, 'Dịch vụ không như mong đợi.'),
(10, 10, 9, 5, 'Phòng sang trọng, phục vụ chuyên nghiệp.'),
(1, 5, 10, 4, 'Vị trí thuận tiện, phòng rộng rãi.'),
(2, 7, NULL, 5, 'Rất yên tĩnh, thích hợp nghỉ dưỡng.');

-- Thêm dữ liệu vào bảng payments
INSERT INTO payments (booking_id, amount, method, status, transaction_id) VALUES
(1, 2000000, 'credit_card', 'completed', 'txn_001'),
(2, 3600000, 'paypal', 'completed', 'txn_002'),
(3, 3000000, 'credit_card', 'pending', 'txn_003'),
(4, 25000000, 'bank_transfer', 'completed', 'txn_004'),
(5, 2400000, 'credit_card', 'completed', 'txn_005'),
(6, 4000000, 'paypal', 'pending', 'txn_006'),
(7, 4400000, 'bank_transfer', 'completed', 'txn_007'),
(8, 3000000, 'cash', 'failed', 'txn_008'),
(9, 10000000, 'credit_card', 'completed', 'txn_009'),
(10, 4000000, 'paypal', 'pending', 'txn_010');

-- ==========================
-- Bảng vouchers
-- ==========================
CREATE TABLE IF NOT EXISTS vouchers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  discount_type ENUM('percent','amount') NOT NULL DEFAULT 'amount',
  value INT NOT NULL,
  min_order INT DEFAULT NULL,
  online_only TINYINT(1) DEFAULT 0,
  expiry_date DATE DEFAULT NULL,
  nights_required INT DEFAULT NULL,
  is_active TINYINT(1) DEFAULT 1,
  hotel_id INT DEFAULT NULL,
  created_by INT DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_vouchers_hotel FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE SET NULL,
  CONSTRAINT fk_vouchers_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS hotel_managers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  hotel_id INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_manager_hotel (user_id, hotel_id),
  CONSTRAINT fk_hotel_managers_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_hotel_managers_hotel FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
);

INSERT INTO hotel_managers (user_id, hotel_id)
VALUES
  (
    (SELECT id FROM users WHERE email = 'manager@example.com' LIMIT 1),
    (SELECT id FROM hotels WHERE name = 'Khách sạn ABC' LIMIT 1)
  ),
  (
    (SELECT id FROM users WHERE email = 'manager2@example.com' LIMIT 1),
    (SELECT id FROM hotels WHERE name = 'Khách sạn XYZ' LIMIT 1)
  ),
  (
    (SELECT id FROM users WHERE email = 'partner@test.com' LIMIT 1),
    (SELECT id FROM hotels WHERE name = 'Resort Sun Beach' LIMIT 1)
  );
-- ==========================
-- Index tối ưu
-- ==========================
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_rooms_hotel ON rooms(hotel_id, room_number);
CREATE INDEX idx_bookings_dates ON bookings(check_in, check_out);
CREATE INDEX idx_payments_txn ON payments(transaction_id);
CREATE INDEX idx_audit_action ON audit_logs(action);

ALTER TABLE bookings
ADD COLUMN check_in_time TIME NULL,
ADD COLUMN check_out_time TIME NULL;


ALTER TABLE payments 
ADD COLUMN gateway VARCHAR(50) DEFAULT 'local';

ALTER TABLE hotels
ADD COLUMN latitude DECIMAL(10,6) NULL,
ADD COLUMN longitude DECIMAL(10,6) NULL;

CREATE TABLE vouchers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) UNIQUE NOT NULL,
  discount_percent INT CHECK (discount_percent BETWEEN 0 AND 100),
  expiry_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (role_id, name, email, password, phone)
VALUES (
  (SELECT id FROM roles WHERE role_name='admin'),
  'Admin Test',
  'admin@test.com',
  '$2a$10$...hash...',
  '+84901234567'
);

INSERT INTO users (role_id, name, email, password, phone)
VALUES (
  (SELECT id FROM roles WHERE role_name='hotel_manager'),
  'Partner Test',
  'partner@test.com',
  '$2a$10$...hash...',
  '+84987654321'
);

ALTER TABLE hotels ADD COLUMN image_url VARCHAR(255) NULL;
ALTER TABLE payments
  ADD COLUMN provider VARCHAR(32) NULL AFTER transaction_id;  -- hoặc ENUM('stripe','momo','vnpay','zalopay','paypal','other')
