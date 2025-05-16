# 🍽️ FOODONDOOR: CONSOLIDATED DEVELOPMENT PLAN (2025)

---

## 📋 PRIORITY CHECKLIST FOR COMPLETION & MONITORING

### 🥇 High Priority (Core Flows)
- [x] Customer: Login/OTP (phone, OTP, JWT, FCM token)
- [x] Customer: Home Screen (auto-fetched address, banners, categories, nearby/top-rated restaurants)
- [x] Customer: Address Selection/Management (auto-GPS, manual entry, edit/delete, API integration)
- [x] Customer: Restaurant Browsing & Menu (grouped menu, add to cart)
- [x] Customer: Cart (list, quantity, remove, total, checkout)
- [ ] Customer: Checkout & Order Placement (address selection, payment, order summary, FCM notify vendor)
    - [x] Add/Edit Address Screen Improvements:
        - [x] Set as default address option
        - [x] Address type selector (Home/Work/Other)
        - [x] Use current location for autofill
        - [x] Inline validation and error handling
        - [x] Prevent duplicate/incomplete addresses
    - [ ] Address Selection Enhancements:
        - [x] Map-based selection
        - [x] Indicate/set default address in list
    - [ ] Checkout UX:
        - [ ] Allow editing cart from checkout
        - [ ] Show payment summary before placing order
        - [ ] Show 'Track Order' after placement
    - [ ] Order Placement Flow:
        - [ ] Confirmation dialog before final order
        - [ ] Loading/progress indicator during placement
        - [ ] Success/failure feedback after order
        - [ ] FCM notification to vendor (backend)
    
- [ ] Customer: Order Tracking (status polling, live tracking basic)
- [x] Customer: Orders List & Details (history, reorder, rate) 
- [x] Customer: Profile (view/update info, manage addresses, logout)
- [x] Vendor: Login/OTP (role=vendor, JWT, FCM token)
- [x] Vendor: Dashboard (orders today, revenue, completed vs pending)
- [x] Vendor: Order Management (list, accept/reject, mark ready)
- [x] Vendor: Menu Management (CRUD items/categories, image upload)
- [x] Vendor: Profile (update info, open hours, delivery radius)

### 🥈 Medium Priority (Enhancements & UX)
- [ ] Customer: Address auto-complete & map picker (Google Maps integration)
- [ ] Customer: Promotions & Coupons (apply at checkout, fetch from API)
- [ ] Customer: Wallet & Transactions (balance, recharge, history)
- [ ] Customer: Support Chat/Ticket (basic UI, API integration)
- [ ] Customer: Order Tracking (live map with delivery agent)
- [ ] Customer: Ratings & Reviews (after order, show in UI)
- [ ] Customer: Push Notification Center (view past notifications, deep link handling)
- [ ] Customer: Error Handling & Empty States (custom error widgets, skeletons)
- [ ] Customer: Multi-language/i18n support
- [ ] Vendor: Promotions/Coupons Management
- [ ] Vendor: Analytics Dashboard (charts, order trends)
- [ ] Vendor: Push Notification Center
- [ ] Vendor: Error/empty states

### 🥉 Future/Advanced (Optional or Later Phases)
- [ ] Customer: Referral & Loyalty System
- [ ] Customer: Scheduled Orders/Reminders
- [ ] Customer: Advanced Search & Filters (cuisine, rating, delivery time)
- [ ] Customer: Admin/support escalation UI
- [ ] Vendor: Advanced analytics, export data
- [ ] Delivery: Login/OTP, Orders list, Pickup/Delivery flow, Earnings, Notifications
- [ ] Delivery: Live location tracking (map), status updates
- [ ] Admin Panel: User/vendor/order management, analytics
- [ ] Core: Real-time order tracking (WebSockets)
- [ ] Core: Multi-database (MongoDB) readiness
- [ ] Core: CI/CD, Docker, Production monitoring

---

## 1. Core Principles & Architecture
- **Custom User System**: No Django built-in User/auth; use custom profile models (customer, vendor, delivery) with custom JWT/OTP logic.
- **Tech Stack**: Django (REST API), PostgreSQL (MongoDB-ready), Flutter (3 apps), FCM for push notifications.
- **Modular Apps**: `auth_app`, `customer_app`, `vendor_app`, `delivery_app`, `core`.
- **RESTful APIs**: JWT auth, FCM, real-time features (WebSockets for tracking/support in future).
- **Documentation**: Maintain `api_endpoints.md` and `work_summary.md` for all changes and endpoints.

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

---

## 2. Feature Roadmap & UI/UX (All Apps)

### 2.1 Customer App

| Screen/Feature         | Description / UI Notes                                                                 |
|-----------------------|---------------------------------------------------------------------------------------|
| Splash/Onboarding     | Auto-login if token; fetch location; intro screens                                    |
| Login/OTP             | Phone login, OTP input, error handling                                                |
| Home                  | Banners, categories, featured, nearby, search bar, location/address display           |
| Restaurant Details    | Menu grouped by category, add to cart, ratings                                        |
| Cart                  | List, quantity, remove, total, proceed to checkout                                    |
| Address Management    | GPS fetch, manual entry, list, edit, delete                                           |
| Checkout              | Show cart, select address, confirm, payment, order summary                            |
| Order Tracking        | Poll status, live tracking, map, delivery agent info                                  |
| Past Orders           | List, reorder, rate, review                                                           |
| Profile               | View/update info, logout, manage addresses                                            |
| Notifications         | List, mark as read, push notification integration                                     |
| Payments & Wallet     | Payment gateway, wallet, coupons, transaction history                                 |
| Support               | Chat/ticket, FAQ, contact support                                                     |

#### UI/UX Enhancements Needed
- Consistent bottom navigation bar.
- Modern, brand-aligned color scheme and typography.
- Smooth state management (Provider/Riverpod).
- Error handling for network/auth failures.
- Loading skeletons for API fetches.
- Push notification integration (order updates, promos).
- Address auto-complete and map picker.
- Friendly empty and error states.

---

### 2.2 Vendor App

| Screen/Feature         | Description / UI Notes                                                                 |
|-----------------------|---------------------------------------------------------------------------------------|
| Login/OTP             | Phone login, OTP, JWT                                                                 |
| Profile               | View/edit vendor info, logout                                                         |
| Restaurant Details    | View/edit restaurant info, upload images                                               |
| Menu Management       | CRUD for menu and categories, photo upload, availability toggle                       |
| Orders                | List, accept/reject, mark ready, filter by status                                     |
| Analytics/Dashboard   | Sales, top items, order trends, charts                                                |
| Promotions            | Create/view promotions, manage coupons                                                |
| Notifications         | List, push notification integration                                                   |

#### UI/UX Enhancements Needed
- Dashboard with analytics and charts.
- Order status color coding and quick actions.
- Menu item photo cropper and preview.
- Push notification integration.
- Modern, clean UI with vendor branding.

---

### 2.3 Delivery App

| Screen/Feature         | Description / UI Notes                                                                 |
|-----------------------|---------------------------------------------------------------------------------------|
| Login/OTP             | Phone login, OTP, JWT                                                                 |
| Profile               | View/edit info, logout                                                                |
| Orders                | List, assign, pickup, deliver, status update                                          |
| Earnings              | Earnings summary, payout requests                                                     |
| Notifications         | List, push notification integration                                                   |
| Live Tracking         | Update location, map for delivery                                                     |

#### UI/UX Enhancements Needed
- Bottom navigation bar (Pending, Ongoing, Completed, Earnings, Notifications, Profile).
- Live map tracking for deliveries.
- Order status timeline.
- Push notification integration.
- Modern, clean UI.

---

## 3. Advanced & Future Features
- **Real-time Order Tracking**: WebSockets for live updates (customer, vendor, delivery).
- **Payments**: Integrate payment gateway (Razorpay/Stripe), wallet, refunds.
- **Promotions/Referral**: Coupons, referral system, loyalty points.
- **Multi-language Support**: i18n for all apps.
- **Scheduled Tasks**: Order reminders, auto-cancel, etc.
- **Admin Panel**: Web dashboard for super-admins.
- **Analytics**: For vendors and admin.
- **Support Chat**: Real-time support for customers/vendors.
- **Migration to MongoDB**: Use JSONField for flexibility now, plan for MongoDB switch later.

---

## 4. Implementation Sequence (Recommended)
1. **Complete all pending core endpoints** (JWT refresh/logout, FCM token, profile update/delete, etc.).
2. **UI/UX Improvements**: Update all apps with modern, consistent UI, navigation, error handling, and push notifications.
3. **Advanced Features**: Payments, wallet, analytics, promotions, real-time tracking.
4. **Delivery App**: Finalize all delivery agent flows and tracking.
5. **Admin Panel & Analytics**: Build web dashboard for management.
6. **Testing & QA**: Automated tests, manual QA, bug fixes.
7. **Documentation**: Keep `api_endpoints.md` and `work_summary.md` up-to-date.
8. **Prepare for MongoDB Migration** (if needed).

---

## 5. References
- [helloharendra/Complete-Food-Delivery-App-Flutter](https://github.com/helloharendra/Complete-Food-Delivery-App-Flutter) (for UI/UX, feature ideas, and best practices)
- Your current API and work summary markdowns.

---

## 6. Next Steps
- Review this consolidated plan.
- Update your `api_endpoints.md` to reflect any missing endpoints or features.
- Prioritize pending backend endpoints and UI/UX improvements.
- Begin implementing advanced features and delivery app flows.

