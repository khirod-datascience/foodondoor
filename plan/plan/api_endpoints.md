## ✅ Authentication & Core (OTP System)

| Endpoint                              | Method | App  | File        | Description                                         | Usage Notes                        |
|---------------------------------------|--------|------|-------------|-----------------------------------------------------|------------------------------------|
| /api/core/auth/send-otp/             | POST   | core | views.py    | Sends OTP to a given mobile number.                | Used in Vendor & Delivery login   |
| /api/core/auth/verify-otp/           | POST   | core | views.py    | Verifies OTP and returns access & refresh tokens, or signup_token. | Used in Vendor, Customer & Delivery login |
| /api/core/auth/token/refresh/        | POST   | core | views.py    | Refreshes access token using the refresh token.     | Requires refresh token            |

---

## 👤 Customer APIs

### 🔐 Authentication & Profile

| Endpoint                               | Method | File    | Description                                        | Notes                           |
|----------------------------------------|--------|---------|----------------------------------------------------|---------------------------------|
| /api/customer/login/                   | POST   | views.py| Customer login with phone+OTP or password (planned)| Tokens (access/refresh) returned|
| /api/customer/auth/register/           | POST   | views.py| Completes signup with profile & email              | Requires signup_token           |
| /api/customer/profile/                 | GET    | views.py| Fetch logged-in customer's profile                 | Requires Authorization          |
| /api/customer/profile/update/          | PUT    | views.py| Updates profile info                               | TODO                            |

### 🍽 Restaurant & Menu Browsing

| Endpoint                                           | Method | App      | File       | Description                                        | Notes                  |
|----------------------------------------------------|--------|----------|------------|----------------------------------------------------|------------------------|
| /api/customer/banners/                             | GET    | customer | views.py   | Fetch promotional banners for homepage             | Requires Authorization |
| /api/customer/categories/                          | GET    | customer | views.py   | Fetch food categories                              | Requires Authorization |
| /api/customer/restaurants/nearby/                  | GET    | customer | views.py   | Get nearby restaurants based on geolocation        | Requires Authorization |
| /api/customer/food/top-rated/                      | GET    | customer | views.py   | Top-rated food items across restaurants           | Requires Authorization |
| /api/customer/restaurants/<uuid:restaurant_pk>/    | GET    | customer | views.py   | Restaurant detail (info, menu items)             | Requires Authorization |
| /api/customer/restaurants/<uuid:restaurant_pk>/categories/ | GET | customer | views.py   | List categories for a specific restaurant menu | Requires Authorization |

### 🛒 Cart Management

| Endpoint                                 | Method | File    | Description                                         | Notes                           |
|------------------------------------------|--------|---------|-----------------------------------------------------|---------------------------------|
| /api/customer/cart/                      | GET    | views.py| Retrieve user's current cart                        | Requires Authorization          |
| /api/customer/cart/add/                  | POST   | views.py| Add item to cart                                    | Requires Authorization          |
| /api/customer/cart/update/               | PUT    | views.py| Update item quantity                                | Requires Authorization          |
| /api/customer/cart/remove/               | DELETE | views.py| Remove item from cart                               | Requires Authorization          |

### 📍 Address Management

| Endpoint                                 | Method | File    | Description                                         | Notes                           |
|------------------------------------------|--------|---------|-----------------------------------------------------|---------------------------------|
| /api/customer/addresses/                 | GET    | views.py| List all saved addresses                            | Requires Authorization          |
| /api/customer/addresses/add/             | POST   | views.py| Add a new address                                   | Requires Authorization          |
| /api/customer/addresses/<id>/update/     | PUT    | views.py| Update an existing address                          | Requires Authorization          |
| /api/customer/addresses/<id>/delete/     | DELETE | views.py| Delete a saved address                              | Requires Authorization          |

### ✅ Orders

| Endpoint                                 | Method | File    | Description                                         | Notes                           |
|------------------------------------------|--------|---------|-----------------------------------------------------|---------------------------------|
| /api/customer/place-order/               | POST   | views.py| Place a new order                                   | Used during checkout            |
| /api/customer/orders/                    | GET    | views.py| List past orders                                    | Past Orders Screen              |
| /api/customer/orders/<id>/status/        | GET    | views.py| Current status of a given order                     | Order tracking                  |
| /api/customer/orders/<id>/track/         | GET    | views.py| Live tracking info for the order                    | For delivery tracking           |
| /api/customer/orders/<id>/rate/          | POST   | views.py| Submit a rating for completed order                 | Restaurant feedback             |

---

## 🍽 Vendor APIs

### 🔐 Authentication & Profile

| Endpoint                             | Method | App    | File    | Description                                     | Notes                           |
|--------------------------------------|--------|--------|---------|-------------------------------------------------|---------------------------------|
| /api/vendor/auth/register/           | POST   | vendor | views.py| Completes signup with profile info            | Requires signup_token           |
| /api/vendor/profile/                 | GET    | vendor | views.py| Get vendor profile (account info)             | Requires Authorization          |
| /api/vendor/profile/update/          | PUT    | vendor | views.py| Update vendor profile (account info)          | TODO                            |

### 🏠 Restaurant Management

| Endpoint                      | Method | App    | File    | Description                                     | Notes                           |
|-------------------------------|--------|--------|---------|-------------------------------------------------|---------------------------------|
| /api/vendor/restaurant/       | GET    | vendor | views.py| Get vendor's restaurant details                 | Requires Authorization          |
| /api/vendor/restaurant/       | PUT    | vendor | views.py| Update vendor's restaurant details            | Requires Authorization          |
| /api/vendor/restaurant/create/| POST   | vendor | views.py| Create restaurant profile for vendor (if none)  | Optional - Needed?             |

### 📦 Order Management

| Endpoint                                 | Method | File    | Description                                         | Notes                           |
|------------------------------------------|--------|---------|-----------------------------------------------------|---------------------------------|
| /api/vendor/orders/                      | GET    | views.py| List all new and preparing orders                   | Requires Authorization          |
| /api/vendor/orders/<id>/accept/          | POST   | views.py| Accept new order                                    | Order status updated            |
| /api/vendor/orders/<id>/reject/          | POST   | views.py| Reject new order                                    |                                 |
| /api/vendor/orders/<id>/ready/           | POST   | views.py| Mark order ready for pickup                         | Used before delivery assignment|

### 📋 Menu Management

| Endpoint                                 | Method | File    | Description                                         | Notes                           |
|------------------------------------------|--------|---------|-----------------------------------------------------|---------------------------------|
| /api/vendor/menu-items/                  | GET    | views.py| List all menu items                                 |                                 |
| /api/vendor/menu-items/add/              | POST   | views.py| Add new menu item                                   | Requires Authorization          |
| /api/vendor/menu-items/<id>/update/      | PUT    | views.py| Update existing item                                |                                 |
| /api/vendor/menu-items/<id>/delete/      | DELETE | views.py| Delete item                                         |                                 |

---

## 🚚 Delivery Agent APIs

### 🔐 Authentication & Profile

| Endpoint                               | Method | App      | File    | Description                                     | Notes                           |
|----------------------------------------|--------|----------|---------|-------------------------------------------------|---------------------------------|
| /api/delivery/auth/register/         | POST   | delivery | views.py| Completes signup with profile info            | Requires signup_token, TODO     |
| /api/delivery/profile/                 | GET    | delivery | views.py| Get agent profile                               | Requires Authorization          |
| /api/delivery/profile/update/          | PUT    | delivery | views.py| Update agent profile                            | TODO                            |

### 🧾 Order Fulfillment

| Endpoint                                 | Method | File    | Description                                         | Notes                           |
|------------------------------------------|--------|---------|-----------------------------------------------------|---------------------------------|
| /api/delivery/orders/available/          | GET    | views.py| List all available orders for delivery              | Requires Authorization          |
| /api/delivery/orders/<id>/assign/        | POST   | views.py| Assign an order to the delivery agent               |                                 |
| /api/delivery/orders/<id>/confirm-pickup/| POST   | views.py| Confirm pickup from restaurant                      |                                 |
| /api/delivery/orders/<id>/confirm-delivery/| POST  | views.py| Confirm delivery to customer                        | Marks order as delivered        |

### 💸 Earnings

| Endpoint                                 | Method | File    | Description                                         | Notes                           |
|------------------------------------------|--------|---------|-----------------------------------------------------|---------------------------------|
| /api/delivery/earnings/                  | GET    | views.py| Get delivery agent's earnings                       | Weekly or monthly view          |

---

## 📌 Notes

- All endpoints requiring authentication expect `Authorization: Bearer <access_token>` in the header.
- Endpoints marked TODO are planned but not yet implemented.
- OTP-based login is centralized in the core app and reused across Vendor and Delivery.
