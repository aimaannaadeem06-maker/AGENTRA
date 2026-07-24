String? validateStrongPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  final upperCaseRegex = RegExp(r'[A-Z]');
  final lowerCaseRegex = RegExp(r'[a-z]');
  final numberRegex = RegExp(r'\d');
  final specialCharRegex = RegExp(r'[!@#\$%&*(),.?":{}|<>\\\[\]\\/\\\\_\-+]');

  if (!upperCaseRegex.hasMatch(value)) {
    return 'Password must include at least one uppercase letter';
  }
  if (!lowerCaseRegex.hasMatch(value)) {
    return 'Password must include at least one lowercase letter';
  }
  if (!numberRegex.hasMatch(value)) {
    return 'Password must include at least one number';
  }
  if (!specialCharRegex.hasMatch(value)) {
    return 'Password must include at least one special character like @, #, %, & or *';
  }
  return null;
}
