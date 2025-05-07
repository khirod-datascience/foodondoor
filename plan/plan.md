# 🍽️ FOODONDOOR: FULL DEVELOPMENT ROADMAP (Flutter + Django + FCM + OTP + MongoDB Ready)

---

## 🧩 CORE SETUP (PHASE 1: SHARED INITIALIZATION)

### ✅ Backend (Django)
- Initialize Django project: `foodondoor_backend/`
- Create 4 Django apps:
  - `auth_app`: OTP logic + role-based login
  - `customer_app`: cart, orders, addresses
  - `vendor_app`: menu, orders, profile
  - `delivery_app`: delivery tracking
- Shared `core/` app:
  - Models: `User`, `Restaurant`, `MenuItem`, `Order`, `Cart`, `DeliveryAgent`, `Address`
  - Use `AbstractUser` + role field (customer, vendor, delivery)
- Setup PostgreSQL DB with `JSONField` & loose coupling for MongoDB-readiness
- Setup JWT Auth with `rest_framework_simplejwt` + custom claims (role, phone)
- Integrate Firebase FCM & device token registration
- Write modular serializers & `.select_related()` for efficiency

### ✅ Frontend (Flutter - All 3 Apps)
- Initialize 3 Flutter projects:
  - `foodondoor_customer_app`
  - `foodondoor_vendor_app`
  - `foodondoor_delivery_app`
- Common packages:
  - `dio` (with interceptors)
  - `flutter_secure_storage` (store JWT)
  - `provider` or `riverpod`
  - `firebase_messaging`, `flutter_local_notifications`
  - `geolocator`, `google_maps_flutter`
  - `cached_network_image`, `image_picker`

---

## 📱 CUSTOMER APP – SCREEN-BY-SCREEN ROADMAP (PHASE 2)

### 1. Splash Screen
- Auto-login if token found
- Fetch location using `geolocator`

### 2. Login / OTP
- Enter phone → send OTP via Django `/auth/send-otp/`
- Verify OTP → receive JWT → save securely
- Upload device FCM token to `/auth/save-fcm-token/`

### 3. Home Screen
- Show:
  - Auto-fetched address (reverse geocode)
  - Banners → `/customer/banners/`
  - Categories → `/customer/categories/`
  - Nearby restaurants → `/customer/restaurants/nearby/`
  - Top-rated food → `/customer/food/top-rated/`

### 4. Restaurant Detail Screen
- Show menu grouped by category
- Add to cart (store locally → sync to `/customer/cart/`)

### 5. Cart Screen
- List items, quantity controls
- Total price calculation
- “Proceed to Checkout” button

### 6. Address Screen
- Auto-fetch GPS → show address
- Manual address form (with label)
- List saved addresses with edit/remove
- API: `/customer/addresses/`

### 7. Checkout Screen
- Show cart + selected address
- Place order → call `/customer/place-order/`
- On success:
  - Notify vendor via FCM
  - Move to Order Tracking

### 8. Order Tracking Screen
- Poll `/customer/orders/<id>/status/`
- Track order stages: placed → accepted → picked → delivered
- If in transit: track delivery live via `/customer/orders/<id>/track/`

### 9. Past Orders Screen
- List order history
- Reorder option
- Rate restaurant

### 10. Profile Screen
- View/update: name, phone
- Manage saved addresses
- Logout

---

## 🧑‍🍳 VENDOR APP – SCREEN-BY-SCREEN ROADMAP (PHASE 3)

### 1. Login / OTP
- Same OTP flow → role = vendor
- Save JWT securely
- Upload FCM token

### 2. Dashboard Screen
- Show:
  - Orders today
  - Revenue today
  - Completed vs pending

### 3. Order Management
- Tabs: New, Preparing, Completed
- Accept/Reject buttons → `/vendor/orders/<id>/accept/`
- Mark “Ready for Pickup”

### 4. Menu Management
- CRUD on menu items:
  - Name, price, category, image, availability
- Use `image_picker` + `/vendor/menu-items/`

### 5. Profile Screen
- Update:
  - Name, open hours, banner
  - Delivery radius & charges

---

## 🚴‍♂️ DELIVERY APP – SCREEN-BY-SCREEN ROADMAP (PHASE 4)

### 1. Login / OTP
- Validate as `delivery` role
- Save token, upload FCM token

### 2. Assigned Orders
- List of available delivery requests
- Accept → lock assignment via `/delivery/orders/<id>/assign/`

### 3. Pickup Screen
- Show restaurant name, items, address
- Enter OTP (from vendor) → `/delivery/orders/<id>/confirm-pickup/`

### 4. Delivery Screen
- Customer address on map
- OTP verification on delivery → `/delivery/orders/<id>/confirm-delivery/`

### 5. Earnings Screen
- Past deliveries, earnings total
- API: `/delivery/earnings/`

---

## 🔔 FCM NOTIFICATION PLAN (PHASE 5)

| Event            | Sent To         | Message                      |
|------------------|------------------|-------------------------------|
| Order placed     | Vendor           | “New order received”         |
| Order accepted   | Delivery Partner | “New delivery assigned”      |
| Pickup done      | Customer         | “Your order is on the way”   |
| Order delivered  | Customer         | “Order delivered”            |

- Use `firebase_messaging` for background messages
- `flutter_local_notifications` for foreground popups

---

## 🛠️ ADMIN PANEL (PHASE 6)
- Django Admin or Custom Web Panel
- Manage:
  - User roles (ban/delete)
  - Vendor approvals
  - Manual orders
  - Coupon system
  - Analytics reports

---

## 🔄 MONGODB MIGRATION PLAN (PHASE 7)

| Now (PostgreSQL)            | Later (MongoDB)                   |
|-----------------------------|-----------------------------------|
| `models.Model`              | `djongo` or `motor` support       |
| Relational fields (FKs)     | Flatten or embed                 |
| `JSONField` for flexibility | Use native MongoDB documents      |
| Django ORM                  | Wrap with repository pattern      |

- Prepare model interfaces for future service-based architecture
- Avoid tight relational joins for portability

---

## 🧪 BEST PRACTICES (APPLY TO ALL PHASES)
- `Dio` with Interceptors → handle auth/token refresh
- `flutter_secure_storage` for storing tokens
- Central `APIService` class
- Lazy loading with shimmer for images & lists
- Use `provider` or `riverpod` for state
- Validate inputs everywhere
- `.select_related()` in Django for query efficiency
- Modular folder structure: `/screens`, `/models`, `/services`, `/providers`

---

# ✅ PHASE-WISE EXECUTION PLAN SUMMARY

| Phase | Deliverables                                                                 |
|-------|------------------------------------------------------------------------------|
| 1     | Django setup + Auth + 3 Flutter projects scaffolded                         |
| 2     | Full Customer app (login → track order)                                     |
| 3     | Vendor App (login, menu, order handling)                                    |
| 4     | Delivery App (login, pickup, delivery tracking, earnings)                   |
| 5     | FCM integration across all apps                                             |
| 6     | Admin panel (optional but recommended)                                      |
| 7     | MongoDB migration-ready architecture + DTO cleanup                         |
| 8     | CI/CD, Docker, Production Deployment (Render/EC2), Monitoring               |

