from django.urls import path
from .views import *
from .views import CustomerOrderStatusView, CustomerOrderTrackingView, UpdateFCMTokenView, TestNotificationView
# from .views import CheckDeliveryView

# from .views import (
#     NearbyRestaurantsView, TopRatedRestaurantsView, SearchView,
#     RestaurantDetailView, FoodDetailView, CreateCODOrderView, VerifyPaymentView,
#     PlaceOrderView # Import the new view
# )
# from .views import PopularFoodsView_test
# # from .views import DeleteAddressView

from .views import CustomerTokenRefreshView

urlpatterns = [
    path('token/refresh/', CustomerTokenRefreshView.as_view(), name='customer-token-refresh'),
    path('fcm-token/update/', UpdateFCMTokenView.as_view(), name='customer-fcm-token-update'),
    path('testnotify/', TestNotificationView.as_view(), name='customer-test-notification'),
    path('reverse-geocode/', ReverseGeocodeView.as_view(), name='reverse-geocode'),
    path('send-otp/', SendOTP.as_view()),
    path('verify-otp/', VerifyOTP.as_view()),
    path('signup/', CustomerSignup.as_view()),
    path('home-data/', HomeDataView.as_view()),
    # path('nearby-restaurants/', NearbyRestaurantsView.as_view(), name='nearby-restaurants'),
    # path('search/', SearchView.as_view(), name='search'),
    # path('search-suggestions/', SearchSuggestionsView.as_view(), name='search-suggestions'),
    path('cart/', CartView.as_view()),
    path('cart/<int:item_id>/', CartView.as_view()),
    path('my-orders/', OrderView.as_view()),
    # path('restaurants/<str:vendor_id>/', RestaurantDetailView.as_view(), name='restaurant-detail'),
    # path('restaurants/<str:vendor_id>/foods/<int:food_id>/', FoodDetailView.as_view(), name='food-detail'),
    path('orders/<str:order_number>/', OrderDetailView.as_view()),
    path('orders/<str:order_number>/status/', CustomerOrderStatusView.as_view()),
    path('orders/<str:order_number>/track/', CustomerOrderTrackingView.as_view()),
    # path('payment/create/', CreatePaymentView.as_view()),
    # # path('payment/verify/', VerifyPaymentView.as_view()),
    path('check-delivery/', CheckDeliveryView.as_view(), name='check-delivery'),
    # path('banners/', HomeBannersView.as_view(), name='home-banners'),
    path('categories/', HomeCategoriesView.as_view(), name='home-categories'),
    # path('top-rated-restaurants/', TopRatedRestaurantsView.as_view(), name='top-rated-restaurants'),

    # Test endpoints
    path('nearby-restaurants/', NearbyRestaurantsView_test.as_view(), name='test-nearby-restaurants'),
    path('top-rated-restaurants/', TopRatedRestaurantsView_test.as_view(), name='test-top-rated-restaurants'),
    path('search/', SearchView_test.as_view(), name='test-search'),
    path('restaurants/<str:vendor_id>/', RestaurantDetailView_test.as_view(), name='test-restaurant-detail'),
    path('restaurants/<str:vendor_id>/foods/<int:food_id>/', FoodDetailView_test.as_view(), name='test-food-detail'),
    path('banners/', HomeBannersView_test.as_view(), name='test-home-banners'),
    path('popular-foods/', PopularFoodsView_test.as_view(), name='test-popular-foods'),
    path('food-listings/<str:vendor_id>/', CustomerFoodListingView.as_view(), name='customer-food-listings'),

    # New endpoints
    path('customer/<str:customer_id>/', CustomerDetailsView.as_view(), name='customer-details'),
    path('customer/<str:customer_id>/addresses/', CustomerAddressesView.as_view(), name='customer-addresses'),
    path('<str:customer_id>/addresses/', CustomerAddressesView.as_view(), name='customer-addresses'),
    path('addresses/', AddAddressView.as_view(), name='add-address'),
    path('addresses/<int:address_id>/', UpdateAddressView.as_view(), name='update-address'),
    # path('customer/addresses/<int:address_id>/delete/', DeleteAddressView.as_view(), name='delete-address'),

    # Payment/Order Endpoints
    path('place-order/', PlaceOrderView.as_view(), name='place-order'), # New unified endpoint
    # Remove old payment endpoints
    # path('payment/cod/', CreateCODOrderView.as_view(), name='create-cod-order'),
    # path('payment/verify/', VerifyPaymentView.as_view(), name='verify-payment'),

    # Add this new pattern
    path('delivery-fee/<str:vendor_id>/', DeliveryFeeView.as_view(), name='delivery-fee'),
]