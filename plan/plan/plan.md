# FOODONDOOR VENDOR APP DEVELOPMENT PLAN (Aligned to Test Report)

## GLOBAL STANDARDS

- **Authentication**: All endpoints require JWT authentication (unless otherwise noted).
- **Error Handling**: All API errors must be surfaced to the user (SnackBar/dialog).
- **Networking**: Use Dio (or equivalent) with proper base URL and headers.
- **Input/Output**: All request and response payloads must match the test report exactly.

---

## 1. AUTH & REGISTRATION

### 1.1. Send OTP  
**POST** `/api/<user_type>/send_otp/`  
**Input:**  
```json
{ "phone_number": "string" }
```
or  
```json
{ "mobile": "string" }
```
**Output:**  
```json
{ "message": "OTP sent successfully." }
```
or  
```json
{ "error": "..." }
```

### 1.2. Verify OTP  
**POST** `/api/<user_type>/verify_otp/`  
**Input:**  
```json
{ "phone_number": "string", "otp": "string" }
```
or  
```json
{ "mobile": "string", "otp": "string" }
```
**Output:**  
```json
{ "access": "jwt", "refresh": "jwt", ... }
```
or  
```json
{ "signup_required": true, "signup_token": "..." }
```

### 1.3. Vendor Signup  
**POST** `/api/vendor/signup/`  
**Input:**  
```json
{ "signup_token": "...", "company_name": "...", "email": "..." }
```
**Output:**  
```json
{ "access": "jwt", "refresh": "jwt", ... }
```

---

## 2. PROFILE & RESTAURANT MANAGEMENT

### 2.1. Get Vendor Profile  
**GET** `/api/vendor/profile/`  
**Output:**  
Vendor profile fields

### 2.2. Update Vendor Profile  
**PUT/PATCH** `/api/vendor/profile/`  
**Input:**  
Partial or full profile fields  
**Output:**  
Updated profile

### 2.3. Get Restaurant Details  
**GET** `/api/vendor/restaurant/`  
**Output:**  
Restaurant details

---

## 3. MENU & CATEGORY MANAGEMENT

### 3.1. Get Menu Items  
**GET** `/api/vendor/menu/`  
**Output:**  
List of menu items

### 3.2. Add Menu Item  
**POST** `/api/vendor/menu/add/`  
**Input:**  
Menu item fields  
**Output:**  
Menu item created

### 3.3. Update Menu Item  
**PUT/PATCH** `/api/vendor/menu/<uuid:pk>/update/`  
**Input:**  
Menu item fields  
**Output:**  
Menu item updated

### 3.4. Delete Menu Item  
**DELETE** `/api/vendor/menu/<uuid:pk>/delete/`  
**Output:**  
Menu item deleted

### 3.5. Get Categories  
**GET** `/api/vendor/categories/`  
**Output:**  
List of categories

### 3.6. Add Category  
**POST** `/api/vendor/categories/`  
**Input:**  
Category fields  
**Output:**  
Category created

### 3.7. Get Category Details  
**GET** `/api/vendor/categories/<uuid:pk>/`  
**Output:**  
Category details

### 3.8. Update Category  
**PUT/PATCH** `/api/vendor/categories/<uuid:pk>/`  
**Input:**  
Category fields  
**Output:**  
Category updated

### 3.9. Delete Category  
**DELETE** `/api/vendor/categories/<uuid:pk>/`  
**Output:**  
Category deleted

---

## 4. ORDER MANAGEMENT

### 4.1. Get Orders  
**GET** `/api/vendor/orders/`  
**Output:**  
List of vendor orders

### 4.2. Update Order Status  
**POST** `/api/vendor/order/<int:pk>/status/`  
**Input:**  
```json
{ "status": "accepted" | "preparing" | "ready" }
```
**Output:**  
Order status updated

### 4.3. Accept Order  
**POST** `/api/vendor/orders/<int:pk>/accept/`  
**Output:**  
Order accepted

### 4.4. Reject Order  
**POST** `/api/vendor/orders/<int:pk>/reject/`  
**Output:**  
Order rejected

### 4.5. Mark Order Ready  
**POST** `/api/vendor/orders/<int:pk>/ready/`  
**Output:**  
Order marked ready

---

## 5. NOTIFICATIONS (Optional/Future)

### 5.1. Register FCM Token  
**POST** `/api/common/register_fcm_token/`  
**Input:**  
```json
{ "user_id": int, "user_type": "string", "fcm_token": "string" }
```
**Output:**  
```json
{ "message": "FCM token registered successfully." }
```

### 5.2. Test Notification  
**POST** `/api/common/test_notification/`  
**Input:**  
```json
{ "user_id": int, "user_type": "string", "message": "string" }
```
**Output:**  
```json
{ "message": "Notification to ..." }
```

---

## 6. SCREEN-TO-ENDPOINT MAPPING

- **Login/OTP**: `/api/vendor/send_otp/`, `/api/vendor/verify_otp/`, `/api/vendor/signup/`
- **Profile**: `/api/vendor/profile/` (GET, PUT/PATCH)
- **Restaurant**: `/api/vendor/restaurant/` (GET)
- **Menu**: `/api/vendor/menu/`, `/api/vendor/menu/add/`, `/api/vendor/menu/<uuid:pk>/update/`, `/api/vendor/menu/<uuid:pk>/delete/`
- **Categories**: `/api/vendor/categories/`, `/api/vendor/categories/<uuid:pk>/`
- **Orders**: `/api/vendor/orders/`, `/api/vendor/order/<int:pk>/status/`, `/api/vendor/orders/<int:pk>/accept/`, `/api/vendor/orders/<int:pk>/reject/`, `/api/vendor/orders/<int:pk>/ready/`
- **Notifications**: `/api/common/register_fcm_token/`, `/api/common/test_notification/`

---

**Note:** All input/output structures must match the test report exactly. Any changes in the backend should be reflected here and in the app code.


## GLOBAL DEVELOPMENT STANDARDS

- **Authentication**: Custom OTP-initiated authentication using JWT for session management (no Django defaults)
- **Theming**: Unified Material 3 theme with Poppins font and `Colors.deepOrange`
- **Naming Conventions**:
  - **Files**: `snake_case.dart`
  - **Classes**: `PascalCase`
  - **Variables/Functions**: `camelCase`
- **API Design**: Custom endpoints as per `api_endpoints.md`
- **State Management**: `provider` package (clean, modular)
- **Code Tracking**: All work and updates logged in `work_summary.md`
- **Notifications**: To be implemented in a future phase

---

## 1 CUSTOMER APP (`foodondoor_customer_app`)

### 1. Splash Screen
- **Logic**:  
  - Check stored JWT token  
  - Fetch location  
- **Libs**: `geolocator`, `shared_preferences`  
- **Next**: Redirect to login or home

### 2. Login / OTP
- **Fields**: Phone Number  
- **APIs**:
  - `POST /api/core/auth/send-otp/`
  - `POST /api/core/auth/verify-otp/`
- **Token**: JWT (access/refresh) stored securely

### 3. Home Screen
- **Features**:
  - Current location (reverse-geocoded)
  - Search bar (future feature)
- **Sections**:
  - **Banners** → `GET /api/customer/banners/`
  - **Food Categories** → `GET /api/customer/categories/`
  - **Nearby Restaurants** → `GET /api/customer/restaurants/nearby/?lat=xx&lon=yy`
  - **Top-rated Dishes** → `GET /api/customer/food/top-rated/`

### 4. Restaurant Details
- **Display**:
  - Restaurant info, ratings
  - Menu grouped by category (`GET /api/customer/restaurants/<id>/categories/`)
  - Menu items (`GET /api/customer/restaurants/<id>/` already includes items)
- **Cart Integration**:
  - Add/Remove item
  - **API**:
    - `POST /api/customer/cart/add/`
    - `PUT /api/customer/cart/update/`
    - `DELETE /api/customer/cart/remove/`
  - Show item modifiers (if any)

### 5. Cart Screen
- Show all selected items
- Modify quantity, delete items
- Show pricing breakdown
- **API**: `GET /api/customer/cart/`
- **Button**: Proceed to Checkout

### 6. Address Screen
- **Features**:
  - List, Add, Edit, Delete addresses
  - Auto-locate option (via GPS)
- **API**:
  - `GET /api/customer/addresses/`
  - `POST /api/customer/addresses/add/`
  - `PUT /api/customer/addresses/<id>/update/`
  - `DELETE /api/customer/addresses/<id>/delete/`

### 7. Checkout Screen
- **Show**:
  - Cart Summary
  - Selected Address
  - Expected Delivery Time
- **Place Order**: `POST /api/customer/place-order/`

### 8. Order Tracking
- **Tracking**: Real-time  
- **Method**: Polling/Future WebSocket → `GET /api/customer/orders/<id>/status/`
- **Info**: Rider info (after assigned)

### 9. Order History
- **List**: `GET /api/customer/orders/`
- **Actions**:
  - View Details
  - Rate & Review (`POST /api/customer/orders/<id>/rate/`)
  - Reorder

### 10. Profile Screen
- **View/Update**: (`GET /api/customer/profile/`, `PUT /api/customer/profile/update/`)
  - Name
  - Phone (non-editable)
- **Actions**:
  - Logout
  - View Addresses

---

## 2 VENDOR APP (`foodondoor_vendor_app`)

### 1. Login / OTP
- **Flow**: Uses Core OTP endpoints
  - `POST /api/core/auth/send-otp/`
  - `POST /api/core/auth/verify-otp/`
- **Role**: `vendor`
- **Signup Completion**: `POST /api/vendor/auth/register/` (after OTP verification returns signup_token)

### 2. Order Management
- **Tabs/Filtering**:
  - New Orders
  - Preparing Orders
  - Completed Orders
- **API**: `GET /api/vendor/orders/` (Use query parameters for filtering e.g., `?status=new`)
- **Actions**:
  - Accept → `POST /api/vendor/orders/<id>/accept/`
  - Mark as Ready → `POST /api/vendor/orders/<id>/ready/`
  - Reject → `POST /api/vendor/orders/<id>/reject/`

### 3. Menu Management
- **Features**:
  - Add/Edit/Delete Item
  - Toggle availability
- **Fields**:
  - Name, Description, Price, Category, Image, IsAvailable
- **API**:
  - `GET /api/vendor/menu-items/`
  - `POST /api/vendor/menu-items/add/`
  - `PUT /api/vendor/menu-items/<id>/update/`
  - `DELETE /api/vendor/menu-items/<id>/delete/`

### 4. Profile & Restaurant Management
- **Vendor Account Info**:
  - View/Update Name, Email, Phone (Non-editable)
  - **API**: `GET /api/vendor/profile/`, `PUT /api/vendor/profile/update/`
- **Restaurant Details**:
  - View/Update Restaurant Name, Logo, Contact, Address, Operating Hours, etc.
  - **API**: `GET /api/vendor/restaurant/`, `PUT /api/vendor/restaurant/`

---

## 3 DELIVERY APP (`foodondoor_delivery_app`)

### 1. Login / OTP
- **Flow**: Uses Core OTP endpoints
  - `POST /api/core/auth/send-otp/`
  - `POST /api/core/auth/verify-otp/`
- **Role**: `delivery`
- **Signup Completion**: `POST /api/delivery/auth/register/` (TODO - after OTP verification returns signup_token)
- **Token**: Save JWT locally

### 2. Assigned Orders
- **Show**:
  - Unassigned/Assigned orders
  - Customer & restaurant details
- **Accept**: `POST /api/delivery/orders/<id>/assign/`

### 3. Pickup Screen
- **Details**:
  - Restaurant Address
  - Items to pick
- **Confirm Pickup**: `POST /api/delivery/orders/<id>/confirm-pickup/`

### 4. Delivery Screen
- **Map**: Showing customer location
- **Confirm Delivery**: `POST /api/delivery/orders/<id>/confirm-delivery/`

### 5. Earnings
- **List**: Completed deliveries
- **Show**: Amount earned (today/week)
- **API**: `GET /api/delivery/earnings/`

---

## PHASE-WISE DEVELOPMENT PLAN

| Phase | Tasks                                                | Apps     |
|-------|------------------------------------------------------|----------|
| 1   | Django backend setup, DB schema, Custom Auth API     | All      |
| 2   | OTP Login flow (vendor, customer, delivery)          | All      |
| 3   | Vendor App → Menu & Restaurant Management            | Vendor   |
| 4   | Customer App → Home, Restaurant, Cart, Checkout      | Customer |
| 5   | Vendor App → Order Management (Accept/Ready/Reject)  | Vendor   |
| 6   | Customer App → Order Tracking & History              | Customer |
| 7   | Delivery App → Assigned Orders → Pickup → Deliver    | Delivery |
| 8   | Notifications (FCM)                                  | All      |
| 9   | Admin Panel (optional)                               | Backend  |
| 10  | MongoDB refactor (optional)                          | Backend  |

---

## FOLDER STRUCTURE

### `foodondoor_backend/`

```bash
foodondoor_backend/
├── auth_app/
├── customer_app/
├── vendor_app/
├── delivery_app/
├── plan.md
├── api_endpoints.md
├── work_summary.md
