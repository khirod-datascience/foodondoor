from django.urls import path
from django.conf import settings
from django.conf.urls.static import static
from .views import (
    VendorRegisterView, VendorLoginView, VendorProfileView,
    MenuListView, MenuDetailView,
    ItemListView, ItemDetailView,
    OrderListView, OrderDetailView,
    ImageUploadView,
    EarningsSummaryView,
    UpdateFCMTokenView,
    NotificationListView,
    VendorSendOTP, VendorVerifyOTP,
)

# Define URL patterns specifically for the vendor functionality within auth_app
# Consider prefixing with 'vendor/' to avoid clashes if auth_app serves others
app_name = 'auth_app' # Optional: Add app namespace

urlpatterns = [
    # OTP Authentication
    path('vendor/send-otp/', VendorSendOTP.as_view(), name='vendor-send-otp'),
    path('vendor/verify-otp/', VendorVerifyOTP.as_view(), name='vendor-verify-otp'),

    # Registration (uses OTP flow now)
    path('vendor/register/', VendorRegisterView.as_view(), name='vendor-register'),

    # --- Keep Email/Password Login for now? Or remove if OTP is the only method ---
    path('vendor/login/', VendorLoginView.as_view(), name='vendor-login'),

    # Profile
    path('vendor/profile/', VendorProfileView.as_view(), name='vendor-profile'), # No ID needed, gets logged-in user

    # Menus
    path('vendor/menus/', MenuListView.as_view(), name='vendor-menu-list'),
    path('vendor/menus/<int:id>/', MenuDetailView.as_view(), name='vendor-menu-detail'),

    # Items (nested under menus)
    path('vendor/menus/<int:menu_id>/items/', ItemListView.as_view(), name='vendor-item-list'),
    path('vendor/items/<int:id>/', ItemDetailView.as_view(), name='vendor-item-detail'), # URL for specific item

    # Orders
    path('vendor/orders/', OrderListView.as_view(), name='vendor-order-list'),
    path('vendor/orders/<str:order_number>/', OrderDetailView.as_view(), name='vendor-order-detail'), # Supports PATCH for status

    # Earnings
    path('vendor/earnings/summary/', EarningsSummaryView.as_view(), name='vendor-earnings-summary'),

    # Notifications
    path('vendor/notifications/', NotificationListView.as_view(), name='vendor-notification-list'),
    path('upload-image/', ImageUploadView.as_view(), name='vendor-regs-upload-image'),
    # Utilities
    path('vendor/upload-image/', ImageUploadView.as_view(), name='vendor-upload-image'),
    path('vendor/fcm-token/', UpdateFCMTokenView.as_view(), name='vendor-update-fcm-token'), # No ID needed, uses logged-in user

    # --- REMOVE CUSTOMER FACING URLS if auth_app is vendor only ---
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

