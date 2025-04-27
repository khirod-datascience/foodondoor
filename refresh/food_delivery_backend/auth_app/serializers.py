from rest_framework import serializers
from .models import Vendor, Menu, FoodListing, Order, Notification
from django.contrib.auth.hashers import make_password
import logging
from django.core.files.storage import default_storage # For constructing image URLs
from django.conf import settings # To access MEDIA_URL

logger = logging.getLogger(__name__)

# --- Serializer for Login Request ---
class VendorLoginSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(required=True, write_only=True, style={'input_type': 'password'})
    fcm_token = serializers.CharField(required=False, allow_blank=True, write_only=True) # Optional FCM token during login


# --- Serializer for Registration Request ---
class VendorRegistrationSerializer(serializers.ModelSerializer):
    # Ensure all required fields by model (unless blank=True) are present or handled
    email = serializers.EmailField(required=False, allow_blank=True, allow_null=True) # Made optional
    restaurant_name = serializers.CharField(required=True)
    address = serializers.CharField(required=True)
    # Optional fields during registration
    contact_number = serializers.CharField(required=False, allow_blank=True)
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True) # Made optional
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True) # Made optional
    pincode = serializers.CharField(required=False, allow_blank=True)
    cuisine_type = serializers.CharField(required=False, allow_blank=True)
    open_hours = serializers.CharField(required=False, allow_blank=True)
    # Images should be uploaded separately, send paths here if needed
    # uploaded_images = serializers.ListField(child=serializers.CharField(), required=False, help_text="List of image paths from upload endpoint")

    class Meta:
        model = Vendor
        fields = [
            'email', 'restaurant_name', 'address',
            'contact_number', 'latitude', 'longitude', 'pincode',
            'cuisine_type', 'open_hours'
        ]

    # REMOVED validate_email as model handles uniqueness and field is optional
    # def validate_email(self, value):
    #     if value and Vendor.objects.filter(email=value).exists():
    #         raise serializers.ValidationError("A vendor with this email already exists.")
    #     return value

    def create(self, validated_data):
        logger.debug(f"Vendor registration data (before hash): {validated_data}")
        # Hash password before creating vendor
        validated_data['password'] = make_password(validated_data.pop('password'))
        # vendor_id is generated automatically by model's save method
        vendor = Vendor.objects.create(**validated_data)
        logger.info(f"Vendor created: {vendor.vendor_id} - {vendor.email}")
        return vendor

# --- Serializer for Vendor Profile (Read/Update) ---
class VendorProfileSerializer(serializers.ModelSerializer):
    # Use this for GET and PUT/PATCH requests on the profile endpoint
    # Password update should ideally be a separate dedicated endpoint

    class Meta:
        model = Vendor
        fields = [
            'vendor_id', 'phone', 'restaurant_name', 'email',
            'address', 'contact_number', 'uploaded_images', 'open_hours',
            'is_active', 'rating', 'latitude', 'longitude', 'pincode',
            'cuisine_type', 'fcm_token', # Allow updating FCM token
            'created_at', 'updated_at'
        ]
        # Fields that shouldn't be changed via the profile update endpoint
        read_only_fields = ['vendor_id', 'email', 'rating', 'is_active', 'created_at', 'updated_at']

    # Optionally override update to handle specific logic like adding images
    def update(self, instance, validated_data):
        # Example: If 'new_image_path' is sent in request data after using upload endpoint
        new_image_path = validated_data.pop('new_image_path', None)
        if new_image_path:
            instance.add_image(new_image_path) # Use the helper method from model

        # If uploaded_images list is sent directly (e.g. to remove images)
        uploaded_images_data = validated_data.get('uploaded_images', None)
        if uploaded_images_data is not None:
            instance.uploaded_images = uploaded_images_data # Replace the list

        # Handle other fields normally
        return super().update(instance, validated_data)


# --- Menu Serializer ---
class MenuSerializer(serializers.ModelSerializer):
    class Meta:
        model = Menu
        fields = ['id', 'name', 'description', 'is_active'] # Basic fields for CRUD
        read_only_fields = ['id']

# --- FoodListing (Item) Serializer ---
class FoodListingSerializer(serializers.ModelSerializer):
    # Make menu read_only for input validation, rely on custom create method
    menu = serializers.PrimaryKeyRelatedField(
        read_only=True
    )
    # On read, include nested menu details if desired, or just ID/name
    menu_name = serializers.CharField(source='menu.name', read_only=True)
    vendor_id = serializers.CharField(source='menu.vendor.vendor_id', read_only=True)

    # Handle image URLs for reading
    image_urls = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = FoodListing
        fields = [
            'id', 'menu', 'menu_name', 'vendor_id', 'name', 'description', 'price',
            'is_available', 'category', 'images', 'image_urls', # include raw paths and constructed URLs
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'menu_name', 'vendor_id', 'image_urls', 'created_at', 'updated_at']
        # Make 'images' write_only if client only sends paths and reads URLs
        # write_only_fields = ['menu', 'images'] # Example if client POSTs/PUTs menu ID and image paths

    def get_image_urls(self, obj):
        """Construct full URLs for images stored as relative paths."""
        request = self.context.get('request')
        if not request:
            return [] # Cannot construct full URL without request context

        image_urls = []
        if isinstance(obj.images, list):
            for image_path in obj.images:
                if image_path: # Ensure path is not empty
                    try:
                        # Assumes image_path is relative to MEDIA_ROOT
                        full_url = request.build_absolute_uri(f"{settings.MEDIA_URL}{image_path}")
                        image_urls.append(full_url)
                    except Exception as e:
                        logger.error(f"Error building image URL for path {image_path}: {e}")
                        image_urls.append(None) # Append None or skip on error
        return image_urls

    def validate_menu(self, menu_instance):
        """Ensure the menu belongs to the authenticated vendor."""
        request = self.context.get('request')
        # Check if request.user and vendor_instance attribute exist (from custom auth backend)
        if request and hasattr(request, 'user') and hasattr(request.user, 'vendor_instance'):
            # Get the vendor instance attached by the custom authentication backend
            authenticated_vendor = request.user.vendor_instance
            if menu_instance.vendor != authenticated_vendor:
                raise serializers.ValidationError(f"Menu ID {menu_instance.id} does not belong to the authenticated vendor.")
        else:
            # This should ideally not be reached if view permissions are correct
            raise serializers.ValidationError("Could not verify vendor for menu validation.")
        return menu_instance

    def create(self, validated_data):
        """Create a new FoodListing, extracting menu from context."""
        menu = self.context.get('menu')
        if not menu:
            # This should ideally be caught by the view passing context
            raise serializers.ValidationError({"menu": "Serializer context is missing the menu object."}) 

        # Add the menu to the validated data before creating the object
        validated_data['menu'] = menu
        logger.info(f"Creating FoodListing via serializer create: {validated_data}")
        # Ensure image_path is handled correctly (assuming it's in validated_data)
        # If 'image_path' was used instead of 'images', map it here if needed.
        # Example: validated_data['images'] = [validated_data.pop('image_path')] if 'image_path' in validated_data else []
        
        # Handle 'image_path' from Flutter app if it exists
        image_path = validated_data.pop('image_path', None)
        if image_path:
            validated_data['images'] = [image_path] # Assuming model field is 'images' (JSON list)
            
        instance = FoodListing.objects.create(**validated_data)
        return instance

# --- Order Serializer (for Listing/Detail) ---
class OrderSerializer(serializers.ModelSerializer):
    # Optionally include nested serializers for vendor/customer if needed
    vendor_name = serializers.CharField(source='vendor.restaurant_name', read_only=True)
    # customer_name = serializers.CharField(source='customer.name', read_only=True) # Example if Customer model linked

    class Meta:
        model = Order
        fields = [
            'id', 'order_number', 'vendor', 'vendor_name', 'customer', # Include foreign keys if helpful
            'items', 'total_price', 'status', 'customer_name', 'customer_phone',
            'delivery_address', 'delivery_latitude', 'delivery_longitude',
            'special_instructions', 'created_at', 'updated_at'
        ]
        # Fields not typically updatable by the vendor via this serializer
        read_only_fields = [
            'id', 'order_number', 'vendor', 'vendor_name', 'customer',
            'total_price', 'created_at', 'updated_at', 'items',
            'customer_name', 'customer_phone', 'delivery_address', # Usually read-only for vendor
            'delivery_latitude', 'delivery_longitude', 'special_instructions'
        ]

# --- Serializer for Updating Order Status ---
class OrderStatusUpdateSerializer(serializers.Serializer):
    # Takes only the status field for update
    status = serializers.ChoiceField(choices=Order.ORDER_STATUS_CHOICES, required=True)

    def update(self, instance, validated_data):
        """Updates the order status and saves."""
        new_status = validated_data.get('status', instance.status)
        logger.info(f"Attempting to update order {instance.order_number} from {instance.status} to {new_status}")
        instance.status = new_status
        instance.save(update_fields=['status', 'updated_at'])
        # TODO: Add logic here to send notifications to customer/rider if needed
        logger.info(f"Order {instance.order_number} status successfully updated to {instance.status}")
        return instance


# --- Notification Serializer ---
class NotificationSerializer(serializers.ModelSerializer):
     class Meta:
        model = Notification
        fields = ['id', 'title', 'body', 'is_read', 'created_at']
        read_only_fields = ['id', 'created_at']


# --- Image Upload Serializer ---
class ImageUploadSerializer(serializers.Serializer):
    # Expects a file named 'image' in the multipart/form-data request
    image = serializers.ImageField(required=True)