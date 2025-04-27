from django.db import models
from django.utils import timezone
import logging
import random
# Remove password hasher imports if no longer needed
# from django.contrib.auth.hashers import make_password, check_password

logger = logging.getLogger(__name__)

# Removed OTPStore and User models as they are replaced by Vendor with password

# --- Remove Vendor Manager ---
# class VendorManager(BaseUserManager): ...

# --- Reverted Vendor Model ---
class Vendor(models.Model):
    vendor_id = models.CharField(max_length=20, unique=True, blank=True)
    phone = models.CharField(max_length=15, null=True, blank=True)
    restaurant_name = models.CharField(max_length=255)
    email = models.EmailField( null=True, blank=True) # Keep unique for contact, but allow null/blank
    address = models.TextField()
    contact_number = models.CharField(max_length=15, unique=True)
    uploaded_images = models.JSONField(default=list, blank=True)
    open_hours = models.CharField(max_length=100, blank=True, null=True)
    rating = models.FloatField(default=0.0)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    pincode = models.CharField(max_length=10, null=True, blank=True)
    cuisine_type = models.CharField(max_length=100, null=True, blank=True)
    fcm_token = models.CharField(max_length=255, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)

    # Remove Django auth fields: is_staff, date_joined, groups, user_permissions
    # Remove USERNAME_FIELD, REQUIRED_FIELDS, objects = VendorManager()

    # Keep custom save logic for vendor_id generation
    def save(self, *args, **kwargs):
        if not self.vendor_id:
            timestamp_part = timezone.now().strftime('%Y%m%d')
            count_part = str(Vendor.objects.count() + 1).zfill(4) # Pad to 4 digits
            self.vendor_id = f'V-{timestamp_part}-{count_part}'
        # No password setting needed here anymore
        super().save(*args, **kwargs)

    def add_image(self, image_url):
        if not isinstance(self.uploaded_images, list): self.uploaded_images = []
        self.uploaded_images.append(image_url)

    def __str__(self):
        return f"{self.restaurant_name} ({self.phone})"

class Menu(models.Model):
    vendor = models.ForeignKey(Vendor, related_name='menus', on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True) # Allow activating/deactivating menus
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name'] # Default ordering
        unique_together = ('vendor', 'name') # Prevent duplicate menu names for the same vendor

    def __str__(self):
        return f"{self.name} ({self.vendor.restaurant_name})"

class FoodListing(models.Model):
    menu = models.ForeignKey(Menu, related_name='items', on_delete=models.CASCADE, null=True)
    vendor = models.ForeignKey(Vendor, related_name='food_listings', on_delete=models.CASCADE, null=True)
    name = models.CharField(max_length=255)
    description = models.TextField(null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_available = models.BooleanField(default=True)
    category = models.CharField(max_length=100, null=True, blank=True, help_text="e.g., Appetizer, Main Course, Beverage")
    images = models.JSONField(default=list, blank=True, help_text="List of image paths/URLs from upload endpoint")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        unique_together = ('menu', 'name') # Prevent duplicate item names within the same menu

    def save(self, *args, **kwargs):
        if self.menu and not self.vendor_id: self.vendor = self.menu.vendor
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} (Menu: {self.menu.name})"

from accounts.models import CustomerProfile

class Order(models.Model):
    ORDER_STATUS_CHOICES = [
        ('Pending', 'Pending'),           # Initial status when placed by customer
        ('Accepted', 'Accepted'),         # Vendor confirms they will prepare
        ('Preparing', 'Preparing'),       # Vendor starts preparing
        ('ReadyForPickup', 'Ready For Pickup'), # Vendor marks as ready for rider
        ('PickedUp', 'Picked Up'),         # Rider confirms pickup
        ('Delivered', 'Delivered'),       # Rider confirms delivery
        ('Cancelled', 'Cancelled'),       # Order cancelled by customer or vendor
    ]

    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name="orders")
    customer = models.ForeignKey('accounts.CustomerProfile', on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    order_number = models.CharField(max_length=20, unique=True, blank=True) # Auto-generated
    items = models.JSONField(help_text="List of items: [{'item_id': id, 'name': name, 'quantity': qty, 'price': price}]")
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=50, choices=ORDER_STATUS_CHOICES, default='Pending')
    customer_name = models.CharField(max_length=150, blank=True)
    customer_phone = models.CharField(max_length=15, blank=True)
    delivery_address = models.TextField(blank=True)
    delivery_latitude = models.FloatField(null=True, blank=True)
    delivery_longitude = models.FloatField(null=True, blank=True)
    special_instructions = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        is_new = self._state.adding # Check if this is a new instance
        if not self.order_number:
            # Generate order number just before the first save
            timestamp = timezone.now().strftime('%Y%m%d%H%M%S')
            # To ensure uniqueness even with rapid orders, include part of vendor_id or use PK after initial save
            # We need the PK for guaranteed uniqueness if saving first
            pass # Generate after first save if needed

        super().save(*args, **kwargs) # Call the original save method

        if is_new and not self.order_number:
            # Now self.id should be available
            timestamp = timezone.now().strftime('%Y%m%d%H%M%S')
            self.order_number = f'ORD-{timestamp}-{self.id}'
            # Save again only to update the order_number field
            super().save(update_fields=['order_number'])

    def __str__(self):
        return f"Order {self.order_number} for {self.vendor.restaurant_name}"

class Notification(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name="notifications")
    title = models.CharField(max_length=255)
    body = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Notification for {self.vendor.restaurant_name}: {self.title}"
