import jwt
from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework import exceptions
from .models import DeliveryUser

class DeliveryUserJWTAuthentication(BaseAuthentication):
    """
    Custom authentication class for DeliveryUser using JWT.
    Verifies the custom JWT token sent in the Authorization header.
    """
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')

        if not auth_header:
            return None # No token provided

        try:
            # Expecting "Bearer <token>"
            auth_type, token = auth_header.split(' ')
            if auth_type.lower() != 'bearer':
                return None # Not a Bearer token
        except ValueError:
            # Header format is incorrect
            return None

        try:
            payload = jwt.decode(
                token,
                settings.SECRET_KEY,
                algorithms=[settings.SIMPLE_JWT['ALGORITHM']]
            )
        except jwt.ExpiredSignatureError:
            raise exceptions.AuthenticationFailed('Access token expired')
        except jwt.InvalidTokenError:
            raise exceptions.AuthenticationFailed('Invalid token')
        except Exception as e:
             # Log unexpected errors during decoding
             print(f"JWT Decode Error: {e}")
             raise exceptions.AuthenticationFailed('Could not decode token')

        # Check if it's our delivery user token
        if payload.get('user_type') != 'delivery':
            raise exceptions.AuthenticationFailed('Incorrect token type')

        user_id = payload.get('user_id')
        if not user_id:
            raise exceptions.AuthenticationFailed('Token missing user identifier')

        try:
            # Retrieve the DeliveryUser using the id from the token
            user = DeliveryUser.objects.get(id=user_id)
        except DeliveryUser.DoesNotExist:
            raise exceptions.AuthenticationFailed('Delivery user not found')
        except ValueError:
             raise exceptions.AuthenticationFailed('Invalid user identifier in token') # If id is not valid UUID

        if not user.is_active:
            raise exceptions.AuthenticationFailed('User account is disabled')

        # Successfully authenticated
        return (user, token) # Return user and token tuple 