from rest_framework import serializers
from auth_app.models import Vendor, FoodListing
from .models import *

class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = '__all__'

class BannerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Banner
        fields = '__all__'

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'

class FoodCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodCategory
        fields = '__all__'

class RestaurantSerializer(serializers.ModelSerializer):
    class Meta:
        model = Restaurant
        fields = '__all__'

class VendorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vendor
        fields = '__all__'

class FoodSerializer(serializers.ModelSerializer):
    restaurant_name = serializers.CharField(source='restaurant.name', read_only=True)
    vendor_details = VendorSerializer(source='vendor', read_only=True)  # Include vendor details

    class Meta:
        model = Food
        fields = '__all__'

class CartItemSerializer(serializers.ModelSerializer):
    food_details = FoodSerializer(source='food', read_only=True)
    
    class Meta:
        model = Cart
        fields = '__all__'

class FoodListingSerializer(serializers.ModelSerializer):
    """Serializer for FoodListing from auth_app"""
    class Meta:
        model = FoodListing
        fields = ('id', 'name', 'price', 'description', 'is_available', 'category', 'images')

class OrderItemSerializer(serializers.ModelSerializer):
    food_id = serializers.IntegerField(write_only=True)
    food = FoodListingSerializer(read_only=True)

    class Meta:
        model = OrderItem
        fields = ('id', 'food_id', 'food', 'quantity', 'price')
        read_only_fields = ('id', 'price', 'food')

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, write_only=True)
    order_items = OrderItemSerializer(many=True, read_only=True, source='orderitem_set')
    customer_id = serializers.CharField(write_only=True)
    vendor_id = serializers.CharField(write_only=True)
    customer = CustomerSerializer(read_only=True)
    vendor_details = VendorSerializer(source='vendor', read_only=True)

    class Meta:
        model = Order
        fields = (
            'id', 'order_number', 'customer_id', 'customer', 'vendor_id', 'vendor_details',
            'total_amount', 'status', 'delivery_address',
            'created_at', 'payment_mode', 'payment_status', 'payment_id',
            'items', 'order_items'
        )
        read_only_fields = ('id', 'order_number', 'total_amount', 'status', 'created_at', 
                           'payment_status', 'payment_id', 'customer', 'order_items')