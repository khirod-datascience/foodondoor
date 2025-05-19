from django.db import models
from django.db import models
from django.core.cache import cache
from datetime import timedelta

class OTPStore(models.Model):
    phone = models.CharField(max_length=15)
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'otp_store'
        
class User(models.Model):
    phone = models.CharField(max_length=15, unique=True)
    name = models.CharField(max_length=100, blank=True, null=True)
    email = models.EmailField(blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    # Add other fields as needed

    def __str__(self):
        return self.phone
    

class Vendor(models.Model):
    vendor_id = models.CharField(max_length=10, unique=True) 
    phone = models.CharField(max_length=15, unique=True)
    restaurant_name = models.CharField(max_length=255)
    email = models.EmailField(unique=True)
    address = models.TextField()
    contact_number = models.CharField(max_length=15)
    uploaded_images = models.JSONField(default=list, blank=True)  # Store image paths or URLs as a list
    open_hours = models.CharField(max_length=15)
    is_active = models.BooleanField(default=True)
    rating = models.FloatField(default=0.0)  # Add rating field
    latitude = models.FloatField(null=True, blank=True)  # Added latitude
    longitude = models.FloatField(null=True, blank=True)  # Added longitude
    pincode = models.CharField(max_length=10, null=True, blank=True)  # Added pincode
    cuisine_type = models.CharField(max_length=100, null=True, blank=True)  # Added cuisine_type
    fcm_token = models.CharField(max_length=255, null=True, blank=True)  # Added FCM token for push notifications

    def save(self, *args, **kwargs):
        # Only generate vendor_id if not provided
        if not self.vendor_id:
            last_vendor = Vendor.objects.all().order_by('-vendor_id').first()
            if last_vendor and last_vendor.vendor_id:
                try:
                    last_num = int(last_vendor.vendor_id[1:])
                    self.vendor_id = f'V{str(last_num + 1).zfill(3)}'
                except ValueError:
                    self.vendor_id = f'V{str(Vendor.objects.count() + 1).zfill(3)}'
            else:
                self.vendor_id = 'V001'
        super().save(*args, **kwargs)

    def add_image(self, image_url):
        """Add image URL to uploaded_images list"""
        if not isinstance(self.uploaded_images, list):
            self.uploaded_images = []
        self.uploaded_images.append(image_url)
        self.save()

    def __str__(self):
        return self.restaurant_name

class Notification(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE)
    title = models.CharField(max_length=255)
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.vendor.restaurant_name}"

class FoodListing(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_available = models.BooleanField(default=True)  # Added is_available
    category = models.CharField(max_length=100, null=True, blank=True)  # Added category
    images = models.JSONField(default=list, blank=True, help_text="List of image paths/URLs")
    # image = models.ImageField(max_length=500, null=True, blank=True)  # Added image
    vendor = models.ForeignKey('Vendor', on_delete=models.CASCADE)

    def __str__(self):
        return self.name

class Order(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name="orders")
    order_number = models.CharField(max_length=20, unique=True)
    items = models.JSONField()  # List of items with quantity and price
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=50, choices=[
        ('Pending', 'Pending'),
        ('Accepted', 'Accepted'),
        ('Preparing', 'Preparing'),
        ('Ready for Pickup', 'Ready for Pickup'),
        ('Out for Delivery', 'Out for Delivery'),
        ('Delivered', 'Delivered'),
        ('Cancelled', 'Cancelled'),
        ('Fulfilled', 'Fulfilled'),
        ('Paid', 'Paid'),
    ], default='Pending')
    delivery_lat = models.FloatField(null=True, blank=True, help_text="Current latitude of delivery agent")
    delivery_lng = models.FloatField(null=True, blank=True, help_text="Current longitude of delivery agent")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Order {self.order_number} for {self.vendor.restaurant_name}"

