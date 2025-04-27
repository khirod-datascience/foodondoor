from django.contrib import admin
from . import models # Import the models module
import inspect # Import inspect module

# Dynamically register all models from the models module
for name, obj in inspect.getmembers(models):
    if inspect.isclass(obj) and issubclass(obj, models.models.Model) and obj._meta.app_label == 'customer_app':
        try:
            admin.site.register(obj)
        except admin.sites.AlreadyRegistered:
            # Ignore if model is already registered (e.g., manually registered above)
            pass

# You can still manually register specific models if you need custom admin classes
# For example:
# class CustomerAdmin(admin.ModelAdmin):
#     list_display = ('customer_id', 'full_name', 'phone', 'email', 'is_active')
#     search_fields = ('full_name', 'phone', 'email', 'customer_id')
#     list_filter = ('is_active',)
#
# admin.site.register(models.Customer, CustomerAdmin)