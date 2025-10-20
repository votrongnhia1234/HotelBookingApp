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

> Lưu ý: nếu chưa bật bảng vouchers, API sẽ tự fallback sang danh sách mặc định.

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

## Kiểm thử nhanh

```bash
cd frontend/stayeasy
flutter test
```

Các test hiện tại kiểm tra logic discount của model `Voucher`. Khi bổ sung test backend, có thể chỉnh `backend/package.json` để chạy `node --test`.

## Các đường dẫn chính

- `lib/screens/home_screen.dart`: điều hướng tab, truy cập nhanh “Phòng đã đặt” & “Ưu đãi”.
- `lib/screens/booking_screen.dart`: đặt phòng và tính tiền VND.
- `lib/screens/payment_screen.dart`: gọi API thanh toán.
- `lib/screens/my_trips_screen.dart`: lịch sử đặt phòng, hỗ trợ hủy đơn.
- `lib/screens/voucher_screen.dart`: lấy data từ `/api/vouchers`.
- `backend/src/controllers/`: API Node (auth, bookings, vouchers…).*** End Patch
