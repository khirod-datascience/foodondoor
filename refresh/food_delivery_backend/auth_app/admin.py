from django.contrib import admin

# Register your models here.
from .models import *

admin.site.register(Vendor)
admin.site.register(Notification)
admin.site.register(FoodListing)
admin.site.register(Order)
# admin.site.register(OTPStore)