# FoodOnDoor Backend Plan (2025-05-08)

## 1. Overview & Principles
- **Architecture:**
  - `auth_app`: Handles all authentication (OTP, JWT, registration, vendor profile, restaurant/menu/category/order management for vendors)
  - `customer_app`: Handles all customer-facing features (profile, addresses, cart, orders, reviews, notifications, payments, search, etc.)
  - `delivery_auth`: Handles delivery agent features (auth, profile, assigned orders, status updates, location tracking, notifications)
- **No Django built-in User/auth system**: All roles use custom profile models, custom JWT/OTP logic.
- **RESTful API** with JWT auth, FCM push notifications.
- **Real-time features** (order tracking, delivery location, support chat) via WebSockets (future).

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
