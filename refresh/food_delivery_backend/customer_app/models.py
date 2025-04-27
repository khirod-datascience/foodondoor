from django.db import models
import random
from auth_app.models import Vendor, FoodListing  # Import Vendor and FoodListing models from auth_app
from accounts.models import Account, CustomerProfile

# --- Address Model ---
class Address(models.Model):
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE, related_name='addresses')
    address_line_1 = models.CharField(max_length=255)
    address_line_2 = models.CharField(max_length=255, null=True, blank=True)
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=10)
    is_default = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        if self.is_default:
            Address.objects.filter(customer=self.customer).update(is_default=False)
        super().save(*args, **kwargs)

class Banner(models.Model):
    image = models.ImageField(upload_to='banners/')
    title = models.CharField(max_length=100)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

class FoodCategory(models.Model):
    name = models.CharField(max_length=100)
    image_url = models.ImageField(upload_to='food_categories/')
    is_active = models.BooleanField(default=True)

class Cart(models.Model):
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE, related_name='cart_items')
    food = models.ForeignKey(FoodListing, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('customer', 'food')

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

    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE)
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE)
    order_number = models.CharField(max_length=20, unique=True)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    delivery_address = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    current_location = models.CharField(max_length=255, null=True, blank=True)
    delivery_partner = models.JSONField(null=True, blank=True)
    estimated_delivery = models.DateTimeField(null=True, blank=True)
    payment_id = models.CharField(max_length=100, null=True, blank=True)
    payment_mode = models.CharField(max_length=10, choices=PAYMENT_MODE_CHOICES, default='COD')
    payment_status = models.CharField(max_length=20, default='pending')
    delivery_fee = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)

    def save(self, *args, **kwargs):
        if not self.order_number:
            self.order_number = f"ORD{random.randint(10000, 99999)}"
        super().save(*args, **kwargs)

class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='order_items')
    food = models.ForeignKey(FoodListing, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)

    def __str__(self):
       return f"{self.quantity} x {self.food.name} for Order {self.order.order_number}"
