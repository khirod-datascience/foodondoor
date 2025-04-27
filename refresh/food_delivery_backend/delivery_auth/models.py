from django.db import models
import uuid
import random
from django.utils import timezone
from datetime import timedelta

class DeliveryUser(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone_number = models.CharField(max_length=15, unique=True, db_index=True)
    name = models.CharField(max_length=255, blank=True, null=True)
    email = models.EmailField(max_length=255, blank=True, null=True)
    profile_picture_url = models.URLField(max_length=500, blank=True, null=True)

    is_active = models.BooleanField(default=True) # Can be used to deactivate partners
    # is_verified is implicitly handled by whether `name` is set during registration
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # OTP fields
    otp = models.CharField(max_length=6, blank=True, null=True)
    otp_expiry_time = models.DateTimeField(blank=True, null=True)

    def __str__(self):
        return self.name if self.name else self.phone_number

    def generate_otp(self):
        """Generates a 6-digit OTP and sets its expiry time."""
        self.otp = str(random.randint(100000, 999999))
        # Ensure timezone awareness if USE_TZ=True
        self.otp_expiry_time = timezone.now() + timedelta(minutes=10) # OTP valid for 10 minutes
        self.save(update_fields=['otp', 'otp_expiry_time'])
        print(f"Generated OTP {self.otp} for {self.phone_number}") # For debugging
        # TODO: Implement actual OTP sending logic (e.g., SMS via Twilio, etc.)
        # Consider using a background task (Celery) for sending OTPs

    def is_otp_valid(self, provided_otp):
        """Checks if the provided OTP is correct and not expired."""
        if self.otp == provided_otp and self.otp_expiry_time and self.otp_expiry_time > timezone.now():
            # OTP is valid, clear it after verification
            self.otp = None
            self.otp_expiry_time = None
            self.save(update_fields=['otp', 'otp_expiry_time'])
            return True
        # Clear expired OTPs if checked
        elif self.otp_expiry_time and self.otp_expiry_time <= timezone.now():
            self.otp = None
            self.otp_expiry_time = None
            self.save(update_fields=['otp', 'otp_expiry_time'])
        return False

    # Indicates if the user profile is complete (i.e., registered)
    @property
    def is_registered(self):
        return bool(self.name)

    # Note: We are NOT adding password fields or manager methods like create_user,
    # create_superuser as we are not using Django's auth system directly.
    # Authentication relies solely on OTP verification and JWT issuance.
