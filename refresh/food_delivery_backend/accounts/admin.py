from django.contrib import admin

# # Register your models here.
# from django.contrib import admin
# from . import models # Import the models module
# import inspect # Import inspect module

# # Dynamically register all models from the models module
# for name, obj in inspect.getmembers(models):
#     if inspect.isclass(obj) and issubclass(obj, models.models.Model) and obj._meta.app_label == 'customer_app':
#         try:
#             admin.site.register(obj)
#         except admin.sites.AlreadyRegistered:
#             # Ignore if model is already registered (e.g., manually registered above)
#             pass

from .models import Account, CustomerProfile

admin.site.register(Account)
admin.site.register(CustomerProfile)
