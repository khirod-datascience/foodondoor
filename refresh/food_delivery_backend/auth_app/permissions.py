from rest_framework import permissions
from .models import Vendor, Menu, FoodListing, Order # Import relevant models
import logging

logger = logging.getLogger(__name__)

class IsVendorUser(permissions.BasePermission):
    """
    Grants permission if request.user is authenticated and has a 'vendor_instance'.
    Relies on VendorJWTAuthentication populating request.user correctly.
    """
    message = "User is not associated with a vendor account."

    def has_permission(self, request, view):
        has_instance = request.user and request.user.is_authenticated and hasattr(request.user, 'vendor_instance')
        # logger.debug(f"[Permission Check - IsVendorUser - has_permission] User: {request.user}, IsAuthenticated: {request.user.is_authenticated if request.user else 'N/A'}, Has Vendor Instance: {has_instance}")
        return has_instance

class IsVendorOwnerOrReadOnly(permissions.BasePermission):
    """
    Allows read access to any authenticated VendorUser.
    Allows write access only if the VendorUser owns the object.
    Relies on VendorJWTAuthentication.
    """
    message = "You do not have permission to modify this resource."

    def has_permission(self, request, view):
        # Check if the user is an authenticated vendor first
        is_vendor = request.user and request.user.is_authenticated and hasattr(request.user, 'vendor_instance')
        # logger.debug(f"[Permission Check - IsVendorOwnerOrReadOnly - has_permission] IsVendor: {is_vendor}, Method: {request.method}")
        return is_vendor

    def has_object_permission(self, request, view, obj):
        # Read permissions are allowed for any authenticated vendor (already checked by has_permission)
        if request.method in permissions.SAFE_METHODS:
            # logger.debug(f"[Permission Check - IsVendorOwnerOrReadOnly - has_object_permission] SAFE METHOD - Allowed for {request.user.vendor_instance.vendor_id if hasattr(request.user, 'vendor_instance') else 'Unknown'}")
            return True

        # Write permissions require ownership.
        if not hasattr(request.user, 'vendor_instance'):
            logger.warning("[Permission Check - IsVendorOwnerOrReadOnly - has_object_permission] Write denied - user has no vendor_instance.")
            return False # Should not happen if has_permission passed, but safe check

        authenticated_vendor = request.user.vendor_instance
        # logger.debug(f"[Permission Check - IsVendorOwnerOrReadOnly - has_object_permission] Authenticated Vendor: {authenticated_vendor.vendor_id}, Object Type: {type(obj)}")

        # Check direct ownership (e.g., Menu, Order)
        if hasattr(obj, 'vendor'):
            is_owner = obj.vendor == authenticated_vendor
            # logger.debug(f"[Permission Check - IsVendorOwnerOrReadOnly - has_object_permission] Checking obj.vendor: {obj.vendor.vendor_id if obj.vendor else 'None'}, Is Owner: {is_owner}")
            return is_owner
        # Check ownership via Menu (e.g., FoodListing)
        if hasattr(obj, 'menu') and hasattr(obj.menu, 'vendor'):
            is_owner = obj.menu.vendor == authenticated_vendor
            # logger.debug(f"[Permission Check - IsVendorOwnerOrReadOnly - has_object_permission] Checking obj.menu.vendor: {obj.menu.vendor.vendor_id if obj.menu.vendor else 'None'}, Is Owner: {is_owner}")
            return is_owner
        # Check for profile update (obj is Vendor instance)
        if isinstance(obj, Vendor):
            is_owner = obj == authenticated_vendor
            # logger.debug(f"[Permission Check - IsVendorOwnerOrReadOnly - has_object_permission] Checking Vendor instance: {obj.vendor_id}, Is Owner: {is_owner}")
            return is_owner

        logger.warning(f"[Permission Check - IsVendorOwnerOrReadOnly - has_object_permission] Write denied - No ownership link found for object {obj}.")
        return False


class IsOrderVendorOwner(permissions.BasePermission):
    """ Specific permission to check if the requesting vendor owns the order. """
    message = "You do not have permission to view or modify this order."

    def has_permission(self, request, view):
        # Check if user is authenticated and is a vendor
        return request.user and request.user.is_authenticated and hasattr(request.user, 'vendor_instance')

    def has_object_permission(self, request, view, obj):
        # Check if the order's vendor matches the requesting user's vendor instance
        if isinstance(obj, Order) and hasattr(request.user, 'vendor_instance'):
            is_owner = obj.vendor == request.user.vendor_instance
            # logger.debug(f"[Permission Check - IsOrderVendorOwner - has_object_permission] OrderVendor: {obj.vendor.vendor_id}, RequestingVendor: {request.user.vendor_instance.vendor_id}, Is Owner: {is_owner}")
            return is_owner
        logger.warning("[Permission Check - IsOrderVendorOwner - has_object_permission] Denied - Object not Order or user has no vendor_instance.")
        return False
