from django.shortcuts import render
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import *
from .serializers import *
# Add these imports if they are missing near the top
from rest_framework.permissions import IsAuthenticated, AllowAny
from .authentication import * # Corrected import
from rest_framework_simplejwt.authentication import JWTAuthentication
from django.db import transaction
import traceback
from rest_framework_simplejwt.tokens import RefreshToken
from accounts.utils import OTPManager
from django.db.models import Q
from math import radians, cos, sin, asin, sqrt
import logging
import random
import razorpay
from django.conf import settings
import time
from razorpay.errors import SignatureVerificationError, BadRequestError
from geopy.distance import geodesic
from auth_app.models import Vendor # Ensure Vendor is imported
from auth_app.models import FoodListing
from django.db import IntegrityError
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.db import transaction
from .serializers import OrderSerializer, OrderItemSerializer # Ensure these are imported correctly
from auth_app.models import Vendor, FoodListing # Ensure these are imported correctly
import logging
import traceback # For detailed error logging
from rest_framework_simplejwt.tokens import RefreshToken # Import for JWT generation
from geopy.geocoders import Nominatim
import re
from auth_app.models import Notification
from rest_framework_simplejwt.authentication import JWTAuthentication # If using JWT
from rest_framework.generics import ListAPIView
from accounts.models import CustomerProfile # Import CustomerProfile
from customer_app.utils import get_jwt_tokens_for_customer
from .serializers import FoodListingSerializer

logger = logging.getLogger('customer_app')

# --- Helper function to get tokens ---
def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        # 'refresh': str(refresh), # Optionally return refresh token
        'access': str(refresh.access_token),
    }

class SendOTP(APIView):
    def post(self, request):
        logger.info(f"[SendOTP] OTP request received for phone: {request.data.get('phone')}")
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
    permission_classes = [AllowAny]

    def post(self, request):
        logger.info(f"[VerifyOTP] OTP verification attempt for phone: {request.data.get('phone')}")
        print(request.data)
        try:
            phone = request.data.get('phone')
            otp = request.data.get('otp')

            if not all([phone, otp]):
                return Response({'error': 'Phone and OTP are required'}, status=status.HTTP_400_BAD_REQUEST)

            is_valid, message = OTPManager.verify_otp(phone, otp)
            if not is_valid:
                logger.warning(f"OTP verification failed for {phone}: {message}")
                return Response({'error': message}, status=status.HTTP_400_BAD_REQUEST)

            try:
                # Find customer by phone
                profile = CustomerProfile.objects.get(phone=phone)
                account = profile.user
                if not account.is_active:
                    return Response({'error': 'This account is inactive.'}, status=status.HTTP_403_FORBIDDEN)
                # Generate JWT tokens (pass CustomerProfile, not Account)
                tokens = get_jwt_tokens_for_customer(profile)
                # Optionally include user data
                from .serializers import CustomerProfileSerializer
                user_data = CustomerProfileSerializer(profile).data
                return Response({
                    'success': True,
                    'is_signup': False,
                    'auth_token': tokens['access'],
                    'refresh_token': tokens['refresh'],
                    'user': user_data
                }, status=status.HTTP_200_OK)
            except CustomerProfile.DoesNotExist:
                request.session['verified_phone'] = phone
                request.session.save() # Ensure session is saved
                logger.info(f"OTP verified for {phone}, signup required. Stored phone in session.")
                return Response({
                    'message': 'OTP verified. Please complete signup.', 'is_signup': True, 'phone': phone
                }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Error in VerifyOTP: {str(e)}")
            import traceback
            traceback.print_exc()
            return Response({'error': 'Verification failed'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- Replace existing CustomerSignup ---
class CustomerSignup(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        print("Signup Request Data:", request.data)
        try:
            phone = request.session.get('verified_phone')
            if not phone:
                logger.warning("Signup attempt without verified phone in session.")
                return Response({'error': 'Phone number verification is missing. Please verify OTP first.'}, status=status.HTTP_400_BAD_REQUEST)

            full_name = request.data.get('name')
            email = request.data.get('email')
            # password = request.data.get('password')

            if not full_name: return Response({'error': 'Name is required.'}, status=status.HTTP_400_BAD_REQUEST)
            if not email: return Response({'error': 'Email is required.'}, status=status.HTTP_400_BAD_REQUEST)
            print('printdata  w o...',phone,full_name,email)
            if CustomerProfile.objects.filter(phone=phone).exists(): return Response({'error': 'An account with this phone number already exists.'}, status=status.HTTP_400_BAD_REQUEST)
            print('printdata  w o oo...',phone,full_name,email)
            if CustomerProfile.objects.filter(user__email=email).exists():
                return Response({'error': 'An account with this email address already exists.'}, status=status.HTTP_400_BAD_REQUEST)

            # Create the Account and CustomerProfile
            account = Account.objects.create(email=email, user_type='customer')
            customer = CustomerProfile.objects.create(user=account, phone=phone, full_name=full_name)
            # Assuming get_tokens_for_user works with your custom Customer model
            tokens = get_jwt_tokens_for_customer(customer)

            if 'verified_phone' in request.session: del request.session['verified_phone']
            logger.info(f"Signup successful for customer {customer.phone}")

            return Response({
                'message': 'Signup successful!', 'phone': customer.phone, 'auth_token': tokens['access']
            }, status=status.HTTP_201_CREATED)

        except IntegrityError as e:
            logger.error(f"Error in CustomerSignup (IntegrityError): {str(e)}")
            error_message = 'An account with this phone number or email already exists.'
            if 'phone' in str(e).lower(): error_message = 'An account with this phone number already exists.'
            elif 'email' in str(e).lower(): error_message = 'An account with this email address already exists.'
            return Response({'error': error_message}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error in CustomerSignup: {str(e)}")
            traceback.print_exc()
            if 'verified_phone' in request.session:
                 try: del request.session['verified_phone']
                 except: pass
            return Response({'error': 'Signup failed due to an internal error.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --- Add CartDetailView ---
class CartDetailView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def get(self, request):
        customer = request.user
        try:
            cart_items = Cart.objects.filter(customer=customer).select_related('food', 'food__vendor')
            serializer = CartItemSerializer(cart_items, many=True, context={'request': request})

            total_amount = 0
            item_count = 0
            vendor_info = None
            if cart_items.exists():
                vendor_info = VendorSerializer(cart_items.first().food.vendor).data
                for item in cart_items:
                    total_amount += item.food.price * item.quantity
                    item_count += item.quantity

            response_data = {
                'success': True, 'items': serializer.data, 'total_amount': float(total_amount),
                'item_count': item_count, 'distinct_item_count': cart_items.count(), 'vendor': vendor_info
            }
            return Response(response_data, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Error in CartDetailView.get for customer {customer.customer_id}: {str(e)}")
            traceback.print_exc()
            return Response({'success': False, 'error': 'Failed to retrieve cart.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def delete(self, request):
        customer = request.user
        try:
            count, _ = Cart.objects.filter(customer=customer).delete()
            logger.info(f"Cleared {count} items from cart for customer {customer.customer_id}")
            return Response({'success': True, 'message': 'Cart cleared successfully.'}, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Error in CartDetailView.delete for customer {customer.customer_id}: {str(e)}")
            traceback.print_exc()
            return Response({'success': False, 'error': 'Failed to clear cart.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- Add CartAddView ---
class CartAddView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def post(self, request):
        customer = request.user
        try:
            food_listing_id = request.data.get('item_id') # Expect item_id
            quantity_str = request.data.get('quantity', '1')

            if not food_listing_id: return Response({'success': False, 'error': 'Item ID (item_id) is required'}, status=status.HTTP_400_BAD_REQUEST)

            try:
                quantity = int(quantity_str)
                if quantity <= 0: raise ValueError("Quantity must be positive")
            except (ValueError, TypeError): return Response({'success': False, 'error': 'Invalid quantity provided.'}, status=status.HTTP_400_BAD_REQUEST)

            try:
                food_listing = FoodListing.objects.get(id=food_listing_id)
                if not food_listing.is_available: return Response({'success': False, 'error': f'{food_listing.name} is currently unavailable.'}, status=status.HTTP_400_BAD_REQUEST)
            except FoodListing.DoesNotExist: return Response({'success': False, 'error': 'Food item not found'}, status=status.HTTP_404_NOT_FOUND)

            existing_cart_items = Cart.objects.filter(customer=customer).select_related('food__vendor')
            if existing_cart_items.exists():
                existing_vendor = existing_cart_items.first().food.vendor
                
                # Check if the new food item is from a different vendor
                if food_listing.vendor.id != existing_vendor.id:
                    # Return multi-vendor error response
                    return Response({ # (copy multi-vendor error dict here)
                           }, status=status.HTTP_400_BAD_REQUEST)

            with transaction.atomic():
                cart_item, created = Cart.objects.get_or_create(
                    customer=customer, food=food_listing, defaults={'quantity': quantity}
                )
                if not created:
                    cart_item.quantity += quantity
                    cart_item.save()

            serializer = CartItemSerializer(cart_item, context={'request': request})
            message = 'Item added to cart.' if created else 'Item quantity updated.'
            logger.info(f"{message} Customer: {customer.customer_id}, Item: {food_listing_id}, Qty: {quantity}")
            return Response({'success': True, 'message': message, 'cart_item': serializer.data}, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Error in CartAddView for customer {customer.customer_id}: {str(e)}")
            traceback.print_exc()
            return Response({'success': False, 'error': 'Failed to add item to cart.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --- Add CartItemUpdateView ---
class CartItemUpdateView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def put(self, request, item_id):
        customer = request.user
        try:
            quantity_str = request.data.get('quantity')
            if not quantity_str: return Response({'success': False, 'error': 'Quantity is required.'}, status=status.HTTP_400_BAD_REQUEST)

            try:
                quantity = int(quantity_str)
                if quantity <= 0: return self.delete(request, item_id)
            except (ValueError, TypeError): return Response({'success': False, 'error': 'Invalid quantity provided.'}, status=status.HTTP_400_BAD_REQUEST)

            cart_item = Cart.objects.get(id=item_id, customer=customer)
            cart_item.quantity = quantity
            cart_item.save()

            serializer = CartItemSerializer(cart_item, context={'request': request})
            logger.info(f"Updated cart item {item_id} quantity to {quantity} for customer {customer.customer_id}")
            return Response({'success': True, 'message': 'Quantity updated.', 'cart_item': serializer.data}, status=status.HTTP_200_OK)

        except Cart.DoesNotExist: return Response({'success': False, 'error': 'Cart item not found.'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error updating cart item {item_id} for customer {customer.customer_id}: {str(e)}")
            traceback.print_exc()
            return Response({'success': False, 'error': 'Failed to update quantity.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def delete(self, request, item_id):
        customer = request.user
        try:
            cart_item = Cart.objects.get(id=item_id, customer=customer)
            item_name = cart_item.food.name
            cart_item.delete()
            logger.info(f"Removed item {item_name} (ID: {item_id}) from cart for customer {customer.customer_id}")
            # Use escaped quotes for the message string
            return Response({'success': True, 'message': f'"{item_name}" removed from cart.'}, status=status.HTTP_200_OK)
        except Cart.DoesNotExist: return Response({'success': False, 'error': 'Cart item not found.'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error removing cart item {item_id} for customer {customer.customer_id}: {str(e)}")
            traceback.print_exc()
            return Response({'success': False, 'error': 'Failed to remove item.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --- Replace existing PlaceOrderView ---
class PlaceOrderView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def post(self, request):
        customer = request.user
        print("Place Order Request Data:", request.data)
        try:
            payment_method = request.data.get('payment_method', '').upper()
            payment_status = request.data.get('payment_status', 'pending')
            txn_id = request.data.get('txn_id')
            address_id = request.data.get('address_id') # Expect DB ID (int)
            vendor_id = request.data.get('vendor_id')   # Expect DB ID (int)
            # Frontend might send delivery_fee, let backend calculate if not present
            delivery_fee_str = request.data.get('delivery_fee')

            # No 'items' expected directly in request, use user's cart items

            if not address_id or not vendor_id:
                 return Response({"error": "address_id and vendor_id are required"}, status=status.HTTP_400_BAD_REQUEST)
            if payment_method not in ['COD', 'ONLINE']:
                 return Response({"error": "Invalid payment_method. Must be 'cod' or 'online'"}, status=status.HTTP_400_BAD_REQUEST)

            try:
                vendor = Vendor.objects.get(id=vendor_id)
                address_obj = Address.objects.get(id=address_id, customer=customer)
                delivery_address_str = f"{address_obj.address_line_1}, {address_obj.address_line_2 or ''}, {address_obj.city}, {address_obj.state}, {address_obj.pincode}"
            except Vendor.DoesNotExist: return Response({"error": "Vendor not found"}, status=status.HTTP_404_NOT_FOUND)
            except Address.DoesNotExist: return Response({"error": "Delivery address not found for this customer"}, status=status.HTTP_404_NOT_FOUND)

            items_total = 0
            order_items_to_create = []
            unavailable_items = []

            with transaction.atomic():
                cart_items = Cart.objects.filter(customer=customer).select_related('food', 'food__vendor')
                if not cart_items.exists(): return Response({"error": "Cannot place order, cart is empty."}, status=status.HTTP_400_BAD_REQUEST)

                cart_vendor = cart_items.first().food.vendor
                if cart_vendor.id != vendor.id: return Response({"error": "Cart items vendor mismatch."}, status=status.HTTP_400_BAD_REQUEST)

                for cart_item in cart_items:
                    food_listing = cart_item.food
                    if not food_listing.is_available:
                        unavailable_items.append(food_listing.name)
                        continue
                    item_total = food_listing.price * cart_item.quantity
                    items_total += item_total
                    order_items_to_create.append({
                        'food': food_listing, 'quantity': cart_item.quantity, 'price': food_listing.price
                    })

                if unavailable_items: return Response({"error": f"Some items are unavailable: {', '.join(unavailable_items)}"}, status=status.HTTP_400_BAD_REQUEST)
                if not order_items_to_create: return Response({"error": "No valid items to order."}, status=status.HTTP_400_BAD_REQUEST)

                # Handle delivery fee
                delivery_fee = 0.0
                if delivery_fee_str is not None:
                    try: delivery_fee = float(delivery_fee_str)
                    except (ValueError, TypeError): return Response({"error": "Invalid delivery_fee format"}, status=status.HTTP_400_BAD_REQUEST)
                else:
                    # Calculate if not provided
                    try:
                        geolocator = Nominatim(user_agent="food_delivery_app")
                        delivery_location = geolocator.geocode(f"{address_obj.pincode}, India")
                        if delivery_location:
                            vendor_location = (vendor.latitude, vendor.longitude)
                            delivery_coords = (delivery_location.latitude, delivery_location.longitude)
                            distance = geodesic(vendor_location, delivery_coords).kilometers
                            if distance <= 5: delivery_fee = 20.0
                            else: delivery_fee = 20.0 + (distance - 5) * 5.0
                            delivery_fee = round(delivery_fee, 2)
                        else: delivery_fee = 20.0 # Default if geocoding fails
                    except Exception as e:
                        logger.warning(f"Could not calculate delivery fee: {e}. Using default.")
                        delivery_fee = 20.0 # Default on error

                total_amount = items_total + delivery_fee

                order = Order.objects.create(
                    customer=customer, vendor=vendor, total_amount=total_amount,
                    delivery_address=delivery_address_str, payment_mode=payment_method,
                    payment_status=payment_status, payment_id=txn_id, status='placed',
                    delivery_fee=delivery_fee
                )

                order_item_instances = [OrderItem(order=order, **item_info) for item_info in order_items_to_create]
                OrderItem.objects.bulk_create(order_item_instances)
                cart_items.delete() # Clear cart AFTER order is successfully created

            # Send notification (implement robustly)
            # ... notification logic ...

            estimated_delivery_time = 30 # Example

            response_data = {
                "success": True, "message": "Order placed successfully!", "order_id": order.order_number,
                "status": order.status, "estimated_delivery_time": estimated_delivery_time,
                "total_amount": float(total_amount), "items_total": float(items_total),
                "delivery_fee": float(delivery_fee),
                "vendor": { "id": vendor.id, "vendor_id": vendor.vendor_id, "name": vendor.restaurant_name, "phone": vendor.contact_number },
                "delivery_address": delivery_address_str
            }
            logger.info(f"Order {order.order_number} created for customer {customer.customer_id}")
            return Response(response_data, status=status.HTTP_201_CREATED)

        except Exception as e:
            logger.error(f"Error placing order for customer {request.user.customer_id if request.user.is_authenticated else 'anonymous'}: {str(e)}")
            traceback.print_exc()
            return Response({"success": False, "error": "Failed to place order."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- Add ItemDetailView ---
class ItemDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, item_id):
        try:
            item = FoodListing.objects.get(id=item_id)
            serializer = FoodListingSerializer(item)
            return Response(serializer.data, status=status.HTTP_200_OK)
        except FoodListing.DoesNotExist:
            return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- Add CartItemIdUpdateView ---
class CartItemIdUpdateView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def put(self, request, cart_item_id):
        try:
            cart_item = CartItem.objects.get(id=cart_item_id, cart__customer=request.user.customer_profile)
            quantity = request.data.get('quantity')
            if quantity is not None:
                cart_item.quantity = quantity
                cart_item.save()
                return Response({'success': True, 'message': 'Quantity updated'}, status=status.HTTP_200_OK)
            return Response({'error': 'Quantity not provided'}, status=status.HTTP_400_BAD_REQUEST)
        except CartItem.DoesNotExist:
            return Response({'error': 'Cart item not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def delete(self, request, cart_item_id):
        try:
            cart_item = CartItem.objects.get(id=cart_item_id, cart__customer=request.user.customer_profile)
            cart_item.delete()
            return Response({'success': True, 'message': 'Item removed from cart'}, status=status.HTTP_200_OK)
        except CartItem.DoesNotExist:
            return Response({'error': 'Cart item not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- Add CartClearView ---
class CartClearView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def post(self, request):
        try:
            cart = Cart.objects.get(customer=request.user.customer_profile)
            cart.items.all().delete()
            return Response({'success': True, 'message': 'Cart cleared successfully.'}, status=status.HTTP_200_OK)
        except Cart.DoesNotExist:
            return Response({'error': 'Cart not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- Ensure Address Views Map Fields Correctly ---
class AddAddressView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    def post(self, request):
        customer = request.user
        data = request.data.copy() # Create mutable copy
        # Map frontend names to model names
        data['address_line_1'] = data.pop('address_line1', None)
        data['address_line_2'] = data.pop('address_line2', None)
        data['pincode'] = data.pop('postal_code', None)

        serializer = AddressSerializer(data=data) # Use AddressSerializer
        if serializer.is_valid():
            # Don't need manual creation if serializer is set up correctly
            # serializer.save(customer=customer) should work if 'customer' is read_only
            # Let's try manual creation for clarity:
            address_data = serializer.validated_data
            address_data['customer'] = customer
            address = Address.objects.create(**address_data)
            return Response({'success': True, 'message': 'Address added successfully', 'id': address.id}, status=status.HTTP_201_CREATED)
        else:
            return Response({'success': False, 'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

class UpdateAddressView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    def put(self, request, address_id):
        customer = request.user
        try:
            address = Address.objects.get(id=address_id, customer=customer)
            # Map fields during update
            address.address_line_1 = request.data.get('address_line1', address.address_line_1)
            address.address_line_2 = request.data.get('address_line2', address.address_line_2)
            address.city = request.data.get('city', address.city)
            address.state = request.data.get('state', address.state)
            address.pincode = request.data.get('postal_code', address.pincode) # Map
            address.is_default = request.data.get('is_default', address.is_default)
            address.save()
            return Response({'success': True, 'message': 'Address updated successfully'}, status=status.HTTP_200_OK)
        except Address.DoesNotExist: return Response({'success': False, 'error': 'Address not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e: return Response({'success': False, 'error': 'Failed to update address'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def delete(self, request, address_id): # Keep DELETE logic
         customer = request.user
         try:
            address = Address.objects.get(id=address_id, customer=customer)
            address.delete()
            return Response({'success': True, 'message': 'Address deleted successfully'}, status=status.HTTP_200_OK)
         except Address.DoesNotExist: return Response({'success': False, 'error': 'Address not found'}, status=status.HTTP_404_NOT_FOUND)
         except Exception as e: return Response({'success': False, 'error': 'Failed to delete address'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- Ensure OrderDetailView is correct ---
class OrderDetailView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    def get(self, request, order_number):
        customer = request.user
        try:
            order = Order.objects.prefetch_related('order_items', 'order_items__food', 'vendor').get(order_number=order_number, customer=customer)
            # Using manual serialization from previous response
            order_items = order.order_items.all()
            subtotal = sum(item.price * item.quantity for item in order_items) # Recalculate subtotal
            delivery_fee_value = float(order.delivery_fee) if order.delivery_fee is not None else 0.0
            total_amount = float(order.total_amount) # Use stored total

            response_data = {
                'id': order.id, 'order_id': order.order_number, 'order_number': order.order_number,
                'status': order.status, 'delivery_address': order.delivery_address,
                'created_at': order.created_at.strftime('%Y-%m-%d %H:%M:%S') if order.created_at else None,
                'payment_mode': order.payment_mode, 'payment_status': order.payment_status,
                'subtotal': float(subtotal), 'delivery_fee': delivery_fee_value, 'tax': 0.00,
                'total': total_amount,
                'vendor': { 'id': order.vendor.id, 'vendor_id': order.vendor.vendor_id, 'name': order.vendor.restaurant_name, 'phone': order.vendor.contact_number } if order.vendor else None,
                'restaurant': { 'name': order.vendor.restaurant_name } if order.vendor else None,
                'items': [ {
                        'id': item.id, 'food_id': item.food.id, 'name': item.food.name,
                        'quantity': item.quantity, 'price': float(item.price), 'variations': None,
                        'image_url': request.build_absolute_uri(item.food.images[0]) if hasattr(item.food, 'images') and item.food.images else None
                    } for item in order_items ]
            }
            return Response(response_data, status=status.HTTP_200_OK)
        except Order.DoesNotExist: return Response({"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error fetching order details for {order_number}: {str(e)}")
            traceback.print_exc()
            return Response({"error": "An error occurred fetching order details."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



class HomeDataView(APIView):
    authentication_classes = [CustomerJWTAuthentication] # Corrected authentication class
    permission_classes = [IsAuthenticated]

    def get(self, request):
        print(request.data)
        print("HomeDataView accessed by:", request.user) # Add print statement for debugging
        try:
            # print(BannerSerializer(Banner.objects.filter(is_active=True), many=True).data)
            # Use VendorSerializer instead of RestaurantSerializer
            # Add nearby_restaurants using VendorSerializer
            data = {
                'banners': BannerSerializer(Banner.objects.filter(is_active=True), many=True, context={'request': request}).data,
                # Use FoodCategorySerializer as CategorySerializer does not exist
                'categories': FoodCategorySerializer(FoodCategory.objects.filter(is_active=True), many=True, context={'request': request}).data,
                # Keep food_categories key as well, in case it's used elsewhere
                'food_categories': FoodCategorySerializer(FoodCategory.objects.filter(is_active=True), many=True, context={'request': request}).data,
                'popular_foods': FoodListingSerializer(
                    FoodListing.objects.filter(is_available=True).order_by('-created_at')[:10],
                    many=True,
                    context={'request': request}
                ).data,
                'top_rated_restaurants': VendorSerializer( # Use VendorSerializer
                    Vendor.objects.filter(is_active=True).order_by('-rating')[:10],
                    many=True,
                    context={'request': request} # Add context
                ).data,
                'nearby_restaurants': VendorSerializer( # Add nearby restaurants
                    Vendor.objects.filter(is_active=True).order_by('?')[:10], # Fetch first 10 active for now
                    many=True,
                    context={'request': request} # Add context
                ).data,
            }
            return Response(data)
        except Exception as e:
            logger.error(f"Error in HomeDataView: {str(e)}\n{traceback.format_exc()}") # Log traceback
            return Response({'error': 'An internal error occurred'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class HomeBannersView(ListAPIView):
    queryset = Banner.objects.filter(is_active=True)
    serializer_class = BannerSerializer

class HomeCategoriesView(ListAPIView):
    queryset = FoodCategory.objects.filter(is_active=True)
    serializer_class = FoodCategorySerializer

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
                    "name": vendor.restaurant_name or "",
                    "address": vendor.address or "",
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
                "name": vendor.restaurant_name or "",
                "address": vendor.address or "",
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
                    "name": vendor.restaurant_name or "",
                    "address": vendor.address or "",
                    "rating": vendor.rating,
                }
                for vendor in vendors
            ],
            "foods": [
                {
                    "id": food.id,
                    "vendor_id": food.vendor.id,
                    "name": food.name or "",
                    "price": food.price,
                    "description": food.description or "",
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
                    "name": vendor.restaurant_name or "",
                    "address": vendor.address or "",
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
                    "name": food.name or "",
                    "price": food.price,
                    "description": food.description or "",
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
            user_id = request.query_params.get('user_id')
            if not user_id:
                return Response({'error': 'User ID is required'}, status=status.HTTP_400_BAD_REQUEST)
                
            customer = CustomerProfile.objects.get(user__id=user_id)
            cart_items = Cart.objects.filter(customer=customer)
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
            user_id = request.data.get('user_id')
            food_id = request.data.get('food_id')
            quantity = int(request.data.get('quantity', 1))
            
            if not all([user_id, food_id]):
                return Response(
                    {'error': 'User ID and Food ID are required'}, 
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
            customer = CustomerProfile.objects.get(user__id=user_id)
            existing_cart_items = Cart.objects.filter(customer=customer)
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
                                'name': existing_vendor.restaurant_name or ""
                            },
                            'new_vendor': {
                                'id': food.vendor.id,
                                'name': food.vendor.restaurant_name or ""
                            }
                        }, 
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            # Check if item already exists in cart
            try:
                existing_item = Cart.objects.get(customer=customer, food_id=food_id)
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
                    customer=customer,
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
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    def post(self, request):
        customer = request.user
        try:
            food_id = request.data.get('food_id')
            quantity = int(request.data.get('quantity', 1))
            
            if not food_id:
                return Response(
                    {'error': 'Food ID is required'}, 
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
            existing_cart_items = Cart.objects.filter(customer=customer)
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
                                'name': existing_vendor.restaurant_name or ""
                            },
                            'new_vendor': {
                                'id': food.vendor.id,
                                'name': food.vendor.restaurant_name or ""
                            }
                        }, 
                        status=status.HTTP_400_BAD_REQUEST
                    )
            
            # Check if item already exists in cart
            try:
                cart_item = Cart.objects.get(customer=customer, food_id=food_id)
                # Update quantity
                cart_item.quantity += quantity
                cart_item.save()
            except Cart.DoesNotExist:
                # Create new cart item
                cart_item = Cart.objects.create(
                    customer=customer,
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
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    def get(self, request):
        customer = request.user
        try:
            orders = Order.objects.filter(customer=customer).order_by('-created_at')
            # Use the OrderSerializer to format output
            serializer = OrderSerializer(orders, many=True, context={'request': request}) # Pass request to serializer context if needed for URLs
            return Response(serializer.data, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Error in OrderView.get: {str(e)}")
            traceback.print_exc()
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def post(self, request):
        """Handle POST requests to either create an order or get customer orders"""
        print("POST request path:", request.path)
        print("Request data:", request.data)
        try:
            # If this is a my-orders request, return the orders for the customer
            if request.path.endswith('my-orders/'):
                customer = request.user
                if not customer:
                    return Response({'error': 'Customer not found'}, status=status.HTTP_404_NOT_FOUND)
                
                orders = Order.objects.filter(customer=customer).order_by('-created_at')
                serializer = OrderSerializer(orders, many=True, context={'request': request})
                return Response(serializer.data, status=status.HTTP_200_OK)
            
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
                Cart.objects.filter(customer_id=request.data['user_id']).delete()
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error in OrderView.post: {str(e)}")
            traceback.print_exc()
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class CheckoutView(APIView):
    def post(self, request):
        try:
            user_id = request.data.get('user_id')
            delivery_address = request.data.get('delivery_address')
            payment_method = request.data.get('payment_method', 'cod')  # Default to cash on delivery
            
            if not all([user_id, delivery_address]):
                return Response(
                    {'error': 'User ID and delivery address are required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Get cart items
            customer = CustomerProfile.objects.get(user__id=user_id)
            cart_items = Cart.objects.filter(customer=customer)
            if not cart_items.exists():
                return Response(
                    {'error': 'Cart is empty'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Calculate total amount
            total_amount = sum(item.food.price * item.quantity for item in cart_items)
            
            # Create order
            order = Order.objects.create(
                customer=customer, total_amount=total_amount,
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
                "name": vendor.restaurant_name or "",
                "address": vendor.address or "",
                "rating": vendor.rating,
                "menu": [
                    {
                        "id": food.id,
                        "name": food.name or "",
                        "price": food.price,
                        "description": food.description or "",
                        "is_available": food.is_available,
                    }
                    for food in vendor.foodlisting_set.all()
                ],
            }
            return Response(data, status=status.HTTP_200_OK)
        except Vendor.DoesNotExist:
            return Response({"error": "Restaurant not found"}, status=status.HTTP_404_NOT_FOUND)

class RestaurantDetailView(APIView):
    def get(self, request, vendor_id):
        try:
            # Fetch the specific vendor by vendor_id
            vendor = Vendor.objects.prefetch_related('foodlisting_set').get(vendor_id=vendor_id)
            # Prepare data for the single vendor found
            data = {
                "id": vendor.id,
                "vendor_id": vendor.vendor_id, # Include vendor_id
                "name": vendor.restaurant_name or "",
                "address": vendor.address or "",
                "latitude": vendor.latitude, # Include latitude
                "longitude": vendor.longitude, # Include longitude
                "pincode": vendor.pincode, # Include pincode
                "cuisine_type": vendor.cuisine_type, # Include cuisine_type
                "rating": vendor.rating,
                "is_active": vendor.is_active, # Include is_active
                "menu": [
                    {
                        "id": food.id,
                        "name": food.name or "",
                        "price": food.price,
                        "description": food.description or "",
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
             logger.error(f"Error in RestaurantDetailView: {str(e)}")
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

class TopRatedRestaurantsView(APIView):
    def get(self, request):
        try:
            # Fetch top-rated restaurants ordered by rating in descending order
            vendors = Vendor.objects.filter(is_active=True).order_by('-rating')[:10]
            data = [
                {
                "id": vendor.id,
                "name": vendor.restaurant_name or "",
                "address": vendor.address or "",
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
                "name": vendor.restaurant_name or "",
                "address": vendor.address or "",
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
                "name": food.name or "",
                "price": food.price,
                "description": food.description or "",
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
                "name": food.name or "",
                "price": food.price,
                "description": food.description or "",
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
                "name": food.name or "",
                "price": food.price,
                "description": food.description or "",
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
                    "name": food.name or "",
                    "price": food.price,
                    "description": food.description or "",
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
    def get(self, request, user_id):
        try:
            customer = CustomerProfile.objects.get(user__id=user_id)
            data = {
                "user_id": customer.user.id,
                "full_name": customer.full_name or "",
                "email": customer.user.email or "",
                "phone": customer.phone or "",
                "default_address": {
                    "id": customer.default_address.id if customer.default_address else None,
                    "address_line_1": customer.default_address.address_line_1 if (customer.default_address and customer.default_address.address_line_1) else "",
                    "city": customer.default_address.city if (customer.default_address and customer.default_address.city) else "",
                } if customer.default_address else None,
            }
            return Response(data, status=status.HTTP_200_OK)
        except CustomerProfile.DoesNotExist:
            return Response({"error": "Customer not found"}, status=status.HTTP_404_NOT_FOUND)

class CustomerAddressesView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    def get(self, request):
        customer = request.user
        addresses = Address.objects.filter(customer=customer)
        
        data = [
            {
                "id": address.id,
                "address_line_1": address.address_line_1 or "",
                "address_line_2": address.address_line_2 or "",
                "city": address.city or "",
                "state": address.state or "",
                "pincode": address.pincode or "",
                "is_default": address.is_default,
            }
            for address in addresses
        ]
        print(data)
        return Response(data, status=status.HTTP_200_OK)

class AddAddressView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    def post(self, request):
        customer = request.user
        # Map incoming field names to the expected field names
        address_line_1 = request.data.get('address_line1')  # Map 'address_line1' to 'address_line_1'
        address_line_2 = request.data.get('address_line2')  # Map 'address_line2' to 'address_line_2'
        city = request.data.get('city')
        state = request.data.get('state')
        pincode = request.data.get('postal_code')  # Map 'postal_code' to 'pincode'

        # Validate required fields
        if not all([address_line_1, city, state, pincode]):
            return Response(
                {"error": "All required fields (address_line1, city, state, postal_code) must be provided."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            address = Address.objects.create(
                customer=customer,
                address_line_1=address_line_1 or "",
                address_line_2=address_line_2 or "",
                city=city or "",
                state=state or "",
                pincode=pincode or "",
                is_default=request.data.get('is_default', False),
            )
            return Response({"message": "Address added successfully", "id": address.id}, status=status.HTTP_201_CREATED)
        except Exception as e:
            logger.error(f"Error adding address for customer {customer.customer_id}: {str(e)}")
            return Response({"error": "Failed to add address"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class UpdateAddressView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    def put(self, request, address_id):
        customer = request.user
        try:
            address = Address.objects.get(id=address_id, customer=customer)
            # Map incoming field names if necessary (similar to AddAddressView)
            address.address_line_1 = request.data.get('address_line1', address.address_line_1) or ""
            address.address_line_2 = request.data.get('address_line2', address.address_line_2) or ""
            address.city = request.data.get('city', address.city) or ""
            address.state = request.data.get('state', address.state) or ""
            address.pincode = request.data.get('postal_code', address.pincode) or "" # Map postal_code
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
        customer = request.user
        try:
            # Fetch the address by ID
            address = Address.objects.get(id=address_id, customer=customer)
            address.delete()
            return Response({"message": "Address deleted successfully"}, status=status.HTTP_200_OK) # Use 200 OK or 204 No Content
        except Address.DoesNotExist:
            return Response({"error": "Address not found"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error deleting address {address_id}: {str(e)}")
            return Response({"error": "Failed to delete address"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# Unified Order Placement View
class PlaceOrderView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
    def post(self, request):
        customer = request.user
        print(request.data)
        """
        Handle POST requests to place an order.
        
        Expected request format:
        {
          "payment_method": "cod" or "paytm",
          "payment_status": "success",
          "txn_id": "optional",
          "order_details": {
            "user_id": "U12345",
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
            
            user_id = order_details.get('user_id')
            items_data = order_details.get('items', [])
            address_param = order_details.get('address')  # Can be either pincode or address ID
            vendor_id = order_details.get('vendor_id')
            delivery_fee = order_details.get('delivery_fee')  # Optional delivery fee from request
            total_price = order_details.get('total_price')  # Optional total price from request
            
            if not all([user_id, items_data, address_param, vendor_id]):
                return Response(
                    {"error": "user_id, items, address, and vendor_id are required in order_details"},
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
                customer = CustomerProfile.objects.get(user__id=user_id)
                vendor = Vendor.objects.get(vendor_id=vendor_id)
            except CustomerProfile.DoesNotExist:
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
                    if distance <= 5: delivery_fee = 20.0
                    else: delivery_fee = 20.0 + (distance - 5) * 5.0
                    
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
                customer=customer, vendor=vendor, total_amount=total_amount,
                delivery_address=delivery_address_str, payment_mode=payment_method,
                payment_status=payment_status, payment_id=txn_id, status='placed',
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
                    "name": vendor.restaurant_name or "",
                    "phone": vendor.contact_number
                },
                "delivery_address": delivery_address_str
            }
            
            # Add distance info if calculated
            if distance:
                response_data["distance_km"] = round(distance, 2)
            
            logger.info(f"Order {order.order_number} created successfully for customer {customer.user.id}")
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
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]
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
                    'name': order.vendor.restaurant_name or "",
                    'phone': order.vendor.contact_number
                } if order.vendor else None,
                 'restaurant': { # Match frontend expectation in other sections
                    'name': order.vendor.restaurant_name or ""
                 } if order.vendor else None,
                'items': [
                    {
                        'id': item.id,
                        'food_id': item.food.id,
                        'name': item.food.name or "",
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

class CheckAuthView(APIView):
    authentication_classes = [CustomerJWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        # If authentication passes, the token is valid.
        return Response({"message": "Authenticated"}, status=status.HTTP_200_OK)
