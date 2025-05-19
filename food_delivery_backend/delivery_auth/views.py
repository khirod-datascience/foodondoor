from django.shortcuts import render
from rest_framework import generics, status, views
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from .models import DeliveryUser
from .serializers import (
    PhoneSerializer, VerifyOTPSerializer, RegisterSerializer, DeliveryUserSerializer, OrderSerializer
)
from django.conf import settings
import jwt # Import PyJWT
from datetime import datetime, timedelta, timezone # Import datetime and timezone
from .authentication import DeliveryUserJWTAuthentication # Import custom authentication
from customer_app.models import Order # Assuming Order model is here
from .permissions import IsAuthenticatedDeliveryUser # Import custom permission

# --- FCM Notification Utility ---
try:
    from auth_app.views import send_notification_to_device
except ImportError:
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

# Custom JWT generation for DeliveryUser
def generate_delivery_jwt(user: DeliveryUser):
    # Convert UUID to string for JSON serialization
    user_id_str = str(user.id)

    access_payload = {
        'token_type': 'access',
        'exp': datetime.now(timezone.utc) + timedelta(minutes=settings.SIMPLE_JWT['ACCESS_TOKEN_LIFETIME'].total_seconds() / 60), # Use configured lifetime
        'iat': datetime.now(timezone.utc),
        'jti': jwt.encode({}, settings.SECRET_KEY, algorithm=settings.SIMPLE_JWT['ALGORITHM']), # Simple unique ID
        'user_id': user_id_str, # <-- Use string representation
        'phone_number': user.phone_number,
        'user_type': 'delivery' # Explicitly set user type
    }
    refresh_payload = {
        'token_type': 'refresh',
        'exp': datetime.now(timezone.utc) + timedelta(days=settings.SIMPLE_JWT['REFRESH_TOKEN_LIFETIME'].total_seconds() / (60*60*24)), # Use configured lifetime
        'iat': datetime.now(timezone.utc),
        'jti': jwt.encode({}, settings.SECRET_KEY, algorithm=settings.SIMPLE_JWT['ALGORITHM']), # Simple unique ID
        'user_id': user_id_str, # <-- Use string representation
        'user_type': 'delivery'
    }

    access_token = jwt.encode(access_payload, settings.SECRET_KEY, algorithm=settings.SIMPLE_JWT['ALGORITHM'])
    refresh_token = jwt.encode(refresh_payload, settings.SECRET_KEY, algorithm=settings.SIMPLE_JWT['ALGORITHM'])

    return {
        'access': access_token,
        'refresh': refresh_token,
    }

class SendOTPView(generics.GenericAPIView):
    serializer_class = PhoneSerializer
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone_number = serializer.validated_data['phone_number']

        # Get or create the delivery user entry
        user, created = DeliveryUser.objects.get_or_create(phone_number=phone_number)

        if not user.is_active:
             return Response({"message": "This account is inactive."}, status=status.HTTP_403_FORBIDDEN)

        user.generate_otp()
        # TODO: Add actual SMS sending logic here
        print(f"Generated OTP for {phone_number}: {user.otp}") # Debugging

        return Response({"success": True, "message": "OTP sent successfully."}, status=status.HTTP_200_OK)

class VerifyOTPView(generics.GenericAPIView):
    serializer_class = VerifyOTPSerializer
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone_number = serializer.validated_data['phone_number']
        otp = serializer.validated_data['otp']

        try:
            user = DeliveryUser.objects.get(phone_number=phone_number)
        except DeliveryUser.DoesNotExist:
            return Response({"success": False, "message": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        if not user.is_active:
            return Response({"message": "This account is inactive."}, status=status.HTTP_403_FORBIDDEN)

        if user.is_otp_valid(otp):
            is_new_user = not user.is_registered

            if is_new_user:
                # Don't issue tokens yet, user needs to register
                return Response({
                    "success": True,
                    "is_new_user": True,
                    "message": "OTP verified. Please complete registration."
                }, status=status.HTTP_200_OK)
            else:
                # Existing, registered user: Issue tokens using CUSTOM function
                tokens = generate_delivery_jwt(user)
                user_data = DeliveryUserSerializer(user).data
                return Response({
                    "success": True,
                    "is_new_user": False,
                    "access": tokens['access'],
                    "refresh": tokens['refresh'],
                    "user": user_data
                }, status=status.HTTP_200_OK)
        else:
            return Response({"success": False, "message": "Invalid or expired OTP."}, status=status.HTTP_400_BAD_REQUEST)

class RegisterView(generics.UpdateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny] # Permission handled by OTP check before this step
    queryset = DeliveryUser.objects.all()
    lookup_field = 'phone_number' # Find user by phone number

    # We override post instead of using UpdateAPIView's default put/patch
    # because the trigger comes after OTP verification, not a direct update request.
    def post(self, request, *args, **kwargs):
        # We expect the phone number to be passed in the URL or identified
        # by a temporary session/cache key set during OTP verification.
        # For simplicity, let's assume the phone number is in the request data
        # ONLY for the purpose of retrieving the user. It won't be validated by the serializer.

        # This is not ideal security-wise. A better approach involves:
        # 1. Setting a short-lived signed token/session variable upon OTP verification.
        # 2. Requiring that token here to identify the user being registered.
        # For now, we'll trust the client sends the correct phone number.
        temp_phone_serializer = PhoneSerializer(data=request.data)
        if not temp_phone_serializer.is_valid():
             return Response({"message": "Phone number missing or invalid."}, status=status.HTTP_400_BAD_REQUEST)
        phone_number = temp_phone_serializer.validated_data['phone_number']

        try:
            user = DeliveryUser.objects.get(phone_number=phone_number)
        except DeliveryUser.DoesNotExist:
             return Response({"message": "User not found. Please verify OTP first."}, status=status.HTTP_404_NOT_FOUND)

        # Check if user already registered
        if user.is_registered:
            return Response({"message": "User already registered."}, status=status.HTTP_400_BAD_REQUEST)

        # Validate registration data (name, email)
        serializer = self.get_serializer(user, data=request.data, partial=True) # Use instance and partial=True
        serializer.is_valid(raise_exception=True)
        serializer.save() # Updates the user instance with name and email

        # Mark user as registered (assuming save() doesn't do this)
        user.is_registered = True # Make sure this field is updated
        user.save(update_fields=['is_registered'])

        # Registration complete, now issue tokens using CUSTOM function
        tokens = generate_delivery_jwt(user)
        user_data = DeliveryUserSerializer(user).data

        return Response({
            "success": True,
            "message": "Registration successful.",
            "access": tokens['access'],
            "refresh": tokens['refresh'],
            "user": user_data
        }, status=status.HTTP_200_OK)

# --- Order Views --- #

class DeliveryOrderListView(generics.ListAPIView):
    serializer_class = OrderSerializer
    authentication_classes = [DeliveryUserJWTAuthentication]
    permission_classes = [IsAuthenticatedDeliveryUser]

    def list(self, request, *args, **kwargs):
        print(f"--- DeliveryOrderListView reached! Request Path: {request.path} ---") # DEBUG
        print(f"--- Authenticated User: {request.user} ({type(request.user)}) ---") # DEBUG
        queryset = self.get_queryset()
        print(f"--- Queryset Count: {queryset.count()} ---") # DEBUG
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    def get_queryset(self):
        """
        This view should return a list of all the orders
        for the currently authenticated delivery user.
        It also supports filtering by status.
        """
        print("--- DeliveryOrderListView.get_queryset called --- ") # DEBUG
        user = self.request.user

        if not isinstance(user, DeliveryUser):
             print("--- ERROR: request.user is NOT a DeliveryUser instance! ---") # DEBUG
             return Order.objects.none()

        print(f"--- Filtering orders for DeliveryUser ID: {user.id} ---") # DEBUG
        queryset = Order.objects.filter(delivery_partner__id=str(user.id))

        status_param = self.request.query_params.get('status', None)
        if status_param:
            statuses = [s.strip() for s in status_param.split(',') if s.strip()]
            if statuses:
                print(f"--- Filtering by status: {statuses} ---") # DEBUG
                queryset = queryset.filter(status__in=statuses)
            else:
                 print("--- Status parameter present but empty after processing. ---") # DEBUG
        else:
             print("--- No status filter applied. ---") # DEBUG

        return queryset.order_by('-created_at')

# --- Delivery Agent: Update Order Status ---
from auth_app.models import Order
from auth_app.views import send_notification_to_device

class DeliveryOrderStatusUpdateView(views.APIView):
    authentication_classes = [DeliveryUserJWTAuthentication]
    permission_classes = [IsAuthenticatedDeliveryUser]
    def patch(self, request, order_number):
        try:
            new_status = request.data.get('status')
            if not new_status:
                return Response({'error': 'Missing status'}, status=status.HTTP_400_BAD_REQUEST)
            order = Order.objects.get(order_number=order_number)
            order.status = new_status
            order.save()
            # Notify customer via FCM if available
            customer = getattr(order, 'customer', None)
            if customer and hasattr(customer, 'fcm_token') and customer.fcm_token:
                title = f"Order {order.order_number} Status Updated"
                body = f"Your order status is now: {new_status}"
                try:
                    send_notification_to_device(customer.fcm_token, title, body)
                except Exception as e:
                    print(f"Failed to send FCM notification: {e}")
            return Response({'order_no': order.order_number, 'status': order.status}, status=status.HTTP_200_OK)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            print(f"Error updating order status for {order_number}: {str(e)}")
            return Response({"error": "Failed to update order status"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- Delivery Agent: Update Live Location ---
class DeliveryOrderLocationUpdateView(views.APIView):
    authentication_classes = [DeliveryUserJWTAuthentication]
    permission_classes = [IsAuthenticatedDeliveryUser]
    def patch(self, request, order_number):
        try:
            lat = request.data.get('lat')
            lng = request.data.get('lng')
            if lat is None or lng is None:
                return Response({'error': 'Missing lat/lng'}, status=status.HTTP_400_BAD_REQUEST)
            order = Order.objects.get(order_number=order_number)
            order.delivery_lat = lat
            order.delivery_lng = lng
            order.save()
            # Notify customer via FCM if available (optional)
            customer = getattr(order, 'customer', None)
            if customer and hasattr(customer, 'fcm_token') and customer.fcm_token:
                title = f"Order {order.order_number} Location Updated"
                body = f"Your order is on the move!"
                try:
                    send_notification_to_device(customer.fcm_token, title, body)
                except Exception as e:
                    print(f"Failed to send FCM notification: {e}")
            return Response({'order_no': order.order_number, 'delivery_lat': order.delivery_lat, 'delivery_lng': order.delivery_lng}, status=status.HTTP_200_OK)
        except Order.DoesNotExist:
            return Response({'error': 'Order not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            print(f"Error updating order location for {order_number}: {str(e)}")
            return Response({"error": "Failed to update order location"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# TODO: Implement custom Authentication Class (DeliveryUserJWTAuthentication)
# This class will be responsible for validating the custom JWT and attaching
# the correct DeliveryUser object to request.user

class UpdateFCMTokenView(views.APIView):
    def get_permissions(self):
        # AllowAny for GET, original permissions for POST
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAuthenticatedDeliveryUser()]

    def get(self, request):
        # HARDCODED TEST VALUES
        fcm_token = '<PUT_YOUR_FCM_TOKEN_HERE>'
        return Response({'success': True, 'fcm_token': fcm_token}, status=status.HTTP_200_OK)

    def post(self, request):
        user = request.user
        fcm_token = request.data.get('fcm_token')
        if not fcm_token:
            return Response({'success': False, 'message': 'No FCM token provided.'}, status=status.HTTP_400_BAD_REQUEST)
        user.fcm_token = fcm_token
        user.save()
        return Response({'success': True, 'message': 'FCM token updated.'}, status=status.HTTP_200_OK)

class TestNotificationView(views.APIView):
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

