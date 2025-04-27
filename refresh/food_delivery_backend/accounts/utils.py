# Centralized OTPManager for both customer and vendor flows
from datetime import datetime, timedelta
import random
from django.core.cache import cache

class OTPManager:
    OTP_EXPIRY_MINUTES = 5
    OTP_CACHE_PREFIX = 'otp_'

    @staticmethod
    def generate_otp(phone):
        try:
            otp = str(random.randint(100000, 999999))
            cache_key = OTPManager.OTP_CACHE_PREFIX + phone
            cache.set(cache_key, otp, timeout=OTPManager.OTP_EXPIRY_MINUTES * 60)
            return otp, None
        except Exception as e:
            return None, str(e)

    @staticmethod
    def verify_otp(phone, otp):
        cache_key = OTPManager.OTP_CACHE_PREFIX + phone
        cached_otp = cache.get(cache_key)
        if not cached_otp:
            return False, 'OTP expired or not found.'
        if str(otp) != str(cached_otp):
            return False, 'Invalid OTP.'
        cache.delete(cache_key)
        return True, 'OTP verified.'
