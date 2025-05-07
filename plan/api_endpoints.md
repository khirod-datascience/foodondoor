# FOODONDOOR - API Endpoints

This document lists all API endpoints created for the FOODONDOOR application.

| Endpoint                        | Method | App           | File                 | Description                                       | Usage Notes                                                |
|---------------------------------|--------|---------------|----------------------|---------------------------------------------------|------------------------------------------------------------|
| **Authentication & Core**       |        |               |                      |                                                   |                                                            |
| `/api/core/auth/send-otp/`      | POST   | `core`        | `views.py`           | Sends OTP to the provided phone number.           | Used in Vendor, Delivery Login/Registration              |
| `/api/core/auth/verify-otp/`    | POST   | `core`        | `views.py`           | Verifies OTP and returns Access/Refresh JWT tokens. | Used in Vendor, Delivery Login/Registration              |
| `/api/core/auth/token/refresh/` | POST   | `core`        | `views.py`           | Refreshes access token using refresh token.       | Requires valid Refresh Token in request body             |
| **Customer**                    |        |               |                      |                                                   |                                                            |
| `/api/customer/login/`          | POST   | `customer_app`| `views.py`           | Customer login (e.g., phone+OTP or phone+password). | Returns Access/Refresh JWT tokens. (Requires implementation) |
| `/api/customer/profile/`        | GET    | `customer_app`| `views.py`           | Gets the authenticated customer's profile details.| Requires `Authorization: Bearer <access_token>`          |
| `/api/customer/profile/update/` | PUT    | `customer_app`| `views.py`           | Updates the authenticated customer's profile.     | Requires `Authorization: Bearer <access_token>`. (TODO)  |
| `/api/customer/banners/`        | GET    | `customer_app`| `views.py`           | Fetches promotional banners for the home screen.  | Customer App Home Screen (Requires Auth)                 |
| `/api/customer/categories/`     | GET    | `customer_app`| `views.py`           | Fetches food categories.                          | Customer App Home Screen (Requires Auth)                 |
| `/api/customer/restaurants/nearby/`| GET | `customer_app`| `views.py`           | Fetches nearby restaurants based on location.     | Customer App Home Screen (Requires Auth)                 |
| `/api/customer/food/top-rated/` | GET    | `customer_app`| `views.py`           | Fetches top-rated food items.                     | Customer App Home Screen (Requires Auth)                 |
| `/api/customer/restaurants/<id>/`| GET   | `customer_app`| `views.py`           | Fetches details and menu for a restaurant.        | Customer App Restaurant Detail Screen (Requires Auth)    |
| `/api/customer/cart/`           | GET    | `customer_app`| `views.py`           | Gets the user's current cart.                     | Customer App Cart Screen (Sync) (Requires Auth)        |
| `/api/customer/cart/add/`       | POST   | `customer_app`| `views.py`           | Adds an item to the cart.                         | Customer App Restaurant Detail Screen (Requires Auth)    |
| `/api/customer/cart/update/`    | PUT    | `customer_app`| `views.py`           | Updates item quantity in the cart.                | Customer App Cart Screen (Requires Auth)                 |
| `/api/customer/cart/remove/`    | DELETE | `customer_app`| `views.py`           | Removes an item from the cart.                    | Customer App Cart Screen (Requires Auth)                 |
| `/api/customer/addresses/`      | GET    | `customer_app`| `views.py`           | Lists saved addresses.                            | Customer App Address Screen (Requires Auth)              |
| `/api/customer/addresses/add/`  | POST   | `customer_app`| `views.py`           | Adds a new address.                               | Customer App Address Screen (Requires Auth)              |
| `/api/customer/addresses/<id>/update/`| PUT | `customer_app`| `views.py`           | Updates an existing address.                      | Customer App Address Screen (Requires Auth)              |
| `/api/customer/addresses/<id>/delete/`| DELETE| `customer_app`| `views.py`          | Deletes a saved address.                          | Customer App Address Screen (Requires Auth)              |
| `/api/customer/place-order/`    | POST   | `customer_app`| `views.py`           | Places a new order.                               | Customer App Checkout Screen (Requires Auth)             |
| `/api/customer/orders/<id>/status/`| GET  | `customer_app`| `views.py`           | Gets the current status of an order.              | Customer App Order Tracking Screen (Requires Auth)       |
| `/api/customer/orders/<id>/track/`| GET  | `customer_app`| `views.py`           | Gets live tracking info for delivery.             | Customer App Order Tracking Screen (Requires Auth)       |
| `/api/customer/orders/`         | GET    | `customer_app`| `views.py`           | Lists past orders.                                | Customer App Past Orders Screen (Requires Auth)          |
| `/api/customer/orders/<id>/rate/`| POST  | `customer_app`| `views.py`           | Rates a completed order/restaurant.               | Customer App Past Orders Screen (Requires Auth)          |
| **Vendor**                      |        |               |                      |                                                   |                                                            |
| `/api/vendor/login/`            | POST   | `vendor_app`  | `views.py`           | Vendor login (Uses OTP flow via Core endpoints).  | Returns Access/Refresh JWT tokens.                       |
| `/api/vendor/profile/`          | GET    | `vendor_app`  | `views.py`           | Gets the authenticated vendor's profile details.  | Requires `Authorization: Bearer <access_token>`          |
| `/api/vendor/profile/update/`   | PUT    | `vendor_app`  | `views.py`           | Updates the authenticated vendor's profile.       | Requires `Authorization: Bearer <access_token>`. (TODO)  |
| `/api/vendor/orders/`           | GET    | `vendor_app`  | `views.py`           | Lists orders for the vendor (new, preparing).   | Vendor App Order Management (Requires Auth)              |
| `/api/vendor/orders/<id>/accept/`| POST  | `vendor_app`  | `views.py`           | Vendor accepts a new order.                       | Vendor App Order Management (Requires Auth)              |
| `/api/vendor/orders/<id>/reject/`| POST  | `vendor_app`  | `views.py`           | Vendor rejects a new order.                       | Vendor App Order Management (Requires Auth)              |
| `/api/vendor/orders/<id>/ready/`| POST  | `vendor_app`  | `views.py`           | Marks an order as ready for pickup.               | Vendor App Order Management (Requires Auth)              |
| `/api/vendor/menu-items/`       | GET    | `vendor_app`  | `views.py`           | Lists vendor's menu items.                        | Vendor App Menu Management (Requires Auth)               |
| `/api/vendor/menu-items/add/`   | POST   | `vendor_app`  | `views.py`           | Adds a new menu item.                             | Vendor App Menu Management (Requires Auth)               |
| `/api/vendor/menu-items/<id>/update/`| PUT| `vendor_app`  | `views.py`           | Updates a menu item.                              | Vendor App Menu Management (Requires Auth)               |
| `/api/vendor/menu-items/<id>/delete/`| DELETE| `vendor_app` | `views.py`          | Deletes a menu item.                              | Vendor App Menu Management (Requires Auth)               |
| **Delivery Agent**              |        |               |                      |                                                   |                                                            |
| `/api/delivery/login/`          | POST   | `delivery_app`| `views.py`           | Delivery agent login (Uses OTP flow via Core).    | Returns Access/Refresh JWT tokens.                       |
| `/api/delivery/profile/`        | GET    | `delivery_app`| `views.py`           | Gets the authenticated agent's profile details.   | Requires `Authorization: Bearer <access_token>`          |
| `/api/delivery/profile/update/` | PUT    | `delivery_app`| `views.py`           | Updates the authenticated agent's profile.        | Requires `Authorization: Bearer <access_token>`. (TODO)  |
| `/api/delivery/orders/available/`| GET   | `delivery_app`| `views.py`           | Lists available orders for delivery agents.       | Delivery App Assigned Orders Screen (Requires Auth)      |
| `/api/delivery/orders/<id>/assign/`| POST | `delivery_app`| `views.py`           | Assigns an order to the delivery agent.           | Delivery App Assigned Orders Screen (Requires Auth)      |
| `/api/delivery/orders/<id>/confirm-pickup/`| POST | `delivery_app`| `views.py`    | Confirms order pickup from the restaurant.        | Delivery App Pickup Screen (Requires Auth)               |
| `/api/delivery/orders/<id>/confirm-delivery/`| POST | `delivery_app`| `views.py` | Confirms order delivery to the customer.          | Delivery App Delivery Screen (Requires Auth)             |
| `/api/delivery/earnings/`       | GET    | `delivery_app`| `views.py`           | Gets the delivery agent's earnings summary.       | Delivery App Earnings Screen (Requires Auth)             |

*(This list is based on current implementation and plans. 'Requires Auth' means a valid JWT Bearer token is needed. 'TODO' indicates planned but not yet implemented/verified endpoints.)*
