from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.db import models

class AccountManager(BaseUserManager):
    def create_user(self, email, password=None, user_type=None, **extra_fields):
        if not email:
            raise ValueError('Users must have an email address')
        email = self.normalize_email(email)
        user = self.model(email=email, user_type=user_type, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        user_type = extra_fields.pop('user_type', 'admin')
        return self.create_user(email, password, user_type=user_type, **extra_fields)

class Account(AbstractBaseUser, PermissionsMixin):
    USER_TYPE_CHOICES = (
        ('customer', 'Customer'),
        ('vendor', 'Vendor'),
        ('delivery', 'Delivery'),
        ('admin', 'Admin'),
    )
    email = models.EmailField(unique=True)
    user_type = models.CharField(max_length=10, choices=USER_TYPE_CHOICES)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['user_type']

    objects = AccountManager()

    def __str__(self):
        return f"{self.email} ({self.user_type})"

# Profiles
class CustomerProfile(models.Model):
    user = models.OneToOneField(Account, on_delete=models.CASCADE, related_name='customer_profile')
    phone = models.CharField(max_length=15, unique=True)
    full_name = models.CharField(max_length=100)

class VendorProfile(models.Model):
    user = models.OneToOneField(Account, on_delete=models.CASCADE, related_name='vendor_profile')
    restaurant_name = models.CharField(max_length=100)
    contact_number = models.CharField(max_length=15)
    # add other vendor-specific fields

class DeliveryProfile(models.Model):
    user = models.OneToOneField(Account, on_delete=models.CASCADE, related_name='delivery_profile')
    phone = models.CharField(max_length=15, unique=True)
    # add other delivery-specific fields
