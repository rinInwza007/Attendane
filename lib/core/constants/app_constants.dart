class AppConstants {
  // API Endpoints
  static const String apiBaseUrl = 'https://your-api-url.com';

  // Shared Preferences Keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'student_id';
  static const String userEmailKey = 'user_email';

  // Default Values
  static const int defaultPageSize = 20;
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  // Validation Patterns
  static final RegExp emailPattern =
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp passwordPattern = RegExp(r'^.{6,}$');
  static final RegExp classIdPattern = RegExp(r'^[A-Z0-9]{2,10}$');

  // Error Messages
  static const String defaultErrorMessage =
      'Something went wrong. Please try again.';
  static const String connectionErrorMessage =
      'Network connection error. Please check your internet connection.';
  static const String authErrorMessage =
      'Authentication failed. Please check your credentials.';

  // Success Messages
  static const String loginSuccessMessage = 'Login successful';
  static const String registerSuccessMessage = 'Registration successful';
  static const String profileUpdateSuccessMessage =
      'Profile updated successfully';
  static const String classCreatedSuccessMessage = 'Class created successfully';

  // Face Recognition
  static const int faceModelInputSize = 112;
  static const int faceEmbeddingSize = 128;
}
