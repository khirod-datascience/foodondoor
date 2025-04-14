from django.db import models
import random
from auth_app.models import Vendor, FoodListing  # Import Vendor and FoodListing models from auth_app
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin # Import necessary classes

# --- Custom User Manager ---
class CustomerManager(BaseUserManager):
    def create_user(self, phone, email, full_name, password=None, **extra_fields):
        """
        Creates and saves a User with the given phone, email, name and password.
        """
        if not phone:
            raise ValueError('Users must have a phone number')
        if not email:
            raise ValueError('Users must have an email address')
        if not full_name:
             raise ValueError('Users must have a full name')

        email = self.normalize_email(email)
        # Generate customer_id here or let the model's save handle it
        customer_id = extra_fields.pop('customer_id', None)
        if not customer_id:
             while True:
                customer_id = f"C{random.randint(10000, 99999)}"
                if not self.model.objects.filter(customer_id=customer_id).exists():
                    break

        user = self.model(
            customer_id=customer_id,
            phone=phone,
            email=email,
            full_name=full_name,
            **extra_fields
        )

        # Use set_password to hash the password
        # If you don't intend to use passwords (only OTP), you can skip this
        # or set an unusable password. For createsuperuser, a password is required.
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password() # Good practice if only using OTP

        user.save(using=self._db)
        return user

    def create_superuser(self, phone, email, full_name, password=None, **extra_fields):
        """
        Creates and saves a superuser with the given phone, email, name and password.
        """
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True) # Superusers should be active

        if extra_fields.get('is_staff') is not True:
            raise ValueError('Superuser must have is_staff=True.')
        if extra_fields.get('is_superuser') is not True:
            raise ValueError('Superuser must have is_superuser=True.')

        # Ensure password is provided for superuser
        if not password:
             raise ValueError('Superuser must have a password.')

        # Generate customer_id (can reuse logic from create_user or simplify)
        customer_id = extra_fields.pop('customer_id', None)
        if not customer_id:
             customer_id = f"C{random.randint(10000, 99999)}" # Simplified for superuser

        # Reuse create_user logic
        return self.create_user(
            phone=phone,
            email=email,
            full_name=full_name,
            password=password,
            customer_id=customer_id, # Pass generated ID
            **extra_fields
        )
# --- End Custom User Manager ---


# Modify Customer model
class Customer(AbstractBaseUser, PermissionsMixin): # Inherit from AbstractBaseUser and PermissionsMixin
    customer_id = models.CharField(max_length=10, unique=True, primary_key=True) # Make customer_id primary key
    phone = models.CharField(max_length=15, unique=True)
    full_name = models.CharField(max_length=100)
    email = models.EmailField(unique=True)
    updated_at = models.DateTimeField(auto_now=True)
    default_address = models.ForeignKey('Address', on_delete=models.SET_NULL, null=True, blank=True, related_name='default_for_customer')

    # Fields required by Django auth system
    is_staff = models.BooleanField(default=False) # Required for admin access
    is_active = models.BooleanField(default=True) # Designates whether this user should be treated as active
    date_joined = models.DateTimeField(auto_now_add=True) # Optional but standard

    # --- Assign the custom manager ---
    objects = CustomerManager()

    # --- Define required fields for Django auth ---
    USERNAME_FIELD = 'phone' # Field used for login
    REQUIRED_FIELDS = ['full_name', 'email'] # Fields prompted for when creating superuser (besides USERNAME_FIELD and password)
    # --- End required fields ---

    def __str__(self):
        return f"{self.full_name} ({self.phone})"

class Address(models.Model):
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='addresses')
    address_line_1 = models.CharField(max_length=255)
    address_line_2 = models.CharField(max_length=255, null=True, blank=True)
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=10)
    is_default = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        # Ensure only one default address per customer
        if self.is_default:
            Address.objects.filter(customer=self.customer).update(is_default=False)
        super().save(*args, **kwargs)

class Banner(models.Model):
    image = models.ImageField(upload_to='banners/')
    title = models.CharField(max_length=100)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

class Category(models.Model):
    name = models.CharField(max_length=50)
    image_url = models.ImageField(upload_to='categories/')
    is_active = models.BooleanField(default=True)

class FoodCategory(models.Model):
    name = models.CharField(max_length=100)
    image_url = models.ImageField(upload_to='food_categories/')
    is_active = models.BooleanField(default=True)

class Restaurant(models.Model):
    name = models.CharField(max_length=100)
    image = models.ImageField(upload_to='restaurants/')
    cuisine_type = models.CharField(max_length=50)
    latitude = models.FloatField()
    longitude = models.FloatField()
    rating = models.FloatField(default=0)
    is_active = models.BooleanField(default=True)

class Food(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE)  # Reference Vendor instead of Restaurant
    category = models.ForeignKey(FoodCategory, on_delete=models.SET_NULL, null=True)
    name = models.CharField(max_length=100)
    description = models.TextField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    image = models.ImageField(upload_to='foods/')
    is_available = models.BooleanField(default=True)

class Cart(models.Model):
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE)
    food = models.ForeignKey(Food, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

class Order(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('preparing', 'Preparing'),
        ('out_for_delivery', 'Out for Delivery'),
        ('delivered', 'Delivered'),
        ('cancelled', 'Cancelled'),
    ]

    PAYMENT_MODE_CHOICES = [
        ('COD', 'Cash on Delivery'),
        ('Online', 'Online Payment'),
    ]

    customer = models.ForeignKey(Customer, on_delete=models.CASCADE)
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE)  # Reference Vendor instead of Restaurant
    order_number = models.CharField(max_length=20, unique=True)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    delivery_address = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    current_location = models.CharField(max_length=255, null=True, blank=True)
    delivery_partner = models.JSONField(null=True, blank=True)
    estimated_delivery = models.DateTimeField(null=True, blank=True)
    payment_id = models.CharField(max_length=100, null=True, blank=True) # For online payments
    payment_mode = models.CharField(max_length=10, choices=PAYMENT_MODE_CHOICES, default='COD') # Added payment_mode
    payment_status = models.CharField(max_length=20, default='pending') # Existing field
    delivery_fee = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True) # Add delivery fee

    def save(self, *args, **kwargs):
        if not self.order_number:
            self.order_number = f"ORD{random.randint(10000, 99999)}"
        super().save(*args, **kwargs)

class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE)
    food = models.ForeignKey(FoodListing, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
