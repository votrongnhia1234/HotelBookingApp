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
('Hội An Ancient House', 'Khách sạn kiểu cổ truyền nằm gần phố cổ Hội An.', '77 Nguyễn Phúc Chu', 'Hội An', 'Việt Nam', 4.7),
('Pleiku Central Hotel', 'Khách sạn 3 sao hiện đại tại trung tâm Pleiku, gần quảng trường Đại Đoàn Kết.', '18 Hùng Vương', 'Pleiku', 'Việt Nam', 4.1),
('Bạc Liêu Riverside Hotel', 'Khách sạn nằm bên sông Bạc Liêu, gần khu nhà Công tử Bạc Liêu.', '5 Trần Huỳnh', 'Bạc Liêu', 'Việt Nam', 4.0),
('Long An Green Park Hotel', 'Khách sạn nhỏ yên tĩnh tại trung tâm Tân An.', '21 Nguyễn Huệ, P.1', 'Long An', 'Việt Nam', 4.2),
('Thanh Hóa Central Hotel', 'Khách sạn 4 sao nằm ngay trung tâm TP Thanh Hóa, gần Vincom.', '88 Lê Hoàn', 'Thanh Hóa', 'Việt Nam', 4.3),
('Vinh City Riverside Hotel', 'Khách sạn nằm cạnh sông Lam, không gian thoáng mát.', '12 Lê Mao, TP Vinh', 'Nghệ An', 'Việt Nam', 4.1),
('Bình Dương Sky View Hotel', 'Khách sạn hiện đại tại trung tâm Thủ Dầu Một, view toàn thành phố.', '66 Yersin, P. Hiệp Thành', 'Bình Dương', 'Việt Nam', 4.2),
('Rạch Giá Pearl Hotel', 'Khách sạn 4 sao gần biển Rạch Giá, tiện nghi và sang trọng.', '22 Nguyễn Trung Trực', 'Rạch Giá', 'Việt Nam', 4.4),
('Kon Tum Highland Resort', 'Khu nghỉ dưỡng giữa núi rừng Kon Tum, yên tĩnh và trong lành.', '14 Trần Hưng Đạo', 'Kon Tum', 'Việt Nam', 4.3),
('Lạng Sơn City View Hotel', 'Khách sạn trung tâm TP Lạng Sơn, gần chợ Đông Kinh.', '10 Trần Phú', 'Lạng Sơn', 'Việt Nam', 4.0),
('Thái Nguyên Galaxy Hotel', 'Khách sạn hiện đại, gần Đại học Thái Nguyên.', '8 Hoàng Văn Thụ', 'Thái Nguyên', 'Việt Nam', 4.2),
('Nam Định Heritage Hotel', 'Khách sạn 4 sao mang phong cách cổ điển châu Âu.', '25 Hùng Vương', 'Nam Định', 'Việt Nam', 4.5),
('Tây Ninh Mountain View', 'Khách sạn gần núi Bà Đen, có hồ bơi ngoài trời.', '88 Cách Mạng Tháng 8', 'Tây Ninh', 'Việt Nam', 4.1),
('Phan Thiết Beach Resort', 'Khu nghỉ dưỡng cao cấp ven biển Mũi Né.', '15 Nguyễn Đình Chiểu', 'Phan Thiết', 'Việt Nam', 4.6),
('Cà Mau River Hotel', 'Khách sạn trung tâm, gần Quảng trường Hùng Vương.', '9 Lý Thường Kiệt', 'Cà Mau', 'Việt Nam', 4.0),
('Lào Cai Green Hotel', 'Khách sạn hiện đại gần ga Lào Cai và biên giới Việt–Trung.', '16 Trần Hưng Đạo', 'Lào Cai', 'Việt Nam', 4.2),
('Sóc Trăng Lotus Hotel', 'Khách sạn 3 sao trung tâm thành phố Sóc Trăng.', '27 Nguyễn Văn Linh', 'Sóc Trăng', 'Việt Nam', 4.0),
('Phan Rang Sun Resort', 'Khu nghỉ dưỡng ven biển với hồ bơi và spa.', '44 Yên Ninh, Phước Mỹ', 'Phan Rang', 'Việt Nam', 4.3),
('Hà Tĩnh Central Park Hotel', 'Khách sạn 4 sao gần biển Thiên Cầm, có nhà hàng và rooftop bar.', '5 Nguyễn Du', 'Hà Tĩnh', 'Việt Nam', 4.2),
('Gia Lai Highland Hotel', 'Khách sạn giữa lòng Tây Nguyên, phong cách thân thiện.', '11 Phạm Văn Đồng', 'Gia Lai', 'Việt Nam', 4.1);


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
(11, '101', 'Standard', 950000, 'available'),
(11, '102', 'Deluxe', 1150000, 'available'),
(11, '201', 'Garden View', 1350000, 'booked'),
(11, '202', 'Family', 1550000, 'available'),
(11, '301', 'Suite', 1800000, 'available'),

-- 17. Pleiku Central Hotel
(12, '101', 'Standard', 700000, 'available'),
(12, '102', 'Deluxe', 900000, 'available'),
(12, '201', 'Family', 1100000, 'available'),
(12, '202', 'Suite', 1300000, 'booked'),
(12, '301', 'VIP', 1550000, 'available'),

-- 18. Bạc Liêu Riverside Hotel
(13, '101', 'Standard', 600000, 'available'),
(13, '102', 'Deluxe', 850000, 'available'),
(13, '201', 'Family', 1000000, 'available'),
(13, '202', 'Suite', 1200000, 'booked'),
(13, '301', 'VIP', 1450000, 'available'),

-- 19. Long An Green Park Hotel
(14, '101', 'Standard', 650000, 'available'),
(14, '102', 'Deluxe', 850000, 'booked'),
(14, '201', 'Family', 1000000, 'available'),
(14, '202', 'Suite', 1200000, 'available'),
(14, '301', 'VIP', 1450000, 'available'),

-- 20. Thanh Hóa Central Hotel
(15, '101', 'Standard', 750000, 'available'),
(15, '102', 'Deluxe', 950000, 'available'),
(15, '201', 'Family', 1150000, 'available'),
(15, '202', 'Suite', 1350000, 'booked'),
(15, '301', 'VIP', 1600000, 'available'),

-- 21. Vinh City Riverside Hotel
(16, '101', 'Standard', 800000, 'available'),
(16, '102', 'Deluxe', 950000, 'available'),
(16, '201', 'Suite', 1250000, 'booked'),
(16, '202', 'Family', 1400000, 'available'),
(16, '301', 'VIP', 1650000, 'available'),

-- 22. Bình Dương Sky View Hotel
(17, '101', 'Standard', 850000, 'available'),
(17, '102', 'Deluxe', 1050000, 'available'),
(17, '201', 'Business', 1250000, 'booked'),
(17, '202', 'Suite', 1450000, 'available'),
(17, '301', 'VIP', 1700000, 'available'),

-- 23. Rạch Giá Pearl Hotel
(18, '101', 'Standard', 750000, 'available'),
(18, '102', 'Deluxe', 950000, 'available'),
(18, '201', 'Family', 1200000, 'booked'),
(18, '202', 'Suite', 1450000, 'available'),
(18, '301', 'VIP', 1650000, 'available'),

-- 24. Kon Tum Highland Resort
(19, '101', 'Standard', 700000, 'available'),
(19, '102', 'Deluxe', 950000, 'booked'),
(19, '201', 'Bungalow', 1200000, 'available'),
(19, '202', 'Family', 1350000, 'available'),
(19, '301', 'VIP', 1500000, 'available'),

-- 25. Lạng Sơn City View Hotel
(20, '101', 'Standard', 650000, 'available'),
(20, '102', 'Deluxe', 850000, 'available'),
(20, '201', 'Suite', 1100000, 'available'),
(20, '202', 'Family', 1250000, 'booked'),
(20, '301', 'VIP', 1450000, 'available'),

-- 26. Thái Nguyên Galaxy Hotel
(21, '101', 'Standard', 700000, 'available'),
(21, '102', 'Deluxe', 950000, 'available'),
(21, '201', 'Suite', 1200000, 'booked'),
(21, '202', 'Family', 1350000, 'available'),
(21, '301', 'VIP', 1500000, 'available'),

-- 27. Nam Định Heritage Hotel
(22, '101', 'Standard', 850000, 'available'),
(22, '102', 'Deluxe', 1100000, 'booked'),
(22, '201', 'Suite', 1450000, 'available'),
(22, '202', 'Family', 1600000, 'available'),
(22, '301', 'VIP', 1850000, 'available'),

-- 28. Tây Ninh Mountain View
(23, '101', 'Standard', 750000, 'available'),
(23, '102', 'Deluxe', 950000, 'booked'),
(23, '201', 'Suite', 1200000, 'available'),
(23, '202', 'Family', 1400000, 'available'),
(23, '301', 'VIP', 1600000, 'available'),

-- 29. Phan Thiết Beach Resort
(24, '101', 'Standard', 950000, 'available'),
(24, '102', 'Sea View', 1300000, 'booked'),
(24, '201', 'Deluxe', 1500000, 'available'),
(24, '202', 'Family', 1700000, 'available'),
(24, '301', 'Suite', 2000000, 'available'),

-- 30. Cà Mau River Hotel
(25, '101', 'Standard', 700000, 'available'),
(25, '102', 'Deluxe', 900000, 'booked'),
(25, '201', 'Suite', 1150000, 'available'),
(25, '202', 'Family', 1300000, 'available'),
(25, '301', 'VIP', 1500000, 'available'),

-- 31. Lào Cai Green Hotel
(26, '101', 'Standard', 800000, 'available'),
(26, '102', 'Deluxe', 1000000, 'available'),
(26, '201', 'Suite', 1250000, 'booked'),
(26, '202', 'Family', 1400000, 'available'),
(26, '301', 'VIP', 1600000, 'available'),

-- 32. Sóc Trăng Lotus Hotel
(27, '101', 'Standard', 650000, 'available'),
(27, '102', 'Deluxe', 850000, 'available'),
(27, '201', 'Family', 1000000, 'booked'),
(27, '202', 'Suite', 1200000, 'available'),
(27, '301', 'VIP', 1400000, 'available'),

-- 33. Phan Rang Sun Resort
(28, '101', 'Standard', 850000, 'available'),
(28, '102', 'Deluxe', 1100000, 'booked'),
(28, '201', 'Sea View', 1300000, 'available'),
(28, '202', 'Family', 1500000, 'available'),
(28, '301', 'Suite', 1750000, 'available'),

-- 34. Hà Tĩnh Central Park Hotel
(29, '101', 'Standard', 750000, 'available'),
(29, '102', 'Deluxe', 950000, 'available'),
(29, '201', 'Suite', 1200000, 'booked'),
(29, '202', 'Family', 1350000, 'available'),
(29, '301', 'VIP', 1600000, 'available'),

-- 35. Gia Lai Highland Hotel
(30, '101', 'Standard', 700000, 'available'),
(30, '102', 'Deluxe', 900000, 'available'),
(30, '201', 'Family', 1100000, 'booked'),
(30, '202', 'Suite', 1300000, 'available'),
(30, '301', 'VIP', 1500000, 'available');


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
