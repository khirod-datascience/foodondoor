class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email address.';
    }
    // Regular expression for email validation
    // Basic regex, consider a more robust one for production
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? validateNotEmpty(String? value, String fieldName) {
     if (value == null || value.trim().isEmpty) { // Use trim() to catch whitespace-only input
      return 'Please enter $fieldName.';
    }
    return null;
  }

  // Add other validators as needed
  /*
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    // Add more complexity checks if needed (e.g., uppercase, number, symbol)
    // final hasUppercase = value.contains(RegExp(r'[A-Z]'));
    // final hasDigits = value.contains(RegExp(r'[0-9]'));
    // final hasLowercase = value.contains(RegExp(r'[a-z]'));
    // final hasSpecialCharacters = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    // if (!hasUppercase || !hasDigits || !hasLowercase || !hasSpecialCharacters) {
    //   return 'Password must include uppercase, lowercase, number, and special character.';
    // }
    return null;
  }
  */
}
