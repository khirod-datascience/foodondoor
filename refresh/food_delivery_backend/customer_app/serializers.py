from rest_framework import serializers
from auth_app.models import Vendor, FoodListing
from .models import *
from accounts.models import Account

# --- CustomerProfile Serializer ---
class CustomerProfileSerializer(serializers.ModelSerializer):
    user_id = serializers.CharField(source='user.id', read_only=True)
    phone = serializers.CharField()
    full_name = serializers.CharField()
    email = serializers.EmailField(source='user.email', allow_blank=True, allow_null=True, required=False)

    class Meta:
        model = CustomerProfile
        fields = ['user_id', 'phone', 'full_name', 'email']

class BannerSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()
    title = serializers.SerializerMethodField()
    created_at = serializers.SerializerMethodField()

    def get_image(self, obj):
        request = self.context.get('request', None)
        if obj.image:
            url = obj.image.url
            if request is not None:
                return request.build_absolute_uri(url)
            return url
        return "https://dummyimage.com/600x200/cccccc/fff.jpg&text=No+Banner"

    def get_title(self, obj):
        return obj.title or "Untitled Banner"

    def get_created_at(self, obj):
        return obj.created_at.isoformat() if obj.created_at else "1970-01-01T00:00:00Z"

    class Meta:
        model = Banner
        fields = '__all__'

class FoodCategorySerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    name = serializers.SerializerMethodField()

    def get_image_url(self, obj):
        request = self.context.get('request', None)
        if obj.image_url:
            url = obj.image_url.url
            if request is not None:
                return request.build_absolute_uri(url)
            return url
        return "https://dummyimage.com/200x200/cccccc/fff.jpg&text=No+Image"

    def get_name(self, obj):
        return obj.name or "Unnamed Category"

    class Meta:
        model = FoodCategory
        fields = '__all__'

class VendorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vendor
        fields = '__all__'

class FoodListingSerializer(serializers.ModelSerializer):
    name = serializers.SerializerMethodField()
    price = serializers.SerializerMethodField()
    description = serializers.SerializerMethodField()
    category = serializers.SerializerMethodField()
    images = serializers.SerializerMethodField()
    vendor = serializers.SerializerMethodField()

    def get_name(self, obj):
        return obj.name or "Unnamed Food"

    def get_price(self, obj):
        return str(obj.price) if obj.price is not None else "0.00"

    def get_description(self, obj):
        return obj.description or "No description available."

    def get_category(self, obj):
        try:
            return obj.category.name if obj.category and obj.category.name else "Unknown Category"
        except Exception:
            return "Unknown Category"

    def get_images(self, obj):
        request = self.context.get('request', None)
        try:
            if hasattr(obj, 'images') and obj.images:
                if hasattr(obj.images, 'all'):
                    images = [request.build_absolute_uri(img.image.url) if request is not None and hasattr(img.image, 'url') else (img.image.url if hasattr(img.image, 'url') else "") for img in obj.images.all()]
                    return images if images else ["https://dummyimage.com/200x200/cccccc/fff.jpg&text=No+Image"]
                elif hasattr(obj.images, 'url'):
                    url = obj.images.url
                    if request is not None:
                        return [request.build_absolute_uri(url)]
                    return [url]
            return ["https://dummyimage.com/200x200/cccccc/fff.jpg&text=No+Image"]
        except Exception:
            return ["https://dummyimage.com/200x200/cccccc/fff.jpg&text=No+Image"]

    def get_vendor(self, obj):
        try:
            return obj.vendor.vendor_id if hasattr(obj.vendor, 'vendor_id') else "Unknown Vendor"
        except Exception:
            return "Unknown Vendor"

    class Meta:
        model = FoodListing
        fields = ('id', 'name', 'price', 'description', 'is_available', 'category', 'images', 'vendor')
        depth = 1 # Optionally include vendor details directly

class CartItemSerializer(serializers.ModelSerializer):
    # Use FoodListingSerializer for the 'food' field
    food = FoodListingSerializer(read_only=True)
    # Add food_id for writing operations if needed elsewhere, but CartAddView handles it
    food_id = serializers.PrimaryKeyRelatedField(
        queryset=FoodListing.objects.all(), source='food', write_only=True
    )

    class Meta:
        model = Cart
        # Include 'id' field
        fields = ('id', 'customer', 'food_id', 'food', 'quantity', 'created_at')
        read_only_fields = ('id', 'customer', 'food', 'created_at') # food_id is write_only

class OrderItemSerializer(serializers.ModelSerializer):
    food_id = serializers.PrimaryKeyRelatedField(queryset=FoodListing.objects.all(), write_only=True, source='food') # Link food_id to FoodListing
    food = FoodListingSerializer(read_only=True)

    class Meta:
        model = OrderItem
        fields = ('id', 'food_id', 'food', 'quantity', 'price')
        read_only_fields = ('id', 'price', 'food')

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, write_only=True)
    order_items = OrderItemSerializer(many=True, read_only=True, source='order_items') # Use related_name
    customer = CustomerProfileSerializer(read_only=True)
    vendor_details = VendorSerializer(source='vendor', read_only=True)

    class Meta:
        model = Order
        fields = (
            'id', 'order_number', 'customer', 'vendor_details',
            'total_amount', 'status', 'delivery_address',
            'created_at', 'payment_mode', 'payment_status', 'payment_id', 'delivery_fee', # Added delivery_fee
            'items', 'order_items'
        )
        read_only_fields = ('id', 'order_number', 'created_at',
                           'customer', 'vendor_details', 'order_items') # Allow more fields to be writable potentially

class AddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = Address
        fields = '__all__'
        read_only_fields = ('customer',)