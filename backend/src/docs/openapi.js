import dotenv from "dotenv";
dotenv.config();

const port = process.env.PORT || 4000;
const serverUrl = `http://localhost:${port}`;

// Minimal OpenAPI spec covering core endpoints
export const openApiSpec = {
  openapi: "3.0.3",
  info: {
    title: "StayEasy API",
    version: "1.0.0",
    description:
      "OpenAPI cho backend StayEasy. Bao gồm các endpoint chính: xác thực, đặt phòng, thanh toán, phòng và khách sạn.",
  },
  servers: [
    { url: `${serverUrl}/api`, description: "Local API" },
  ],
  tags: [
    { name: "Auth", description: "Đăng nhập/Đăng ký" },
    { name: "Bookings", description: "Đặt phòng" },
    { name: "Payments", description: "Thanh toán" },
    { name: "Rooms", description: "Phòng" },
    { name: "Hotels", description: "Khách sạn" },
    { name: "Users", description: "Người dùng" },
    { name: "Admin", description: "Quản trị" },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
      },
    },
    schemas: {
      ApiError: {
        type: "object",
        properties: {
          message: { type: "string" },
          code: { type: "string" },
          errors: {
            type: "array",
            items: {
              type: "object",
              properties: {
                path: { type: "string" },
                message: { type: "string" },
              },
            },
          },
        },
      },
      BookingCreateRequest: {
        type: "object",
        required: ["room_id", "check_in", "check_out"],
        properties: {
          room_id: { type: "integer", minimum: 1 },
          check_in: { type: "string", format: "date" },
          check_out: { type: "string", format: "date" },
        },
      },
      UpdateBookingStatusRequest: {
        type: "object",
        required: ["status"],
        properties: {
          status: { type: "string", enum: ["pending", "confirmed", "cancelled"] },
        },
      },
      CreatePaymentRequest: {
        type: "object",
        required: ["booking_id", "amount", "method"],
        properties: {
          booking_id: { type: "integer", minimum: 1 },
          amount: { type: "number", minimum: 0 },
          currency: { type: "string", default: "USD" },
          method: { type: "string", enum: ["offline", "online"] },
        },
      },
      ConfirmPaymentDemoRequest: {
        type: "object",
        required: ["booking_id", "amount"],
        properties: {
          booking_id: { type: "integer", minimum: 1 },
          amount: { type: "number", minimum: 0 },
        },
      },
      // Admin: Users & Hotels schemas
      AdminCreateUserRequest: {
        type: "object",
        required: ["name", "email", "password"],
        properties: {
          name: { type: "string" },
          email: { type: "string", format: "email" },
          password: { type: "string" },
          role: { type: "string", enum: ["customer", "hotel_manager", "admin"], default: "customer" },
          phone: { type: "string" },
          address: { type: "string" },
        },
      },
      AdminUpdateUserRequest: {
        type: "object",
        properties: {
          name: { type: "string" },
          phone: { type: "string" },
          address: { type: "string" },
        },
      },
      ChangeUserRoleRequest: {
        type: "object",
        required: ["role"],
        properties: {
          role: { type: "string", enum: ["customer", "hotel_manager", "admin"] },
        },
      },
      AssignHotelManagerRequest: {
        type: "object",
        required: ["user_id"],
        properties: {
          user_id: { type: "integer", minimum: 1 },
        },
      },
      CreateHotelRequest: {
        type: "object",
        required: ["name"],
        properties: {
          name: { type: "string" },
          description: { type: "string" },
          address: { type: "string" },
          city: { type: "string" },
          country: { type: "string" },
          rating: { type: "number", minimum: 0, maximum: 5 },
        },
      },
      UpdateHotelRequest: {
        type: "object",
        properties: {
          name: { type: "string" },
          description: { type: "string" },
          address: { type: "string" },
          city: { type: "string" },
          country: { type: "string" },
          image_url: { type: "string" },
          rating: { type: "number", minimum: 0, maximum: 5 },
          latitude: { type: "number" },
          longitude: { type: "number" },
        },
      },
      AdminDashboardStats: {
        type: "object",
        properties: {
          users: { type: "integer" },
          hotels: { type: "integer" },
          rooms: { type: "integer" },
          bookings: { type: "integer" },
          revenueAll: { type: "number" },
          revenueToday: { type: "number" },
          asOf: { type: "string", format: "date" },
        },
      },
      RevenueItem: {
        type: "object",
        properties: {
          period: { type: "string" },
          revenue: { type: "number" },
        },
      },
      HotelOccupancyItem: {
        type: "object",
        properties: {
          hotel_id: { type: "integer" },
          name: { type: "string" },
          total_rooms: { type: "integer" },
          occupied_rooms: { type: "integer" },
          occupancy_rate: { type: "number" },
        },
      },
      TopHotelItem: {
        type: "object",
        properties: {
          hotel_id: { type: "integer" },
          name: { type: "string" },
          revenue: { type: "number" },
          bookings: { type: "integer" },
        },
      },
      UsersGrowthItem: {
        type: "object",
        properties: {
          period: { type: "string" },
          new_users: { type: "integer" },
        },
      },
    },
  },
  paths: {
    "/auth/login": {
      post: {
        tags: ["Auth"],
        summary: "Đăng nhập",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "password"],
                properties: {
                  email: { type: "string", format: "email" },
                  password: { type: "string" },
                },
              },
            },
          },
        },
        responses: {
          200: {
            description: "Đăng nhập thành công",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    token: { type: "string" },
                    user: { type: "object" },
                  },
                },
              },
            },
          },
          401: { description: "Sai thông tin" },
        },
      },
    },
    "/bookings": {
      post: {
        tags: ["Bookings"],
        summary: "Tạo đặt phòng",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": { schema: { $ref: "#/components/schemas/BookingCreateRequest" } },
          },
        },
        responses: {
          201: { description: "Đặt phòng thành công" },
          400: { description: "Lỗi input", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } },
          409: { description: "Phòng đã được đặt" },
        },
      },
    },
    "/bookings/{id}/status": {
      patch: {
        tags: ["Bookings"],
        summary: "Cập nhật trạng thái đặt phòng",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "integer", minimum: 1 } },
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": { schema: { $ref: "#/components/schemas/UpdateBookingStatusRequest" } },
          },
        },
        responses: { 200: { description: "Cập nhật thành công" } },
      },
    },
    "/payments": {
      post: {
        tags: ["Payments"],
        summary: "Tạo thanh toán",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": { schema: { $ref: "#/components/schemas/CreatePaymentRequest" } },
          },
        },
        responses: { 200: { description: "Tạo payment thành công" } },
      },
    },
    "/payments/confirm-demo": {
      post: {
        tags: ["Payments"],
        summary: "Xác nhận thanh toán demo",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": { schema: { $ref: "#/components/schemas/ConfirmPaymentDemoRequest" } },
          },
        },
        responses: { 200: { description: "Thanh toán hoàn tất" } },
      },
    },
    "/rooms/available": {
      get: {
        tags: ["Rooms"],
        summary: "Danh sách phòng trống",
        parameters: [
          { name: "hotel_id", in: "query", schema: { type: "integer", minimum: 1 } },
          { name: "check_in", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "check_out", in: "query", required: true, schema: { type: "string", format: "date" } },
        ],
        responses: { 200: { description: "Danh sách phòng trống" } },
      },
    },
    "/hotels": {
      get: {
        tags: ["Hotels"],
        summary: "Danh sách khách sạn",
        parameters: [
          { name: "q", in: "query", schema: { type: "string" } },
          { name: "city", in: "query", schema: { type: "string" } },
          { name: "page", in: "query", schema: { type: "integer", default: 1 } },
          { name: "limit", in: "query", schema: { type: "integer", default: 20 } },
        ],
        responses: { 200: { description: "Danh sách khách sạn" } },
      },
    },
    "/hotels/cities": {
      get: {
        tags: ["Hotels"],
        summary: "Thành phố có khách sạn",
        parameters: [
          { name: "q", in: "query", schema: { type: "string" } },
          { name: "limit", in: "query", schema: { type: "integer", minimum: 1 } },
        ],
        responses: { 200: { description: "Danh sách thành phố" } },
      },
    },
    "/rooms/{id}/images": {
      get: {
        tags: ["Rooms"],
        summary: "Lấy danh sách ảnh của phòng",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "integer" } },
        ],
        responses: {
          200: { description: "OK" },
          400: { description: "Bad Request" },
          403: { description: "Forbidden" },
          404: { description: "Not Found" },
        },
      },
    },
    "/rooms/images/upload": {
      post: {
        tags: ["Rooms"],
        summary: "Tải lên 1 ảnh phòng",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "multipart/form-data": {
              schema: {
                type: "object",
                properties: {
                  room_id: { type: "integer" },
                  file: { type: "string", format: "binary" },
                },
                required: ["room_id", "file"],
              },
            },
          },
        },
        responses: { 201: { description: "Created" }, 400: { description: "Bad Request" }, 403: { description: "Forbidden" }, 404: { description: "Not Found" } },
      },
    },
    "/rooms/images/upload-many": {
      post: {
        tags: ["Rooms"],
        summary: "Tải lên nhiều ảnh phòng",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "multipart/form-data": {
              schema: {
                type: "object",
                properties: {
                  room_id: { type: "integer" },
                  files: {
                    type: "array",
                    items: { type: "string", format: "binary" },
                  },
                },
                required: ["room_id", "files"],
              },
            },
          },
        },
        responses: { 201: { description: "Created" }, 400: { description: "Bad Request" }, 403: { description: "Forbidden" }, 404: { description: "Not Found" } },
      },
    },
    "/rooms/images/{imageId}": {
      patch: {
        tags: ["Rooms"],
        summary: "Thay thế ảnh phòng",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "imageId", in: "path", required: true, schema: { type: "integer" } },
        ],
        requestBody: {
          required: true,
          content: {
            "multipart/form-data": {
              schema: {
                type: "object",
                properties: { file: { type: "string", format: "binary" } },
                required: ["file"],
              },
            },
          },
        },
        responses: { 200: { description: "OK" }, 400: { description: "Bad Request" }, 403: { description: "Forbidden" }, 404: { description: "Not Found" } },
      },
      delete: {
        tags: ["Rooms"],
        summary: "Xóa ảnh phòng",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "imageId", in: "path", required: true, schema: { type: "integer" } },
        ],
        responses: { 200: { description: "OK" }, 400: { description: "Bad Request" }, 403: { description: "Forbidden" }, 404: { description: "Not Found" } },
      },
    },
    "/hotels/{id}/images": {
      get: {
        tags: ["Hotels"],
        summary: "Lấy danh sách ảnh của khách sạn",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "integer" } },
        ],
        responses: { 200: { description: "OK" }, 400: { description: "Bad Request" }, 403: { description: "Forbidden" }, 404: { description: "Not Found" } },
      },
    },
    "/hotels/images/upload": {
      post: {
        tags: ["Hotels"],
        summary: "Tải lên 1 ảnh khách sạn",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "multipart/form-data": {
              schema: {
                type: "object",
                properties: {
                  hotel_id: { type: "integer" },
                  file: { type: "string", format: "binary" },
                },
                required: ["hotel_id", "file"],
              },
            },
          },
        },
        responses: { 201: { description: "Created" }, 400: { description: "Bad Request" }, 403: { description: "Forbidden" }, 404: { description: "Not Found" } },
      },
    },
    "/hotels/images/upload-many": {
      post: {
        tags: ["Hotels"],
        summary: "Tải lên nhiều ảnh khách sạn",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "multipart/form-data": {
              schema: {
                type: "object",
                properties: {
                  hotel_id: { type: "integer" },
                  files: {
                    type: "array",
                    items: { type: "string", format: "binary" },
                  },
                },
                required: ["hotel_id", "files"],
              },
            },
          },
        },
        responses: { 201: { description: "Created" }, 400: { description: "Bad Request" }, 403: { description: "Forbidden" }, 404: { description: "Not Found" } },
      },
    },
    "/hotels/images/{imageId}": {
      patch: {
        tags: ["Hotels"],
        summary: "Thay thế ảnh khách sạn",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "imageId", in: "path", required: true, schema: { type: "integer" } },
        ],
        requestBody: {
          required: true,
          content: {
            "multipart/form-data": {
              schema: {
                type: "object",
                properties: { file: { type: "string", format: "binary" } },
                required: ["file"],
              },
            },
          },
        },
        responses: { 200: { description: "OK" }, 400: { description: "Bad Request" }, 403: { description: "Forbidden" }, 404: { description: "Not Found" } },
      },
      delete: {
        tags: ["Hotels"],
        summary: "Xóa ảnh khách sạn",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "imageId", in: "path", required: true, schema: { type: "integer" } },
        ],
        responses: { 200: { description: "OK" }, 400: { description: "Bad Request" }, 403: { description: "Forbidden" }, 404: { description: "Not Found" } },
      },
    },
    "/users/me": {
      get: {
        tags: ["Users"],
        summary: "Lấy hồ sơ người dùng hiện tại",
        security: [{ bearerAuth: [] }],
        responses: {
          200: { description: "Thông tin hồ sơ hiện tại" },
          404: { description: "Không tìm thấy", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } },
        },
      },
      patch: {
        tags: ["Users"],
        summary: "Cập nhật hồ sơ người dùng hiện tại",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  name: { type: "string" },
                  phone: { type: "string" },
                  address: { type: "string" },
                  email: { type: "string", format: "email" },
                },
              },
            },
          },
        },
        responses: {
          200: { description: "Cập nhật hồ sơ thành công" },
          400: { description: "Lỗi input", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } },
          409: { description: "Xung đột dữ liệu", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } },
        },
      },
    },
    "/users/me/transactions": {
      get: {
        tags: ["Users"],
        summary: "Lấy danh sách giao dịch/đặt phòng của người dùng",
        security: [{ bearerAuth: [] }],
        responses: {
          200: { description: "Danh sách giao dịch gần đây" },
        },
      },
    },
    // Admin: Users management
    "/admin/users": {
      get: {
        tags: ["Admin"],
        summary: "Danh sách người dùng",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "q", in: "query", schema: { type: "string" } },
          { name: "role", in: "query", schema: { type: "string", enum: ["customer","hotel_manager","admin"] } },
          { name: "page", in: "query", schema: { type: "integer", default: 1 } },
          { name: "limit", in: "query", schema: { type: "integer", default: 20 } },
        ],
        responses: { 200: { description: "OK" } },
      },
      post: {
        tags: ["Admin"],
        summary: "Tạo người dùng (admin)",
        security: [{ bearerAuth: [] }],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/AdminCreateUserRequest" } } } },
        responses: {
          201: { description: "Created" },
          400: { description: "Bad Request", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } },
          409: { description: "Conflict", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } },
        },
      },
    },
    "/admin/users/{id}": {
      get: {
        tags: ["Admin"],
        summary: "Chi tiết người dùng",
        security: [{ bearerAuth: [] }],
        parameters: [ { name: "id", in: "path", required: true, schema: { type: "integer" } } ],
        responses: { 200: { description: "OK" }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
      },
      patch: {
        tags: ["Admin"],
        summary: "Cập nhật người dùng",
        security: [{ bearerAuth: [] }],
        parameters: [ { name: "id", in: "path", required: true, schema: { type: "integer" } } ],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/AdminUpdateUserRequest" } } } },
        responses: { 200: { description: "OK" }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
      },
      delete: {
        tags: ["Admin"],
        summary: "Xóa người dùng",
        security: [{ bearerAuth: [] }],
        parameters: [ { name: "id", in: "path", required: true, schema: { type: "integer" } } ],
        responses: { 200: { description: "OK" }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
      },
    },
    "/admin/users/{id}/role": {
      patch: {
        tags: ["Admin"],
        summary: "Đổi vai trò người dùng",
        security: [{ bearerAuth: [] }],
        parameters: [ { name: "id", in: "path", required: true, schema: { type: "integer" } } ],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/ChangeUserRoleRequest" } } } },
        responses: { 200: { description: "OK" }, 400: { description: "Bad Request", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
      },
    },
    "/admin/users/{id}/deactivate": {
      patch: {
        tags: ["Admin"],
        summary: "Khóa mềm tài khoản người dùng",
        security: [{ bearerAuth: [] }],
        parameters: [ { name: "id", in: "path", required: true, schema: { type: "integer" } } ],
        responses: { 200: { description: "OK" }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
      },
     },
     // Admin: Bookings list
     "/admin/bookings": {
       get: {
         tags: ["Admin"],
         summary: "Danh sách đặt phòng",
         security: [{ bearerAuth: [] }],
         parameters: [
           { name: "userId", in: "query", schema: { type: "integer" } },
           { name: "user_id", in: "query", schema: { type: "integer" } },
         ],
         responses: { 200: { description: "OK" } },
       },
     },
     // Admin: Hotels CRUD
     "/admin/hotels": {
       post: {
         tags: ["Admin"],
         summary: "Tạo khách sạn",
         security: [{ bearerAuth: [] }],
         requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/CreateHotelRequest" } } } },
         responses: { 201: { description: "Created" }, 400: { description: "Bad Request", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
       },
     },
     "/admin/hotels/{id}": {
       patch: {
         tags: ["Admin"],
         summary: "Cập nhật khách sạn",
         security: [{ bearerAuth: [] }],
         parameters: [ { name: "id", in: "path", required: true, schema: { type: "integer" } } ],
         requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/UpdateHotelRequest" } } } },
         responses: { 200: { description: "OK" }, 400: { description: "Bad Request", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
       },
       delete: {
         tags: ["Admin"],
         summary: "Xóa khách sạn",
         security: [{ bearerAuth: [] }],
         parameters: [ { name: "id", in: "path", required: true, schema: { type: "integer" } } ],
         responses: { 200: { description: "OK" }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
       },
     },
    // Admin: Hotel Managers
    "/admin/hotels/{id}/managers": {
      get: {
        tags: ["Admin"],
        summary: "Danh sách quản lý khách sạn theo khách sạn",
        security: [{ bearerAuth: [] }],
        parameters: [ { name: "id", in: "path", required: true, schema: { type: "integer" } } ],
        responses: { 200: { description: "OK" }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
      },
      post: {
        tags: ["Admin"],
        summary: "Gán quản lý cho khách sạn",
        security: [{ bearerAuth: [] }],
        parameters: [ { name: "id", in: "path", required: true, schema: { type: "integer" } } ],
        requestBody: { required: true, content: { "application/json": { schema: { $ref: "#/components/schemas/AssignHotelManagerRequest" } } } },
        responses: { 201: { description: "Created" }, 400: { description: "Bad Request", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
      },
    },
    "/admin/hotels/{id}/managers/{userId}": {
      delete: {
        tags: ["Admin"],
        summary: "Hủy gán quản lý khỏi khách sạn",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "integer" } },
          { name: "userId", in: "path", required: true, schema: { type: "integer" } },
        ],
        responses: { 200: { description: "OK" }, 404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } } },
      },
    },
    "/admin/hotel-managers/export": {
      get: {
        tags: ["Admin"],
        summary: "Xuất danh sách quản lý khách sạn (toàn hệ thống)",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "format", in: "query", schema: { type: "string", enum: ["csv","xlsx"], default: "csv" } },
        ],
        responses: {
          200: {
            description: "File xuất (CSV/XLSX)",
            content: {
              "text/csv": { schema: { type: "string", format: "binary" } },
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": { schema: { type: "string", format: "binary" } },
            },
          },
        },
      },
    },
    "/admin/hotels/{id}/managers/export": {
      get: {
        tags: ["Admin"],
        summary: "Xuất danh sách quản lý của 1 khách sạn",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "integer" } },
          { name: "format", in: "query", schema: { type: "string", enum: ["csv","xlsx"], default: "csv" } },
        ],
        responses: {
          200: {
            description: "File xuất (CSV/XLSX)",
            content: {
              "text/csv": { schema: { type: "string", format: "binary" } },
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": { schema: { type: "string", format: "binary" } },
            },
          },
          404: { description: "Not Found", content: { "application/json": { schema: { $ref: "#/components/schemas/ApiError" } } } },
        },
      },
    },
    // Admin: Stats & Export
    "/admin/stats/dashboard": {
      get: {
        tags: ["Admin"],
        summary: "Thống kê tổng quan dashboard",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "OK",
            content: { "application/json": { schema: { $ref: "#/components/schemas/AdminDashboardStats" } } },
          },
        },
      },
    },
    "/admin/stats/revenue": {
      get: {
        tags: ["Admin"],
        summary: "Doanh thu theo thời gian",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "from", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "to", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "group", in: "query", schema: { type: "string", enum: ["day","month"], default: "day" } },
        ],
        responses: {
          200: {
            description: "OK",
            content: {
              "application/json": { schema: { type: "array", items: { $ref: "#/components/schemas/RevenueItem" } } },
            },
          },
        },
      },
    },
    "/admin/stats/occupancy": {
      get: {
        tags: ["Admin"],
        summary: "Tỷ lệ lấp đầy theo khách sạn",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "date", in: "query", schema: { type: "string", format: "date" } },
          { name: "from", in: "query", schema: { type: "string", format: "date" } },
          { name: "to", in: "query", schema: { type: "string", format: "date" } },
        ],
        responses: {
          200: {
            description: "OK",
            content: {
              "application/json": { schema: { type: "array", items: { $ref: "#/components/schemas/HotelOccupancyItem" } } },
            },
          },
        },
      },
    },
    "/admin/stats/top-hotels": {
      get: {
        tags: ["Admin"],
        summary: "Top khách sạn theo doanh thu/đặt phòng",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "from", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "to", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "limit", in: "query", schema: { type: "integer", default: 5 } },
        ],
        responses: {
          200: {
            description: "OK",
            content: {
              "application/json": { schema: { type: "array", items: { $ref: "#/components/schemas/TopHotelItem" } } },
            },
          },
        },
      },
    },
    "/admin/stats/users-growth": {
      get: {
        tags: ["Admin"],
        summary: "Tăng trưởng người dùng",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "from", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "to", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "group", in: "query", schema: { type: "string", enum: ["month"], default: "month" } },
        ],
        responses: {
          200: {
            description: "OK",
            content: {
              "application/json": { schema: { type: "array", items: { $ref: "#/components/schemas/UsersGrowthItem" } } },
            },
          },
        },
      },
    },
    "/admin/stats/revenue/export": {
      get: {
        tags: ["Admin"],
        summary: "Xuất doanh thu theo thời gian",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "from", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "to", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "group", in: "query", schema: { type: "string", enum: ["day","month"], default: "day" } },
          { name: "format", in: "query", schema: { type: "string", enum: ["csv","xlsx"], default: "csv" } },
        ],
        responses: {
          200: {
            description: "File xuất (CSV/XLSX)",
            content: {
              "text/csv": { schema: { type: "string", format: "binary" } },
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": { schema: { type: "string", format: "binary" } },
            },
          },
        },
      },
    },
    "/admin/stats/revenue/export-summary": {
      get: {
        tags: ["Admin"],
        summary: "Xuất tổng hợp doanh thu",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "from", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "to", in: "query", required: true, schema: { type: "string", format: "date" } },
          { name: "group", in: "query", schema: { type: "string", enum: ["day","month"], default: "day" } },
          { name: "format", in: "query", schema: { type: "string", enum: ["csv","xlsx"], default: "csv" } },
        ],
        responses: {
          200: {
            description: "File xuất (CSV/XLSX)",
            content: {
              "text/csv": { schema: { type: "string", format: "binary" } },
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": { schema: { type: "string", format: "binary" } },
            },
          },
        },
      },
    }
  }

};