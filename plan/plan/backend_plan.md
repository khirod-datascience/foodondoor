# API Documentation

## 🔹 Phase 1: Custom OTP Auth System (All Apps)

### ✅ 1. Send OTP
**Endpoint:** /api/<user_type>/send_otp/  
**Method:** POST  
**Auth:** ❌ No  

**Params:**
{
  "mobile": "9876543210"
}

**Response:**
{
  "message": "OTP sent successfully"
}

**Description:** Sends a 6-digit OTP via SMS to the given mobile number. Used for both login and signup. Separate logic to check if the user exists or not.

---

### ✅ 2. Verify OTP & Generate Token
**Endpoint:** /api/<user_type>/verify_otp/  
**Method:** POST  
**Auth:** ❌ No  

**Params:**
{
  "mobile": "9876543210",
  "otp": "123456"
}

**Response:**
{
  "token": "jwt.token.value",
  "user_id": 3,
  "user_type": "vendor",
  "is_new": false
}

**Description:** Verifies the OTP. If correct, returns a JWT token for authenticated access. `is_new=true` means redirect to signup screen in frontend.

---

### ✅ 3. Complete Signup (if `is_new = true`)
**Endpoint:** /api/<user_type>/signup/  
**Method:** POST  
**Auth:** ✅ Yes (Pass JWT)  

**Params (example for vendor):**
{
  "full_name": "Khirod",
  "email": "vendor@example.com",
  "restaurant_name": "Spicy Hut",
  "location": "Bhubaneswar"
}

**Response:**
{
  "message": "Signup complete",
  "user_id": 3,
  "user_type": "vendor"
}

**Description:** Completes registration by saving full profile data. Fields vary by role.

---

## 🔹 Phase 2: Customer App API

### ✅ 1. Home Data API
**Endpoint:** /api/customer/home/  
**Method:** GET  
**Auth:** ✅ Yes  

**Params:** _None_

**Response:**
{
  "banners": [...],
  "categories": [...],
  "nearby_restaurants": [...],
  "top_rated_restaurants": [...],
  "popular_foods": [...]
}

**Description:** Shows the dashboard. Fetches everything required to render the homepage of the customer app.

---

### ✅ 2. Restaurant Details & Menu
**Endpoint:** /api/customer/restaurant/<id>/  
**Method:** GET  
**Auth:** ✅ Yes  

**Params:** _None_

**Response:**
{
  "name": "Spicy Hut",
  "rating": 4.5,
  "delivery_time": "30-40 min",
  "menu": [...]
}

**Description:** Used on the restaurant detail page to show menu items and info.

---

### ✅ 3. Add to Cart
**Endpoint:** /api/customer/cart/add/  
**Method:** POST  
**Auth:** ✅ Yes  

**Params:**
{
  "item_id": 12,
  "quantity": 2
}

**Response:**
{
  "message": "Item added to cart"
}

**Description:** Add selected food item to the cart. Each user has their own cart.

---

### ✅ 4. View Cart
**Endpoint:** /api/customer/cart/  
**Method:** GET  
**Auth:** ✅ Yes  

**Description:** Fetches all items in the cart with quantity, total, and vendor association.

---

### ✅ 5. Remove Item from Cart
**Endpoint:** /api/customer/cart/remove/  
**Method:** POST  

**Params:**
{
  "item_id": 12
}

---

### ✅ 6. Place Order
**Endpoint:** /api/customer/order/place/  
**Method:** POST  
**Auth:** ✅ Yes  

**Params:**
{
  "address": "My Home Address"
}

**Response:**
{
  "message": "Order placed successfully",
  "order_id": 101
}

**Description:** Creates an order from the current cart and clears the cart. Order goes to the vendor.

---

### ✅ 7. Order History
**Endpoint:** /api/customer/orders/  
**Method:** GET  
**Auth:** ✅ Yes  

**Description:** Shows customer’s previous orders.

---

## 🔹 Phase 3: Vendor App API

### ✅ 1. Vendor Profile
**Endpoint:** /api/vendor/profile/
**Method:** GET
**Auth:**
- Required. Use JWT Bearer token.
- Add the following header:
  - `Authorization: Bearer <access_token>`

**Sample Request Headers:**
```
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOi...
Content-Type: application/json
```

**Sample cURL Command:**
```
curl -X GET "https://yourdomain.com/api/vendor/profile/" \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOi..." \
  -H "Content-Type: application/json"
```

**Params:** _None_

**Response:**
{
  "id": "uuid",
  "email": "vendor@example.com",
  "phone_number": "9876543210",
  "company_name": "Vendor Company",
  "fcm_token": "string",
  "is_active": true,
  "is_approved": true,
  "created_at": "2025-05-04T00:00:00Z",
  "updated_at": "2025-05-04T00:00:00Z"
}

**Description:** Used to render the vendor profile page.

---

### ✅ 2. Menu List
**Endpoint:** /api/vendor/menu/
**Method:** GET
**Auth:**
- Required. Use JWT Bearer token.
- Add the following header:
  - `Authorization: Bearer <access_token>`

**Sample Request Headers:**
```
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOi...
Content-Type: application/json
```

**Sample cURL Command:**
```
curl -X GET "https://yourdomain.com/api/vendor/menu/" \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOi..." \
  -H "Content-Type: application/json"
```

**Params:** _None_

**Response:**
[
  {
    "id": "uuid",
    "restaurant": "uuid",
    "category_id": "uuid",
    "category": "uuid",
    "category_name": "Pizza",
    "name": "Pizza Margherita",
    "description": "Classic pizza with tomatoes and cheese",
    "price": 299.99,
    "image_url": "https://yourdomain.com/media/images/pizza.jpg",
    "is_available": true,
    "is_vegetarian": true,
    "created_at": "2025-05-04T00:00:00Z",
    "updated_at": "2025-05-04T00:00:00Z"
  }
]

**Description:** Returns the list of menu items for the logged-in vendor.

---

### ✅ 3. Add Menu Item
**Endpoint:** /api/vendor/menu/add/  
**Method:** POST  
**Auth:** ✅ Yes  

**Params:**
{
  "name": "Chicken Biryani",
  "price": 180,
  "description": "Spicy biryani",
  "image": (file)
}

---

### ✅ 4. Update Menu Item
**Endpoint:** /api/vendor/menu/<id>/update/  
**Method:** PUT  

**Params:** Same as above.

---

### ✅ 5. Delete Menu Item
**Endpoint:** /api/vendor/menu/<id>/delete/  
**Method:** DELETE  

**Description:** Only the vendor who owns the item can delete it.

---

### ✅ 6. View Orders
**Endpoint:** /api/vendor/orders/  
**Method:** GET  

**Description:** Fetches orders made to this vendor with current status.

---

### ✅ 7. Update Order Status
**Endpoint:** /api/vendor/order/<id>/status/  
**Method:** POST  

**Params:**
{
  "status": "accepted" // or "preparing", "ready"
}

---

## 🔹 Phase 4: Delivery App API

### ✅ 1. View Assigned Orders
**Endpoint:** /api/delivery/orders/  
**Method:** GET  
**Auth:** ✅ Yes  

**Description:** Delivery partner sees all orders assigned to them.

---

### ✅ 2. Update Order Status
**Endpoint:** /api/delivery/order/<id>/status/  
**Method:** POST  

**Params:**
{
  "status": "picked_up" // or "delivered"
}

---

### ✅ 3. Delivery History
**Endpoint:** /api/delivery/history/  
**Method:** GET  
**Auth:** ✅ Yes  

**Description:** Shows previously delivered orders.

---

## 🔹 Phase 5: Common & Notifications (Optional for now)

### ✅ Register Device Token
**Endpoint:** /api/common/register_fcm_token/  
**Method:** POST  

**Params:**
{
  "device_token": "fcm_device_token"
}

---

### ✅ Trigger Test Notification
**Endpoint:** /api/common/test_notification/  
**Method:** POST  

**Params:**
{
  "user_id": 4,
  "title": "Test",
  "message": "Hello World"
}

---

## 🚀 Hosting Phase
Once all APIs are implemented:

- Run full API test using Postman
- Add Swagger or ReDoc (optional)
- Prepare `requirements.txt`, `Procfile`, static/media setup
- Deploy to:
  - Railway (simple)
  - EC2 + Nginx (scalable)
- Host backend URL and test with Flutter apps
