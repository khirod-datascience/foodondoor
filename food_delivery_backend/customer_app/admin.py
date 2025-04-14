from django.contrib import admin

# Register your models here.
from .models import *

admin.site.register(Customer)
admin.site.register(Banner)
admin.site.register(Category)
admin.site.register(FoodCategory)
admin.site.register(Restaurant)
admin.site.register(Food)
admin.site.register(Cart)
admin.site.register(Order)
admin.site.register(OrderItem)
admin.site.register(Address)