from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, generics, permissions
from .models import Vendor, Menu, FoodListing, Order, Notification
from .serializers import (
    VendorRegistrationSerializer, VendorLoginSerializer, VendorProfileSerializer,
    MenuSerializer, FoodListingSerializer, OrderSerializer, OrderStatusUpdateSerializer,
    NotificationSerializer, ImageUploadSerializer
)
from rest_framework_simplejwt.tokens import RefreshToken # To generate tokens manually
from django.contrib.auth.hashers import check_password
from rest_framework.permissions import AllowAny, IsAuthenticated
from .authentication import VendorJWTAuthentication
from .permissions import IsVendorUser, IsVendorOwnerOrReadOnly, IsOrderVendorOwner # Import custom permissions
from django.core.files.storage import default_storage
from django.conf import settings
import os
import logging
import traceback # For detailed error logging
from django.utils import timezone
from rest_framework.exceptions import ValidationError # Add this if missing
from accounts.utils import OTPManager # Assuming OTPManager exists or will be created in accounts.utils
import random
from geopy.geocoders import Nominatim # <-- Import geocoder
from geopy.exc import GeocoderTimedOut, GeocoderServiceError # <-- Import exceptions

logger = logging.getLogger(__name__)

# --- Helper to Generate Vendor JWT ---
# (Similar to VendorLoginView logic, extracting to a helper)
def get_tokens_for_vendor(vendor):
    try:
        refresh = RefreshToken()
        # Add custom claims specific to vendor
        refresh['vendor_id'] = vendor.vendor_id
        refresh['email'] = vendor.email
        refresh['name'] = vendor.restaurant_name
        refresh['role'] = 'vendor'
        logger.info(f"Generated tokens for vendor {vendor.vendor_id}")
        # Explicitly generate access token
        access = refresh.access_token
        return {
            'refresh': str(refresh),
            'access': str(access), # Use the explicitly generated token string
        }
    except Exception as e:
        logger.error(f"Error generating JWT for vendor {vendor.vendor_id}: {e}")
        return None

# --- Authentication Views ---

class VendorRegisterView(APIView): # Changed from CreateAPIView
    """Handles Vendor registration using verified phone number."""
    serializer_class = VendorRegistrationSerializer # Keep for schema reference
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        logger.info("Vendor OTP Registration attempt.")
        verified_phone = request.session.get('verified_vendor_phone')

        if not verified_phone:
            logger.warning("Vendor registration attempt without verified phone in session.")
            return Response({'error': 'Phone number verification is missing. Please verify OTP first.'}, status=status.HTTP_400_BAD_REQUEST)

        # Data expected from frontend after OTP verification
        data = request.data.copy()
        print(data)
        # Remove password if present, ensure serializer handles its absence
        data.pop('password', None)
        data.pop('password2', None)
        # Explicitly remove lat/lon from incoming data to prevent premature validation
        data.pop('latitude', None)
        data.pop('longitude', None)

        # Minimal validation here, rely on serializer/model constraints
        if not data.get('restaurant_name') or not data.get('address'):
             return Response({'error': 'Restaurant name and address are required.'}, status=status.HTTP_400_BAD_REQUEST)
        if Vendor.objects.filter(contact_number=verified_phone).exists():
             return Response({'error': 'An account with this phone number already exists.'}, status=status.HTTP_400_BAD_REQUEST)
        if data.get('email') and Vendor.objects.filter(email=data['email']).exists():
             return Response({'error': 'An account with this email address already exists.'}, status=status.HTTP_400_BAD_REQUEST)

        # Use serializer primarily for validation if possible, or manual creation
        # Pass the cleaned data (without lat/lon) to the serializer
        serializer = self.serializer_class(data=data)
        try:
            serializer.is_valid(raise_exception=True)

            # --- Geocoding --- >
            geolocator = Nominatim(user_agent="food_delivery_app") # Replace with your app name
            address_string = serializer.validated_data['address']
            latitude = None
            longitude = None
            try:
                location = geolocator.geocode(address_string, timeout=10) # 10 second timeout
                if location:
                    latitude = location.latitude
                    longitude = location.longitude
                    logger.info(f"Geocoding successful for address '{address_string}': Lat={latitude}, Lon={longitude}")
                else:
                    logger.warning(f"Geocoding failed: Address not found for '{address_string}'")
            except (GeocoderTimedOut, GeocoderServiceError) as geo_e:
                logger.error(f"Geocoding service error for address '{address_string}': {geo_e}")
            except Exception as geo_exc:
                logger.error(f"Unexpected error during geocoding for address '{address_string}': {geo_exc}")
            # --- End Geocoding ---

            # Serializer's save might still expect a password if not modified
            # Let's try manual creation first:
            vendor = Vendor.objects.create(
                 vendor_id=f"V{timezone.now().strftime('%Y%m%d%H%M%S')}{random.randint(100, 999)}", # Example ID
                 contact_number=verified_phone,
                 restaurant_name=serializer.validated_data['restaurant_name'],
                 address=address_string, # Use the validated address
                 email=serializer.validated_data.get('email'), # Optional
                 # Set other fields as needed from serializer.validated_data
                 latitude=latitude, # Use derived latitude
                 longitude=longitude, # Use derived longitude
                 pincode=serializer.validated_data.get('pincode'),
                 cuisine_type=serializer.validated_data.get('cuisine_type'),
                 # DO NOT set password
            )
            logger.info(f"Vendor registered via OTP successfully: {vendor.vendor_id}")

            tokens = get_tokens_for_vendor(vendor)
            if not tokens:
                # Should we delete the partially created vendor?
                vendor.delete()
                return Response({"error": "Failed to generate authentication tokens after registration."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

            if 'verified_vendor_phone' in request.session: del request.session['verified_vendor_phone']

            profile_serializer = VendorProfileSerializer(vendor)
            return Response({
                 'refresh': tokens['refresh'],
                 'access': tokens['access'],
                 'vendor': profile_serializer.data
            }, status=status.HTTP_201_CREATED)

        except ValidationError as e:
             logger.warning(f"Vendor OTP Registration validation failed: {e.detail}")
             return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Unexpected error during vendor OTP registration: {e}\n{traceback.format_exc()}")
            # Clean up session if error occurs
            if 'verified_vendor_phone' in request.session: del request.session['verified_vendor_phone']
            return Response({"error": "Registration failed due to an unexpected error."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class VendorLoginView(APIView):
    """Handles Vendor login using Email/Password and returns JWT."""
    permission_classes = [AllowAny]
    serializer_class = VendorLoginSerializer # Specify serializer for schema generation

    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        if not serializer.is_valid():
            logger.warning(f"Login validation failed: {serializer.errors}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data.get('email')
        password = serializer.validated_data.get('password')
        fcm_token = serializer.validated_data.get('fcm_token') # Get optional token
        logger.info(f"Login attempt for email: {email}")

        try:
            vendor = Vendor.objects.get(email__iexact=email) # Case-insensitive email check
        except Vendor.DoesNotExist:
            logger.warning(f"Login failed: Vendor not found for email {email}")
            return Response({'error': 'Invalid Credentials'}, status=status.HTTP_401_UNAUTHORIZED)

        if not vendor.check_password(password):
            logger.warning(f"Login failed: Invalid password for vendor {vendor.vendor_id}")
            return Response({'error': 'Invalid Credentials'}, status=status.HTTP_401_UNAUTHORIZED)

        if not vendor.is_active:
            logger.warning(f"Login failed: Vendor account disabled for {vendor.vendor_id}")
            return Response({'error': 'Account disabled. Please contact support.'}, status=status.HTTP_403_FORBIDDEN)

        # --- Update FCM Token if provided ---
        if fcm_token and vendor.fcm_token != fcm_token:
            logger.info(f"Updating FCM token for vendor {vendor.vendor_id}")
            vendor.fcm_token = fcm_token
            vendor.save(update_fields=['fcm_token', 'updated_at'])

        # --- Generate JWT Tokens Manually ---
        logger.info(f"Login successful for vendor: {vendor.vendor_id}. Generating tokens.")
        try:
            refresh = RefreshToken()
            # Add custom claims - MUST match what VendorJWTAuthentication expects
            refresh['vendor_id'] = vendor.vendor_id
            refresh['email'] = vendor.email
            # Add other claims if needed (e.g., name, role)
            refresh['name'] = vendor.restaurant_name
            refresh['role'] = 'vendor' # Example role claim

            access_token = str(refresh.access_token)
            refresh_token = str(refresh)

            # Prepare response data (use Profile Serializer for consistency)
            profile_data = VendorProfileSerializer(vendor).data

            return Response({
                'refresh': refresh_token,
                'access': access_token,
                'vendor': profile_data # Send profile data on login
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Error generating JWT for vendor {vendor.vendor_id}: {e}\n{traceback.format_exc()}")
            return Response({"error": "Token generation failed."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --- Profile View ---
class VendorProfileView(generics.RetrieveUpdateAPIView):
    """GET/PUT/PATCH the logged-in Vendor's profile."""
    queryset = Vendor.objects.all()
    serializer_class = VendorProfileSerializer
    authentication_classes = [VendorJWTAuthentication]
    permission_classes = [IsVendorUser] # Custom permission checks if user is a vendor

    def get_object(self):
        # Retrieve the vendor instance attached by the custom authentication backend
        if hasattr(self.request.user, 'vendor_instance'):
            logger.debug(f"Fetching profile for vendor: {self.request.user.vendor_instance.vendor_id}")
            return self.request.user.vendor_instance
        else:
            # This should not happen if IsVendorUser permission works correctly
            logger.error("Vendor instance not found on request.user in ProfileView.")
            raise serializers.ValidationError("Could not identify vendor profile.") # Or Http404


# --- Menu Views ---
class MenuListView(generics.ListCreateAPIView):
    """List vendor's menus or create a new menu."""
    serializer_class = MenuSerializer
    authentication_classes = [VendorJWTAuthentication]
    permission_classes = [IsVendorUser] # Only vendors can list/create menus

    def get_queryset(self):
        # Filter menus belonging to the authenticated vendor
        vendor_instance = self.request.user.vendor_instance
        logger.debug(f"Listing menus for vendor: {vendor_instance.vendor_id}")
        return Menu.objects.filter(vendor=vendor_instance)

    def perform_create(self, serializer):
        # Assign the authenticated vendor automatically
        vendor_instance = self.request.user.vendor_instance
        logger.info(f"Creating menu for vendor: {vendor_instance.vendor_id} with data: {serializer.validated_data}")
        serializer.save(vendor=vendor_instance)

class MenuDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, Update or Delete a specific menu."""
    serializer_class = MenuSerializer
    authentication_classes = [VendorJWTAuthentication]
    permission_classes = [IsVendorUser, IsVendorOwnerOrReadOnly] # Check ownership for write operations
    queryset = Menu.objects.all() # Base queryset
    lookup_field = 'id' # Use Menu primary key 'id'

    def get_queryset(self):
        # Further filter to ensure the object lookup is scoped to the vendor
        # Although IsVendorOwnerOrReadOnly handles object check, pre-filtering is good practice
        vendor_instance = self.request.user.vendor_instance
        return Menu.objects.filter(vendor=vendor_instance)


# --- Food Listing (Item) Views ---
class ItemListView(generics.ListCreateAPIView):
    """List items for a specific menu or create a new item in that menu."""
    serializer_class = FoodListingSerializer
    authentication_classes = [VendorJWTAuthentication]
    permission_classes = [IsVendorUser] # Requires authenticated vendor

    def get_queryset(self):
        # Filter items based on the menu_id from the URL and ensure menu belongs to vendor
        vendor_instance = self.request.user.vendor_instance
        menu_id = self.kwargs.get('menu_id')
        logger.debug(f"Listing items for menu_id: {menu_id} of vendor: {vendor_instance.vendor_id}")
        # Ensure the menu belongs to the vendor before listing items
        return FoodListing.objects.filter(menu__id=menu_id, menu__vendor=vendor_instance)

    def perform_create(self, serializer):
        # Get the menu instance and check ownership before saving the item
        vendor_instance = self.request.user.vendor_instance
        menu_id = self.kwargs.get('menu_id')
        try:
            # Explicitly check menu ownership before saving item to it
            menu = Menu.objects.get(id=menu_id, vendor=vendor_instance)
            logger.info(f"Creating item for menu: {menu_id} (Vendor: {vendor_instance.vendor_id}) with data: {serializer.validated_data}")
            # Get existing context and add menu to it
            context = serializer.context
            context['menu'] = menu
            serializer.save() # Context is already set on the serializer instance
        except Menu.DoesNotExist:
             logger.warning(f"Attempt to create item failed. Menu {menu_id} not found or doesn't belong to vendor {vendor_instance.vendor_id}")
             # Use rest_framework.exceptions.ValidationError
             raise ValidationError({"menu": f"Menu ID {menu_id} not found for this vendor."})

class ItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, Update or Delete a specific item."""
    serializer_class = FoodListingSerializer
    authentication_classes = [VendorJWTAuthentication]
    permission_classes = [IsVendorUser, IsVendorOwnerOrReadOnly] # Check ownership via menu
    queryset = FoodListing.objects.all()
    lookup_field = 'id' # Use FoodListing primary key 'id'

    def get_queryset(self):
        # Further filter items to ensure they belong to the vendor
        vendor_instance = self.request.user.vendor_instance
        return FoodListing.objects.filter(menu__vendor=vendor_instance)

# --- Order Views ---
class OrderListView(generics.ListAPIView):
    """Lists orders for the authenticated vendor, supports status filtering."""
    serializer_class = OrderSerializer
    authentication_classes = [VendorJWTAuthentication]
    permission_classes = [IsVendorUser]

    def get_queryset(self):
        vendor_instance = self.request.user.vendor_instance
        logger.debug(f"Listing orders for vendor: {vendor_instance.vendor_id}")
        queryset = Order.objects.filter(vendor=vendor_instance).order_by('-created_at')

        # Filter by status query parameter (e.g., /vendor/orders/?status=Pending)
        status_filter = self.request.query_params.get('status', None)
        if status_filter:
            # Validate status_filter against choices if necessary
            valid_statuses = [choice[0] for choice in Order.ORDER_STATUS_CHOICES]
            if status_filter in valid_statuses:
                logger.debug(f"Filtering orders by status: {status_filter}")
                queryset = queryset.filter(status=status_filter)
            else:
                logger.warning(f"Invalid status filter received: {status_filter}")
                # Return empty queryset or raise validation error? Empty is safer.
                queryset = queryset.none()

        return queryset

class OrderDetailView(generics.RetrieveUpdateAPIView): # Changed to allow PATCH for status update
    """Retrieve order details or Update order status (via PATCH)."""
    queryset = Order.objects.all()
    authentication_classes = [VendorJWTAuthentication]
    permission_classes = [IsVendorUser, IsOrderVendorOwner] # Use specific order owner permission
    lookup_field = 'order_number' # Use unique order_number from URL

    def get_serializer_class(self):
        # Use OrderStatusUpdateSerializer for PATCH requests
        if self.request.method == 'PATCH':
            return OrderStatusUpdateSerializer
        # Use full OrderSerializer for GET requests
        return OrderSerializer

    def get_queryset(self):
        # Ensure lookup is scoped to the vendor's orders
        vendor_instance = self.request.user.vendor_instance
        return Order.objects.filter(vendor=vendor_instance)

    # PATCH is handled implicitly by RetrieveUpdateAPIView using the serializer's update method

    # Disable PUT to prevent updating other fields via this endpoint
    def put(self, request, *args, **kwargs):
        logger.warning(f"PUT method not allowed for OrderDetailView (order: {kwargs.get('order_number')})")
        return Response({"detail": "Method \"PUT\" not allowed."}, status=status.HTTP_405_METHOD_NOT_ALLOWED)


# --- Image Upload View ---
class ImageUploadView(APIView):
    """
    Handles uploading a single image file.
    Allows any user for registration purposes, but should ideally be more restricted
    in production (e.g., requiring a temporary token or specific flag).
    """
    permission_classes = [AllowAny] # <--- CHANGE THIS
    serializer_class = ImageUploadSerializer # For schema documentation

    def post(self, request):
        serializer = self.serializer_class(data=request.data)
        if not serializer.is_valid():
            logger.warning(f"Image upload failed validation: {serializer.errors}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        image_file = serializer.validated_data['image']
        # Cannot associate with vendor here as user might not be authenticated yet
        # Create a more generic path or include a temporary identifier if needed
        logger.info(f"Anonymous/Pre-Reg Image upload attempt, Filename: {image_file.name}")

        try:
            # Save to a temporary or generic location initially? Or use a structure that doesn't rely on vendor_id yet.
            # Example: Use timestamp for uniqueness
            timestamp = timezone.now().strftime('%Y%m%d%H%M%S%f')
            file_ext = os.path.splitext(image_file.name)[1]
            # Save to a generic 'uploads' folder within vendor_images
            file_name = f"vendor_images/uploads/{timestamp}_{default_storage.get_available_name(image_file.name)}"
            saved_path = default_storage.save(file_name, image_file)
            logger.info(f"Image saved successfully at path: {saved_path}")

            # Return the relative path
            image_url = f"{settings.MEDIA_URL}{saved_path}" # Construct relative URL

            return Response({'message': 'Image uploaded successfully', 'image_path': saved_path, 'image_url': image_url}, status=status.HTTP_201_CREATED)
        except Exception as e:
            logger.error(f"Error saving uploaded image: {e}\n{traceback.format_exc()}")
            return Response({'error': 'Image upload failed.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --- Placeholder Earnings View ---
class EarningsSummaryView(APIView):
    authentication_classes = [VendorJWTAuthentication]
    permission_classes = [IsVendorUser]
    def get(self, request):
        vendor_instance = request.user.vendor_instance
        logger.debug(f"Fetching earnings summary for vendor: {vendor_instance.vendor_id}")
        # TODO: Implement logic to calculate earnings based on 'Delivered' or 'Paid' orders
        # Example: Calculate sum of total_price for orders with status 'Delivered'
        # total_earned = Order.objects.filter(vendor=vendor_instance, status='Delivered').aggregate(Sum('total_price'))['total_price__sum'] or 0.00
        return Response({'total_earnings': "0.00", 'message': 'Earnings calculation not yet implemented.'})


# --- FCM Token Update View ---
class UpdateFCMTokenView(APIView):
     authentication_classes = [VendorJWTAuthentication]
     permission_classes = [IsVendorUser]

     def post(self, request):
         fcm_token = request.data.get('fcm_token')
         if not fcm_token:
             return Response({'error': 'FCM token is required.'}, status=status.HTTP_400_BAD_REQUEST)

         vendor_instance = request.user.vendor_instance
         if vendor_instance.fcm_token != fcm_token:
             logger.info(f"Updating FCM token for vendor {vendor_instance.vendor_id}")
             vendor_instance.fcm_token = fcm_token
             vendor_instance.save(update_fields=['fcm_token', 'updated_at'])
             return Response({'message': 'FCM token updated successfully.'}, status=status.HTTP_200_OK)
         else:
             logger.debug(f"FCM token for vendor {vendor_instance.vendor_id} is already up-to-date.")
             return Response({'message': 'FCM token is already up-to-date.'}, status=status.HTTP_200_OK)


# --- Notification View ---
class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    authentication_classes = [VendorJWTAuthentication]
    permission_classes = [IsVendorUser]

    def get_queryset(self):
        vendor_instance = self.request.user.vendor_instance
        logger.debug(f"Fetching notifications for vendor: {vendor_instance.vendor_id}")
        # TODO: Add filtering for read/unread if needed
        return Notification.objects.filter(vendor=vendor_instance) # Already ordered by '-created_at' in model Meta

# --- Vendor OTP Views ---

class VendorSendOTP(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            phone = request.data.get('phone')
            if not phone:
                return Response({'error': 'Phone number is required'}, status=status.HTTP_400_BAD_REQUEST)

            # Basic phone validation (improve as needed)
            if not phone.isdigit() or len(phone) < 10:
                 return Response({'error': 'Invalid phone number format.'}, status=status.HTTP_400_BAD_REQUEST)

            otp, error = OTPManager.generate_otp(phone)
            if error:
                logger.error(f"Vendor OTP generation failed for {phone}: {error}")
                return Response({'error': error}, status=status.HTTP_400_BAD_REQUEST)

            logger.info(f"Vendor OTP for {phone}: {otp}") # Remove in production
            return Response({'message': 'OTP sent successfully', 'debug_otp': otp}, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Error in VendorSendOTP for phone {request.data.get('phone')}: {e}\n{traceback.format_exc()}")
            return Response({'error': 'Failed to send OTP'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class VendorVerifyOTP(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            phone = request.data.get('phone')
            otp = request.data.get('otp')
            fcm_token = request.data.get('fcm_token') # Optional FCM token

            if not all([phone, otp]):
                return Response({'error': 'Phone and OTP are required'}, status=status.HTTP_400_BAD_REQUEST)

            is_valid, message = OTPManager.verify_otp(phone, otp)
            if not is_valid:
                logger.warning(f"Vendor OTP verification failed for {phone}: {message}")
                return Response({'error': message}, status=status.HTTP_400_BAD_REQUEST)

            try:
                vendor = Vendor.objects.get(contact_number=phone)
                logger.info(f"Vendor OTP verified, logging in vendor: {vendor.vendor_id}")

                # --- Update FCM Token if provided ---
                if fcm_token and vendor.fcm_token != fcm_token:
                    logger.info(f"Updating FCM token for vendor {vendor.vendor_id} during OTP login")
                    vendor.fcm_token = fcm_token
                    vendor.save(update_fields=['fcm_token', 'updated_at'])

                tokens = get_tokens_for_vendor(vendor)
                if not tokens:
                     return Response({"error": "Failed to generate authentication tokens."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

                profile_data = VendorProfileSerializer(vendor).data
                if 'verified_vendor_phone' in request.session: del request.session['verified_vendor_phone']

                return Response({
                    'message': 'Login successful', 'is_signup': False,
                    'refresh': tokens['refresh'],
                    'access': tokens['access'],
                    'vendor': profile_data
                }, status=status.HTTP_200_OK)

            except Vendor.DoesNotExist:
                # Vendor doesn't exist, store phone in session for registration
                request.session['verified_vendor_phone'] = phone
                request.session.save()
                logger.info(f"Vendor OTP verified for {phone}, signup required. Stored phone in session.")
                return Response({'message': 'OTP verified. Please complete registration.', 'is_signup': True}, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error(f"Error in VendorVerifyOTP for phone {request.data.get('phone')}: {e}\n{traceback.format_exc()}")
            return Response({'error': 'OTP verification failed'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# --- Keep or Remove Customer-Facing Views ---
# Remove these if auth_app is ONLY for vendors
# class ActiveRestaurantsView(APIView): ...
# class RestaurantDetailView(APIView): ...
# etc...