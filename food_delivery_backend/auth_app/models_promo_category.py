from django.db import models
from .models import Vendor

class Promotion(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name="promotions")
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    start_date = models.DateField(blank=True, null=True)
    end_date = models.DateField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} ({self.vendor.restaurant_name})"

class VendorCategory(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name="categories")
    name = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.vendor.restaurant_name})"
