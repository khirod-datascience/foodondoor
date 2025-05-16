# FoodOnDoor Backend Plan (2025-05-08)

## Backend Status Summary (2025-05-08)
- **Customer App:** All core endpoints (profile, addresses, cart, order, browsing) implemented except JWT refresh/logout, FCM token, profile update/delete, and advanced features (tracking, payment, wallet, etc.).
- **Vendor App:** All core endpoints (auth, profile, restaurant/menu/category CRUD, orders, dashboard) implemented. Advanced features (analytics, notifications, promotions) in progress.
- **Next Steps:** Complete pending endpoints for customer (see checklist), then proceed to advanced features for both customer and vendor flows.

## 1. Overview & Principles
- **Architecture:**
  - `auth_app`: Handles all authentication (OTP, JWT, registration, vendor profile, restaurant/menu/category/order management for vendors)
  - `customer_app`: Handles all customer-facing features (profile, addresses, cart, orders, reviews, notifications, payments, search, etc.)
  - `delivery_auth`: Handles delivery agent features (auth, profile, assigned orders, status updates, location tracking, notifications)
- **No Django built-in User/auth system**: All roles use custom profile models, custom JWT/OTP logic.
- **RESTful API** with JWT auth, FCM push notifications.
- **Real-time features** (order tracking, delivery location, support chat) via WebSockets (future).

---

## 2. Authentication & User Management (`auth_app`)
- `POST /api/vendor/send_otp/` — Send OTP to vendor
- `POST /api/vendor/verify_otp/` — Verify OTP, return JWT
- `POST /api/vendor/signup/` — Complete vendor registration
- `POST /api/vendor/token/refresh/` — Refresh JWT
- `POST /api/vendor/token/blacklist/` — Logout
- `POST /api/vendor/fcm-token/` — Update FCM token

### Vendor Profile & Restaurant Management
- `GET/PUT /api/vendor/profile/` — View/update vendor profile
- `GET/PUT /api/vendor/restaurant/` — Restaurant details
- `POST /api/vendor/upload-image/` — Upload images
- `GET/POST/PUT/DELETE /api/vendor/menu/` — CRUD menu items
- `GET/POST/PUT/DELETE /api/vendor/categories/` — CRUD food categories

### Vendor Orders & Analytics
- `GET /api/vendor/orders/` — List orders
- `GET /api/vendor/orders/<order_number>/` — Order detail
- `POST /api/vendor/orders/<order_number>/status/` — Update order status (accept, reject, ready, etc.)
- `GET /api/vendor/dashboard/` — Sales, analytics

### Vendor Notifications & Promotions
- `GET /api/vendor/notifications/`
- `GET/POST /api/vendor/promotions/`

---

## 3. Customer App (`customer_app`)

### 3.1 Profile & Addresses
- `GET/PUT /api/customer/profile/`
- `GET/POST/PUT/DELETE /api/customer/addresses/`

### 3.2 Home & Discovery
- `GET /api/customer/home/` — Banners, categories, featured restaurants/foods
- `GET /api/customer/restaurants/` — List/search restaurants
- `GET /api/customer/restaurants/<id>/` — Restaurant details/menu
- `GET /api/customer/categories/` — Food categories
- `GET /api/customer/foods/<id>/` — Food item detail
- `GET /api/customer/search/` — Search/autocomplete

### 3.3 Cart & Orders
- `GET/POST/DELETE /api/customer/cart/`
- `POST /api/customer/place-order/`
- `GET /api/customer/my-orders/`
- `GET /api/customer/orders/<order_number>/`
- `GET /api/customer/orders/<order_number>/track/` — Real-time tracking (future)
- `GET /api/customer/orders/<order_number>/status/` — Polling order status

### 3.4 Payments & Wallet
- `POST /api/customer/payment/verify/`
- `GET /api/customer/wallet/`
- `GET /api/customer/transactions/`
- `GET /api/customer/promotions/`
- `POST /api/customer/apply-coupon/`

### 3.5 Ratings, Reviews, Notifications
- `POST /api/customer/ratings/`
- `POST /api/customer/reviews/`
- `GET /api/customer/notifications/`
- `POST /api/customer/fcm-token/`

### 3.6 Support
- `GET/POST /api/customer/support/` — Support chat/ticket (future)

---

## 4. Delivery App (`delivery_auth`)

### 4.1 Auth & Profile
- `POST /api/delivery/otp/send/`
- `POST /api/delivery/otp/verify/`
- `POST /api/delivery/register/`
- `GET/PUT /api/delivery/profile/`
- `POST /api/delivery/fcm-token/`

### 4.2 Orders & Tracking
- `GET /api/delivery/orders/` — Assigned orders
- `POST /api/delivery/orders/<order_number>/accept/`
- `POST /api/delivery/orders/<order_number>/reject/`
- `POST /api/delivery/orders/<order_number>/status/`
- `POST /api/delivery/location/` — Live location update (future)

### 4.3 Notifications
- `GET /api/delivery/notifications/`

---

## 5. Admin & Static Content (future)
- `GET /api/admin/dashboard/`
- `GET/POST /api/admin/users/`
- `GET/POST /api/admin/restaurants/`
- `GET/POST /api/admin/orders/`
- `GET /api/static/faqs/`
- `GET /api/static/terms/`
- `GET /api/static/support/`

---

## 6. Real-Time & Advanced Features (future)
- **WebSocket endpoints** for:
  - Live order status for customers, vendors, delivery agents
  - Delivery agent live location tracking
  - Support chat
- **Push notifications** (order updates, promotions, etc.)
- **Scheduled tasks** (order reminders, auto-cancel, etc.)
- **Analytics** for vendors/admin
- **Referral, loyalty, and promo systems**
- **Multi-language support**

---

## 7. Recommendations & Next Steps
- Modularize code, keep business logic in respective apps.
- Use `auth_app` only for authentication and vendor logic.
- Implement all endpoints above; prioritize missing or incomplete ones.
- Document all endpoints in `api_endpoints.md` and keep in sync with code.
- Plan for real-time features and advanced analytics as next phase.

---

## 8. Appendix: Endpoint Checklist
- [ ] All endpoints implemented and tested
- [ ] JWT/OTP flows secure and robust
- [ ] Real-time order tracking in place
- [ ] Push notifications functional
- [ ] All business logic separated per app
- [ ] Documentation up-to-date
