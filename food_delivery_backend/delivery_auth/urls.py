from django.urls import path, re_path
# Import ALL views used in paths
from .views import *
print("--- Loading delivery_auth/urls.py ---") # DEBUG

# Define an app_name for namespacing if needed, though not strictly required for API views
# app_name = 'delivery_auth'

urlpatterns = [
    # Authentication endpoints
    path('otp/send/', SendOTPView.as_view(), name='delivery_send_otp'),
    path('otp/verify/', VerifyOTPView.as_view(), name='delivery_verify_otp'),
    path('register/', RegisterView.as_view(), name='delivery_register'),

    # Order endpoints - Make trailing slash optional
    re_path(r'^orders/?$', DeliveryOrderListView.as_view(), name='delivery_order_list'),
    path('orders/<str:order_number>/status/', DeliveryOrderStatusUpdateView.as_view(), name='delivery-order-status-update'),
    path('orders/<str:order_number>/location/', DeliveryOrderLocationUpdateView.as_view(), name='delivery-order-location-update'),

    # FCM/Notification endpoints
    path('fcm-token/update/', UpdateFCMTokenView.as_view(), name='delivery-fcm-token-update'),
    path('testnotify/', TestNotificationView.as_view(), name='delivery-test-notification'),

    # TODO: Add endpoint for custom token refresh if needed
]

print(f"--- delivery_auth urlpatterns: {urlpatterns} ---") # DEBUG
