"""
URL configuration for food_delivery_backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

# print("--- Loading food_delivery_backend/urls.py ---") # DEBUG

urlpatterns = [
    path('admin/', admin.site.urls),
    path('auth/', include('auth_app.urls')),
    path('customer/', include('customer_app.urls')),
    path('api/delivery/', include('delivery_auth.urls')),
]

# print(f"--- food_delivery_backend urlpatterns: {urlpatterns} ---") # DEBUG

# Serve general media files
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# Serve customer-specific media files
if settings.DEBUG:
    urlpatterns += static(settings.CUSTOMER_MEDIA_URL, document_root=settings.CUSTOMER_MEDIA_ROOT)
