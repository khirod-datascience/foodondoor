# FOODONDOOR - Work Summary

This document tracks the development progress, including features implemented, changes made, and screens created.

## Phase 1: Core Setup

*   [X] Initialize Django Backend Project (`foodondoor_backend`)
*   [X] Create Django Apps (`auth_app`, `customer_app`, `vendor_app`, `delivery_app`, `core`)
*   [X] Define Core Models (`Restaurant`, `MenuItem`, `Order`, `Cart`, `CartItem`, `Address`) - *Removed default User, moved profile logic*
*   [X] Define Independent Profile Models (`CustomerProfile`, `VendorProfile`, `DeliveryAgentProfile`) for Custom Authentication
*   [X] Removed Django `User` model dependency from core models
*   [X] Setup ~~PostgreSQL~~ SQLite Database (User request)
*   [X] Removed `djangorestframework-simplejwt`, Custom JWT Implementation Planned
*   [X] Reset and Re-initialized Database Migrations
*   [X] Integrate Firebase FCM (`fcm_token` added to profile models)
*   [X] Initialize Flutter Customer App (`foodondoor_customer_app`)
*   [X] Initialize Flutter Vendor App (`foodondoor_vendor_app`)
*   [X] Initialize Flutter Delivery App (`foodondoor_delivery_app`)
*   [X] Add Common Flutter Packages

## Phase 2: Customer App Development

*   [ ] **Splash Screen:**
    *   [ ] Check for JWT token
    *   [ ] Fetch user location
    *   [ ] Navigate to Login/Home

## Phase 3: Custom Authentication Implementation

*   [X] Implement JWT Handling: Create utility functions for generating and validating JWTs upon successful login.
*   [X] Create Login Views: Implement API views for user login for each profile type.
*   [X] Implement Authentication Backend/Middleware: Create a custom authentication mechanism to validate incoming JWTs.
*   [X] Update API Endpoints: Secure relevant API endpoints using the new custom authentication.
*   [X] Testing: Implement unit tests for the new authentication system and models to ensure functionality and security (Manual testing performed via API calls).

### Custom Authentication Implementation (Session 2 - Date: 2025-05-01)

**Objective:** Implement a custom JWT-based authentication system separate from Django's built-in auth, using the independent profile models.

**Key Changes:**
*   **Dependencies:** Added `PyJWT` to `requirements.txt`.
*   **Settings (`settings.py`):**
    *   Added custom JWT configuration (`JWT_SECRET_KEY`, `JWT_ALGORITHM`, `JWT_EXPIRATION_DELTA`, `JWT_AUTH_HEADER_PREFIX`). **Note:** `JWT_SECRET_KEY` is currently a placeholder and MUST be moved to environment variables.
    *   Configured `REST_FRAMEWORK` defaults:
        *   `DEFAULT_AUTHENTICATION_CLASSES`: Set to use `core.authentication.JWTAuthentication`.
        *   `DEFAULT_PERMISSION_CLASSES`: Set to `IsAuthenticatedOrReadOnly`.
*   **JWT Utility (`core/utils.py`):**
    *   Created `generate_jwt_token` function to create JWTs containing `user_id`, `user_type`, `exp`, and `iat` claims.
*   **Login Views:**
    *   Added `CustomerLoginView`, `VendorLoginView`, `DeliveryAgentLoginView` to handle credentials verification (using `check_password` from models) and return a JWT upon success.
    *   Set `permission_classes` to `AllowAny` for login views.
*   **Registration Views (`views.py` in each app):**
    *   Set `permission_classes` to `AllowAny`.
*   **Custom Authentication Backend (`core/authentication.py`):**
    *   Created `JWTAuthentication` class inheriting from `rest_framework.authentication.BaseAuthentication`.
    *   Validates `Authorization: Bearer <token>` header.
    *   Decodes token using `PyJWT` and settings.
    *   Retrieves the correct user profile (`CustomerProfile`, `VendorProfile`, `DeliveryAgentProfile`) based on `user_type` and `user_id` from the token payload.
    *   Populates `request.user` with the authenticated profile instance.
    *   Handles token errors (expired, invalid) and inactive/unapproved users.
*   **Profile Views (`views.py` in each app):**
    *   Added simple `RetrieveAPIView`s (`CustomerProfileView`, `VendorProfileView`, `DeliveryAgentProfileView`) as protected endpoints.
    *   These rely on the default `JWTAuthentication` to identify the user via `request.user`.
*   **URLs (`urls.py` in project and apps):**
    *   Added URL patterns for `/login/` and `/profile/` endpoints in each app.
    *   Ensured app URLs are included in the main project `urls.py` under `/api/`.
    *   Created empty `core/urls.py`.
*   **Migrations:** Confirmed migrations are up-to-date.
*   **Testing:** Started the development server for manual API testing.

### Custom Authentication Implementation (Session 3 - Date: YYYY-MM-DD)

**Objective:** Implement OTP-based authentication for Vendor and Delivery Agent profiles.

**Key Changes:**
*   **OTP Utility (`core/utils.py`):**
    *   Created `generate_otp` function to create OTPs.
    *   Created `get_otp_expiry` function to get OTP expiry time.
*   **OTP Views:**
    *   Added `SendOTPView` and `VerifyOTPView` to handle OTP generation, sending, and verification.
    *   Set `permission_classes` to `AllowAny` for OTP views.
*   **Vendor and Delivery Agent Profile Models:**
    *   Added `otp_code` and `otp_expiry` fields to `VendorProfile` and `DeliveryAgentProfile` models.
*   **Vendor and Delivery Agent Login Views:**
    *   Updated `VendorLoginView` and `DeliveryAgentLoginView` to use OTP-based authentication.

### Custom Authentication Implementation (Session 4 - Date: YYYY-MM-DD)

**Objective:** Implement registration flow for Customer profile.

**Key Changes:**
*   **Authentication Logic (Django - `core.views`, `customer_app.views`):**
    *   Implemented `SendOTPView` (`core.views`):
        *   Generates OTP.
        *   Stores OTP in cache (new user) or profile (existing - *refactor needed*).
    *   Implemented `VerifyOTPView` (`core.views`):
        *   Validates phone, OTP.
        *   **Signup Flow:** Returns `signup_required: True`, `signup_token`. Stores `{'phone_number': ...}` in cache keyed by `signup_token`.
        *   **Login Flow:** Returns access/refresh tokens.
    *   Implemented `RegisterCustomerView` (`customer_app.views`):
        *   Accepts `first_name`, `last_name`, `email`, `signup_token`.
        *   Validates `signup_token` against cache, retrieves `phone_number`.
        *   Creates `CustomerProfile` record.
        *   Deletes `signup_token` from cache.
        *   Generates and returns access/refresh tokens.
    *   Added JWT generation utilities (`core.utils`).
    *   Updated URLs (`core.urls`, `customer_app.urls`, main `urls.py`) to include `/api/customer/auth/register/`.
*   **Registration Screen (Flutter):**
    *   Created `RegistrationScreen.dart` UI with fields for name and email.
    *   Receives `signupToken` as navigation argument.
    *   Integrated with `AuthProvider`/`AuthService`'s new `registerUser` method.
    *   Calls backend `/api/customer/auth/register/` endpoint.
    *   Navigates to `HomeScreen` on successful registration (status 201 and token receipt).
*   **Flutter Integration:**
    *   Updated `OtpVerificationScreen` to navigate to `RegistrationScreen` with token when `AuthStatus` is `signupRequired`.
    *   Added route definition for `RegistrationScreen` in `main.dart`.
    *   Added `registerUser` methods to `AuthService` and `AuthProvider`.
    *   Added necessary API constant (`customerRegisterUrl`).

### Phase 3: Vendor App (Frontend - In Progress)

*   **Goal:** Implement core Vendor functionalities (Profile, Orders, Menu Management).
*   **Status:** Basic OTP Authentication implemented.
*   **Details:**
    *   Set up project structure similar to Customer App (`constants`, `features/auth`, `features/home`).
    *   Created `api_constants.dart` with relevant backend URLs.
    *   Checked `pubspec.yaml` for necessary dependencies (`dio`, `flutter_secure_storage`, `provider`). Ran `flutter pub get`.
    *   Implemented `AuthService` (`lib/src/features/auth/services/auth_service.dart`) with `sendOtp` and `verifyOtp` methods, setting `user_type` to `'vendor'`. Uses `flutter_secure_storage` for token handling.
    *   Implemented `AuthProvider` (`lib/src/features/auth/providers/auth_provider.dart`) using `ChangeNotifier` to manage authentication state (`AuthStatus`).
    *   Created `LoginScreen` (`lib/src/features/auth/screens/login_screen.dart`) for phone number input and OTP request.
    *   Created `OtpVerificationScreen` (`lib/src/features/auth/screens/otp_verification_screen.dart`) for OTP input and verification.
    *   Created placeholder `HomeScreen` (`lib/src/features/home/screens/home_screen.dart`) accessible after login.
    *   Updated `main.dart` to use `MultiProvider` (with `AuthProvider`), defined routes (`/login`, `/otp-verification`, `/home`), and implemented logic to show the initial screen based on `AuthStatus` (`LoginScreen` or `HomeScreen`). Used Teal theme color.
    *   **Menu Management Feature:**
        *   **Provider (`menu_provider.dart`):**
            *   Refactored from `ChangeNotifier` to `StateNotifier` (`MenuNotifier`).
            *   Manages state using `AsyncValue<List<MenuItem>>` for loading/error/data.
            *   Provides methods (`fetchMenuItems`, `addMenuItem`, `updateMenuItem`, `deleteMenuItem`) wrapping `MenuService` calls.
            *   Added `menuServiceProvider` to provide `MenuService` instance.
        *   **Menu List Screen (`menu_list_screen.dart`):**
            *   Created `MenuListScreen` (ConsumerWidget).
            *   Displays menu items using `ListView.builder` when state is `AsyncData`.
            *   Shows `CircularProgressIndicator` for loading state (`AsyncLoading`).
            *   Shows error message and retry button for error state (`AsyncError`).
            *   Includes UI elements for item details (name, description, price).
            *   Added buttons/icons for Edit (navigates) and Delete (shows confirmation dialog).
            *   Added a `Switch` for `isAvailable` status (calls `updateMenuItem` optimistically).
            *   Added AppBar action button to navigate to Add screen.
        *   **Add/Edit Menu Item Screen (`add_edit_menu_item_screen.dart`):**
            *   Created `AddEditMenuItemScreen` (ConsumerStatefulWidget).
            *   Accepts optional `MenuItem` for editing.
            *   Uses `GlobalKey<FormState>` for validation.
            *   Includes `TextFormField`s for name, description, price, category ID (temporary).
            *   Includes `SwitchListTile` for `isAvailable`.
            *   Calls `MenuNotifier.addMenuItem` or `MenuNotifier.updateMenuItem` on submit.
            *   Manages loading state (`_isLoading`) for the submit button.
            *   Navigates back on successful save.
        *   **Navigation:** Implemented navigation from `MenuListScreen` to `AddEditMenuItemScreen` using `Navigator.push`.
    *   **Order Management Feature:**
        *   **Provider (`order_provider.dart`):** Created `OrderProvider` (ChangeNotifier) to manage order state, list, current filter, loading status, and errors. Includes methods (`fetchOrders`, `acceptOrder`, `rejectOrder`, `markOrderReady`) wrapping `OrderService` calls and updating the local list.
        *   **Service (`order_service.dart`):** Implemented `OrderService` to handle API calls (`GET`, `POST`) for fetching and updating orders, using `dio` and handling authentication headers.
        *   **Model (`order_model.dart`):** Created `Order`, `OrderItem`, and `CustomerInfo` models with `fromJson` factory constructors. Added `copyWith` method to `Order` model for easier state updates.
        *   **Order List Screen (`order_list_screen.dart`):** Created `OrderListScreen` (ConsumerStatefulWidget) with `TabBar` for filtering orders by status (Pending, Accepted/Preparing, Ready, All). Displays orders in a `ListView`, showing key details and action buttons (Accept, Reject, Mark Ready) based on order status.
        *   **Integration:** Added 'Orders' tab to `HomeScreen`'s bottom navigation, pointing to `OrderListScreen`. Defined route in `main.dart`.
        *   **Dependencies:** Added `intl` package to `pubspec.yaml` for date/time formatting.
        *   **Debugging:** Resolved multiple compilation errors related to:
            *   Syntax errors in `OrderProvider`.
            *   Missing `intl` package.
            *   Missing `copyWith` method in `Order` model.
            *   Incorrect `VendorProfile` model usage/imports in `ProfileScreen`, `ProfileProvider`, and `ProfileService`.
            *   Unhandled `switch` case in `OrderProvider`.
            *   Multiple connected devices issue during `flutter run`.
        *   **Status:** App successfully launches on the target device after fixes.

### Phase 4: Delivery App (Frontend - In Progress)

*   **Goal:** Implement core Delivery Agent functionalities (Profile, Available Orders, Active Delivery Tracking).
*   **Status:** Basic OTP Authentication implemented.
*   **Details:**
    *   Set up project structure similar to Customer App (`constants`, `features/auth`, `features/home`).
    *   Created `api_constants.dart` with relevant backend URLs.
    *   Checked `pubspec.yaml` for necessary dependencies (`dio`, `flutter_secure_storage`, `provider`). Ran `flutter pub get`.
    *   Implemented `AuthService` (`lib/src/features/auth/services/auth_service.dart`) with `sendOtp` and `verifyOtp` methods, setting `user_type` to `'delivery_agent'`. Uses `flutter_secure_storage` for token handling.
    *   Implemented `AuthProvider` (`lib/src/features/auth/providers/auth_provider.dart`) using `ChangeNotifier` to manage authentication state (`AuthStatus`).
    *   Created `LoginScreen` (`lib/src/features/auth/screens/login_screen.dart`) for phone number input and OTP request.
    *   Created `OtpVerificationScreen` (`lib/src/features/auth/screens/otp_verification_screen.dart`) for OTP input and verification.
    *   Created placeholder `HomeScreen` (`lib/src/features/home/screens/home_screen.dart`) accessible after login.
    *   Updated `main.dart` to use `MultiProvider` (with `AuthProvider`), defined routes (`/login`, `/otp-verification`, `/home`), and implemented logic to show the initial screen based on `AuthStatus` (`LoginScreen` or `HomeScreen`). Used Orange theme color.

### Phase 5: FCM Push Notifications
{{ ... }}

### Next Steps

- [x] Update the `api_endpoints.md` file to accurately reflect the implemented authentication and profile endpoints.
- [x] Implement the splash screen logic in the Customer app to check for JWT tokens and navigate accordingly.
- [x] Document all changes made in the `work_summary.md` file.
- [x] Successfully tested the end-to-end customer registration flow (OTP send -> OTP verify -> Registration -> Home Screen navigation).
- [ ] Implement Vendor App features based on `plan.md`:
    - [ ] Dashboard Screen (Initial Structure)
    - [ ] Profile Screen (View Profile)
    - [x] Order Management (Backend + Frontend - *Initial Implementation Done, Needs Testing*)
    - [x] Menu Management (Backend + Frontend - *Implementation Done*)
- [ ] Implement Customer App features:
    - [ ] Profile View/Update screens.
    - [ ] Home screen content (Banners, Categories, Restaurants etc.).
- [ ] Implement Delivery App features based on `plan.md`.
- [ ] Review and finalize the implementation of the Vendor and Delivery apps as per the planned features.
- [ ] Implement FCM Push Notifications.

## Phase X: Customer App - Menu Browsing (Completed)

*   **Objective:** Allow customers to browse restaurants, categories, and food items.
*   **Backend Changes (`vendor_app`, `customer_app`):
    *   **Models:** Utilized `Restaurant`, `Category`, `FoodItem` models (defined initially, refined in `vendor_app`).
    *   **Serializers:** Created `RestaurantSerializer`, `CategorySerializer`, `FoodItemSerializer` in `vendor_app.serializers`.
    *   **Views (`customer_app.views`):** Implemented `RestaurantListView`, `RestaurantDetailView`, `CategoryListView`, `FoodItemDetailView`. `RestaurantDetailView` likely fetches related categories/items via serializer.
    *   **URLs (`customer_app.urls`):** Added endpoints for `/restaurants/`, `/restaurants/<id>/`, `/categories/`, `/food-items/<id>/`, and nested categories list `/restaurants/<uuid:restaurant_pk>/categories/`.
*   **Frontend Changes (Customer App):** (Details TBD/Not implemented yet in summary)
    *   Screens likely needed: Restaurant List, Restaurant Detail (showing categories/items).
*   **Migrations:** Ran `makemigrations` and `migrate` for `vendor_app` and `customer_app` after model/serializer additions.

## Phase 2: Customer App - Authentication

*   **Login Screen:**
    *   Implemented UI (`LoginScreen.dart`) for phone number input.
    *   Integrated with `AuthProvider` to call `sendOtp`.
    *   Handled loading state within the screen and button.
    *   **Debugging & Fix (OTP Navigation):**
        *   Diagnosed issue where navigation to `OtpVerificationScreen` failed after successful OTP send.
        *   Used print statements to track `AuthProvider` state changes and widget `mounted` status.
        *   Identified root cause: `Consumer<AuthProvider>` in `main.dart` was rebuilding with `SplashScreen` when status became `loading`, causing `LoginScreen` to unmount before `await authProvider.sendOtp()` completed.
        *   Fixed by modifying the `Consumer` in `main.dart` to only show `SplashScreen` for `AuthStatus.initial`, keeping `LoginScreen` mounted during its own loading process.
*   **OTP Verification Screen:**
    *   Implemented UI (`OtpVerificationScreen.dart`) using `pinput` package.
    *   Integrated with `AuthProvider` to call `verifyOtp`.
    *   Added resend OTP functionality.
    *   **Signup Flow Integration:**
        *   Modified `_submitOtp` to check `AuthProvider.status` *after* `verifyOtp` completes.
        *   Handles `AuthStatus.authenticated` (navigates to `HomeScreen`).
        *   Handles `AuthStatus.signupRequired` (currently shows a SnackBar with the `signup_token`, will navigate to `RegistrationScreen`).
        *   Handles `AuthStatus.error` (shows error SnackBar).
*   **Authentication Logic (Flutter - `AuthProvider`, `AuthService`):**
    *   Implemented `sendOtp` and `verifyOtp` methods.
    *   Used `flutter_secure_storage` to store/retrieve access/refresh tokens.
    *   Managed different authentication states (`AuthStatus` enum).
    *   **Signup Flow Handling:**
        *   Created `AuthResult` model and `AuthResultType` enum.
        *   Updated `AuthService.verifyOtp` to return `AuthResult` based on backend response (`loginSuccess` with tokens, `signupRequired` with `signup_token`, or `failure`).
        *   Updated `AuthProvider` to include `AuthStatus.signupRequired`, store `signup_token`, and process `AuthResult` from the service.
*   **Authentication Logic (Django - `core.views`):**
    *   Implemented `SendOTPView`:
        *   Generates OTP.
        *   Stores OTP in cache (for new users) or `UserProfile` (for existing - *to be refactored later for separate profiles*).
        *   Simulates SMS sending (prints OTP to console).
    *   Implemented `VerifyOTPView`:
        *   Validates phone, OTP, and user type.
        *   Checks OTP against cache (new user) or `UserProfile` (existing - *to be refactored*).
        *   **Signup Flow:** Returns `{'signup_required': True, 'signup_token': ...}` for valid OTP from new users.
        *   **Login Flow:** Returns access/refresh tokens for existing users with valid OTP.
    *   Added basic JWT generation utilities (`core.utils`).
    *   Updated core URLs (`core.urls`).

*   **Next Steps:**
    *   Create `RegistrationScreen.dart` in Flutter.
    *   Implement backend registration view/endpoint (`/api/customer/auth/register/`).
    *   Connect Flutter registration UI to backend API via `AuthService`/`AuthProvider`.
    *   Refactor backend OTP logic to use distinct `CustomerProfile` model instead of cache/temporary fields.

## Phase 3: Vendor App
{{ ... }}

### Session Summaries

### Session Date: [Insert Date Here - e.g., 2024-07-26]

*   **API Documentation:** Reviewed backend `urls.py` files and updated `plan/api_endpoints.md` to accurately reflect the implemented custom authentication (JWT/OTP) structure, profile endpoints, and correct URL paths (`/api/core/auth/...` etc.). Clarified authentication requirements in usage notes.
*   **Customer App Splash Screen:** Investigated the splash screen implementation. Verified that the existing `AuthProvider` checks for the access token in `FlutterSecureStorage` upon app initialization and the `Consumer` in `main.dart` handles navigation correctly based on the authentication status. The splash screen itself simply shows a loading indicator while this check occurs.
*   **Next Steps:** Plan to update this work summary, then potentially move to Customer App Login/Profile implementation or review Vendor/Delivery app progress.

### Session Date: 2025-05-01

*   **Vendor App Backend:**
    *   Created `Restaurant`, `Category`, and `FoodItem` models in `vendor_app/models.py`.
    *   Created corresponding `RestaurantSerializer`, `CategorySerializer`, and `FoodItemSerializer` in `vendor_app/serializers.py`.

*   **Migrations & Bug Fixes:**
    *   Resolved multiple `ImportError` instances related to serializers in `customer_app` and `delivery_app` views.
    *   Moved `OTP_EXPIRY_MINUTES` constant from `core.models` to `settings.py` and updated imports in `core.views`.
    *   Removed conflicting `Address`, `Restaurant`, and `MenuItem` models from `core.models.py` to resolve migration clashes. Temporarily adjusted FKs in remaining `core` models (Cart/Order) to allow migration.
    *   Successfully created and applied migrations for `vendor_app` models.
*   **Customer App Backend (Browsing):**
    *   Implemented `RestaurantListView` (`/api/customer/restaurants/`) to list active restaurants.
    *   Implemented `RestaurantDetailView` (`/api/customer/restaurants/<uuid:pk>/`) to show details of a specific active restaurant (including nested categories/items via serializer).
    *   Implemented `CategoryListView` (`/api/customer/restaurants/<uuid:restaurant_pk>/categories/`) to list categories for a specific active restaurant.
    *   Implemented `FoodItemDetailView` (`/api/customer/food-items/<uuid:pk>/`) to show details for a specific available food item.
    *   Corrected `ImportError` for `CategorySerializer` in `customer_app/views.py`.
*   **Next Steps:** Move to implement frontend Customer App authentication (Login/Signup) and home screen, connecting to backend endpoints.

### Session Date: 2025-05-01 (Continued)

*   **Flutter Customer App (Theme):**
    *   Created `lib/config/theme/app_theme.dart`.
    *   Defined a `ThemeData` using an orange primary color (inspired by provided screenshot) and the Poppins font via `google_fonts`.
*   **Next Steps:** Add `google_fonts` dependency, apply theme in `main.dart`, and implement Login/Signup screens.

### Session Date: YYYY-MM-DD

*   **Registration Flow Implementation:**
    *   Implemented `RegisterCustomerView` in Django to handle customer registration.
    *   Created `RegistrationScreen` in Flutter to handle user input for registration.
    *   Integrated `RegistrationScreen` with `AuthProvider` and `AuthService` to call backend registration endpoint.
    *   Updated `OtpVerificationScreen` to navigate to `RegistrationScreen` when `AuthStatus` is `signupRequired`.
    *   Added necessary API constants and route definitions.
*   **Next Steps:**
    *   **Testing:** Thoroughly test the login (existing user) and registration (new user) flows.
    *   **Refactor Backend OTP:** Modify `SendOTPView`/`VerifyOTPView` to use distinct `CustomerProfile` model instead of cache/temporary fields for existing user OTP checks.
    *   Implement profile view/edit functionality.
    *   Implement logout functionality properly (clearing state and tokens).

### Session Date: YYYY-MM-DD

*   **Vendor App Fixes:**
    *   **OTP Navigation:**
        *   Diagnosed issue where `LoginScreen` didn't navigate to `OtpVerificationScreen`.
        *   Removed direct navigation call in `LoginScreen._submit`.
        *   Added `AuthStatus.otpSent` enum value.
        *   Updated `AuthProvider.sendOtp` to set status to `otpSent` on success.
        *   Updated `Consumer<AuthProvider>` in `main.dart` to navigate to `OtpVerificationScreen` on `otpSent` status.
    *   **Theme Alignment:**
        *   Added `google_fonts` dependency to `foodondoor_vendor_app`.
        *   Updated `ThemeData` in `main.dart` to use `Colors.orange` primary swatch and 'Poppins' font family, matching the Customer App theme.

*   **Next Steps:** Test OTP login flow and theme appearance in Vendor App. Continue implementing Vendor App features (e.g., Dashboard, Menu Management).

### Session Date: YYYY-MM-DD

*   **Vendor Signup Profile Creation Flow:**
    *   **Objective:** Implement the profile creation step for new vendors after OTP verification.
    *   **Changes:**
        1.  **`api_constants.dart`:**
            *   Added `completeProfileUrl` constant for the new backend endpoint (`/api/auth/vendor/complete-profile/`).
        2.  **`src/utils/validators.dart`:** (New File)
            *   Created a utility file for form validation functions.
            *   Added `validateEmail` and `validateNotEmpty` static methods.
        3.  **`AuthService` (`src/features/auth/services/auth_service.dart`):**
            *   Added handling for `signupToken` (secure storage key, `getSignupToken`, `clearSignupToken`).
            *   Modified `verifyOtp` to store the `signupToken` when backend response indicates signup.
            *   Updated `clearTokens` to also clear `signupToken`.
            *   Implemented `completeProfile(Map<String, dynamic> profileData)` method:
                *   Retrieves `signupToken`.
                *   Sends profile data and `signupToken` (as Bearer token) to `completeProfileUrl`.
                *   On success (200/201 response with access/refresh tokens), stores new tokens and clears `signupToken`.
                *   Returns `true` on success, `false` on failure.
        4.  **`AuthProvider` (`src/features/auth/providers/auth_provider.dart`):**
            *   Added `submitProfile(Map<String, dynamic> profileData)` method:
                *   Sets status to `loading`.
                *   Calls `_authService.completeProfile()`.
                *   On success, sets status to `authenticated`.
                *   On failure, sets status back to `needsProfileSetup` and stores an error message.
        5.  **`ProfileScreen` (`src/features/profile/screens/profile_screen.dart`):**
            *   Modified `initState` to only call `fetchProfile` if `AuthProvider` status is already `authenticated`.
            *   Modified `build` method:
                *   Checks `AuthProvider.status`.
                *   If `needsProfileSetup`:
                    *   Displays a `Form` with fields for Business Name and Email, using `TextEditingController`s and `validators.dart`.
                    *   Includes a submit button calling `_submitForm`.
                    *   Manages `_isSubmitting` state to show loading indicator on button and prevent double submission.
                    *   Calls `context.read<AuthProvider>().submitProfile()` on valid submission.
                    *   Displays error messages from `AuthProvider` if submission fails.
                *   If `authenticated`:
                    *   Displays the existing profile view logic using `Consumer<ProfileProvider>`.
        6.  **API Endpoint Alignment (Vendor Registration):**
            *   Reviewed `api_endpoints.md` and determined the vendor profile completion should mirror the customer registration endpoint.
            *   **`api_constants.dart`:**
                *   Removed `completeProfileUrl` (`/api/auth/vendor/complete-profile/`).
                *   Added `vendorRegisterUrl` (`/api/vendor/auth/register/`).
            *   **`AuthService`:**
                *   Renamed `completeProfile` method to `registerVendor`.
                *   Modified `registerVendor` to target the new `vendorRegisterUrl`.
                *   Changed logic to send the `signupToken` in the request *body* (key: `signup_token`) instead of the `Authorization` header.
            *   **`AuthProvider`:**
                *   Updated `submitProfile` method to call the renamed `_authService.registerVendor` method.

### Phase 4: Delivery App Development
{{ ... }}

### Session Date: YYYY-MM-DD

*   **Dependency Injection & Error Fixes:**
    *   Resolved compilation errors arising after `AuthService` constructor modification.
    *   **`AuthProvider` & `ProfileProvider`:**
        *   Updated constructors to accept injected `AuthService` instance (Dependency Injection) instead of creating their own.
        *   Fixed null assignment error for `_errorMessage` in `AuthProvider`.
        *   Fixed variable scope error for `success` variable in `AuthProvider.submitProfile`.
    *   **`main.dart`:**
        *   Implemented `MultiProvider` to manage dependencies.
        *   Added `Provider` for `Dio` and `FlutterSecureStorage`.
        *   Added `ProxyProvider` to create and provide `AuthService` (using Dio/Storage) and `ProfileService` (assuming dependency on AuthService).
        *   Updated `ChangeNotifierProvider` for `AuthProvider` and `ProfileProvider` to `ChangeNotifierProxyProvider` to receive their respective service dependencies (`AuthService`, `ProfileService`).

### Phase 4: Delivery App Development
{{ ... }}

## Backend Changes

*   **`foodondoor_backend/urls.py`**: Uncommented `include('vendor_app.urls')` and `include('delivery_app.urls')` to enable access to vendor and delivery API endpoints.
*   **`vendor_app/views.py`**: Implemented `VendorRegistrationView` to handle the final step of vendor signup using the `signup_token` received from `core.views.VerifyOTPView`. This view validates the token, creates the `VendorProfile`, generates access/refresh tokens, and clears the signup token from the cache.
*   **`vendor_app/urls.py`**: Added the URL pattern `path('auth/register/', VendorRegistrationView.as_view(), name='vendor-register')` to map the registration endpoint.

## Frontend Changes (Customer App - `foodondoor_customer_app`)
{{ ... }}

*   **Frontend Review:** Confirmed `AuthService` uses correct core endpoints for OTP send/verify and customer registration (`/api/customer/auth/register/`). Reviewed `main.dart` for correct provider setup and initial routing based on `AuthProvider` state.

## Frontend Changes (Vendor App - `foodondoor_vendor_app`)

*   **Constants Review:** Located and reviewed `api_constants.dart`. Identified the correct core auth endpoints but an incorrect `vendorRegisterUrl` (`/api/vendor/auth/register/`) which has now been implemented in the backend.
*   **Service Review:** Reviewed `AuthService.dart`. Confirmed correct usage of core OTP endpoints and `signup_token` handling. The `registerVendor` method correctly uses the `/api/vendor/auth/register/` endpoint, which should now work.

## Frontend Changes (Delivery App - `foodondoor_delivery_app`)

*   *(Pending Review)*

## Discrepancies & Issues

*   ~~**Vendor Registration:** The vendor frontend (`AuthService.registerVendor`) was calling `/api/vendor/auth/register/`, but the backend view to handle this was missing. The `core.views.VerifyOTPView` correctly generated a `signup_token`, but no view consumed it.~~ **RESOLVED:** Implemented `VendorRegistrationView` in `vendor_app/views.py` and mapped it to `/api/vendor/auth/register/` in `vendor_app/urls.py`.
*   **Placeholder Views:** Many views in `vendor_app/views.py` and `delivery_app/views.py` are still placeholders.
*   **Delivery App Registration:** The registration flow for the delivery app needs similar verification (frontend constants/service vs backend implementation).

## Next Steps

**Immediate Focus: Vendor App Completion**

1.  **Backend Verification:**
    *   Manually test the vendor registration flow (Send OTP -> Verify OTP (get signup token) -> Register Vendor) using a tool like Postman or curl to ensure the new `VendorRegistrationView` works correctly.

2.  **Vendor Frontend Implementation (`foodondoor_vendor_app`):**
    *   **Review `main.dart`:** Check provider setup and initial routing logic.
    *   **Implement Auth Screens:**
        *   `LoginScreen`: Input phone number, call `AuthService.sendOtp`.
        *   `OtpVerificationScreen`: Input OTP, call `AuthService.verifyOtp`. Handle navigation based on response ('login' -> Home, 'signup' -> Registration).
        *   `RegistrationScreen`: Input profile details (Restaurant Name, Address etc. as per `VendorRegistrationSerializer`), call `AuthService.registerVendor`. Navigate to Home on success.
    *   **Implement Core Screens:**
        *   `SplashScreen` (if needed, or rely on `AuthProvider` initial state).
        *   `HomeScreen` (Dashboard): Basic structure, potentially showing pending orders count, quick links.
        *   `ProfileScreen`: Display vendor details (fetched via `/api/vendor/profile/`), potentially link to profile update.
    *   **Implement Feature Screens (using placeholder backend APIs initially):**
        *   `OrderListScreen`: Display list of orders (using `/api/vendor/orders/`).
        *   `OrderDetailScreen`: Show order details, provide buttons for Accept/Reject/Ready (using `/api/vendor/orders/<pk>/...`).
        *   `MenuItemListScreen`: Display menu items (using `/api/vendor/menu-items/`).
        *   `MenuItemAddEditScreen`: Form to add/edit menu items (using `/api/vendor/menu-items/add/` or `/api/vendor/menu-items/<pk>/update/`).
    *   **Theme Application:** Apply the theme defined in `plan.md` consistently across all screens.
    *   **API Integration:** Ensure all screens correctly use `AuthService`, `ProfileService` (needs implementation or check existence), and potentially new services for Orders and Menu Items.

3.  **Backend Implementation (Vendor - Parallel):**
    *   Implement the placeholder views in `vendor_app/views.py` for profile update, orders, and menu items.

4.  **Delivery App Analysis:**
    *   Review `foodondoor_delivery_app` constants, services, and `main.dart`.
    *   Verify/Implement backend registration/profile completion for delivery agents.

5.  **Testing:**
    *   End-to-end testing of Customer, Vendor flows.

---
*Task Progress Marker*
---

### Phase 3: Vendor App - In Progress

**Objective:** Implement core vendor functionalities: Authentication, Profile Management, Menu Management, Order Handling.

**Current Focus:** Vendor Authentication Flow

**Completed (Vendor Auth):**
- **Backend:**
  - Implemented `VendorRegistrationView` (POST `/api/vendor/auth/register/`) using `VendorRegistrationSerializer`.
    - Handles `signup_token` validation.
    - Creates `VendorProfile`.
    - Generates access/refresh tokens using a helper function (reused from core).
    - Clears `signup_token` from cache.
  - Added URL pattern for `VendorRegistrationView`.
- **Frontend:**
  - Refactored `AuthProvider`:
    - Renamed `needsProfileSetup` -> `signupRequired`.
    - Stores `signup_token` when status is `signupRequired`.
    - Removed unused `submitProfile` method.
  - Updated `main.dart` routing:
    - Added route for `RegistrationScreen`.
    - Navigates to `RegistrationScreen` when `AuthProvider` status is `signupRequired`, passing the `signup_token`.
  - Verified `LoginScreen` implementation (calls `sendOtp`).
  - Corrected `OtpVerificationScreen` (removed explicit navigation, calls `verifyOtp`).
  - Created initial `RegistrationScreen` UI (Email, ~~Password~~, Business Name).
  - Added `validatePassword` to `validators.dart`.
  - Verified `AuthService.registerVendor` implementation (sends `signup_token` in body, calls correct URL, stores tokens, clears signup token).
  - Verified `ApiConstants.vendorRegisterUrl`.

**CORRECTION (2025-05-02):**
- **Issue:** Incorrectly introduced password fields (`password`, `confirm password`) in the vendor registration flow (`VendorProfile` model, `VendorRegistrationSerializer`, `RegistrationScreen`) deviating from the project plan of **OTP-only authentication** for all apps.
- **Action:** Removing all password-related fields and logic from backend models/serializers/views and frontend screens/validators/services. Vendor authentication will rely solely on OTP verification and token management.

**Next Steps (Vendor App):**
1.  **Apply Password Removal:** Implement the backend and frontend code changes to remove password fields.
2.  **Run Backend Migrations:** Apply database changes.
3.  **Implement Vendor `ProfileScreen`:** Create UI for viewing vendor profile details (Business Name, Email - read-only). Fetch data using `ProfileProvider` (was `AuthService`). 
4.  **Implement Vendor `HomeScreen` UI:** Basic structure and navigation elements.
5.  **Implement Menu Management:** Models (`Restaurant`, `Category`, `FoodItem` - already exist), Serializers, Views (CRUD operations), and Frontend Screens.
6.  **End-to-End Testing:** Test the corrected registration flow and profile/menu features.

### Fixes Made to the Vendor Registration Flow

*   **OTP Navigation:** Fixed an issue where `LoginScreen` didn't navigate to `OtpVerificationScreen` after sending OTP.
*   **Theme Alignment:** Updated `ThemeData` in `main.dart` to use `Colors.orange` primary swatch and 'Poppins' font family, matching the Customer App theme.
*   **Vendor Registration:** Implemented `VendorRegistrationView` in `vendor_app/views.py` to handle the final step of vendor signup using the `signup_token` received from `core.views.VerifyOTPView`.
*   **API Endpoint Alignment:** Updated `api_constants.dart` to use the correct `vendorRegisterUrl` (`/api/vendor/auth/register/`) which has been implemented in the backend.
*   **Service Review:** Verified `AuthService.dart` uses the correct core OTP endpoints and `signup_token` handling.

---

### [2025-05-03] Vendor App ProfileService Refactor (CRUD Alignment)

*   **ProfileService:** Implemented real API calls for vendor profile fetch and update (getVendorProfile, updateVendorProfile).
*   **Removed dummy data** and improved error handling for profile operations.
*   **Plan Alignment:** Step 1 of vendor CRUD alignment with plan.md.
*   **Next:** Restaurant and menu management CRUD fixes, then error handling improvements.

### Restaurant Profile Management
*   **Frontend (Display):**
    *   Created `Restaurant` model (`restaurant_model.dart`).
    *   Created `RestaurantService` (`restaurant_service.dart`) with `getRestaurantDetails` and `updateRestaurantDetails` methods.
    *   Created `RestaurantProvider` (`restaurant_provider.dart`) for state management.
    *   Registered provider in `main.dart`.
    *   Created `RestaurantProfileScreen` (`restaurant_profile_screen.dart`) to display details fetched via provider.
    *   Added navigation from `HomeScreen` and route in `main.dart`.
*   **Backend (Retrieve/Update):**
    *   Verified `Restaurant` model and `RestaurantSerializer`.
    *   Created `VendorRestaurantView` (RetrieveUpdateAPIView) in `vendor_app/views.py` to handle GET/PATCH/PUT for the vendor's associated restaurant using `request.user`.
    *   Added URL pattern `/api/vendor/restaurant/` in `vendor_app/urls.py`.
*   **Frontend (Edit):** 
    *   **Completed:** Added Edit button to `RestaurantProfileScreen` AppBar, navigates to `EditRestaurantScreen` passing current data.
    *   Created `EditRestaurantScreen` (`edit_restaurant_screen.dart`) with a form using `TextEditingController`s initialized with data.
    *   Implemented `_submitForm` in `EditRestaurantScreen` to validate, call `RestaurantProvider.updateRestaurantDetails` with updated data map, handle loading/success/error states, and navigate back.
    *   Configured `onGenerateRoute` in `main.dart` to handle the `EditRestaurantScreen` route and pass the `Restaurant` argument.

*   **Menu Management (Categories & Items):**
    *   List Categories Screen.

### Flutter App Dependency Injection Refactoring (May 2025)

*   **Context:** Addressed significant build failures related to provider setup and dependency injection, primarily impacting `ProfileService`, `ProfileProvider`, and `Dio` usage.
*   **Identified Issues:**
    *   `ProfileService` incorrectly instantiated its own `Dio` and `AuthService` dependencies.
    *   `ProfileProvider` used the wrong service (`AuthService` instead of `ProfileService`) to fetch profile data and had type mismatches.
    *   Provider setup in `main.dart` was incorrect, leading to constructor argument errors (too few/too many arguments) for `ProfileService` and `ProfileProvider`.
    *   Persistent `Dio` type errors suggested build cache or Pub cache corruption.
*   **Fixes Implemented:**
    *   Added a constructor to `ProfileService` to accept injected `Dio` and `AuthService`.
    *   Modified `ProfileProvider` to correctly use the injected `ProfileService` and handle the `VendorProfile` object return type.
    *   Refactored provider setup in `main.dart` using `ProxyProvider2` and `ChangeNotifierProxyProvider2` for correct multi-dependency injection.
    *   Executed `flutter clean`, `dart pub cache repair`, and `flutter pub get` to resolve underlying package cache issues contributing to `Dio` errors.

 **Other/Misc:**
 
 *   **Documentation:**








------------------------------------------------------------------

### [2025-05-04] Vendor App API & Model Cleanup

* **API Constants Deduplication:**
  - Removed duplicate and outdated `api_constants.dart` from `lib/src/utils/`.
  - Ensured all imports in the codebase reference the single source of truth at `lib/src/constants/api_constants.dart`.

* **VendorProfile Model Alignment:**
  - Updated `VendorProfile` model to match backend API response (flat structure, no nested `user`).
  - Adjusted null safety and field types to match backend contract.

* **OrderService & Profile Fixes:**
  - Fixed all imports and usages of `ApiConstants` in `OrderService`.
  - Corrected order status URL construction to use the right constants.
  - Updated `ProfileScreen` to handle nulls and new model structure.

* **General Codebase Cleanup:**
  - Removed all references to deprecated constants and fields.
  - Improved error handling and null safety in profile-related screens.

* **Build/Test:**
  - Ran `flutter clean`, `flutter pub get` and verified build launches successfully after fixes.

------------------------------------------------------------------



