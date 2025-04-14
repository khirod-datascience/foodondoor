
from rest_framework import serializers
from .models import Vendor, Notification, FoodListing, Order

class VendorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vendor
        fields = '__all__'
        read_only_fields = ['vendor_id']  # Make vendor_id read-only as it's auto-generated

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = '__all__'

class FoodListingSerializer(serializers.ModelSerializer):
    image_urls = serializers.SerializerMethodField() # Add this field
    class Meta:
        model = FoodListing
        fields = '__all__'
        extra_kwargs = {
            'images': {'write_only': True}
        }
    def get_image_urls(self, obj):
        request = self.context.get('request')
        image_paths = obj.images # Get the list of paths from the model instance

        if not isinstance(image_paths, list): # Basic validation
             return []

        if request:
            # Build absolute URLs for each path in the list
        #     return [request.build_absolute_uri(path) for path in image_paths if path]
        # else:
            # Return the paths as-is if no request context is available
            return [path for path in image_paths if path]

    # # Optional: Add validation for the incoming 'images' list if needed
    # def validate_images(self, value):
    #     if not isinstance(value, list):
    #         raise serializers.ValidationError("Images must be provided as a list.")
    #     # You could add more validation here, e.g., check if items are strings
    #     return value
    
class OrderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Order
        fields = '__all__'