# FOODONDOOR - Work Summary

_Last synced: 2025-05-18_

This document tracks the development progress for each app. Features are listed with checkboxes ([x] = complete, [ ] = pending) matching the consolidated plan's checklist for easy monitoring.

## Features Completed (since last sync)

- **Order Tracking Backend Implementation (2025-05-18):**
  - Expanded `Order.status` field to support full order lifecycle (Pending, Accepted, Preparing, Ready for Pickup, Out for Delivery, Delivered, Cancelled, Fulfilled, Paid).
  - Added `delivery_lat` and `delivery_lng` fields to Order for live tracking.
  - Endpoints implemented for:
    - Vendor: update order status (`PATCH /api/vendor/orders/<order_number>/status/`)
    - Delivery: update order status and live location (`PATCH /api/delivery/orders/<order_number>/status/`, `PATCH /api/delivery/orders/<order_number>/location/`)
    - Customer: poll order status (`GET /api/customer/orders/<order_number>/status/`), track order with location (`GET /api/customer/orders/<order_number>/track/`)
  - FCM notification logic integrated for order placement and status changes (vendor/delivery/customer).
  - [x] **Order tracking backend complete. Next: frontend integration for vendor, delivery, and customer apps.**

- **Checkout Cart Editing:**
  - Users can now edit cart items (increment, decrement, remove) directly from the checkout screen's order summary.
  - UI updates live and the total amount recalculates instantly as changes are made.
  - User feedback is shown via snackbar when an item is removed.
  - This completes the planned enhancement for a seamless and user-friendly checkout experience.

1. Backend (Django)
Vendor FCM Token Endpoint:
Confirmed that the vendor backend (auth_app) has a POST endpoint at /auth_app/vendors/<vendor_id>/fcm-token/ handled by UpdateFCMTokenView.
This endpoint updates the fcm_token field of the Vendor model when called with JSON { "fcm_token": "<token>" }.
Delivery and Customer Apps:
Both have similar endpoints (/delivery/fcm-token/update/ and /customer/fcm-token/update/) for updating FCM tokens for their respective users.
These endpoints are already registered and ready to receive tokens.
2. Frontend (Flutter/Dart)
Vendor App (foodondoor_restaurant):
The notification service (simple_notification_service.dart) was previously a stub.
I implemented logic to:
Retrieve the FCM token on app load.
POST the token to the backend using the vendor ID.
Listen for FCM token refresh and update the backend automatically.
Uses the backend URL from Config.baseUrl.
Plan & Next Steps
What Has Been Done
Verified and documented backend FCM token update endpoints for vendor, customer, and delivery.
Implemented full FCM token sync logic in the vendor app frontend.
Token is sent to backend on app start and refresh.
Ensured all logic is robust and runs after authentication and vendor ID are available.
What Will Be Done Next
Update Customer and Delivery Apps (Frontend):
Implement the same FCM token retrieval and backend sync logic in the customer and delivery Flutter apps.
Ensure the token is sent to:
/customer/fcm-token/update/ for customers.
/delivery/fcm-token/update/ for delivery users.
Listen for token refresh and update backend as in the vendor app.
Testing and Verification:
Test all three apps to confirm FCM tokens are updated in the backend on app load and token refresh.
Ensure no duplicate or missing updates.
Why This Matters
Ensures all user types (vendor, customer, delivery) can receive push notifications reliably.
Keeps backend FCM tokens in sync with the device, even if the token changes.


- **Backend JWT Refresh & Logout:**
  - Implemented custom JWT refresh and logout endpoints for vendor (auth_app) using PyJWT, with in-memory blacklist.
  - Registered endpoints in urls.py. No Django auth dependency.

- **Menu Browsing & Address Endpoints:**
  - Created Restaurant, Category, FoodItem models and serializers in vendor_app.
  - Implemented menu browsing endpoints in customer_app (RestaurantListView, RestaurantDetailView, CategoryListView, FoodItemDetailView).
  - Updated customer_app.urls for nested category listing.
  - Address endpoints unified to use latest access token and consistent Authorization header.

- **Reverse Geocode API:**
  - Implemented /api/reverse-geocode/ endpoint in customer_app using geopy/Nominatim. No Django User/auth dependencies.

---

## 📱 Customer App

### High Priority (Core Flows)

#### 2025-05-18: Checkout, Order Placement & Address Logic
- Cart editing from checkout is complete and live.
- Menu browsing endpoints, address endpoints, and reverse geocode API are implemented and tested.
- Backend JWT refresh/logout for vendors is implemented.
- Address logic unified: all address-fetching logic uses the latest access token and consistent Authorization header.
- Add/Edit Address improvements (default, type, validation, autofill) are done.
- Remaining focus: Complete checkout/order placement flow (confirmation dialog, payment summary, FCM notification to vendor, order placement feedback), order tracking (status polling, live tracking), and vendor notification.

- [x] Login/OTP (phone, OTP, JWT, FCM token)
- [x] Home Screen (auto-fetched address, banners, categories, nearby/top-rated restaurants)
- [x] Address Selection/Management (auto-GPS, manual entry, edit/delete, API integration)
- [x] Restaurant Browsing & Menu (grouped menu, add to cart)
- [x] Cart (list, quantity, remove, total, checkout)
- [ ] Checkout & Order Placement (confirmation dialog, payment summary, FCM notify vendor, feedback)
- [ ] Order Tracking (status polling, live tracking basic)
- [x] Orders List & Details (history, reorder, rate)
- [x] Profile (view/update info, manage addresses, logout)

### Medium Priority (Enhancements & UX)
- [ ] Address auto-complete & map picker (Google Maps integration)
- [ ] Promotions & Coupons (apply at checkout, fetch from API)
- [ ] Wallet & Transactions (balance, recharge, history)
- [ ] Support Chat/Ticket (basic UI, API integration)
- [ ] Order Tracking (live map with delivery agent)
- [ ] Ratings & Reviews (after order, show in UI)
- [ ] Push Notification Center (view past notifications, deep link handling)
- [ ] Error Handling & Empty States (custom error widgets, skeletons)
- [ ] Multi-language/i18n support

### Future/Advanced
- [ ] Referral & Loyalty System
- [ ] Scheduled Orders/Reminders
- [ ] Advanced Search & Filters (cuisine, rating, delivery time)
- [ ] Admin/support escalation UI

---

## Next Steps (2025-05-18)

1. **Customer Checkout & Order Placement**
   - Complete all pending UX and backend features for a seamless checkout (confirmation dialog, payment summary, FCM notify vendor, order placement feedback).
   - Ensure address selection and cart editing are fully integrated and bug-free.
2. **Order Tracking**
   - Implement status polling and basic live tracking for customers.
   - Backend: Ensure order status changes are reflected in real time.
3. **Vendor Notification**
   - Complete FCM notification to vendor on new order.
4. **Testing & Error Handling**
   - Test all flows (address, checkout, order, JWT refresh) and improve error handling.

---

## 🧑‍🍳 Vendor App

### High Priority (Core Flows)
- [x] Login/OTP (role=vendor, JWT, FCM token)
- [x] Dashboard (orders today, revenue, completed vs pending)
- [x] Order Management (list, accept/reject, mark ready)
- [x] Menu Management (CRUD items/categories, image upload)
- [x] Profile (update info, open hours, delivery radius)

### Medium Priority (Enhancements & UX)
- [ ] Promotions/Coupons Management
- [ ] Analytics Dashboard (charts, order trends)
- [ ] Push Notification Center
- [ ] Error/empty states
- [ ] Advanced analytics, export data

---

## 🚴 Delivery App

### High Priority (Core Flows)
- [ ] Login/OTP, Orders list, Pickup/Delivery flow, Earnings, Notifications
- [ ] Live location tracking (map), status updates

---

## 🛠️ Core & Admin
- [ ] Admin Panel: User/vendor/order management, analytics
- [ ] Real-time order tracking (WebSockets)
- [ ] Multi-database (MongoDB) readiness
- [ ] CI/CD, Docker, Production monitoring

---

_Keep this summary updated as you complete features and check off items in plan.md._
