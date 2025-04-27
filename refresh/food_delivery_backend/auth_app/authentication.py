from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, AuthenticationFailed
from django.utils.translation import gettext_lazy as _
from .models import Vendor

import logging
logger = logging.getLogger(__name__)

# Define a simple proxy class
class VendorUserProxy:
    # Mimics necessary attributes for DRF checks
    is_authenticated = True
    is_anonymous = False
    # Add attributes to hold vendor info
    vendor_instance = None
    vendor_id = None

    def __init__(self, vendor=None):
        if vendor:
            self.vendor_instance = vendor
            self.vendor_id = vendor.vendor_id

    # Add other methods if needed by permissions (e.g., has_perm)
    def __str__(self):
        return f"VendorUserProxy({self.vendor_id})"


class VendorJWTAuthentication(JWTAuthentication):
    """
    Authenticates Vendor based on vendor_id claim in JWT.
    Attaches the corresponding Vendor model instance to request.user.vendor_instance
    and the vendor_id to request.user.vendor_id for convenience.
    Sets request.user to an authenticated VendorUserProxy instance.
    """
    def authenticate(self, request):
        header = self.get_header(request)
        if header is None:
            logger.debug("No Authorization header found.")
            return None

        raw_token = self.get_raw_token(header)
        if raw_token is None:
            logger.debug("No raw token found in header.")
            return None

        try:
            validated_token = self.get_validated_token(raw_token)
            logger.debug(f"Validated Token Payload: {validated_token}")
        except InvalidToken as e:
            logger.warning(f"Token validation failed: {e}")
            # Let DRF handle the response for InvalidToken
            raise InvalidToken(e.args[0])
        except Exception as e:
            # Catch other potential validation errors
            logger.error(f"Unexpected error during token validation: {e}", exc_info=True)
            raise AuthenticationFailed(_("Token validation failed unexpectedly."), code="token_not_valid")

        # --- Custom part: Get Vendor from vendor_id claim ---
        # Ensure claim name matches what's used in VendorLoginView when creating token
        vendor_id_claim = validated_token.get('vendor_id')
        if not vendor_id_claim:
            logger.warning("Token validation succeeded but 'vendor_id' claim is missing.")
            raise AuthenticationFailed(_("Token is missing required vendor identification."), code="token_claim_missing")

        try:
            # Fetch the active vendor based on the claim
            vendor_instance = Vendor.objects.get(vendor_id=vendor_id_claim, is_active=True)
            logger.debug(f"Vendor found for vendor_id claim {vendor_id_claim}: {vendor_instance}")
        except Vendor.DoesNotExist:
            logger.warning(f"Vendor with vendor_id {vendor_id_claim} from token not found or not active.")
            raise AuthenticationFailed(_("Vendor account associated with this token not found or is disabled."), code="vendor_not_found")
        except Exception as e:
            logger.error(f"Database error fetching vendor {vendor_id_claim}: {e}", exc_info=True)
            raise AuthenticationFailed(_("Could not retrieve vendor details for authentication."), code="vendor_fetch_error")

        # Use the new VendorUserProxy class
        user_proxy = VendorUserProxy(vendor=vendor_instance)
        # No need to set is_authenticated manually, it's True by default

        logger.debug(f"Authentication successful for vendor {vendor_id_claim}. Attaching vendor proxy to request.user.")
        # Return the user proxy and the validated token
        return (user_proxy, validated_token)
