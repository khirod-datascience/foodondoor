from rest_framework import serializers
from .models import DeliveryUser
from django.core.validators import RegexValidator
from customer_app.models import Order # Assuming Order model is here

# Simple validator for basic phone number format (adjust as needed)
# Allows optional '+' and requires 9 to 15 digits
phone_regex = RegexValidator(
    regex=r'^\+?\d{9,15}$',
    message="Phone number must be entered in a valid format (e.g., +919876543210 or 9876543210). Up to 15 digits allowed."
)

class PhoneSerializer(serializers.Serializer):
    phone_number = serializers.CharField(validators=[phone_regex], max_length=17)

class OTPSerializer(serializers.Serializer):
    otp = serializers.CharField(max_length=6, min_length=6,
                                error_messages={
                                    'max_length': 'OTP must be 6 digits.',
                                    'min_length': 'OTP must be 6 digits.'
                                })

class VerifyOTPSerializer(PhoneSerializer, OTPSerializer):
    # Inherits phone_number and otp fields
    pass

class DeliveryUserSerializer(serializers.ModelSerializer):
    """Serializer for displaying DeliveryUser details"""
    class Meta:
        model = DeliveryUser
        fields = ['id', 'phone_number', 'name', 'email', 'profile_picture_url', 'is_active', 'is_registered', 'created_at']
        read_only_fields = ['id', 'is_active', 'is_registered', 'created_at']

class RegisterSerializer(serializers.ModelSerializer):
    """Serializer for registering/completing the DeliveryUser profile"""
    # phone_number will be added implicitly from the instance in the view
    class Meta:
        model = DeliveryUser
        fields = ['name', 'email'] # Only these are expected from the request body
        extra_kwargs = {
            'name': {'required': True, 'allow_blank': False}
        }

    def validate_name(self, value):
        if not value or len(value.strip()) == 0:
            raise serializers.ValidationError("Name cannot be empty.")
        return value.strip()

# No specific token serializers needed here as simplejwt handles token creation directly.

# Add a basic OrderSerializer (adjust fields as needed)
class OrderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Order
        fields = '__all__' # Or list specific fields needed by the app
