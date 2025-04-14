from django.urls import path
from django.conf import settings
from django.conf.urls.static import static
from .views import (
    SendOTP, VerifyOTP, SignupView, VendorListView, NotificationListView, 
    ProfileView, FoodListingView, OrderListView, OrderDetailView, ImageUploadView,
    ActiveRestaurantsView, RestaurantDetailView, MenuView, FoodDetailView, 
    BannersView, CategoriesView, NearbyRestaurantsView, TopRatedRestaurantsView, 
    SearchView, UpdateFCMTokenView
)

urlpatterns = [
    path('send-otp/', SendOTP.as_view(), name='send-otp'),
    path('verify-otp/', VerifyOTP.as_view(), name='verify-otp'),
    path('signup/', SignupView.as_view(), name='signup'),
    path('vendors/', VendorListView.as_view(), name='vendor-list'),
    path('vendors/<str:vendor_id>/', RestaurantDetailView.as_view(), name='vendor-detail'),
    path('notifications/<str:vendor_id>/', NotificationListView.as_view(), name='notification-list'),
    path('vendors/<str:vendor_id>/fcm-token/', UpdateFCMTokenView.as_view(), name='update-fcm-token'),
    path('profile/<str:vendor_id>/', ProfileView.as_view(), name='profile'),
    path('food-listings/<str:vendor_id>/', FoodListingView.as_view(), name='food-listings'),
    path('food-listings/<str:vendor_id>/<int:food_id>/', FoodListingView.as_view(), name='food-listing-detail'),
    path('orders/<str:vendor_id>/', OrderListView.as_view(), name='orders'),
    path('order-detail/<str:order_number>/', OrderDetailView.as_view(), name='order-detail'),
    path('upload-image/', ImageUploadView.as_view(), name='upload-image'),
    path('restaurants/', ActiveRestaurantsView.as_view(), name='active-restaurants'),
    path('restaurants/<str:vendor_id>/', RestaurantDetailView.as_view(), name='restaurant-detail'),
    path('banners/', BannersView.as_view(), name='banners'),
    path('categories/', CategoriesView.as_view(), name='categories'),
    path('nearby-restaurants/', NearbyRestaurantsView.as_view(), name='nearby-restaurants'),
    path('top-rated-restaurants/', TopRatedRestaurantsView.as_view(), name='top-rated-restaurants'),
    path('search/', SearchView.as_view(), name='search'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

