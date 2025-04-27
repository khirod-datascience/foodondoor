import random
import logging
from django.core.cache import cache
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from customer_app.models import CustomerProfile # Use the new CustomerProfile
from auth_app.models import Vendor # Import your custom Vendor

logger = logging.getLogger(__name__)

class OTPManager:
    @staticmethod
    def generate_otp(phone):
        try:
            # Check rate limiting
            rate_limit_key = f"rate_limit_{phone}"
            if cache.get(rate_limit_key):
                return None, "Please wait before requesting another OTP"
            
            # Generate 6-digit OTP
            otp = str(random.randint(100000, 999999))
            
            # Store OTP in cache
            otp_key = f"otp_{phone}"
            cache.set(otp_key, {
                'otp': otp,
                'attempts': 0
            }, timeout=300)  # 5 minutes expiry
            
            # Set rate limit
            cache.set(rate_limit_key, True, timeout=60)  # 1 minute rate limit
            
            return otp, None
            
        except Exception as e:
            logger.error(f"Error generating OTP: {e}")
            return None, str(e)

    @staticmethod
    def verify_otp(phone, submitted_otp):
        try:
            otp_key = f"otp_{phone}"
            otp_data = cache.get(otp_key)
            
            if not otp_data:
                return False, "OTP has expired"
            
            if otp_data['attempts'] >= 3:
                cache.delete(otp_key)
                return False, "Too many attempts. Please request new OTP"
            
            # Update attempts
            otp_data['attempts'] += 1
            cache.set(otp_key, otp_data, timeout=300)
            
            # Verify OTP
            return str(otp_data['otp']) == str(submitted_otp), "Invalid OTP"
            
        except Exception as e:
            logger.error(f"Error verifying OTP: {e}")
            return False, str(e)

def custom_exception_handler(exc, context):
    response = exception_handler(exc, context)
    
    if response is None:
        return Response({
            'error': str(exc),
            'detail': 'An unexpected error occurred'
        }, status=500)
        
    return response

def get_jwt_tokens_for_customer(customer: CustomerProfile) -> dict:
    """Manually generates JWT tokens for a Customer instance."""
    if not isinstance(customer, CustomerProfile):
        raise TypeError("Must provide a Customer instance")

    refresh = RefreshToken()
    # Add custom claims - identify the user by phone or user_id
    refresh['phone'] = customer.phone
    refresh['user_id'] = customer.user.id
    # Add a claim to distinguish user type if needed (optional)
    refresh['user_type'] = 'customer'

    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }

def get_jwt_tokens_for_vendor(vendor: Vendor) -> dict:
    """Manually generates JWT tokens for a Vendor instance."""
    if not isinstance(vendor, Vendor):
         raise TypeError("Must provide a Vendor instance")

    refresh = RefreshToken()
    refresh['phone'] = vendor.phone
    refresh['vendor_id'] = vendor.vendor_id # Or vendor.id if preferred
    refresh['user_type'] = 'vendor'

    return {
        'refresh': str(refresh),
        'access': str(refresh.access_token),
    }