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

# TODO: Implement custom Authentication Class (DeliveryUserJWTAuthentication)
# This class will be responsible for validating the custom JWT and attaching
# the correct DeliveryUser object to request.user
