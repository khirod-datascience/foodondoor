# Backend Implementation Checklist & Progress Tracker

## Usage Instructions
- Use this file to track the progress of endpoint implementation, features, and changes in the backend.
- Check off items as they are completed.
- Log every significant change, bugfix, or new feature added, with a short description and date.
- Maintain an up-to-date list of current features for quick reference.

---

## 1. Endpoint Implementation Checklist

### Auth & Vendor (auth_app)
- [x] OTP Send (Vendor)
- [x] OTP Verify (Vendor)
- [x] Vendor Signup
- [x] Vendor JWT Refresh/Logout
- [x] Vendor FCM Token
- [x] Vendor Profile (CRUD)
- [x] Restaurant Details (CRUD)
- [x] Upload Image
- [x] Menu CRUD
- [x] Category CRUD
- [x] Orders (List/Detail/Status)
- [x] Vendor Dashboard/Analytics
- [x] Vendor Notifications
- [x] Vendor Promotions

### Customer (customer_app)
- [x] OTP Send (Customer)
- [x] OTP Verify (Customer)
- [x] Customer Signup
- [x] Customer JWT Refresh/Logout
- [ ] Customer FCM Token *(pending)*
- [x] Customer Profile (GET)
- [ ] Customer Profile (PUT/DELETE) *(pending)*
- [x] Addresses (CRUD)
- [x] Home Data
- [x] Restaurant List/Search
- [x] Restaurant Detail/Menu
- [x] Categories
- [x] Food Detail
- [x] Search/Autocomplete
- [x] Cart (CRUD)
- [x] Place Order
- [x] My Orders
- [x] Order Detail
- [ ] Order Tracking (Real-time)
- [ ] Order Status (Polling)
- [ ] Payment Verification
- [ ] Wallet
- [ ] Transactions
- [ ] Promotions/Coupons
- [ ] Ratings/Reviews
- [ ] Notifications
- [ ] Support Chat

### Delivery (delivery_auth)
- [ ] OTP Send (Delivery)
- [ ] OTP Verify (Delivery)
- [ ] Delivery Agent Register
- [ ] Delivery JWT Refresh/Logout
- [ ] Delivery FCM Token
- [ ] Delivery Profile (CRUD)
- [ ] Assigned Orders (List)
- [ ] Accept/Reject Order
- [ ] Update Order Status
- [ ] Location Update (Real-time)
- [ ] Notifications

### Admin & Static (future)
- [ ] Admin Dashboard
- [ ] Admin Users/Restaurants/Orders
- [ ] Static Content (FAQs, Terms, Support)

---

## 2. Current Features (as of 2025-05-07)
- Custom OTP/JWT authentication (all roles)
- Vendor registration and profile management
- Customer registration, profile, addresses, cart, and order placement
- Delivery agent registration and basic order assignment
- Restaurant/menu/category/food management
- Basic order management (place, view, status)
- Push notification token endpoints
- Home data, search, and restaurant/food browsing

---

## 3. Progress Log

### 2025-05-08
- [SUMMARY] All core customer endpoints (profile, addresses, cart, order, browsing) implemented except JWT refresh/logout, FCM token, profile update/delete, and advanced features (tracking, payment, wallet, etc.). Checklist updated. See work summary for details.

### 2025-05-07
- [INIT] Created backend implementation checklist and progress tracker.
- [PLAN] Saved new backend_plan.md in project root.
- [ANALYSIS] Compared planned endpoints with current implementation; identified missing features and modularization needs.

### [Add new entries below as you make changes]
- [DATE] [FEATURE/BUGFIX/CHANGE] Short description of what was done.

---

## 4. Guidelines
- Update this file after every feature, bugfix, or significant change.
- Use clear, concise descriptions and include date.
- Keep the "Current Features" section up to date for quick team reference.
- Use checklist to prioritize next implementation steps.
