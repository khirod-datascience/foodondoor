from django.core.cache import cache
from datetime import datetime
import random
import logging

logger = logging.getLogger(__name__)

class OTPManager:
    @staticmethod
    def generate_otp(phone):
        """Generate 6-digit OTP and store in cache"""
        try:
            # Rate limiting check
            rate_limit_key = f"rate_limit_{phone}"
            if cache.get(rate_limit_key):
                return None, "Please wait before requesting another OTP"
            
            # Generate OTP
            otp = random.randint(100000, 999999)
            
            # Store OTP with expiry (5 minutes) and attempt counter
            cache_key = f"otp_{phone}"
            cache.set(cache_key, {
                'otp': otp,
                'attempts': 0,
                'created_at': datetime.now().timestamp()
            }, timeout=300)  # 5 minutes
            
            # Set rate limit for 1 minute
            cache.set(rate_limit_key, True, timeout=60)
            
            return otp, None
            
        except Exception as e:
            logger.error(f"Error generating OTP: {str(e)}")
            return None, "Failed to generate OTP"

    @staticmethod
    def verify_otp(phone, submitted_otp):
        """Verify OTP with attempt limiting"""
        try:
            cache_key = f"otp_{phone}"
            otp_data = cache.get(cache_key)
            
            if not otp_data:
                return False, "OTP has expired"
            
            # Check attempts
            if otp_data['attempts'] >= 3:
                cache.delete(cache_key)
                return False, "Too many attempts. Please request new OTP"
                
            # Update attempts
            otp_data['attempts'] += 1
            cache.set(cache_key, otp_data, timeout=300)
            
            # Verify OTP
            return otp_data['otp'] == int(submitted_otp), "Invalid OTP"
            
        except Exception as e:
            logger.error(f"Error verifying OTP: {str(e)}")
            return False, "Error verifying OTP"