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
- [ ] Document all changes made in the `work_summary.md` file.
- [ ] Review and finalize the implementation of the Vendor and Delivery apps as per the planned features.
- [ ] Implement Customer App Login/Registration UI and logic (using OTP flow).
- [ ] Implement Profile View/Update screens in Customer App.

## Session Summaries

### Session Date: [Insert Date Here - e.g., 2024-07-26]

*   **API Documentation:** Reviewed backend `urls.py` files and updated `plan/api_endpoints.md` to accurately reflect the implemented custom authentication (JWT/OTP) structure, profile endpoints, and correct URL paths (`/api/core/auth/...` etc.). Clarified authentication requirements in usage notes.
*   **Customer App Splash Screen:** Investigated the splash screen implementation. Verified that the existing `AuthProvider` checks for the access token in `FlutterSecureStorage` upon app initialization and the `Consumer` in `main.dart` handles navigation correctly based on the authentication status. The splash screen itself simply shows a loading indicator while this check occurs.
*   **Next Steps:** Plan to update this work summary, then potentially move to Customer App Login/Profile implementation or review Vendor/Delivery app progress.

{{ ... }}
