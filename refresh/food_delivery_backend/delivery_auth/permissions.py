from rest_framework import permissions
from .models import DeliveryUser

class IsAuthenticatedDeliveryUser(permissions.BasePermission):
    """
    Allows access only to authenticated requests where request.user
    is an instance of DeliveryUser.
    """

    def has_permission(self, request, view):
        # Check if the user attached by the authentication class
        # is an instance of DeliveryUser.
        # Our DeliveryUserJWTAuthentication ensures request.user is set
        # if authentication is successful.
        return isinstance(request.user, DeliveryUser) 