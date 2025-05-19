# FOODONDOOR - API Endpoints

This document lists all API endpoints for the FOODONDOOR application, covering Customer, Vendor, and Delivery flows, and advanced features.

| Endpoint                                    | Method  | App           | File         | Description                                              | Usage Notes                                    |
|----------------------------------------------|---------|---------------|--------------|----------------------------------------------------------|------------------------------------------------|
| **Authentication & Core**                    |         |               |              |                                                          |                                                |
| `/api/core/auth/send-otp/`                   | POST    | `core`        | `views.py`   | Sends OTP to the provided phone number.                  | Used in all role login/registration            |
| `/api/core/auth/verify-otp/`                 | POST    | `core`        | `views.py`   | Verifies OTP and returns JWT tokens.                     | Used in all role login/registration            |
| `/api/core/auth/token/refresh/`              | POST    | `core`        | `views.py`   | Refreshes access token using refresh token.              | Requires valid Refresh Token                   |
| `/api/core/auth/token/blacklist/`            | POST    | `core`        | `views.py`   | Blacklists refresh token (logout).                       | Logout for all roles                           |
| `/api/core/fcm-token/`                       | POST    | `core`        | `views.py`   | Saves/updates device FCM token.                          | For push notifications                         |
| **Customer**                                 |         |               |              |                                                          |                                                |
| `/api/customer/login/`                       | POST    | `customer_app`| `views.py`   | Customer login (phone+OTP or phone+password).            | Returns JWT tokens                             |
| `/api/customer/profile/`                     | GET/PUT | `customer_app`| `views.py`   | View/update customer profile.                            | Requires JWT                                   |
| `/api/customer/addresses/`                   | GET     | `customer_app`| `views.py`   | List saved addresses.                                   | Requires JWT                                   |
| `/api/customer/addresses/add/`               | POST    | `customer_app`| `views.py`   | Add new address.                                         | Requires JWT                                   |
| `/api/customer/addresses/<id>/update/`       | PUT     | `customer_app`| `views.py`   | Update address.                                          | Requires JWT                                   |
| `/api/customer/addresses/<id>/delete/`       | DELETE  | `customer_app`| `views.py`   | Delete address.                                          | Requires JWT                                   |
| `/api/customer/banners/`                     | GET     | `customer_app`| `views.py`   | Fetch promotional banners for home.                      | Home screen                                    |
| `/api/customer/categories/`                  | GET     | `customer_app`| `views.py`   | Fetch food categories.                                   | Home screen                                    |
| `/api/customer/restaurants/nearby/`          | GET     | `customer_app`| `views.py`   | Fetch nearby restaurants by location.                    | Home screen                                    |
| `/api/customer/restaurants/<id>/`            | GET     | `customer_app`| `views.py`   | Restaurant details and menu.                             | Restaurant detail screen                       |
| `/api/customer/food/top-rated/`              | GET     | `customer_app`| `views.py`   | Top-rated food items.                                    | Home screen                                    |
| `/api/customer/cart/`                        | GET     | `customer_app`| `views.py`   | Get current cart.                                        | Cart screen                                    |
| `/api/customer/cart/add/`                    | POST    | `customer_app`| `views.py`   | Add item to cart.                                        | Menu/restaurant detail                         |
| `/api/customer/cart/update/`                 | PUT     | `customer_app`| `views.py`   | Update quantity in cart.                                 | Cart screen                                    |
| `/api/customer/cart/remove/`                 | DELETE  | `customer_app`| `views.py`   | Remove item from cart.                                   | Cart screen                                    |
| `/api/customer/place-order/`                 | POST    | `customer_app`| `views.py`   | Place a new order.                                       | Checkout                                       |
| `/api/customer/orders/`                      | GET     | `customer_app`| `views.py`   | List past orders.                                        | Past orders screen                             |
| `/api/customer/orders/<id>/status/`          | GET     | `customer_app`| `views.py`   | Get order status (polling).                              | Order tracking, implemented                    |
| `/api/customer/orders/<id>/track/`           | GET     | `customer_app`| `views.py`   | Live tracking for delivery (status + delivery location). | Order tracking, implemented                    |
| `/api/delivery/orders/<id>/status/`          | PATCH   | `delivery_auth`| `views.py`  | Delivery agent updates order status.                     | Triggers FCM to customer, implemented          |
| `/api/delivery/orders/<id>/location/`        | PATCH   | `delivery_auth`| `views.py`  | Delivery agent updates live location (lat/lng).          | Triggers FCM to customer, implemented          |
| `/api/vendor/orders/<id>/status/`            | PATCH   | `auth_app`    | `views.py`   | Vendor updates order status.                             | Triggers FCM to customer, implemented          |
| `/api/customer/orders/<id>/rate/`            | POST    | `customer_app`| `views.py`   | Rate completed order/restaurant.                         | Past orders                                    |
| `/api/customer/payment/verify/`              | POST    | `customer_app`| `views.py`   | Verify payment from gateway.                             | Checkout                                       |
| `/api/customer/wallet/`                      | GET     | `customer_app`| `views.py`   | View wallet balance.                                     | Wallet/checkout                                |
| `/api/customer/transactions/`                | GET     | `customer_app`| `views.py`   | View transaction history.                                | Wallet                                         |
| `/api/customer/promotions/`                  | GET     | `customer_app`| `views.py`   | List available promotions/coupons.                       | Checkout, wallet                               |
| `/api/customer/apply-coupon/`                | POST    | `customer_app`| `views.py`   | Apply coupon to cart/order.                              | Checkout                                       |
| `/api/customer/notifications/`               | GET     | `customer_app`| `views.py`   | List notifications.                                      | Notifications screen                           |
| `/api/customer/fcm-token/`                   | POST    | `customer_app`| `views.py`   | Save/update FCM token.                                   | Push notifications                             |
| `/api/customer/support/`                     | GET/POST| `customer_app`| `views.py`   | Support chat/ticket.                                     | Support screen                                 |
| **Vendor**                                   |         |               |              |                                                          |                                                |
| `/api/vendor/login/`                         | POST    | `vendor_app`  | `views.py`   | Vendor login (OTP via core).                             | Returns JWT tokens                             |
| `/api/vendor/profile/`                       | GET/PUT | `vendor_app`  | `views.py`   | View/update vendor profile.                              | Requires JWT                                   |
| `/api/vendor/restaurant/`                    | GET/PUT | `vendor_app`  | `views.py`   | View/update restaurant info.                             | Requires JWT                                   |
| `/api/vendor/menu-items/`                    | GET     | `vendor_app`  | `views.py`   | List menu items.                                         | Menu management                                |
| `/api/vendor/menu-items/add/`                | POST    | `vendor_app`  | `views.py`   | Add menu item.                                           | Menu management                                |
| `/api/vendor/menu-items/<id>/update/`        | PUT     | `vendor_app`  | `views.py`   | Update menu item.                                        | Menu management                                |
| `/api/vendor/menu-items/<id>/delete/`        | DELETE  | `vendor_app`  | `views.py`   | Delete menu item.                                        | Menu management                                |
| `/api/vendor/categories/`                    | GET/POST/PUT/DELETE | `vendor_app` | `views.py` | CRUD food categories.                                    | Menu management                                |
| `/api/vendor/orders/`                        | GET     | `vendor_app`  | `views.py`   | List vendor orders.                                      | Order management                               |
| `/api/vendor/orders/<id>/accept/`            | POST    | `vendor_app`  | `views.py`   | Accept order.                                            | Order management                               |
| `/api/vendor/orders/<id>/reject/`            | POST    | `vendor_app`  | `views.py`   | Reject order.                                            | Order management                               |
| `/api/vendor/orders/<id>/ready/`             | POST    | `vendor_app`  | `views.py`   | Mark order ready for pickup.                             | Order management                               |
| `/api/vendor/dashboard/`                     | GET     | `vendor_app`  | `views.py`   | Sales analytics, order trends.                           | Dashboard                                      |
| `/api/vendor/promotions/`                    | GET/POST| `vendor_app`  | `views.py`   | View/create promotions/coupons.                          | Promotions management                          |
| `/api/vendor/notifications/`                 | GET     | `vendor_app`  | `views.py`   | List notifications.                                      | Notifications screen                           |
| `/api/vendor/fcm-token/`                     | POST    | `vendor_app`  | `views.py`   | Save/update FCM token.                                   | Push notifications                             |
| **Delivery Agent**                           |         |               |              |                                                          |                                                |
| `/api/delivery/login/`                       | POST    | `delivery_app`| `views.py`   | Delivery agent login (OTP via core).                     | Returns JWT tokens                             |
| `/api/delivery/profile/`                     | GET/PUT | `delivery_app`| `views.py`   | View/update delivery agent profile.                      | Requires JWT                                   |
| `/api/delivery/orders/available/`            | GET     | `delivery_app`| `views.py`   | List available orders for delivery agents.               | Assigned orders                                |
| `/api/delivery/orders/<id>/assign/`          | POST    | `delivery_app`| `views.py`   | Assign order to delivery agent.                          | Assign order                                   |
| `/api/delivery/orders/<id>/confirm-pickup/`  | POST    | `delivery_app`| `views.py`   | Confirm pickup from restaurant.                          | Pickup screen                                  |
| `/api/delivery/orders/<id>/confirm-delivery/`| POST    | `delivery_app`| `views.py`   | Confirm delivery to customer.                            | Delivery screen                                |
| `/api/delivery/earnings/`                    | GET     | `delivery_app`| `views.py`   | Get earnings summary.                                   | Earnings screen                                |
| `/api/delivery/notifications/`               | GET     | `delivery_app`| `views.py`   | List notifications.                                      | Notifications screen                           |
| `/api/delivery/fcm-token/`                   | POST    | `delivery_app`| `views.py`   | Save/update FCM token.                                   | Push notifications                             |
| `/api/delivery/location/`                    | POST    | `delivery_app`| `views.py`   | Live location update (future).                           | Live tracking                                  |
| **Support & Advanced**                       |         |               |              |                                                          |                                                |
| `/api/support/chat/`                         | GET/POST| `core`        | `views.py`   | Support chat/ticket for all roles.                       | Real-time support (future)                     |
| `/api/admin/dashboard/`                      | GET     | `core`        | `views.py`   | Admin analytics dashboard.                               | Admin panel                                    |
| `/api/admin/users/`                          | GET/PUT/DELETE | `core`   | `views.py`   | Manage users (ban/delete/update).                        | Admin panel                                    |
| `/api/admin/vendors/`                        | GET/PUT/DELETE | `core`   | `views.py`   | Manage vendors (approval, update, delete).               | Admin panel                                    |
| `/api/admin/orders/`                         | GET/PUT/DELETE | `core`   | `views.py`   | Manage all orders.                                       | Admin panel                                    |

---

> This table should be updated as new endpoints are added or existing ones are changed. For endpoint details, see the backend plan and work summary.
 Auth)             |

*(This list is based on current implementation and plans. 'Requires Auth' means a valid JWT Bearer token is needed. 'TODO' indicates planned but not yet implemented/verified endpoints.)*
