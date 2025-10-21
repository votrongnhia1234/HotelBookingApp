# StayEasy Flutter App

StayEasy là ứng dụng đặt phòng khách sạn chạy trên Flutter, kết nối tới backend Node/Express. Dưới đây là hướng dẫn cấu hình nhanh và cách vận hành toàn bộ hệ thống.

## Yêu cầu môi trường

- Flutter 3.19 trở lên (`flutter --version` để kiểm tra)
- Dart SDK đi kèm Flutter
- Node.js 18+ và npm
- MySQL 8 với cơ sở dữ liệu đã chạy script `backend/schema.sql`
- Firebase project cho Phone Auth (bản web/native)

## Chuẩn bị backend

```bash
cd backend
cp .env.example .env   # nếu chưa có .env
# cập nhật DB_HOST, DB_USER, DB_PASSWORD, DB_NAME, JWT_SECRET...
npm install
npm run dev            # mặc định chạy ở http://127.0.0.1:4000
```

> Lưu ý: chạy lại `schema.sql` (xem mục **Cập nhật cơ sở dữ liệu**) để tạo bảng `vouchers` trước khi bật API ưu đãi.

## Chuẩn bị frontend

```bash
cd frontend/stayeasy
flutter pub get
```

Chỉnh `lib/firebase_options.dart` cho đúng project Firebase (Android/iOS/Web). Phone Auth cần thêm số điện thoại test trong Firebase Console nếu chưa bật billing.

## Chạy ứng dụng

```bash
# Terminal 1
cd backend && npm run dev

# Terminal 2
cd frontend/stayeasy
flutter run
```

Ứng dụng mặc định trỏ tới `http://127.0.0.1:4000/api`. Nếu chạy trên Android emulator, API_CONSTANTS sẽ tự đổi sang `10.0.2.2`.

## Luồng chính đã hỗ trợ

1. Đăng nhập bằng số điện thoại/OTP Firebase hoặc qua API login sẵn có.
2. Tìm khách sạn, xem chi tiết phòng và đặt phòng.
3. Thanh toán (trực tuyến hoặc tại khách sạn). Sau khi thanh toán sẽ hiển thị màn hình xác nhận và cập nhật trạng thái đơn.
4. Xem danh sách “Phòng đã đặt”, kéo để refresh, có thể hủy đơn khi trạng thái là *pending/confirmed*.
5. Tab “Ưu đãi” hiển thị voucher của tài khoản đang đăng nhập.
6. Quản trị viê̂n xem bảng điều khiển hệ thống (người dùng/khách sạn/phòng/doanh thu).
7. Đối tác khách sạn xem thống kê đơn và doanh thu của khách sạn mình.

## Phân quyền vai trò

| Vai trò          | Quyền chính |
| ---------------- | ----------- |
| `admin`          | Quản lý toàn bộ hệ thống: tạo/sửa/xóa khách sạn, phòng, voucher; duyệt/hủy mọi booking; xem báo cáo. |
| `hotel_manager`  | Quản lý khách sạn được gán (`hotel_managers`), xác nhận/hoàn tất/hủy booking thuộc khách sạn đó, tạo voucher dành riêng cho khách sạn mình. |
| `customer`       | Đặt phòng, thanh toán, xem & hủy booking của chính mình, dùng voucher được phân phối. |

Middleware `authorize(...)` trong backend đã phân tách quyền. Với các hành động liên quan tới khách sạn, backend kiểm tra quyền sở hữu qua `managerOwnsHotel`.

## API bổ sung

- `GET /api/vouchers` (customer/admin/hotel_manager): Danh sách voucher áp dụng cho tài khoản.
- `POST /api/vouchers` (admin + hotel_manager): tạo voucher. Partner bắt buộc gửi `hotelId`.
- `PATCH /api/vouchers/:id` (admin + hotel_manager): cập nhật nội dung. Partner chỉ sửa voucher thuộc khách sạn mình.
- `DELETE /api/vouchers/:id` (admin): vô hiệu hóa voucher.
- `PATCH /api/bookings/:id/cancel` (customer + admin + hotel_manager): hủy booking (customer chỉ khi là chủ đơn và trạng thái pending/confirmed).

## Cập nhật cơ sở dữ liệu

Chạy lại `backend/schema.sql` hoặc chạy riêng đoạn sau trong MySQL:

```sql
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
```

Nếu dùng `hotel_manager`, đảm bảo bảng `hotel_managers` có dữ liệu gán user với hotel.

## Kiểm thử nhanh

```bash
cd frontend/stayeasy
flutter test
```

Các test hiện tại kiểm tra logic discount của model `Voucher`. Khi bổ sung test backend, có thể chỉnh `backend/package.json` để chạy `node --test`.

## Các đường dẫn chính

- lib/screens/home_screen.dart: điều hướng tab, truy cập nhanh “Phòng đã đặt” & “Ưu đãi”.
- lib/screens/booking_screen.dart: đặt phòng và tính tiền VND.
- lib/screens/payment_screen.dart: gọi API thanh toán.
- lib/screens/my_trips_screen.dart: lịch sử đặt phòng, hỗ trợ hủy đơn.
- lib/screens/voucher_screen.dart: lấy data từ /api/vouchers.
- backend/src/controllers/: API Node (auth, bookings, vouchers…).
- backend/src/utils/audit.js: ghi log thao tác nhạy cảm vào bảng audit_logs.
