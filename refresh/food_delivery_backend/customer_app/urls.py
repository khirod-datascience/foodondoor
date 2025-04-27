from django.urls import path
from .views import *
from rest_framework_simplejwt.views import TokenRefreshView

urlpatterns = [
    # Authentication (Matching frontend prefix)
    path('customer_auth/send-otp/', SendOTP.as_view(), name='send-otp'),
    path('customer_auth/verify-otp/', VerifyOTP.as_view(), name='verify-otp'),
    path('customer_auth/register/', CustomerSignup.as_view(), name='customer-signup'),
    path('customer_auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/check-auth/', CheckAuthView.as_view(), name='check-auth'),

    # --- ALIASES for OTP to match frontend expectations ---
    path('api/request-otp/', SendOTP.as_view(), name='request-otp-alias'),
    path('api/verify-otp/', VerifyOTP.as_view(), name='verify-otp-alias'),

    # Use /api/ prefix for other endpoints as expected by frontend ApiService
    path('api/home-data/', HomeDataView.as_view(), name='home-data'),
    path('api/banners/', HomeBannersView.as_view(), name='home-banners'),
    path('api/categories/', HomeCategoriesView.as_view(), name='home-categories'),
    path('api/nearby-restaurants/', NearbyRestaurantsView.as_view(), name='nearby-restaurants'),
    path('api/top-rated-restaurants/', TopRatedRestaurantsView.as_view(), name='top-rated-restaurants'),
    path('api/search/', SearchView.as_view(), name='search'),
    path('api/popular-foods/', PopularFoodsView_test.as_view(), name='popular-foods'), # Review if test view is okay

    # Vendor / Food Details (use actual ID if that's what frontend gets/sends)
    # Assuming vendor_id in URL is the integer ID from the DB
    path('api/restaurants/<str:vendor_id>/', RestaurantDetailView.as_view(), name='restaurant-detail'), # Review test view
    path('api/food-listings/<int:vendor_id>/', CustomerFoodListingView.as_view(), name='customer-food-listings'),
    path('api/items/<int:item_id>/', ItemDetailView.as_view(), name='item-detail'),

    # Cart Management (Matching ApiService)
    path('api/cart/', CartDetailView.as_view(), name='cart-detail'),                 # GET/DELETE
    path('api/cart/add/', CartAddView.as_view(), name='cart-add-item'),             # POST
    path('api/cart/item/<int:item_id>/', CartItemUpdateView.as_view(), name='cart-item-update'), # PUT/DELETE
    path('api/cart/update/<int:cart_item_id>/', CartItemIdUpdateView.as_view(), name='cart-item-id-update'),
    path('api/cart/clear/', CartClearView.as_view(), name='cart-clear'),

    # Address Management
    path('api/user/addresses/', CustomerAddressesView.as_view(), name='customer-addresses'), # GET for logged-in user
    path('api/addresses/', CustomerAddressesView.as_view(), name='customer-addresses-alias'), # ALIAS
    path('api/addresses/', AddAddressView.as_view(), name='add-address'),                     # POST
    path('api/addresses/<int:address_id>/', UpdateAddressView.as_view(), name='update-delete-address'), # PUT/DELETE

    # Order Management
    path('api/place-order/', PlaceOrderView.as_view(), name='place-order'),         # POST
    path('api/my-orders/', OrderView.as_view(), name='my-orders'),                 # GET
    path('api/orders/<str:order_number>/', OrderDetailView.as_view(), name='order-detail'), # GET

    # Delivery Fee (Use actual vendor ID)
    path('api/delivery-fee/<int:vendor_id>/', DeliveryFeeView.as_view(), name='delivery-fee'),
    path('api/details/<str:user_id>/', CustomerDetailsView.as_view(), name='customer-details'),
]