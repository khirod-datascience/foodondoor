# Flutter Food Delivery App UI Update

## Goal:
Update my in-progress Flutter food delivery app UI using the given Figma reference, **without breaking any logic or backend integration**.

### 🔗 Figma UI Reference
Use this Figma design as the visual base only (not for functionality or logic):

[Food Delivery App UI ](https://www.figma.com/design/r6eBsC6sfgFJBYYFVmvlnF/Food-Delivery-App--Community-?node-id=601-969&t=2WznHlbNA0Hmnduk-0)

## 📱 Project Overview:
This is a three-part Flutter app stack:

- **Customer App** (`food_ordering_app`)
- **Vendor App** (`foodondoor_vendor`)
- **Delivery Partner App** (`delivery_partner_app`)

### Existing Tech Stack:
- **Backend**: Django
- **Authentication**: OTP-based mobile authentication (custom, no Firebase/JWT)
- **Architecture**: Modular
- **APIs**: Working and wired with business logic
- **State Management**: Already implemented

### 🚫 Do Not:
- ❌ **Regenerate screens from scratch**.
- ❌ **Change routing, logic, or API integration**.
- ❌ **Modify state management or controllers**.
- ❌ **Introduce any new logic** unless absolutely necessary for UI.

## 🎯 What to Do:
- ✅ **Update only the visual design** using Figma as reference.
- ✅ **Use Material 3 design**, Poppins font, and Deep Orange A700 as primary color.
- ✅ **Maintain all functionality** and existing widget structure.
- ✅ **Break down designs into reusable widgets/components**.
- ✅ **Follow clean UI architecture** and naming conventions.
- ✅ **Implement modern, rounded, minimal design** with soft shadows, good spacing, and mobile-first responsiveness.

---

## 🔄 Screen-by-Screen Design Update Scope:

### 1️⃣ **Customer App** (`food_ordering_app`)

#### 🔐 **Authentication:**
- Only OTP-based mobile login.
- Redirect unregistered users to signup screen (Full Name + Mobile Number only).
- Remove email/password logic.

#### 🏠 **Home Screen:**
- Location & delivery zone check at top.
- Search bar with icon.
- Horizontally scrollable banners, categories.
- Nearby Restaurants (horizontal).
- Top Rated (horizontal).
- Food Items (vertical grid/list).

#### 🍽️ **Restaurant Detail:**
- Name, rating, delivery estimate.
- Menu items → tap to add to cart.
- Show “Add” or “+” button on each item.

#### 🛒 **Cart:**
- List of selected items with quantity.
- Show item total and overall total.
- Checkout → show address + summary + “Place Order” (no payment integration).

#### 👤 **Profile:**
- User info.
- Order history.

---

### 2️⃣ **Vendor App** (`foodondoor_vendor`)

#### 🔐 **OTP Login Only**

#### 📋 **Dashboard:**
- Order List (Tabs: New / In Progress / Completed).
- Accept / Reject orders.
- Show order summary.

#### 🍴 **Menu Management:**
- Add/update/delete items.
- Item: Name, price, image, description.

#### 🏪 **Profile:**
- Restaurant info (address, phone, hours).

---

### 3️⃣ **Delivery Partner App** (`delivery_partner_app`)

#### 🔐 **OTP Login**

#### 🚚 **Order Flow:**
- Show New Order requests.
- Accept Order → show pickup + drop address.
- Status change: Picked Up → Delivered.

#### 📜 **Order History:**
- List of delivered orders with status/date.

---

## 🧩 **UI Guidelines Recap:**

| Element           | Value                              |
|-------------------|------------------------------------|
| **Font**          | Poppins                            |
| **Primary Color** | Deep Orange A700                   |
| **Design Style**  | Material 3, soft shadows           |
| **Corners**       | Rounded, 16–20px radius            |
| **Layout**        | Clean, mobile-first, padded        |
| **Icons**         | Use Lucide or Material Icons       |
| **Components**    | Modular & reusable widgets        |

---

## 🧠 **Final Instructions for AI UI Generator:**

- 🔁 **Update screen-by-screen** using existing files (don’t create new routing or files unless a new widget is needed).
- ♻️ **Extract and replace UI components** like cards, buttons, text fields, app bars into modular widgets.
- ✨ Ensure **styling matches the Figma** for all UI elements.
- 💡 For unmatched screens, **match the purpose and layout**, but adopt the design language from Figma.
