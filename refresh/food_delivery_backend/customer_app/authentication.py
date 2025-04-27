from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.conf import settings
import jwt
from accounts.models import Account
from datetime import timedelta, datetime, timezone # Import datetime, timezone

class CustomerJWTAuthentication(BaseAuthentication):
    """
    Custom JWT Authentication for Customer using user_id claim.
    """
    def authenticate(self, request):
        print(request.data)
        print("[DEBUG] CustomerJWTAuthentication attempting authentication...") # Added
        auth_header = request.headers.get('Authorization')

        if not auth_header:
            print("[DEBUG] No Authorization header found.") # Added
            return None  # No token provided

        try:
            # Expecting "Bearer <token>"
            auth_type, token = auth_header.split(' ')
            if auth_type.lower() != 'bearer':
                print(f"[DEBUG] Invalid auth_type: {auth_type}") # Added
                raise AuthenticationFailed('Invalid token header. No credentials provided.')
            print(f"[DEBUG] Received token: {token[:10]}...{token[-10:]}") # Added - Log part of token
        except ValueError:
            print("[DEBUG] Invalid token header format (ValueError).") # Added
            raise AuthenticationFailed('Invalid token header format.')
        except Exception as e:
            print(f"[DEBUG] Error processing token header: {e}") # Added
            raise AuthenticationFailed('Error processing token header.')

        try:
            # Get leeway from settings
            leeway_setting = settings.SIMPLE_JWT.get('LEEWAY', timedelta(seconds=0))
            print(f"[DEBUG] Using leeway: {leeway_setting}") # Added

            # Decode the token using the secret key and leeway
            print("[DEBUG] Attempting jwt.decode...") # Added
            payload = jwt.decode(
                token,
                settings.SECRET_KEY,
                algorithms=settings.SIMPLE_JWT.get('ALGORITHM', "HS256"), # Use algorithm from settings
                leeway=leeway_setting # Pass leeway here
            )
            print(f"[DEBUG] Token decoded successfully. Payload: {payload}") # Added

            # Get user_id and user_type from the payload
            user_id = payload.get(settings.SIMPLE_JWT.get('USER_ID_CLAIM', 'user_id')) # Use claim from settings
            user_type = payload.get('user_type')
            if not user_id or user_type != 'customer':
                print("[DEBUG] Invalid token or user type.") # Added
                raise AuthenticationFailed('Invalid token or user type.')
            print(f"[DEBUG] Found user_id in token: {user_id}") # Added

            # Fetch the user from the database
            try:
                user = Account.objects.get(id=user_id, user_type='customer')
            except Account.DoesNotExist:
                print(f"[DEBUG] Account with user_id {user_id} not found in DB.") # Added
                raise AuthenticationFailed('No such customer account.')
            print(f"[DEBUG] Account found: {user}") # Added

            print(f"[DEBUG] Authentication successful for user {user_id}.") # Added
            return (user, token)

        except jwt.ExpiredSignatureError:
            print("[DEBUG] jwt.ExpiredSignatureError caught!") # Added
            # Log current time vs expiry
            try:
                unverified_payload = jwt.decode(token, options={"verify_signature": False, "verify_exp": False}) # Decode without verification to get claims
                exp_timestamp = unverified_payload.get('exp')
                current_utc_time = datetime.now(timezone.utc)
                current_timestamp = int(current_utc_time.timestamp())
                print(f"[DEBUG] Token 'exp': {exp_timestamp} ({datetime.fromtimestamp(exp_timestamp, timezone.utc) if exp_timestamp else 'N/A'}) UTC")
                print(f"[DEBUG] Current UTC time: {current_timestamp} ({current_utc_time}) UTC")
                print(f"[DEBUG] Difference (current - exp): {current_timestamp - exp_timestamp if exp_timestamp else 'N/A'} seconds")
                print(f"[DEBUG] Leeway applied: {leeway_setting.total_seconds()} seconds")
            except Exception as e_inner:
                print(f"[DEBUG] Could not decode token to check expiry details: {e_inner}")
            raise AuthenticationFailed('Token has expired.')
        except jwt.DecodeError as e:
            print(f"[DEBUG] jwt.DecodeError caught: {e}") # Added
            raise AuthenticationFailed('Error decoding token.')
        except jwt.InvalidTokenError as e:
            print(f"[DEBUG] jwt.InvalidTokenError caught: {e}") # Added
            raise AuthenticationFailed('Invalid token.')
        except Exception as e:
            print(f"[DEBUG] Unexpected authentication error: {e}") # Log the error e for debugging
            raise AuthenticationFailed('Could not authenticate user.')

    def authenticate_header(self, request):
        """
        Return a string value for the WWW-Authenticate header.
        """
        return 'Bearer realm="api"'
