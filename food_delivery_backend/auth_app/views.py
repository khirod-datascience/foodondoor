from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Vendor
from .serializers import *
import firebase_admin
from firebase_admin import credentials, messaging
from .utils import OTPManager
import os

# Initialize Firebase Admin SDK with explicit service account JSON
try:
    firebase_admin.get_app()
except ValueError:
    cred_path = os.path.join(os.path.dirname(__file__), '..', 'foodondoor-9d46b-fe4f07a4039b.json')
    cred_path = os.path.abspath(cred_path)
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

from django.conf import settings
import os
from datetime import datetime
from django.utils import timezone
from datetime import timedelta
import logging
from django.db.models import Prefetch, Q
from .models import Vendor, FoodListing, Notification
from customer_app.models import Banner, FoodCategory, Order, OrderItem
import json
import traceback
import random

logger = logging.getLogger(__name__)

class SendOTP(APIView):
    def post(self, request):
        try:
            phone = request.data.get('phone')
            if not phone:
                return Response(
                    {'error': 'Phone number is required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            otp, error = OTPManager.generate_otp(phone)
            if error:
                return Response({'error': error}, status=status.HTTP_400_BAD_REQUEST)
            
            # In production, integrate with SMS service
            logger.info(f"OTP for {phone}: {otp}")  # Remove in production
            
            return Response(
                {'message': 'OTP sent successfully'}, 
                status=status.HTTP_200_OK
            )
            
        except Exception as e:
            logger.error(f"Error in SendOTP: {str(e)}")
            return Response(
                {'error': 'Failed to send OTP'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

import jwt
from datetime import datetime, timedelta

# ...

def generate_vendor_jwt(vendor):
    """Generate JWT access and refresh tokens for vendor login."""
    now = datetime.utcnow()
    access_payload = {
        'vendor_id': vendor.vendor_id,
        'exp': now + timedelta(hours=2),
        'iat': now,
        'token_type': 'access',
    }
    refresh_payload = {
        'vendor_id': vendor.vendor_id,
        'exp': now + timedelta(days=30),
        'iat': now,
        'token_type': 'refresh',
    }
    access_token = jwt.encode(access_payload, settings.SECRET_KEY, algorithm='HS256')
    refresh_token = jwt.encode(refresh_payload, settings.SECRET_KEY, algorithm='HS256')
    return {'access': access_token, 'refresh': refresh_token}

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

            is_valid, message = OTPManager.verify_otp(phone, otp)
            if not is_valid:
                return Response(
                    {'error': message}, 
                    status=status.HTTP_400_BAD_REQUEST
                )

            try:
                vendor = Vendor.objects.get(phone=phone)
                tokens = generate_vendor_jwt(vendor)
                return Response({
                    'message': 'Login successful',
                    'is_signup': False,
                    'vendorId': vendor.vendor_id,
                    'token': tokens['access'],
                    'refreshToken': tokens['refresh'],
                }, status=status.HTTP_200_OK)
                
            except Vendor.DoesNotExist:
                new_vendor_id = self.generate_vendor_id()
                return Response({
                    'message': 'Signup required',
                    'is_signup': True,
                    'vendor_id': new_vendor_id
                }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"Error in VerifyOTP: {str(e)}")
            return Response(
                {'error': 'Verification failed'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def generate_vendor_id(self):
        """Generate unique vendor ID"""
        try:
            last_vendor = Vendor.objects.all().order_by('-vendor_id').first()
            if last_vendor and last_vendor.vendor_id:
                try:
                    last_num = int(last_vendor.vendor_id[1:])
                    return f'V{str(last_num + 1).zfill(3)}'
                except ValueError:
                    return f'V{str(Vendor.objects.count() + 1).zfill(3)}'
            return 'V001'
        except Exception as e:
            logger.error(f"Error generating vendor ID: {str(e)}")
            return f'V{str(random.randint(1, 999)).zfill(3)}'

class VendorListView(APIView):
    def get(self, request):
        vendors = Vendor.objects.all()
        serializer = VendorSerializer(vendors, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

class SignupView(APIView):
    def post(self, request):
        try:
            phone = request.data.get('phone')
            
            # Check if vendor already exists
            if Vendor.objects.filter(phone=phone).exists():
                return Response({
                    'error': 'Vendor with this phone number already exists'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Generate new vendor_id
            last_vendor = Vendor.objects.all().order_by('-vendor_id').first()
            if last_vendor and last_vendor.vendor_id:
                try:
                    last_num = int(last_vendor.vendor_id[1:])
                    new_vendor_id = f'V{str(last_num + 1).zfill(3)}'
                except ValueError:
                    new_vendor_id = f'V{str(Vendor.objects.count() + 1).zfill(3)}'
            else:
                new_vendor_id = 'V001'
            
            # Add vendor_id to request data
            data = request.data.copy()
            data['vendor_id'] = new_vendor_id
            
            serializer = VendorSerializer(data=data)
            if serializer.is_valid():
                vendor = serializer.save()
                return Response({
                    'message': 'Vendor registered successfully',
                    'vendor_id': vendor.vendor_id
                }, status=status.HTTP_201_CREATED)
            
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            print(f"Error in vendor signup: {e}")
            return Response({
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class NotificationListView(APIView):
    def get(self, request, vendor_id):
        notifications = Notification.objects.filter(vendor__vendor_id=vendor_id).order_by('-created_at')
        serializer = NotificationSerializer(notifications, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
    

class ProfileView(APIView):
    def get(self, request, vendor_id):
        try:
            vendor = Vendor.objects.get(vendor_id=vendor_id)
            
            # Ensure uploaded_images is a list and format URLs properly
            uploaded_images = []
            if vendor.uploaded_images:
                uploaded_images = [
                    img.replace('\\', '/') for img in vendor.uploaded_images
                ]
            
            data = {
                'vendor_id': vendor.vendor_id,
                'restaurant_name': vendor.restaurant_name,
                'email': vendor.email,
                'phone': vendor.phone,
                'address': vendor.address,
                'contact_number': vendor.contact_number,
                'open_hours': vendor.open_hours,
                'uploaded_images': uploaded_images
            }
            print("Profile data being sent:", data)  # Debug print
            return Response(data)
        except Vendor.DoesNotExist:
            return Response({'error': 'Vendor not found'}, status=404)
        except Exception as e:
            print(f"Error in profile view: {e}")
            return Response({'error': str(e)}, status=500)
class FoodListingView(APIView):
    def get(self, request, vendor_id):
        food_listings = FoodListing.objects.filter(vendor__vendor_id=vendor_id)
        serializer = FoodListingSerializer(food_listings, many=True, context={'request': request}) # Pass request context if needed for full URLs later
        print(serializer.data)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request, vendor_id):
        logger.info(f"Received POST data for food listing creation: {request.data}")
        try:
            vendor = Vendor.objects.get(vendor_id=vendor_id)
        except Vendor.DoesNotExist:
            return Response({'error': 'Vendor not found'}, status=status.HTTP_404_NOT_FOUND)

        data = request.data.copy()
        data['vendor'] = vendor.id # Assign vendor primary key

        # The serializer now expects 'images' as a list directly
        # No need to extract the first element anymore

        serializer = FoodListingSerializer(data=data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            # The response from the serializer will now include 'image_urls'
            # You might want to return the created object's data
            return Response(serializer.data, status=status.HTTP_201_CREATED) # Return serialized data

        logger.error(f"FoodListing POST validation errors: {serializer.errors}")
        return Response({'error': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, vendor_id, food_id):
        try:
            vendor = Vendor.objects.get(vendor_id=vendor_id)
            food_item = FoodListing.objects.get(id=food_id, vendor=vendor)
        except Vendor.DoesNotExist:
             return Response({'error': 'Vendor not found'}, status=status.HTTP_404_NOT_FOUND)
        except FoodListing.DoesNotExist:
            return Response({'error': 'Food item not found'}, status=status.HTTP_404_NOT_FOUND)

        data = request.data.copy()
        # --- Expect 'image' to be a string path/URL ---
        # The frontend sends the updated path string if the image is changed.

        serializer = FoodListingSerializer(food_item, data=data, partial=True) # partial=True allows partial updates
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        logger.error(f"FoodListing PUT validation errors: {serializer.errors}") # Log errors
        return Response({'error': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, vendor_id, food_id):
        try:
            vendor = Vendor.objects.get(vendor_id=vendor_id)
            food_item = FoodListing.objects.get(id=food_id, vendor=vendor)
            # Note: This only deletes the FoodListing record.
            # The actual image file in vendor_images remains, as it might be used elsewhere.
            food_item.delete()
            return Response({'message': 'Food item deleted successfully!'}, status=status.HTTP_204_NO_CONTENT)
        except Vendor.DoesNotExist:
             return Response({'error': 'Vendor not found'}, status=status.HTTP_404_NOT_FOUND)
        except FoodListing.DoesNotExist:
            return Response({'error': 'Food item not found or does not belong to this vendor'}, status=status.HTTP_404_NOT_FOUND)

class OrderListView(APIView):
    def get(self, request, vendor_id):
        try:
            orders = Order.objects.filter(vendor__vendor_id=vendor_id).order_by('-created_at')
            # Serialize the orders in a format expected by the mobile app
            response_data = []
            for order in orders:
                # Get the order items
                order_items = OrderItem.objects.filter(order=order)
                
                # Create a dictionary for each order
                order_data = {
                    "order_no": order.order_number,
                    "status": order.status,
                    "timestamp": order.created_at.strftime("%Y-%m-%d %H:%M"),
                    "total": sum(float(item.price * item.quantity) for item in order_items), #float(order.total_amount),
                    "items": [
                        {
                            "id": item.id,
                            "name": item.food.name,
                            "quantity": item.quantity,
                            "price": float(item.price)
                        }
                        for item in order_items
                    ],
                    "subtotal": sum(float(item.price * item.quantity) for item in order_items),
                    "tax": 0.0  # Add tax calculation if needed
                }
                
                response_data.append(order_data)
            
            logger.info(f"Retrieved {len(response_data)} orders for vendor {vendor_id}")
            return Response(response_data, status=status.HTTP_200_OK)
        except Exception as e:
            logger.error(f"Error retrieving orders for vendor {vendor_id}: {str(e)}")
            traceback.print_exc()
            return Response({"error": "Failed to retrieve orders"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class OrderDetailView(APIView):
    def get(self, request, order_number):
        try:
            order = Order.objects.get(order_number=order_number)
            # Get the order items
            order_items = OrderItem.objects.filter(order=order)
            
            # Create response data in the format expected by the mobile app
            response_data = {
                "order_no": order.order_number,
                "status": order.status,
                "timestamp": order.created_at.strftime("%Y-%m-%d %H:%M"),
                "customer_info": {
                    "name": order.customer.full_name,
                    "phone": order.customer.phone,
                    "address": order.delivery_address
                },
                "items": [
                    {
                        "id": item.id,
                        "name": item.food.name,
                        "quantity": item.quantity,
                        "price": float(item.price)
                    }
                    for item in order_items
                ],
                "subtotal": sum(float(item.price * item.quantity) for item in order_items),
                "tax": 0.0,  # Add tax calculation if needed
                "total": sum(float(item.price * item.quantity) for item in order_items), #float(order.total_amount),
                "payment_method": order.payment_mode,
                "payment_status": order.payment_status
            }
            
            return Response(response_data, status=status.HTTP_200_OK)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error retrieving order details for {order_number}: {str(e)}")
            traceback.print_exc()
            return Response({"error": "Failed to retrieve order details"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class VendorOrderStatusUpdateView(APIView):
    def patch(self, request, order_number):
        """Vendor updates order status (PATCH). Notifies customer via FCM."""
        try:
            new_status = request.data.get('status')
            if not new_status:
                return Response({'error': 'Missing status'}, status=status.HTTP_400_BAD_REQUEST)
            order = Order.objects.get(order_number=order_number)
            order.status = new_status
            order.save()
            # Notify customer via FCM if customer FCM token exists (pseudo-code)
            customer = getattr(order, 'customer', None)
            if customer and hasattr(customer, 'fcm_token') and customer.fcm_token:
                title = f"Order {order.order_number} Status Updated"
                body = f"Your order status is now: {new_status}"
                try:
                    send_notification_to_device(customer.fcm_token, title, body)
                except Exception as e:
                    logger.error(f"Failed to send FCM notification: {e}")
            return Response({'order_no': order.order_number, 'status': order.status}, status=status.HTTP_200_OK)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Error updating order status for {order_number}: {str(e)}")
            traceback.print_exc()
            return Response({"error": "Failed to update order status"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class ImageUploadView(APIView):
    def post(self, request):
        try:
            # Debug prints
            print("Request FILES:", request.FILES)
            print("Query params:", request.query_params)
            
            if 'image' not in request.FILES:
                return Response({'error': 'No image file provided'}, 
                              status=status.HTTP_400_BAD_REQUEST)

            image = request.FILES['image']
            vendor_id = request.query_params.get('vendor_id')
            
            print(f"Processing upload for vendor_id: {vendor_id}")  # Debug print
            
            if not vendor_id:
                return Response({'error': 'Vendor ID is required'}, 
                              status=status.HTTP_400_BAD_REQUEST)

            try:
                vendor = Vendor.objects.get(vendor_id=vendor_id)
                print(f"Found vendor: {vendor.restaurant_name}")  # Debug print
            except Vendor.DoesNotExist:
                return Response({'error': 'Vendor not found'}, 
                              status=status.HTTP_404_NOT_FOUND)
            
            # Create directory if it doesn't exist
            upload_dir = os.path.join(settings.MEDIA_ROOT, 'vendor_images', str(vendor_id))
            os.makedirs(upload_dir, exist_ok=True)
            
            # Generate unique filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"{timestamp}_scaled_{image.name}"
            filepath = os.path.join(upload_dir, filename)
            
            # Save the file
            with open(filepath, 'wb+') as destination:
                for chunk in image.chunks():
                    destination.write(chunk)
            
            # Generate URL for the uploaded image
            relative_path = os.path.join('vendor_images', str(vendor_id), filename).replace('\\', '/')
            image_url = f"/media/{relative_path}"
            
            if not hasattr(vendor, 'uploaded_images'):
                vendor.uploaded_images = []
            
            # Store image URL in vendor's record
            if not isinstance(vendor.uploaded_images, list):
                vendor.uploaded_images = []
            vendor.uploaded_images.append(image_url)
            vendor.save()
            
            print(f"Image URL stored: {image_url}")  # Debug print
            print(f"Vendor images after update: {vendor.uploaded_images}")  # Debug print
            
            return Response({
                'message': 'Image uploaded successfully',
                'image_url': image_url
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            print(f"Error uploading image: {e}")
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

def send_notification_to_device(token, title, body):
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        token=token,
    )
    response = messaging.send(message)
    print('Successfully sent message:', response)

class ActiveRestaurantsView(APIView):
    def get(self, request):
        pincode = request.GET.get('pincode')
        vendors = Vendor.objects.filter(is_active=True)
        if pincode:
            vendors = vendors.filter(address__icontains=pincode)
        vendors = vendors.prefetch_related('foodlisting_set')
        data = [
            {
                "name": vendor.restaurant_name,
                "address": vendor.address,
                "rating": vendor.rating,
                "menu_preview": [food.name for food in vendor.foodlisting_set.all()[:5]],
            }
            for vendor in vendors
        ]
        return Response(data, status=status.HTTP_200_OK)

class RestaurantDetailView(APIView):
    def get(self, request, vendor_id):
        try:
            vendor = Vendor.objects.prefetch_related('foodlisting_set').get(vendor_id=vendor_id)
            data = {
                "name": vendor.restaurant_name,
                "address": vendor.address,
                "rating": vendor.rating,
                "menu": [
                    {
                        "name": food.name,
                        "price": food.price,
                        "is_available": food.is_available,
                    }
                    for food in vendor.foodlisting_set.all()
                ],
            }
            return Response(data, status=status.HTTP_200_OK)
        except Vendor.DoesNotExist:
            return Response({"error": "Restaurant not found"}, status=status.HTTP_404_NOT_FOUND)

class MenuView(APIView):
    def get(self, request, vendor_id):
        foods = FoodListing.objects.filter(vendor__vendor_id=vendor_id, is_available=True)
        data = [
            {
                "name": food.name,
                "description": food.description,
                "price": food.price,
                "is_available": food.is_available,
            }
            for food in foods
        ]
        return Response(data, status=status.HTTP_200_OK)

class FoodDetailView(APIView):
    def get(self, request, vendor_id, food_id):
        try:
            food = FoodListing.objects.get(vendor__vendor_id=vendor_id, id=food_id)
            data = {
                "name": food.name,
                "description": food.description,
                "price": food.price,
                "is_available": food.is_available,
            }
            return Response(data, status=status.HTTP_200_OK)
        except FoodListing.DoesNotExist:
            return Response({"error": "Food item not found"}, status=status.HTTP_404_NOT_FOUND)

class BannersView(APIView):
    def get(self, request):
        banners = Banner.objects.filter(is_active=True)
        data = [{"title": banner.title, "image": banner.image.url} for banner in banners]
        return Response(data, status=status.HTTP_200_OK)

class CategoriesView(APIView):
    def get(self, request):
        categories = FoodCategory.objects.filter(is_active=True)
        data = [{"name": category.name, "icon": category.icon.url} for category in categories]
        return Response(data, status=status.HTTP_200_OK)

class NearbyRestaurantsView(APIView):
    def get(self, request):
        pincode = request.GET.get('pincode')
        vendors = Vendor.objects.filter(is_active=True, address__icontains=pincode)
        data = [{"name": vendor.restaurant_name, "address": vendor.address} for vendor in vendors]
        return Response(data, status=status.HTTP_200_OK)

class TopRatedRestaurantsView(APIView):
    def get(self, request):
        vendors = Vendor.objects.filter(is_active=True).order_by('-rating')[:10]
        data = [{"name": vendor.restaurant_name, "rating": vendor.rating} for vendor in vendors]
        return Response(data, status=status.HTTP_200_OK)

class SearchView(APIView):
    def get(self, request):
        query = request.GET.get('query', '')
        vendors = Vendor.objects.filter(
            Q(restaurant_name__icontains=query) | Q(foodlisting__name__icontains=query)
        ).distinct()
        data = [
            {
                "name": vendor.restaurant_name,
                "address": vendor.address,
                "menu_preview": [food.name for food in vendor.foodlisting_set.all()[:5]],
            }
            for vendor in vendors
        ]
        return Response(data, status=status.HTTP_200_OK)

class UpdateFCMTokenView(APIView):
    def post(self, request, vendor_id):
        try:
            fcm_token = request.data.get('fcm_token')
            if not fcm_token:
                return Response(
                    {'error': 'FCM token is required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            try:
                # Fix: handle vendor_id case-insensitively and strip whitespace
                normalized_vendor_id = vendor_id.strip().upper()
                try:
                    vendor = Vendor.objects.get(vendor_id__iexact=normalized_vendor_id)
                except Vendor.DoesNotExist:
                    logger.error(f"Vendor not found for vendor_id: '{vendor_id}' (normalized: '{normalized_vendor_id}')")
                    return Response(
                        {'error': f'Vendor not found for vendor_id: {vendor_id}'},
                        status=status.HTTP_404_NOT_FOUND
                    )
                vendor.fcm_token = fcm_token
                vendor.save()
                logger.info(f"FCM token updated for vendor_id: {vendor.vendor_id}")
                return Response(
                    {'message': 'FCM token updated successfully'}, 
                    status=status.HTTP_200_OK
                )
            except Vendor.DoesNotExist:
                return Response(
                    {'error': 'Vendor not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
                
        except Exception as e:
            logger.error(f"Error updating FCM token: {str(e)}")
            return Response(
                {'error': 'Failed to update FCM token'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class TestSendVendorNotificationView(APIView):
    def post(self, request, vendor_id):
        print(f"[DEBUG] Incoming request data: {request.data}")
        title = request.data.get('title', 'Test Notification')
        body = request.data.get('body', 'This is a test notification.')
        try:
            print(f"[DEBUG] Looking up vendor with id: '{vendor_id}' (normalized: '{vendor_id.strip()}')")
            vendor = Vendor.objects.get(vendor_id__iexact=vendor_id.strip())
            print(f"[DEBUG] Vendor found: {vendor.vendor_id}, FCM token: {vendor.fcm_token}")
            if not vendor.fcm_token:
                print(f"[DEBUG] Vendor {vendor_id} has no FCM token.")
                return Response({'error': 'Vendor has no FCM token.'}, status=status.HTTP_400_BAD_REQUEST)
            # Send notification with custom sound and channel (best practice)
            # Construct FCM message with notification payload (not just data)
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='vendor_notifications',
                        sound='vendor_delivery_ring.wav',
                    ),
                ),
                token=vendor.fcm_token,
                # Do not add unnecessary data fields unless needed for app logic
            )
            print(f"[DEBUG] Constructed FCM message (backend): {message}")
            # FLUTTER FRONTEND INSTRUCTIONS:
            # - Place 'vendor_delivery_ring.wav' in android/app/src/main/res/raw/ (Android) and iOS main bundle.
            # - Create NotificationChannel with id 'vendor_notifications' and sound 'vendor_delivery_ring.wav' in Flutter (see work_summary.md for example).
            # - For foreground notifications, use flutter_local_notifications to play sound and show alert.
            print(f"[DEBUG] Constructed FCM message: {message}")
            response = messaging.send(message)
            print(f"[DEBUG] FCM send response: {response}")
            # Save notification to DB for notification tab
            Notification.objects.create(
                vendor=vendor,
                title=title,
                body=body,
            )
            print(f"[DEBUG] Notification saved to DB for vendor {vendor.vendor_id}")
            return Response({'message': 'Notification sent!', 'firebase_response': response}, status=status.HTTP_200_OK)
        except Vendor.DoesNotExist:
            print(f"[DEBUG] Vendor not found: {vendor_id}")
            return Response({'error': 'Vendor not found.'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            print(f"[DEBUG] Exception sending notification: {str(e)}")
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)