from django.shortcuts import render
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import *
from .serializers import *
from .utils import OTPManager
from django.db.models import Q
from math import radians, cos, sin, asin, sqrt
import logging
import random
import razorpay
from django.conf import settings
import time
from razorpay.errors import SignatureVerificationError, BadRequestError
from geopy.distance import geodesic
from auth_app.models import Vendor
from auth_app.models import FoodListing
from django.db import IntegrityError
from rest_framework.permissions import IsAuthenticated, AllowAny
import jwt
from django.db import transaction
import jwt
from datetime import datetime, timedelta
from django.conf import settings

# --- FCM Notification Utility ---
try:
    from firebase_admin import messaging
except ImportError:
    messaging = None

def send_notification_to_device(token, title, body):
    if not messaging:
        print("firebase_admin.messaging is not available.")
        return False
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=token,
        )
        response = messaging.send(message)
        print(f"FCM notification sent: {response}")
        return True
    except Exception as e:
        print(f"Failed to send FCM notification: {e}")
        return False

# --- Custom JWT Refresh for Customer ---
class CustomerTokenRefreshView(APIView):
    permission_classes = [AllowAny]
    def post(self, request):
        refresh_token = request.data.get('refresh')
        print('[REFRESH] Incoming refresh token:', refresh_token)
        if not refresh_token:
            print('[REFRESH] No refresh token provided')
            return Response({'error': 'Refresh token required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            payload = jwt.decode(refresh_token, settings.SECRET_KEY, algorithms=['HS256'])
            print('[REFRESH] Decoded payload:', payload)
            customer_id = payload.get('customer_id') or payload.get('user_id')
            if not customer_id:
                print('[REFRESH] Payload missing customer_id/user_id')
                return Response({'error': 'Invalid refresh token'}, status=status.HTTP_401_UNAUTHORIZED)
            token_type = payload.get('type') or payload.get('token_type')
            if token_type != 'refresh':
                print('[REFRESH] Token type is not refresh:', token_type)
                return Response({'error': 'Invalid refresh token type'}, status=status.HTTP_401_UNAUTHORIZED)
            # Validate customer
            from .models import Customer
            try:
                customer = Customer.objects.get(customer_id=customer_id)
            except Customer.DoesNotExist:
                print('[REFRESH] Customer not found:', customer_id)
                return Response({'error': 'Customer not found'}, status=status.HTTP_401_UNAUTHORIZED)
            # Issue new access token (2 hours expiry)
            access_payload = {
                'customer_id': customer.customer_id,
                'exp': datetime.utcnow() + timedelta(hours=2),
                'iat': datetime.utcnow(),
                'token_type': 'access',
            }
            access_token = jwt.encode(access_payload, settings.SECRET_KEY, algorithm='HS256')
            # Issue new refresh token (30 days expiry, rotation)
            refresh_payload = {
                'customer_id': customer.customer_id,
                'exp': datetime.utcnow() + timedelta(days=30),
                'iat': datetime.utcnow(),
                'token_type': 'refresh',
            }
            refresh_token_new = jwt.encode(refresh_payload, settings.SECRET_KEY, algorithm='HS256')
            print('[REFRESH] Issued new tokens for customer:', customer_id)
            return Response({'access': access_token, 'refresh': refresh_token_new}, status=status.HTTP_200_OK)
        except jwt.ExpiredSignatureError:
            print('[REFRESH] Token expired')
            return Response({'error': 'Refresh token expired'}, status=status.HTTP_401_UNAUTHORIZED)
        except Exception as e:
            print('[REFRESH] Exception:', str(e))
            return Response({'error': 'Invalid refresh token'}, status=status.HTTP_401_UNAUTHORIZED)


from .serializers import OrderSerializer, OrderItemSerializer # Ensure these are imported correctly
from auth_app.models import Vendor, FoodListing # Ensure these are imported correctly
import logging
import traceback # For detailed error logging
from rest_framework_simplejwt.tokens import RefreshToken # Import for JWT generation
from geopy.geocoders import Nominatim
from rest_framework.permissions import AllowAny

import re
from auth_app.models import Notification
from rest_framework_simplejwt.authentication import JWTAuthentication # If using JWT



logger = logging.getLogger(__name__)

# --- Helper function to get tokens ---
def generate_customer_jwt(customer):
    import jwt
    from datetime import datetime, timedelta
    from django.conf import settings
    now = datetime.utcnow()
    access_payload = {
        'customer_id': customer.customer_id,
        'exp': now + timedelta(hours=2),
        'iat': now,
        'token_type': 'access',
    }
    refresh_payload = {
        'customer_id': customer.customer_id,
        'exp': now + timedelta(days=30),
        'iat': now,
        'token_type': 'refresh',
    }
    access_token = jwt.encode(access_payload, settings.SECRET_KEY, algorithm='HS256')
    refresh_token = jwt.encode(refresh_payload, settings.SECRET_KEY, algorithm='HS256')
    return {'access': access_token, 'refresh': refresh_token}


class SendOTP(APIView):
    def post(self, request):
        try:
            phone = request.data.get('phone')
            if not phone:
                return Response(
                    {'error': 'Phone number is required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Generate OTP
            otp, error = OTPManager.generate_otp(phone)
            if error:
                logger.error(f"OTP generation failed: {error}")
                return Response(
                    {'error': error}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Log OTP (remove in production)
            logger.info(f"OTP for {phone}: {otp}")
            
            return Response(
                {
                    'message': 'OTP sent successfully',
                    'debug_otp': otp  # Remove in production
                }, 
                status=status.HTTP_200_OK
            )
            
        except Exception as e:
            logger.error(f"Error in SendOTP: {str(e)}")
            return Response(
                {'error': 'Failed to send OTP'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class VerifyOTP(APIView):
    def post(self, request):
        try:
            phone = request.data.get('phone')
            otp = request.data.get('otp')
            
            if not all([phone, otp]):
                return Response(
                    {'error': 'Phone and OTP are required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Verify OTP
            is_valid, message = OTPManager.verify_otp(phone, otp)
            if not is_valid:
                return Response(
                    {'error': message}, 
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Check if customer exists
            try:
                customer = Customer.objects.get(phone=phone)
                # --- Generate JWT ---
                tokens = generate_customer_jwt(customer)
                # --- End JWT Generation ---
                logger.info(f"Login successful for customer {customer.customer_id}")
                return Response({
                    'message': 'Login successful',
                    'is_signup': False,
                    'customer_id': customer.customer_id,
                    'auth_token': tokens['access'], # Return JWT access token
                    'refresh_token': tokens['refresh'],
                }, status=status.HTTP_200_OK)
                
            except Customer.DoesNotExist:
                # No token generated here, user needs to signup
                logger.info(f"OTP verified for {phone}, signup required.")
                return Response({
                    'message': 'Please complete signup',
                    'is_signup': True,
                }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error in VerifyOTP: {str(e)}")
            traceback.print_exc()
            return Response(
                {'error': 'Verification failed'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class CustomerSignup(APIView):
    def post(self, request):
        print(request.data)
        try:
            phone = request.data.get('phone')
            # Use 'name' from request payload for 'full_name' model field
            full_name = request.data.get('name')
            email = request.data.get('email')

            if not all([phone, full_name, email]):
                return Response(
                    {'error': 'All fields (phone, name, email) are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Check if customer already exists (optional but good practice)
            if Customer.objects.filter(phone=phone).exists():
                 return Response({'error': 'An account with this phone number already exists.'}, status=status.HTTP_400_BAD_REQUEST)
            if Customer.objects.filter(email=email).exists():
                 return Response({'error': 'An account with this email address already exists.'}, status=status.HTTP_400_BAD_REQUEST)


            # Generate customer ID (ensure uniqueness if needed, maybe check DB)
            while True:
                customer_id = f"C{random.randint(10000, 99999)}" # Increased range slightly
                if not Customer.objects.filter(customer_id=customer_id).exists():
                    break

            customer = Customer.objects.create(
                customer_id=customer_id,
                phone=phone,
                full_name=full_name, # Use the mapped name here
                email=email
            )

            # --- Generate JWT for the new customer ---
            tokens = generate_customer_jwt(customer)
            # --- End JWT Generation ---

            logger.info(f"Signup successful for customer {customer.customer_id}")
            return Response({
                'message': 'Signup successful!',
                'customer_id': customer.customer_id,
                'auth_token': tokens['access'] # Return JWT access token
            }, status=status.HTTP_201_CREATED)

        except IntegrityError as e:
             # Handle potential duplicate phone or email
            logger.error(f"Error in CustomerSignup (IntegrityError): {str(e)}")
            error_message = 'An account with this phone number or email already exists.'
            if 'phone' in str(e).lower():
                error_message = 'An account with this phone number already exists.'
            elif 'email' in str(e).lower():
                 error_message = 'An account with this email address already exists.'
            return Response(
                {'error': error_message},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.error(f"Error in CustomerSignup: {str(e)}")
            traceback.print_exc()
            return Response(
                {'error': 'Signup failed due to an internal error.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class HomeDataView(APIView):
    def get(self, request):
        try:
            print(BannerSerializer(Banner.objects.filter(is_active=True), many=True).data)
            data = {
                'banners': BannerSerializer(Banner.objects.filter(is_active=True), many=True).data,
                'categories': CategorySerializer(Category.objects.filter(is_active=True), many=True).data,
                'food_categories': FoodCategorySerializer(FoodCategory.objects.filter(is_active=True), many=True).data,
                'popular_foods': FoodSerializer(
                    Food.objects.filter(is_available=True).order_by('-id')[:10], 
                    many=True
                ).data,
                'top_rated_restaurants': RestaurantSerializer(
                    Restaurant.objects.filter(is_active=True).order_by('-rating')[:10],
                    many=True
                ).data
            }
            return Response(data)
        except Exception as e:
            logger.error(f"Error in HomeDataView: {str(e)}")
            return Response({'error': str(e)}, status=500)

class HomeBannersView(APIView):
    def get(self, request):
        banners = Banner.objects.filter(is_active=True)
        data = [{"title": banner.title, "image": banner.image.url} for banner in banners]
        return Response(data, status=status.HTTP_200_OK)

class HomeBannersView_test(APIView):
    def get(self, request):
        # Return a test banner for testing
        data = [
            "https://coreldrawdesign.com/templates/1053.png"
           
        ]
        return Response(data, status=status.HTTP_200_OK)

class HomeCategoriesView(APIView):
    def get(self, request):
        categories = FoodCategory.objects.filter(is_active=True)
        print(categories)
        data = [{"name": category.name, "image_url": category.image_url.url} for category in categories]
        return Response(data, status=status.HTTP_200_OK)

class ReverseGeocodeView(APIView):
    permission_classes = [AllowAny]
    def post(self, request):
        try:
            lat = request.data.get('latitude')
            lon = request.data.get('longitude')
            if lat is None or lon is None:
                return Response({'error': 'Latitude and longitude are required.'}, status=status.HTTP_400_BAD_REQUEST)
            geolocator = Nominatim(user_agent="foodondoor_geocoder")
            location = geolocator.reverse(f"{lat}, {lon}", language='en')
            if location is None or not location.address:
                return Response({'error': 'Address not found for the given coordinates.'}, status=status.HTTP_404_NOT_FOUND)
            address = location.raw.get('address', {})
            # Structure the address fields for frontend
            result = {
                'address_line1': address.get('road', '') or address.get('suburb', '') or address.get('neighbourhood', ''),
                'city': address.get('city', '') or address.get('town', '') or address.get('village', ''),
                'state': address.get('state', ''),
                'postal_code': address.get('postcode', ''),
                'latitude': lat,
                'longitude': lon
            }
            return Response(result, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"ReverseGeocodeView error: {str(e)}")
            return Response({'error': 'Failed to reverse geocode location.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class NearbyRestaurantsView(APIView):
    def get(self, request):
        try:
            lat = float(request.GET.get('lat'))
            long = float(request.GET.get('long'))
        except (TypeError, ValueError):
            return Response({"error": "Invalid latitude or longitude"}, status=status.HTTP_400_BAD_REQUEST)

        user_location = (lat, long)
        vendors = Vendor.objects.filter(is_active=True)
        nearby_restaurants = []

        for vendor in vendors:
            vendor_location = (vendor.latitude, vendor.longitude)
            distance = geodesic(user_location, vendor_location).km
            if distance <= 5:  # Assuming a 5 km radius
                nearby_restaurants.append({
                    "id": vendor.id,
                    "name": vendor.restaurant_name,
                    "address": vendor.address,
                    "rating": vendor.rating,
                    "distance": round(distance, 2),
                })

        return Response(nearby_restaurants, status=status.HTTP_200_OK)

class NearbyRestaurantsView_test(APIView):
    def get(self, request):
        # Fetch all vendors for testing
        vendors = Vendor.objects.all()
        data = [
            {
                "id": vendor.id,
                "vendor_id": vendor.vendor_id,
                "name": vendor.restaurant_name,
                "address": vendor.address,
                "latitude": vendor.latitude,
                "longitude": vendor.longitude,
                "pincode": vendor.pincode,
                "cuisine_type": vendor.cuisine_type,
                "rating": vendor.rating,
                "is_active": vendor.is_active,
            }
            for vendor in vendors
        ]
        return Response(data, status=status.HTTP_200_OK)

class SearchView(APIView):
    def get(self, request):
        query = request.GET.get('query', '').strip()
        if not query:
            return Response({"error": "Query parameter is required"}, status=status.HTTP_400_BAD_REQUEST)

        vendors = Vendor.objects.filter(
            Q(restaurant_name__icontains=query) | Q(address__icontains(query))
        ).distinct()

        foods = FoodListing.objects.filter(
            Q(name__icontains=query) | Q(description__icontains(query))
        ).distinct()

        data = {
            "restaurants": [
                {
                    "id": vendor.id,
                    "vendor_id": vendor.vendor_id,
                    "name": vendor.restaurant_name,
                    "address": vendor.address,
                    "rating": vendor.rating,
                }
                for vendor in vendors
            ],
            "foods": [
                {
                    "id": food.id,
                    "vendor_id": food.vendor.id,
                    "name": food.name,
                    "price": food.price,
                    "description": food.description,
                    "is_available": food.is_available,
                }
                for food in foods
            ],
        }
        return Response(data, status=status.HTTP_200_OK)

class SearchView_test(APIView):
    def get(self, request):
        # Fetch all vendors and food listings for testing
        vendors = Vendor.objects.all()
        foods = FoodListing.objects.all()

        data = {
            "restaurants": [
                {
                    "id": vendor.id,
                    "vendor_id": vendor.vendor_id,
                    "name": vendor.restaurant_name,
                    "address": vendor.address,
                    "latitude": vendor.latitude,
                    "longitude": vendor.longitude,
                    "pincode": vendor.pincode,
                    "cuisine_type": vendor.cuisine_type,
                    "rating": vendor.rating,
                    "is_active": vendor.is_active,
                }
                for vendor in vendors
            ],
            "foods": [
                {
                    "id": food.id,
                    "vendor_id": food.vendor.vendor_id, # Access vendor_id through vendor relation
                    "name": food.name,
                    "price": food.price,
                    "description": food.description,
                    "is_available": food.is_available,
                    "category": food.category,
                    # --- Updated image handling ---
                    "image_urls": [request.build_absolute_uri(img_path) for img_path in food.images if img_path] if isinstance(food.images, list) else [],
                    # --- End update ---
                }
                for food in foods
            ],
        }
        return Response(data, status=status.HTTP_200_OK)

class CartView(APIView):
    def get(self, request):
        try:
            customer_id = request.query_params.get('customer_id')
            if not customer_id:
                return Response({'error': 'Customer ID is required'}, status=status.HTTP_400_BAD_REQUEST)
                
            cart_items = Cart.objects.filter(customer_id=customer_id)
            serializer = CartItemSerializer(cart_items, many=True)
            
            # Calculate total amount
            total_amount = sum(item.food.price * item.quantity for item in cart_items)
            
            response_data = {
                'items': serializer.data,
                'total_amount': total_amount,
                'item_count': cart_items.count()
            }
            
            return Response(response_data, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Error in CartView.get: {str(e)}")
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        try:
            customer_id = request.data.get('customer_id')
            food_id = request.data.get('food_id')
            quantity = int(request.data.get('quantity', 1))
            
            if not all([customer_id, food_id]):
                return Response(
                    {'error': 'Customer ID and Food ID are required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Validate food exists
            try:
                food = Food.objects.get(id=food_id)
            except Food.DoesNotExist:
                return Response(
                    {'error': 'Food item not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Check if there are existing items in the cart from a different restaurant
            existing_cart_items = Cart.objects.filter(customer_id=customer_id)
            if existing_cart_items.exists():
                # Get the vendor of the existing cart items
                existing_vendor = existing_cart_items.first().food.vendor
                
                # Check if the new food item is from a different vendor
                if food.vendor.id != existing_vendor.id:
                    return Response(
                        {
                            'error': 'MULTI_VENDOR_ERROR',
                            'message': 'Orders from multiple restaurants are not allowed. Please clear your cart or complete your existing order before ordering from another restaurant.',
                            'current_vendor': {
                                'id': existing_vendor.id,
                                'name': existing_vendor.restaurant_name
                            },
                            'new_vendor': {
                                'id': food.vendor.id,
                                'name': food.vendor.restaurant_name
                            }
                        }, 
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            # Check if item already exists in cart
            try:
                existing_item = Cart.objects.get(customer_id=customer_id, food_id=food_id)
                # Update quantity
                existing_item.quantity += quantity
                existing_item.save()
                serializer = CartItemSerializer(existing_item)
                return Response(
                    {
                        'message': 'Item quantity updated in cart',
                        'cart_item': serializer.data
                    }, 
                    status=status.HTTP_200_OK
                )
            except Cart.DoesNotExist:
                # Create new cart item
                cart_item = Cart.objects.create(
                    customer_id=customer_id,
                    food_id=food_id,
                    quantity=quantity
                )
                serializer = CartItemSerializer(cart_item)
                return Response(
                    {
                        'message': 'Item added to cart successfully',
                        'cart_item': serializer.data
                    }, 
                    status=status.HTTP_201_CREATED
                )
        except Exception as e:
            logger.error(f"Error in CartView.post: {str(e)}")
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def delete(self, request, item_id):
        try:
            item = Cart.objects.get(id=item_id)
            item.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Cart.DoesNotExist:
            return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)

class CartAddView(APIView):
    def post(self, request):
        try:
            customer_id = request.data.get('customer_id')
            food_id = request.data.get('food_id')
            quantity = int(request.data.get('quantity', 1))
            
            if not all([customer_id, food_id]):
                return Response(
                    {'error': 'Customer ID and Food ID are required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Validate food exists
            try:
                food = Food.objects.get(id=food_id)
            except Food.DoesNotExist:
                return Response(
                    {'error': 'Food item not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Check if there are existing items in the cart from a different restaurant
            existing_cart_items = Cart.objects.filter(customer_id=customer_id)
            if existing_cart_items.exists():
                # Get the vendor of the existing cart items
                existing_vendor = existing_cart_items.first().food.vendor
                
                # Check if the new food item is from a different vendor
                if food.vendor.id != existing_vendor.id:
                    return Response(
                        {
                            'error': 'MULTI_VENDOR_ERROR',
                            'message': 'Orders from multiple restaurants are not allowed. Please clear your cart or complete your existing order before ordering from another restaurant.',
                            'current_vendor': {
                                'id': existing_vendor.id,
                                'name': existing_vendor.restaurant_name
                            },
                            'new_vendor': {
                                'id': food.vendor.id,
                                'name': food.vendor.restaurant_name
                            }
                        }, 
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            # Check if item already exists in cart
            try:
                cart_item = Cart.objects.get(customer_id=customer_id, food_id=food_id)
                # Update quantity
                cart_item.quantity += quantity
                cart_item.save()
            except Cart.DoesNotExist:
                # Create new cart item
                cart_item = Cart.objects.create(
                    customer_id=customer_id,
                    food_id=food_id,
                    quantity=quantity
                )
            
            serializer = CartItemSerializer(cart_item)
            return Response(
                {
                    'message': 'Item added to cart successfully',
                    'cart_item': serializer.data
                }, 
                status=status.HTTP_200_OK
            )
            
        except Exception as e:
            logger.error(f"Error in CartAddView: {str(e)}")
            traceback.print_exc()
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class OrderView(APIView):
    def _get_customer_orders(self, customer_id, inprogress=False):
        """Helper method to get customer orders used by both GET and POST. Optionally filter for in-progress orders."""
        try:
            # Verify the customer exists
            customer = Customer.objects.get(customer_id=customer_id)
        except Customer.DoesNotExist:
            return None, {'error': 'Customer not found'}, status.HTTP_404_NOT_FOUND
        
        # Get all orders for this customer
        orders = Order.objects.filter(customer=customer).order_by('-created_at')
        if inprogress:
            inprogress_statuses = ['pending', 'confirmed', 'preparing', 'out_for_delivery']
            orders = orders.filter(status__in=inprogress_statuses)
        
        # Get order items for each order
        response_data = []
        for order in orders:
            order_items = OrderItem.objects.filter(order=order)
            
            # Serialize the order and its items
            order_data = {
                'id': order.id,
                'order_number': order.order_number,
                'total_amount': float(order.total_amount),
                'status': order.status,
                'delivery_address': order.delivery_address,
                'created_at': order.created_at,
                'payment_mode': order.payment_mode,
                'payment_status': order.payment_status,
                'vendor': {
                    'vendor_id': order.vendor.vendor_id,
                    'name': order.vendor.restaurant_name,
                    'address': order.vendor.address
                },
                'items': [
                    {
                        'id': item.id,
                        'food': {
                            'id': item.food.id,
                            'name': item.food.name,
                            'price': float(item.price),
                            'category': item.food.category,
                            'images': item.food.images if hasattr(item.food, 'images') else []
                        },
                        'quantity': item.quantity,
                        'price': float(item.price)
                    }
                    for item in order_items
                ]
            }
            response_data.append(order_data)
            
        return response_data, None, status.HTTP_200_OK

    def get(self, request):
        """Handle GET requests to get orders for a customer. Supports optional inprogress filter."""
        print("GET request to my-orders")
        print(request.query_params)
        try:
            customer_id = request.query_params.get('customer_id')
            if not customer_id:
                return Response({'error': 'Customer ID is required'}, status=status.HTTP_400_BAD_REQUEST)
            # Support ?inprogress=true
            inprogress = request.query_params.get('inprogress', 'false').lower() == 'true'
            response_data, error, status_code = self._get_customer_orders(customer_id, inprogress=inprogress)
            if error:
                return Response(error, status=status_code)
            return Response(response_data, status=status_code)
        except Exception as e:
            logger.error(f"Error in OrderView.get: {str(e)}")
            traceback.print_exc()
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Handle POST requests to either create an order or get customer orders. Supports optional inprogress filter."""
        print("POST request path:", request.path)
        print("Request data:", request.data)
        try:
            # If this is a my-orders request, return the orders for the customer
            if request.path.endswith('my-orders/'):
                customer_id = request.data.get('customer_id')
                if not customer_id:
                    return Response({'error': 'Customer ID is required'}, status=status.HTTP_400_BAD_REQUEST)
                # Support {"inprogress": true}
                inprogress = bool(request.data.get('inprogress', False))
                response_data, error, status_code = self._get_customer_orders(customer_id, inprogress=inprogress)
                if error:
                    return Response(error, status=status_code)
                return Response(response_data, status=status_code)
            # Otherwise, this is a regular order creation request
            serializer = OrderSerializer(data=request.data)
            if serializer.is_valid():
                order = serializer.save()
                # Create order items
                for item in request.data.get('items', []):
                    OrderItem.objects.create(
                        order=order,
                        food_id=item['food_id'],
                        quantity=item['quantity'],
                        price=item['price']
                    )
                # Clear cart
                Cart.objects.filter(customer_id=request.data['customer_id']).delete()
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error in OrderView.post: {str(e)}")
            traceback.print_exc()
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class CheckoutView(APIView):
    def post(self, request):
        try:
            customer_id = request.data.get('customer_id')
            delivery_address = request.data.get('delivery_address')
            payment_method = request.data.get('payment_method', 'cod')  # Default to cash on delivery
            
            if not all([customer_id, delivery_address]):
                return Response(
                    {'error': 'Customer ID and delivery address are required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Get cart items
            cart_items = Cart.objects.filter(customer_id=customer_id)
            if not cart_items.exists():
                return Response(
                    {'error': 'Cart is empty'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Calculate total amount
            total_amount = sum(item.food.price * item.quantity for item in cart_items)
            
            # Create order
            order = Order.objects.create(
                customer_id=customer_id,
                total_amount=total_amount,
                delivery_address=delivery_address,
                payment_status='pending' if payment_method == 'online' else 'cod',
            )
            
            # Create order items
            for cart_item in cart_items:
                OrderItem.objects.create(
                    order=order,
                    food=cart_item.food,
                    quantity=cart_item.quantity,
                    price=cart_item.food.price
                )
            
            # Clear cart
            cart_items.delete()
            
            # Return order details
            order_serializer = OrderSerializer(order)
            order_items = OrderItem.objects.filter(order=order)
            order_items_serializer = OrderItemSerializer(order_items, many=True)
            
            return Response(
                {
                    'message': 'Order placed successfully',
                    'order': order_serializer.data,
                    'order_items': order_items_serializer.data,
                    'total_amount': total_amount
                }, 
                status=status.HTTP_201_CREATED
            )
            
        except Exception as e:
            logger.error(f"Error in CheckoutView: {str(e)}")
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class RestaurantDetailView(APIView):
    def get(self, request, vendor_id):
        try:
            vendor = Vendor.objects.prefetch_related('foodlisting_set').get(vendor_id=vendor_id)
            data = {
                "id": vendor.id,
                "name": vendor.restaurant_name,
                "address": vendor.address,
                "rating": vendor.rating,
                "menu": [
                    {
                        "id": food.id,
                        "name": food.name,
                        "price": food.price,
                        "description": food.description,
                        "is_available": food.is_available,
                    }
                    for food in vendor.foodlisting_set.all()
                ],
            }
            return Response(data, status=status.HTTP_200_OK)
        except Vendor.DoesNotExist:
            return Response({"error": "Restaurant not found"}, status=status.HTTP_404_NOT_FOUND)

class RestaurantDetailView_test(APIView):
    def get(self, request, vendor_id):
        try:
            # Fetch the specific vendor by vendor_id
            vendor = Vendor.objects.prefetch_related('foodlisting_set').get(vendor_id=vendor_id)
            # Prepare data for the single vendor found
            data = {
                "id": vendor.id,
                "vendor_id": vendor.vendor_id, # Include vendor_id
                "name": vendor.restaurant_name,
                "address": vendor.address,
                "latitude": vendor.latitude, # Include latitude
                "longitude": vendor.longitude, # Include longitude
                "pincode": vendor.pincode, # Include pincode
                "cuisine_type": vendor.cuisine_type, # Include cuisine_type
                "rating": vendor.rating,
                "is_active": vendor.is_active, # Include is_active
                "menu": [
                    {
                        "id": food.id,
                        "name": food.name,
                        "price": food.price,
                        "description": food.description,
                        "is_available": food.is_available,
                        "category": food.category, # Include category
                        # --- Updated image handling ---
                        "image_urls": [request.build_absolute_uri(img_path) for img_path in food.images if img_path] if isinstance(food.images, list) else [],
                        # --- End update ---
                    }
                    for food in vendor.foodlisting_set.all()
                ],
            }
            return Response(data, status=status.HTTP_200_OK) # Return single object
        except Vendor.DoesNotExist:
            return Response({"error": "Restaurant not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
             logger.error(f"Error in RestaurantDetailView_test: {str(e)}")
             # Log traceback for detailed debugging
             import traceback
             traceback.print_exc()
             return Response({'error': 'An error occurred fetching restaurant details.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class OrderTrackingView(APIView):
    def get(self, request, order_number):
        try:
            order = Order.objects.get(order_number=order_number)
            return Response({
                'status': order.status,
                'estimated_delivery': order.estimated_delivery,
                'tracking_details': {
                    'current_location': order.current_location,
                    'delivery_partner': order.delivery_partner
                }
            })
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)

# --- Customer: Poll Order Status ---
class CustomerOrderStatusView(APIView):
    def get(self, request, order_number):
        try:
            order = Order.objects.get(order_number=order_number)
            return Response({'order_no': order.order_number, 'status': order.status}, status=200)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)

# --- Customer: Track Order (status + location) ---
class CustomerOrderTrackingView(APIView):
    def get(self, request, order_number):
        try:
            order = Order.objects.get(order_number=order_number)
            return Response({
                'order_no': order.order_number,
                'status': order.status,
                'delivery_lat': order.delivery_lat,
                'delivery_lng': order.delivery_lng
            }, status=200)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=404)

class CreatePaymentView(APIView):
    def post(self, request):
        try:
            amount = request.data.get('amount')
            if not amount:
                return Response(
                    {'error': 'Amount is required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Convert amount to paise (Razorpay expects amount in smallest currency unit)
            amount_in_paise = int(float(amount) * 100)
            
            client = razorpay.Client(
                auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)
            )
            
            payment_data = {
                'amount': amount_in_paise,
                'currency': 'INR',
                'payment_capture': '1',
                'notes': {
                    'merchant_order_id': f"ORDER_{int(time.time())}"
                }
            }
            
            payment = client.order.create(payment_data)
            
            return Response({
                'order_id': payment['id'],
                'amount': amount,
                'currency': payment['currency'],
                'key': settings.RAZORPAY_KEY_ID
            })
            
        except ValueError as e:
            return Response(
                {'error': 'Invalid amount format'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

class CheckDeliveryView(APIView):
    def post(self, request):
        print(request.data)
        # Example logic to check delivery availability
        pincode = request.data.get('pincode')
        if not pincode:
            return Response({"error": "Pincode is required"}, status=status.HTTP_400_BAD_REQUEST)

        # Mock logic: Assume delivery is available for certain pincodes
        available_pincodes = ["12345", "67890", "54321"]
        if pincode in available_pincodes:
            return Response({"delivery_available": True}, status=status.HTTP_200_OK)
        else:
            return Response({"delivery_available": False}, status=status.HTTP_200_OK)

class UpdateFCMTokenView(APIView):
    permission_classes = [AllowAny]
    def get(self, request):
        # HARDCODED TEST VALUES
        fcm_token = '<PUT_YOUR_FCM_TOKEN_HERE>'
        return Response({'success': True, 'fcm_token': fcm_token}, status=status.HTTP_200_OK)

class TestNotificationView(APIView):
    permission_classes = [AllowAny]
    def get(self, request):
        # HARDCODED TEST VALUES
        fcm_token = '<PUT_YOUR_FCM_TOKEN_HERE>'
        title = 'Test Notification (GET)'
        body = 'This is a test notification triggered by GET request.'
        success = send_notification_to_device(fcm_token, title, body)
        if success:
            return Response({'success': True, 'message': 'Notification sent via GET.'}, status=status.HTTP_200_OK)
        else:
            return Response({'success': False, 'message': 'Failed to send notification.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class TopRatedRestaurantsView(APIView):
    def get(self, request):
        try:
            # Fetch top-rated restaurants ordered by rating in descending order
            vendors = Vendor.objects.filter(is_active=True).order_by('-rating')[:10]
            data = [
                {
                "id": vendor.id,
                "name": vendor.restaurant_name,
                "address": vendor.address,
                "rating": vendor.rating,
            }
            for vendor in vendors
        ]
            return Response(data, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class TopRatedRestaurantsView_test(APIView):
    def get(self, request):
        # Fetch all vendors sorted by rating for testing
        vendors = Vendor.objects.all().order_by('-rating')
        data = [
            {
                "id": vendor.id,
                "vendor_id": vendor.vendor_id,
                "name": vendor.restaurant_name,
                "address": vendor.address,
                "latitude": vendor.latitude,
                "longitude": vendor.longitude,
                "pincode": vendor.pincode,
                "cuisine_type": vendor.cuisine_type,
                "rating": vendor.rating,
                "is_active": vendor.is_active,
            }
            for vendor in vendors
        ]
        return Response(data, status=status.HTTP_200_OK)

class FoodDetailView(APIView):
    def get(self, request, vendor_id, food_id):
        try:
            food = FoodListing.objects.get(vendor__vendor_id=vendor_id, id=food_id)
            data = {
                "id": food.id,
                "name": food.name,
                "price": food.price,
                "description": food.description,
                "is_available": food.is_available,
            }
            return Response(data, status=status.HTTP_200_OK)
        except FoodListing.DoesNotExist:
            return Response({"error": "Food item not found"}, status=status.HTTP_404_NOT_FOUND)

class FoodDetailView_test(APIView):
    def get(self, request, vendor_id, food_id):
        # Fetch all food listings for testing
        foods = FoodListing.objects.all()
        data = [
            {
                "id": food.id,
                "vendor_id": food.vendor.id, # Assuming vendor relation exists
                "name": food.name,
                "price": food.price,
                "description": food.description,
                "is_available": food.is_available,
                "category": food.category,
                # --- Updated image handling ---
                "image_urls": [request.build_absolute_uri(img_path) for img_path in food.images if img_path] if isinstance(food.images, list) else [],
                # --- End update ---
            }
            for food in foods
        ]
        return Response(data, status=status.HTTP_200_OK)

class PopularFoodsView_test(APIView):
    def get(self, request):
        # Fetch all foods for testing
        foods = FoodListing.objects.all()  # Assuming FoodListing is the model for foods
        data = [
            {
                "id": food.id,
                "vendor_id": food.vendor.id,
                "name": food.name,
                "price": food.price,
                "description": food.description,
                "is_available": food.is_available,
                "category": food.category,
                 # --- Updated image handling ---
                "image_urls": [request.build_absolute_uri(img_path) for img_path in food.images if img_path] if isinstance(food.images, list) else [],
                 # --- End update ---
            }
            for food in foods
        ]
        return Response(data, status=status.HTTP_200_OK)
    
class CustomerFoodListingView(APIView):
    def get(self, request, vendor_id):
        try:
            # Fetch food listings for the given vendor_id from auth_app
            foods = FoodListing.objects.filter(vendor__vendor_id=vendor_id)
            if not foods.exists():
                return Response({"error": "No food items found for this vendor."}, status=status.HTTP_404_NOT_FOUND)

            data = [
                {
                    "id": food.id,
                    "vendor_id": food.vendor.vendor_id,
                    "name": food.name,
                    "price": food.price,
                    "description": food.description,
                    "is_available": food.is_available,
                    "category": food.category,
                    # --- Updated image handling ---
                    "image_urls": [request.build_absolute_uri(img_path) for img_path in food.images if img_path] if isinstance(food.images, list) else [],
                    # --- End update ---
                }
                for food in foods
            ]
            return Response(data, status=status.HTTP_200_OK)
        except Vendor.DoesNotExist:
            return Response({"error": "Vendor not found."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error in CustomerFoodListingView for vendor {vendor_id}: {str(e)}")
            import traceback
            traceback.print_exc()
            return Response({"error": "An error occurred fetching food listings."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



class CustomerDetailsView(APIView):
    def get(self, request, customer_id):
        try:
            customer = Customer.objects.get(customer_id=customer_id)
            data = {
                "customer_id": customer.customer_id,
                "full_name": customer.full_name,
                "email": customer.email,
                "phone": customer.phone,
                "default_address": {
                    "id": customer.default_address.id if customer.default_address else None,
                    "address_line_1": customer.default_address.address_line_1 if customer.default_address else None,
                    "city": customer.default_address.city if customer.default_address else None,
                } if customer.default_address else None,
            }
            return Response(data, status=status.HTTP_200_OK)
        except Customer.DoesNotExist:
            return Response({"error": "Customer not found"}, status=status.HTTP_404_NOT_FOUND)

class CustomerAddressesView(APIView):
    permission_classes = [AllowAny]
    def get(self, request, customer_id):
        print("... this is test header request for request.headers...........................................",request.headers)
        print("... this is test data request for request.data",request.data)
        print("=== CUSTOMER ADDRESSES VIEW HIT - MAIN FILE ===")
        # --- JWT Auth Start ---
        auth_header = request.headers.get('Authorization')
        print(f"[DEBUG][CustomerAddressesView] Incoming headers: {dict(request.headers)}")
        if not auth_header or not auth_header.startswith('Bearer '):
            return Response({'error': 'Authorization header missing'}, status=status.HTTP_401_UNAUTHORIZED)
        token = auth_header.split(' ')[1]
        print(f"[DEBUG][CustomerAddressesView] Received JWT token: {token}")
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=['HS256'])
            print(f"[DEBUG][CustomerAddressesView] Decoded JWT payload: {payload}")
        except jwt.ExpiredSignatureError:
            return Response({'error': 'Token expired'}, status=status.HTTP_401_UNAUTHORIZED)
        except jwt.InvalidTokenError:
            return Response({'error': 'Invalid token'}, status=status.HTTP_401_UNAUTHORIZED)
        # Debug print for troubleshooting
        print(f"[CustomerAddressesView] customer_id from URL: {customer_id}, customer_id from token: {payload.get('customer_id')}")
        # Check token_type is 'access'
        print(f"[CustomerAddressesView] token_type in payload: {payload.get('token_type')}")
        if payload.get('token_type') != 'access':
            print("------Payload.. for token type......",payload.get('token_type'))
            return Response({'error': 'Given token not valid for any token type'}, status=status.HTTP_401_UNAUTHORIZED)
        # Check customer_id match
        if str(payload.get('customer_id')) != str(customer_id):
            print("------Payload.. for customer id......",payload.get('customer_id'))
            return Response({'error': 'Token does not match customer'}, status=status.HTTP_401_UNAUTHORIZED)
        # --- JWT Auth End ---
        try:
            customer = Customer.objects.get(customer_id=customer_id)
            addresses = customer.addresses.all()
            data = [
                {
                    "id": address.id,
                    "address_line_1": address.address_line_1,
                    "address_line_2": address.address_line_2,
                    "city": address.city,
                    "state": address.state,
                    "pincode": address.pincode,
                    "is_default": address.is_default,
                }
                for address in addresses
            ]
            print(data)
            return Response(data, status=status.HTTP_200_OK)
        except Customer.DoesNotExist:
            return Response({"error": "Customer not found"}, status=status.HTTP_404_NOT_FOUND)

class AddAddressView(APIView):
    def post(self, request):
        # Map incoming field names to the expected field names
        customer_id = request.data.get('customer_id')
        address_line_1 = request.data.get('address_line1')  # Map 'address_line1' to 'address_line_1'
        address_line_2 = request.data.get('address_line2')  # Map 'address_line2' to 'address_line_2'
        city = request.data.get('city')
        state = request.data.get('state')
        pincode = request.data.get('postal_code')  # Map 'postal_code' to 'pincode'

        # Validate required fields
        if not all([customer_id, address_line_1, city, state, pincode]):
            return Response(
                {"error": "All required fields (customer_id, address_line1, city, state, postal_code) must be provided."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            customer = Customer.objects.get(customer_id=customer_id)
            address = Address.objects.create(
                customer=customer,
                address_line_1=address_line_1,
                address_line_2=address_line_2,
                city=city,
                state=state,
                pincode=pincode,
                is_default=request.data.get('is_default', False),
            )
            return Response({"message": "Address added successfully", "id": address.id}, status=status.HTTP_201_CREATED)
        except Customer.DoesNotExist:
            return Response({"error": "Customer not found"}, status=status.HTTP_404_NOT_FOUND)

class UpdateAddressView(APIView):
    def put(self, request, address_id):
        try:
            address = Address.objects.get(id=address_id)
            # Map incoming field names if necessary (similar to AddAddressView)
            address.address_line_1 = request.data.get('address_line1', address.address_line_1)
            address.address_line_2 = request.data.get('address_line2', address.address_line_2)
            address.city = request.data.get('city', address.city)
            address.state = request.data.get('state', address.state)
            address.pincode = request.data.get('postal_code', address.pincode) # Map postal_code
            address.is_default = request.data.get('is_default', address.is_default)
            address.save()
            return Response({"message": "Address updated successfully"}, status=status.HTTP_200_OK)
        except Address.DoesNotExist:
            return Response({"error": "Address not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error updating address {address_id}: {str(e)}")
            return Response({"error": "Failed to update address"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    # Add DELETE method handler here
    def delete(self, request, address_id):
        try:
            # Fetch the address by ID
            address = Address.objects.get(id=address_id)
            address.delete()
            return Response({"message": "Address deleted successfully"}, status=status.HTTP_200_OK) # Use 200 OK or 204 No Content
        except Address.DoesNotExist:
            return Response({"error": "Address not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error deleting address {address_id}: {str(e)}")
            return Response({"error": "Failed to delete address"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# Unified Order Placement View
class PlaceOrderView(APIView):
    def post(self, request):
        print(request.data)
        """
        Handle POST requests to place an order.
        
        Expected request format:
        {
          "payment_method": "cod" or "paytm",
          "payment_status": "success",
          "txn_id": "optional",
          "order_details": {
            "customer_id": "C12345",
            "items": [
              {
                "food_id": "4",
                "quantity": 1,
                "price": 150.0,
                "vendor_id": "V001"
              }
            ],
            "address": "123456",  # 6-digit pincode
            "vendor_id": "V001"
          }
        }
        
        Returns:
        {
          "order_id": "ORD123",
          "status": "placed",
          "estimated_delivery_time": 30,
          "total_amount": 170.0,  # items total + delivery fee
          "delivery_fee": 20.0,
          "items_total": 150.0
        }
        """
        try:
            # Extract data from request
            payment_method = request.data.get('payment_method', '').upper()
            payment_status = request.data.get('payment_status', 'pending')
            txn_id = request.data.get('txn_id', None)
            order_details = request.data.get('order_details', {})

            # Validate required fields
            if not order_details:
                return Response(
                    {"error": "order_details is required"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            customer_id = order_details.get('customer_id')
            items_data = order_details.get('items', [])
            address_param = order_details.get('address')  # Can be either pincode or address ID
            vendor_id = order_details.get('vendor_id')
            delivery_fee = order_details.get('delivery_fee')  # Optional delivery fee from request
            total_price = order_details.get('total_price')  # Optional total price from request
            
            if not all([customer_id, items_data, address_param, vendor_id]):
                return Response(
                    {"error": "customer_id, items, address, and vendor_id are required in order_details"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Validate payment method
            if payment_method not in ['COD', 'PAYTM']:
                return Response(
                    {"error": "Invalid payment_method. Must be 'cod' or 'paytm'"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Get customer and vendor
            try:
                customer = Customer.objects.get(customer_id=customer_id)
                vendor = Vendor.objects.get(vendor_id=vendor_id)
            except Customer.DoesNotExist:
                return Response(
                    {"error": "Customer not found"},
                    status=status.HTTP_404_NOT_FOUND
                )
            except Vendor.DoesNotExist:
                return Response(
                    {"error": "Vendor not found"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Handle address - could be an address ID or a pincode
            address_obj = None
            delivery_pincode = None
            delivery_address_str = None
            
            # Check if address is a numeric ID (for a saved address) or a pincode
            try:
                # Try to convert to int - if successful, it might be an address ID
                address_id = int(address_param)
                try:
                    # Try to get the address object
                    address_obj = Address.objects.get(id=address_id, customer=customer)
                    delivery_pincode = address_obj.pincode
                    delivery_address_str = f"{address_obj.address_line_1}, {address_obj.address_line_2 or ''}, {address_obj.city}, {address_obj.state}, {address_obj.pincode}"
                except Address.DoesNotExist:
                    # If address not found, assume it's a pincode
                    delivery_pincode = address_param
                    delivery_address_str = delivery_pincode
            except ValueError:
                # If conversion fails, use the value directly as pincode
                delivery_pincode = address_param
                delivery_address_str = delivery_pincode
            
            # Calculate items total and validate items
            items_total = 0
            order_items_to_create = []
            unavailable_items = []

            for item_data in items_data:
                food_id = item_data.get('food_id')
                quantity = item_data.get('quantity')
                price = item_data.get('price')
                
                # Convert quantity to int if it's a string
                if isinstance(quantity, str):
                    try:
                        quantity = int(quantity)
                    except ValueError:
                        return Response(
                            {"error": f"Invalid quantity value: {quantity}"},
                            status=status.HTTP_400_BAD_REQUEST
                        )

                if not food_id or not isinstance(quantity, int) or quantity <= 0:
                    return Response(
                        {"error": "Invalid item data. Each item must have food_id and positive integer quantity."},
                        status=status.HTTP_400_BAD_REQUEST
                    )

                try:
                    food_listing = FoodListing.objects.get(id=food_id, vendor=vendor)
                    if not food_listing.is_available:
                        unavailable_items.append(food_listing.name)
                        continue
                    
                    item_total = price * quantity
                    items_total += item_total
                    
                    order_items_to_create.append({
                        'food': food_listing,
                        'quantity': quantity,
                        'price': price
                    })
                except FoodListing.DoesNotExist:
                    return Response(
                        {"error": f"Food item with id {food_id} not found for this vendor."},
                        status=status.HTTP_404_NOT_FOUND
                    )

            if unavailable_items:
                return Response(
                    {"error": f"Some items are unavailable: {', '.join(unavailable_items)}"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not order_items_to_create:
                return Response(
                    {"error": "No valid items to order."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Use delivery_fee from request if provided, otherwise calculate
            distance = 0
            if not delivery_fee:
                try:
                    # Get coordinates for delivery address using pincode
                    geolocator = Nominatim(user_agent="food_delivery_app")
                    delivery_location = geolocator.geocode(f"{delivery_pincode}, India")
                    
                    if not delivery_location:
                        return Response(
                            {"error": "Could not geocode delivery address. Please ensure the pincode is valid."},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    
                    # Get coordinates for vendor
                    vendor_location = (vendor.latitude, vendor.longitude)
                    delivery_coords = (delivery_location.latitude, delivery_location.longitude)
                    
                    # Calculate distance in kilometers
                    distance = geodesic(vendor_location, delivery_coords).kilometers
                    print(f"Distance: {distance} km")
                    
                    # Calculate delivery fee
                    if distance <= 5:
                        delivery_fee = 20.0
                    else:
                        delivery_fee = 20.0 + (distance - 5) * 5.0
                    
                    delivery_fee = round(delivery_fee, 2)
                    
                except Exception as e:
                    logger.error(f"Error calculating delivery fee: {str(e)}")
                    return Response(
                        {"error": "Failed to calculate delivery fee"},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR
                    )

            # Calculate total amount including delivery fee
            # Use total_price from request if provided, otherwise calculate
            if total_price:
                total_amount = float(total_price)
            else:
                total_amount = items_total + delivery_fee

            # Create the Order
            order = Order.objects.create(
                customer=customer,
                vendor=vendor,
                total_amount=total_amount,
                delivery_address=delivery_address_str,
                payment_mode=payment_method,
                payment_status=payment_status,
                payment_id=txn_id,
                status='placed',
                delivery_fee=delivery_fee
            )

            # Create OrderItems
            order_item_instances = []
            for item_info in order_items_to_create:
                order_item_instances.append(
                    OrderItem(
                        order=order,
                        food=item_info['food'],
                        quantity=item_info['quantity'],
                        price=item_info['price']
                    )
                )
            OrderItem.objects.bulk_create(order_item_instances)

            # Create notification for vendor
            try:
                notification_body = f"""New Order Received!
Order ID: {order.order_number}
Customer: {customer.full_name}
Items Total: ₹{items_total}
Delivery Fee: ₹{delivery_fee}
Total Amount: ₹{total_amount}
Payment Mode: {payment_method}
Delivery Address: {delivery_address_str}"""
                
                # Create database notification
                notification = Notification.objects.create(
                    vendor=vendor,
                    title=f"New Order #{order.order_number}",
                    body=notification_body
                )
                
                # Send push notification if vendor has FCM token
                if vendor.fcm_token:
                    try:
                        from auth_app.views import send_notification_to_device
                        send_notification_to_device(
                            vendor.fcm_token,
                            f"New Order #{order.order_number}",
                            f"New order received for ₹{total_amount}"
                        )
                    except Exception as e:
                        logger.error(f"Failed to send push notification: {str(e)}")
                
                logger.info(f"Notification sent to vendor {vendor.vendor_id} for order {order.order_number}")
            except Exception as e:
                logger.error(f"Failed to send notification to vendor: {str(e)}")
            
            # Calculate estimated delivery time (in minutes)
            estimated_delivery_time = 30  # Default 30 minutes
            
            # Return the response with detailed price breakdown
            response_data = {
                "order_id": order.order_number,
                "status": order.status,
                "estimated_delivery_time": estimated_delivery_time,
                "total_amount": total_amount,
                "items_total": items_total,
                "delivery_fee": delivery_fee,
                "vendor": {
                    "id": vendor.vendor_id,
                    "name": vendor.restaurant_name,
                    "phone": vendor.contact_number
                },
                "delivery_address": delivery_address_str
            }
            
            # Add distance info if calculated
            if distance:
                response_data["distance_km"] = round(distance, 2)
            
            logger.info(f"Order {order.order_number} created successfully for customer {customer.customer_id}")
            return Response(response_data, status=status.HTTP_201_CREATED)

        except Exception as e:
            logger.error(f"Error creating order: {str(e)}")
            traceback.print_exc()
            return Response(
                {"error": "Failed to create order."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class DeliveryFeeView(APIView):
    """
    Calculate delivery fee based on distance between restaurant and delivery address.
    For testing purposes, uses a default fee of 20 when pincode is 123456.
    """
    permission_classes = [AllowAny]  # Explicitly allow unauthenticated access
    
    def get(self, request, vendor_id):
        """
        Calculate delivery fee based on distance.
        
        Query parameters:
        - pin: The 6-digit delivery pincode (required)
        - address: The delivery address (optional)
        
        Returns:
        {
            "delivery_fee": 50.0,
            "distance_km": 2.5
        }
        """
        print(f"DEBUG: DeliveryFeeView.get called with vendor_id={vendor_id}")
        print(f"DEBUG: Request query params: {request.query_params}")
        print(f"DEBUG: Request headers: {request.headers}")
        print(f"DEBUG: Request user: {request.user}")
        print(f"DEBUG: Request auth: {request.auth}")
        print(f"DEBUG: Request META: {request.META.get('HTTP_AUTHORIZATION', 'No Authorization header')}")
        print(f"DEBUG: Request session: {request.session}")
        print(f"DEBUG: Request COOKIES: {request.COOKIES}")
        
        try:
            # Get the pincode from query parameters
            delivery_pincode = request.query_params.get('pin')
            print(f"DEBUG: Delivery pincode: {delivery_pincode}")
            if not delivery_pincode:
                return Response(
                    {
                        "error": "Pincode is required as a query parameter",
                        "example": "/customer/delivery-fee/V001/?pin=123456"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Validate pincode format (must be 6 digits)
            if not re.match(r'^\d{6}$', delivery_pincode):
                return Response(
                    {
                        "error": "Invalid pincode format. Please provide a 6-digit pincode.",
                        "example": "/customer/delivery-fee/V001/?pin=123456"
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Get the vendor
            try:
                vendor = Vendor.objects.get(vendor_id=vendor_id)
                print(f"DEBUG: Found vendor: {vendor.restaurant_name}")
            except Vendor.DoesNotExist:
                print(f"DEBUG: Vendor not found with vendor_id={vendor_id}")
                return Response(
                    {"error": "Vendor not found"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # For testing purposes, use a default delivery fee of 20 when pincode is 123456
            if delivery_pincode == "123456":
                print(f"DEBUG: Using default delivery fee for test pincode")
                return Response({
                    "delivery_fee": 20.0,
                    "distance_km": 0.0,
                    "note": "Using default delivery fee for testing"
                }, status=status.HTTP_200_OK)
            
            # Get coordinates for delivery address using pincode
            geolocator = Nominatim(user_agent="food_delivery_app")
            delivery_location = geolocator.geocode(f"{delivery_pincode}, India")
            
            if not delivery_location:
                print(f"DEBUG: Could not geocode delivery address for pincode {delivery_pincode}")
                return Response(
                    {"error": "Could not geocode delivery address. Please ensure the pincode is valid."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Get coordinates for vendor
            vendor_location = (vendor.latitude, vendor.longitude)
            delivery_coords = (delivery_location.latitude, delivery_location.longitude)
            
            # Calculate distance in kilometers
            distance = geodesic(vendor_location, delivery_coords).kilometers
            print(f"DEBUG: Calculated distance: {distance} km")
            
            # Calculate delivery fee
            # If distance is less than 5km, fee is 20
            # Otherwise, fee is 20 + 5 per km beyond 5km
            if distance <= 5:
                delivery_fee = 20.0
            else:
                delivery_fee = 20.0 + (distance - 5) * 5.0
            
            # Round to 2 decimal places
            delivery_fee = round(delivery_fee, 2)
            print(f"DEBUG: Calculated delivery fee: {delivery_fee}")
            
            return Response({
                "delivery_fee": delivery_fee,
                "distance_km": round(distance, 2)
            }, status=status.HTTP_200_OK)
            
        except Exception as e:
            logger.error(f"Error calculating delivery fee: {str(e)}")
            traceback.print_exc()
            return Response(
                {"error": "Failed to calculate delivery fee"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

# --- View for fetching specific order details ---
class OrderDetailView(APIView):
    # authentication_classes = [JWTAuthentication] # Uncomment if auth is needed
    # permission_classes = [IsAuthenticated]     # Uncomment if auth is needed

    def get(self, request, order_number):
        print(f"Fetching details for order number: {order_number}")
        try:
            # Fetch the order by its order_number
            # Use prefetch_related for efficiency, using the correct related name
            order = Order.objects.prefetch_related(
                'orderitem_set',          # Correct related name (default)
                'orderitem_set__food',    # Prefetch food within items
                'vendor'
            ).get(order_number=order_number)
            print(order)
            # --- Optional: Check if the requesting user owns this order ---
            # If using authentication:
            # if request.user.customer_profile.customer_id != order.customer.customer_id:
            #    return Response({"error": "Not authorized to view this order"}, status=status.HTTP_403_FORBIDDEN)
            # --- End Optional Check ---

            # Serialize the order data
            # You might need a more detailed OrderSerializer or build the dict manually
            order_items = order.orderitem_set.all() # Use correct related name
            
            # Calculate subtotal robustly
            subtotal = float(order.total_amount) # Default to total_amount
            delivery_fee_value = 0.0
            if order.delivery_fee is not None:
                delivery_fee_value = float(order.delivery_fee)
                # Prevent negative subtotal if data is inconsistent
                subtotal = max(0.0, float(order.total_amount) )
            
            # Manually construct the response dictionary matching frontend expectations
            response_data = {
                'id': order.id,
                'order_id': order.order_number, 
                'order_number': order.order_number,
                # 'total_amount': float(order.total_amount), # Internal field, not directly needed by frontend price details
                'status': order.status,
                'delivery_address': order.delivery_address,
                'created_at': order.created_at.strftime('%Y-%m-%d %H:%M:%S') if order.created_at else None,
                'payment_mode': order.payment_mode,
                'payment_status': order.payment_status,
                
                # Fields for Price Details section
                'subtotal': subtotal, 
                'delivery_fee': delivery_fee_value,
                'tax': 0.00, # Add tax if applicable
                'total': float(order.total_amount )+ delivery_fee_value, # This is the final price customer paid
                
                'vendor': {
                    'id': order.vendor.id,
                    'vendor_id': order.vendor.vendor_id,
                    'name': order.vendor.restaurant_name,
                    'address': order.vendor.address
                } if order.vendor else None,
                 'restaurant': { # Match frontend expectation in other sections
                    'name': order.vendor.restaurant_name
                 } if order.vendor else None,
                'items': [
                    {
                        'id': item.id,
                        'food_id': item.food.id,
                        'name': item.food.name,
                        'quantity': item.quantity,
                        'price': float(item.price),
                        'variations': None, # Add variations if your model supports it
                         # Include image URL if available in FoodListing
                        'image_url': request.build_absolute_uri(item.food.images[0]) if hasattr(item.food, 'images') and item.food.images else None 
                    }
                    for item in order_items
                ]
            }

            return Response(response_data, status=status.HTTP_200_OK)
        
        except Order.DoesNotExist:
            logger.warning(f"Order not found: {order_number}")
            return Response({"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error fetching order details for {order_number}: {str(e)}")
            traceback.print_exc()
            return Response({"error": "An error occurred fetching order details."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
